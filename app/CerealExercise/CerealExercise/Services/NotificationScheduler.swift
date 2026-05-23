import Foundation
import UserNotifications

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
        calendar: Calendar = .current
    ) {
        self.center = center
        self.settings = settings
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    func scheduleDaily(todayAchieved: Bool, currentStreak: Int, weeklyProgressRate: Double) async {
        cancelToday()

        guard settings.isEnabled, settings.notificationCount > 0, !todayAchieved else { return }

        await schedule(
            identifier: Self.morningIdentifier,
            time: settings.morning,
            slot: .morning,
            currentStreak: currentStreak,
            weeklyProgressRate: weeklyProgressRate
        )
        if settings.notificationCount > 1 {
            await schedule(
                identifier: Self.eveningIdentifier,
                time: settings.evening,
                slot: .evening,
                currentStreak: currentStreak,
                weeklyProgressRate: weeklyProgressRate
            )
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
        currentStreak: Int,
        weeklyProgressRate: Double
    ) async {
        var components = DateComponents()
        components.calendar = calendar
        components.hour = time.hour
        components.minute = time.minute

        let content = UNMutableNotificationContent()
        content.title = "シリアルエクササイズ"
        content.body = NotificationMessageProvider.message(
            for: slot,
            currentStreak: currentStreak,
            weeklyProgressRate: weeklyProgressRate,
            seedDate: dateProvider.currentDate(),
            calendar: calendar
        )
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
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
