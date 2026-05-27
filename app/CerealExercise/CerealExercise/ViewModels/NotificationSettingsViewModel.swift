import Foundation
import Observation
import UserNotifications

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
        // Codex round1 priority 1: 設定変更時の reschedule で
        // currentStreak/weeklyProgressRate に 0 を固定値で渡すと、quiet 性格
        // モードでは streakAtRisk=false 扱いで全 reminder が消えるバグになる。
        // 直近の WidgetSnapshot から実際の状態を読んで渡す (Widget は記録の
        // たびに publish されるので最新)。
        let snapshot = SharedSnapshotStore().read()
        let weeklyRate = snapshot.weeklyTotal > 0
            ? Double(snapshot.weeklyAchieved) / Double(snapshot.weeklyTotal)
            : 0
        await NotificationScheduler(settings: settings, calendar: calendar).scheduleDaily(
            todayAchieved: snapshot.todayAchieved,
            currentStreak: snapshot.currentStreak,
            weeklyProgressRate: weeklyRate
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
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

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

    var shouldShowPermissionWarning: Bool {
        authorizationStatus == .denied || authorizationStatus == .notDetermined
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await permissionManager.authorizationStatus()
    }

    /// 通知の性格モードが UI で変更された時、現在の settings で reschedule を
    /// やり直す (旧モードで登録された pending request を捨てて新モードで再登録)。
    /// Codex round1 priority 1 で「設定を変えても即座に反映されない」を解消。
    func rescheduleForCurrentSettings() async {
        await persistAndApply()
    }

    func setEnabled(_ enabled: Bool) async {
        isEnabled = enabled
        if enabled {
            if notificationCount == 0 {
                notificationCount = 1
            }
            await permissionManager.requestAuthorizationIfNeeded()
            await refreshAuthorizationStatus()
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
            await refreshAuthorizationStatus()
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
