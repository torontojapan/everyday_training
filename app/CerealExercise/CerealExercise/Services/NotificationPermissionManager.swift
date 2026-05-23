import Foundation
import UserNotifications

extension UNNotificationSettings: @retroactive @unchecked Sendable {}

@MainActor
protocol NotificationPermissionManaging: AnyObject {
    func requestAuthorizationIfNeeded() async
}

@MainActor
final class NotificationPermissionManager: NotificationPermissionManaging {
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let requestedKey = "notif.permission.requested"

    init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
    }

    func requestAuthorizationIfNeeded() async {
        guard !defaults.bool(forKey: requestedKey) else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        defaults.set(true, forKey: requestedKey)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
}
