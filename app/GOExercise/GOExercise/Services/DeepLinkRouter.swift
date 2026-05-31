import Foundation
import Observation

/// All routes the app can deep-link into. Single source of truth used by:
///   - `--initial-route` launch arg (UI tests, screenshots)
///   - `goexercise://<host>` URL scheme via `.onOpenURL`
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
    /// QR/ディープリンク (`goexercise://friends?code=XXX`) で渡された友達コード。
    /// FriendsView が表示時に消費し、友達追加画面をプリフィルして開く。
    /// feature flag でゲートされ home に振り替わる場合は `resolve` が nil を返す。
    var pendingFriendCode: String? = nil

    /// Parse a `goexercise://<host>[/path]` URL into an AppRoute.
    /// Returns nil for unknown schemes or unsupported hosts.
    static func route(from url: URL) -> AppRoute? {
        guard url.scheme?.lowercased() == "goexercise" else { return nil }
        let key = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        return AppRoute(rawValue: key)
    }

    /// `?code=` クエリを抽出し `FriendCodeValidator` で正規化・検証する (Codex#6)。
    /// 不在/不正なら nil。
    static func friendCode(from url: URL) -> String? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let raw = comps.queryItems?.first(where: { $0.name == "code" })?.value else { return nil }
        let sanitized = FriendCodeValidator.sanitize(raw)
        return FriendCodeValidator.isValid(sanitized) ? sanitized : nil
    }

    /// route をパースし feature flag でゲートする。**friends に着地する時だけ**
    /// 検証済みコードを返す (home へ振替時は code を破棄 = Codex#1)。純粋関数でテスト可。
    static func resolve(url: URL,
                        friendsEnabled: Bool = AppFeatureFlags.friendsEnabled) -> (route: AppRoute?, friendCode: String?) {
        guard let raw = route(from: url) else { return (nil, nil) }
        let gated = AppFeatureFlags.resolvedRoute(raw, friendsEnabled: friendsEnabled)
        let code = (gated == .friends) ? friendCode(from: url) : nil
        return (gated, code)
    }
}
