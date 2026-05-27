import Foundation
import OSLog
import UserNotifications

private let notificationLogger = Logger(subsystem: "com.serial.cerealexercise", category: "NotificationScheduler")

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
}

extension UNUserNotificationCenter: @retroactive @unchecked Sendable {}
extension UNUserNotificationCenter: NotificationScheduling {}

@MainActor
final class NotificationScheduler {
    static let morningIdentifier = "notif.morning"
    static let eveningIdentifier = "notif.evening"

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
        cancelToday()

        guard settings.isEnabled, settings.notificationCount > 0, !todayAchieved else { return }

        // Codex UX #6: 通知の性格モードに応じて scheduling を変える。
        // - voice (デフォルト): 朝 + 夕方 の現状仕様
        // - quiet: 夕方 1 通のみ、しかも streak が "危険" (=ある or 週進捗あり)
        //   なときだけ。何もない真新規ユーザーには夕方も鳴らない。
        // - friendDriven: 日常リマインダーは抑制 (push 基盤未完成のため
        //   degrade: quiet と同等の振る舞いで本日 1 通も鳴らないケースも許容)。
        let personality = NotificationPersonalityPreferences.shared.current
        let streakAtRisk = currentStreak > 0 || weeklyProgressRate > 0
        switch personality {
        case .voice:
            await schedule(identifier: Self.morningIdentifier, time: settings.morning,
                           slot: .morning, personality: personality,
                           currentStreak: currentStreak, weeklyProgressRate: weeklyProgressRate)
            if settings.notificationCount > 1 {
                await schedule(identifier: Self.eveningIdentifier, time: settings.evening,
                               slot: .evening, personality: personality,
                               currentStreak: currentStreak, weeklyProgressRate: weeklyProgressRate)
            }
        case .quiet:
            guard streakAtRisk else { return }
            await schedule(identifier: Self.eveningIdentifier, time: settings.evening,
                           slot: .evening, personality: personality,
                           currentStreak: currentStreak, weeklyProgressRate: weeklyProgressRate)
        case .friendDriven:
            // 友達 push が来たときだけ反応する設計。日常 push は鳴らさない。
            // (将来 CloudKit + push 完成後、ここで CKQuerySubscription を読んで
            // 必要時のみ alert を投げる予定。)
            return
        }
    }

    func cancelToday() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.morningIdentifier, Self.eveningIdentifier])
    }

    func rescheduleAfterAchievement(currentStreak: Int, weeklyProgressRate: Double) async {
        await scheduleDaily(todayAchieved: true, currentStreak: currentStreak, weeklyProgressRate: weeklyProgressRate)
    }

    private func schedule(
        identifier: String,
        time: NotificationTime,
        slot: NotificationSlot,
        personality: NotificationPersonality,
        currentStreak: Int,
        weeklyProgressRate: Double
    ) async {
        var components = DateComponents()
        components.calendar = calendar
        components.hour = time.hour
        components.minute = time.minute

        let content = UNMutableNotificationContent()
        content.title = "GOエクササイズ"
        content.body = NotificationMessageProvider.message(
            for: slot,
            personality: personality,
            currentStreak: currentStreak,
            weeklyProgressRate: weeklyProgressRate,
            seedDate: dateProvider.currentDate(),
            calendar: calendar
        )
        content.sound = .default
        // Tap on the reminder should jump straight to the record screen.
        // AppDelegate reads this and forwards into DeepLinkRouter.
        content.userInfo = ["route": AppRoute.record.rawValue]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            // Surface the failure via os_log so it shows up in Console.app
            // without crashing the app. Common causes: permission denied,
            // App Group / entitlement mismatch, or trigger malformed.
            notificationLogger.error("Failed to schedule notification \(identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
