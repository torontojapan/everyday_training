import Foundation
import Observation

/// All routes the app can deep-link into. Single source of truth used by:
///   - `--initial-route` launch arg (UI tests, screenshots)
///   - `cerealexercise://<host>` URL scheme via `.onOpenURL`
///   - Notification taps (NotificationDelegate writes the matching value)
///   - In-app navigation overrides (Home -> Settings back button, etc.)
enum AppRoute: String {
    case home
    case record
    case history
    case settings
    case notificationSettings = "notification-settings"
    case streakShare = "streak-share"
    case friends
    case weeklyRanking = "weekly-ranking"
    case league
}

@MainActor
@Observable
final class RouteState {
    var override: AppRoute? = nil
}

/// Singleton bridge so non-SwiftUI callbacks (URL scheme handler, notification
/// delegate) can hand routes to the SwiftUI layer. The app observes
/// `pendingRoute` and forwards it into `RouteState.override`.
@MainActor
@Observable
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()
    var pendingRoute: AppRoute? = nil

    /// Parse a `cerealexercise://<host>[/path]` URL into an AppRoute.
    /// Returns nil for unknown schemes or unsupported hosts.
    static func route(from url: URL) -> AppRoute? {
        guard url.scheme?.lowercased() == "cerealexercise" else { return nil }
        let key = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        return AppRoute(rawValue: key)
    }
}
