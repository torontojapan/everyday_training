import UIKit
import UserNotifications

/// Bridges UIKit-only callbacks (notification taps) into SwiftUI by forwarding
/// the route info into `DeepLinkRouter.shared`. SwiftUI observes the router
/// and applies the route override.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        return true
    }
}

/// Separate NSObject so we can keep the AppDelegate free of UN delegate
/// methods (those need nonisolated declarations under Swift 6 strict
/// concurrency, while AppDelegate-level UIApplicationDelegate methods are
/// fine at the default isolation).
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    // Allow notifications to show their banner even when the app is in the
    // foreground — daily reminders that pop while the user is browsing
    // history are still useful and we'd rather surface them than swallow them.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let routeKey = response.notification.request.content.userInfo["route"] as? String
        Task { @MainActor in
            // route キー欠落時の既定はホーム。`.record` だと通知タップで全画面が
            // 文脈のない記録入力に置き換わる(Claude 監査)。自前通知は常に route=home を付与する。
            let route = routeKey.flatMap(AppRoute.init(rawValue:)) ?? .home
            DeepLinkRouter.shared.pendingRoute = route
        }
        completionHandler()
    }
}
