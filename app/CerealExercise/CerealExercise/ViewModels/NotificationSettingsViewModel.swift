import Foundation
import Observation

@MainActor
protocol NotificationSettingsScheduling: AnyObject {
    func apply(settings: NotificationSettings) async
}

@MainActor
final class NotificationSettingsScheduler: NotificationSettingsScheduling {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func apply(settings: NotificationSettings) async {
        await NotificationScheduler(settings: settings, calendar: calendar).scheduleDaily(
            todayAchieved: false,
            currentStreak: 0,
            weeklyProgressRate: 0
        )
    }
}

@MainActor
@Observable
final class NotificationSettingsViewModel {
    private let store: NotificationSettingsStore
    private let scheduler: any NotificationSettingsScheduling
    private let permissionManager: any NotificationPermissionManaging

    private(set) var isEnabled: Bool
    private(set) var notificationCount: Int
    private(set) var firstTime: Date
    private(set) var secondTime: Date

    init(
        store: NotificationSettingsStore = NotificationSettingsStore(),
        scheduler: (any NotificationSettingsScheduling)? = nil,
        permissionManager: (any NotificationPermissionManaging)? = nil,
        calendar: Calendar = .current
    ) {
        self.store = store
        self.scheduler = scheduler ?? NotificationSettingsScheduler(calendar: calendar)
        self.permissionManager = permissionManager ?? NotificationPermissionManager()

        let settings = store.load()
        self.isEnabled = settings.isEnabled
        self.notificationCount = settings.notificationCount
        self.firstTime = Self.date(from: settings.morning, calendar: calendar)
        self.secondTime = Self.date(from: settings.evening, calendar: calendar)
    }

    var firstTimeComponents: DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: firstTime)
    }

    var secondTimeComponents: DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: secondTime)
    }

    func setEnabled(_ enabled: Bool) async {
        isEnabled = enabled
        if enabled {
            if notificationCount == 0 {
                notificationCount = 1
            }
            await permissionManager.requestAuthorizationIfNeeded()
        } else {
            notificationCount = 0
        }
        await persistAndApply()
    }

    func setNotificationCount(_ count: Int) async {
        notificationCount = max(0, min(2, count))
        isEnabled = notificationCount > 0
        if isEnabled {
            await permissionManager.requestAuthorizationIfNeeded()
        }
        await persistAndApply()
    }

    func setFirstTime(_ date: Date) async {
        firstTime = date
        await persistAndApply()
    }

    func setSecondTime(_ date: Date) async {
        secondTime = date
        await persistAndApply()
    }

    func setFirstTime(hour: Int, minute: Int) async {
        firstTime = Self.date(from: NotificationTime(hour: hour, minute: minute), calendar: .current)
        await persistAndApply()
    }

    func setSecondTime(hour: Int, minute: Int) async {
        secondTime = Self.date(from: NotificationTime(hour: hour, minute: minute), calendar: .current)
        await persistAndApply()
    }

    private func persistAndApply() async {
        let settings = currentSettings
        store.save(settings)
        await scheduler.apply(settings: settings)
    }

    private var currentSettings: NotificationSettings {
        NotificationSettings(
            isEnabled: isEnabled,
            notificationCount: notificationCount,
            morning: Self.time(from: firstTime),
            evening: Self.time(from: secondTime)
        )
    }

    private static func date(from time: NotificationTime, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: time.hour, minute: time.minute)) ?? Date()
    }

    private static func time(from date: Date) -> NotificationTime {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return NotificationTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }
}
