import Foundation
import OSLog
import UserNotifications

private let notificationLogger = Logger(subsystem: "com.goexercise.app", category: "NotificationScheduler")

struct NotificationTime: Equatable, Sendable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}

struct NotificationSettings: Equatable, Sendable {
    let isEnabled: Bool
    let notificationCount: Int
    let morning: NotificationTime
    let evening: NotificationTime

    init(
        isEnabled: Bool = true,
        notificationCount: Int = 2,
        morning: NotificationTime = NotificationTime(hour: 8, minute: 30),
        evening: NotificationTime = NotificationTime(hour: 20, minute: 0)
    ) {
        self.isEnabled = isEnabled
        self.notificationCount = notificationCount
        self.morning = morning
        self.evening = evening
    }
}

protocol NotificationScheduling: AnyObject, Sendable {
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeAllPendingNotificationRequests()
}

extension UNUserNotificationCenter: @retroactive @unchecked Sendable {}
extension UNUserNotificationCenter: NotificationScheduling {}

@MainActor
final class NotificationScheduler {
    static let morningIdentifier = "notif.morning"
    static let eveningIdentifier = "notif.evening"
    /// 先のぶんまで one-shot 通知を予約しておく日数。
    /// `repeats:true` の単一トリガーだと「達成日に cancel → 繰り返しごと消える」
    /// 問題があったため、ローリングで N 日分の **one-shot** を貼る方式に変更
    /// (3 LLM 監査 B-Major-2)。これによりアプリを数日開かなくてもリマインドが届く。
    /// iOS の保留上限 64 件に対し N=7 × 2 枠 = 14 件で十分余裕がある。
    static let rollingDays = 7

    private let center: any NotificationScheduling
    private let settings: NotificationSettings
    private let dateProvider: any DateProviding
    private let calendar: Calendar

    init(
        center: any NotificationScheduling = UNUserNotificationCenter.current(),
        settings: NotificationSettings = NotificationSettingsStore().load(),
        dateProvider: any DateProviding = SystemDateProvider(),
        // Default to .mondayFirst to stay aligned with the rest of the app
        // (weekly streak / progress logic all start on Monday). Using
        // .current here used to drift week boundaries depending on the
        // user's locale and silently de-sync notification gating from the
        // displayed weekly progress.
        calendar: Calendar = .mondayFirst
    ) {
        self.center = center
        self.settings = settings
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    func scheduleDaily(todayAchieved: Bool, currentStreak: Int, weeklyProgressRate: Double) async {
        // 保留中の通知を全消去してローリング window を貼り直す。これにより
        // 「達成日だけ抑制し、翌日以降は残す」を full rebuild で実現する
        // (旧 repeats:true + cancelToday は将来の繰り返しごと消していた)。
        center.removeAllPendingNotificationRequests()

        guard settings.isEnabled, settings.notificationCount > 0 else { return }

        // Codex UX #6: 通知の性格モードに応じて scheduling を変える。
        // - voice (デフォルト): 朝 + 夕方
        // - quiet: 夕方 1 通のみ、しかも streak が "危険" (=ある or 週進捗あり) なときだけ
        // - friendDriven: 日常リマインダーは抑制
        let personality = NotificationPersonalityPreferences.shared.current
        if personality == .friendDriven { return }
        let streakAtRisk = currentStreak > 0 || weeklyProgressRate > 0
        if personality == .quiet, !streakAtRisk { return }

        let now = dateProvider.currentDate()
        // 「今日 + 翌日以降 rollingDays 日」を常に対象にする (offset 0...rollingDays)。
        // 今日分は達成済み or 発火時刻超過でスキップされ得るが、翌日以降の
        // rollingDays 日分は必ず未来なので、どのケースでも将来 rollingDays 日の
        // カバレッジを保証できる (Codex 指摘の off-by-one / 時刻超過の両方を解消)。
        for offset in 0...Self.rollingDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let isToday = offset == 0
            // 今日達成済みなら今日分だけスキップ。将来分は残す (= B-Major-2 の肝)。
            if isToday && todayAchieved { continue }

            if personality != .quiet {
                // voice / cheer / spartan / cool / tsundere: 朝+夕の標準スケジュール。
                // トーン(声掛けの性格)が違うだけで頻度は voice と同じ。
                await scheduleOneShot(slot: .morning, time: settings.morning, day: day,
                                      isToday: isToday, now: now, personality: personality,
                                      currentStreak: currentStreak, weeklyProgressRate: weeklyProgressRate)
                if settings.notificationCount > 1 {
                    await scheduleOneShot(slot: .evening, time: settings.evening, day: day,
                                          isToday: isToday, now: now, personality: personality,
                                          currentStreak: currentStreak, weeklyProgressRate: weeklyProgressRate)
                }
            } else { // .quiet (atRisk は上で確認済み)
                await scheduleOneShot(slot: .evening, time: settings.evening, day: day,
                                      isToday: isToday, now: now, personality: personality,
                                      currentStreak: currentStreak, weeklyProgressRate: weeklyProgressRate)
            }
        }
    }

    /// 今日分の通知だけを取り消す (将来分は残す)。
    func cancelToday() {
        let today = dateProvider.currentDate()
        center.removePendingNotificationRequests(withIdentifiers: [
            identifier(slot: .morning, day: today),
            identifier(slot: .evening, day: today)
        ])
    }

    func rescheduleAfterAchievement(currentStreak: Int, weeklyProgressRate: Double) async {
        await scheduleDaily(todayAchieved: true, currentStreak: currentStreak, weeklyProgressRate: weeklyProgressRate)
    }

    /// 日付ごとに一意な identifier。例: `notif.morning.20260528`。
    /// これで「今日分だけ cancel」が可能になり、将来の予約を巻き込まない。
    private func identifier(slot: NotificationSlot, day: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        let key = slot == .morning ? "morning" : "evening"
        return String(format: "notif.%@.%04d%02d%02d", key, c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func scheduleOneShot(
        slot: NotificationSlot,
        time: NotificationTime,
        day: Date,
        isToday: Bool,
        now: Date,
        personality: NotificationPersonality,
        currentStreak: Int,
        weeklyProgressRate: Double
    ) async {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = time.hour
        components.minute = time.minute
        components.calendar = calendar
        guard let fireDate = calendar.date(from: components) else { return }
        // 今日分で発火時刻が既に過ぎていたら one-shot は鳴らないのでスキップ。
        if isToday && fireDate <= now { return }

        let content = UNMutableNotificationContent()
        content.title = "GO エクササイズ"
        content.body = NotificationMessageProvider.message(
            for: slot,
            personality: personality,
            currentStreak: currentStreak,
            weeklyProgressRate: weeklyProgressRate,
            seedDate: fireDate,
            calendar: calendar
        )
        content.sound = .default
        // タップしたらまずホーム (猫劇場) を見せる。記録は CTA からすぐ起こせる。
        content.userInfo = ["route": AppRoute.home.rawValue]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(slot: slot, day: day),
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            notificationLogger.error("Failed to schedule notification \(request.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

struct NotificationSettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> NotificationSettings {
        let enabled = defaults.object(forKey: "notif.enabled") as? Bool ?? true
        let count = defaults.object(forKey: "notif.count") as? Int ?? 2
        let morningHour = defaults.object(forKey: "notif.morning.hour") as? Int ?? 8
        let morningMinute = defaults.object(forKey: "notif.morning.minute") as? Int ?? 30
        let eveningHour = defaults.object(forKey: "notif.evening.hour") as? Int ?? 20
        let eveningMinute = defaults.object(forKey: "notif.evening.minute") as? Int ?? 0

        let notificationCount = enabled ? max(0, min(2, count)) : 0
        return NotificationSettings(
            isEnabled: enabled && notificationCount > 0,
            notificationCount: notificationCount,
            morning: NotificationTime(hour: morningHour, minute: morningMinute),
            evening: NotificationTime(hour: eveningHour, minute: eveningMinute)
        )
    }

    func save(_ settings: NotificationSettings) {
        defaults.set(settings.isEnabled, forKey: "notif.enabled")
        defaults.set(max(0, min(2, settings.notificationCount)), forKey: "notif.count")
        defaults.set(settings.morning.hour, forKey: "notif.morning.hour")
        defaults.set(settings.morning.minute, forKey: "notif.morning.minute")
        defaults.set(settings.evening.hour, forKey: "notif.evening.hour")
        defaults.set(settings.evening.minute, forKey: "notif.evening.minute")
    }
}
