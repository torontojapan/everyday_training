import Foundation

/// アプリ全体の機能フラグ。リリースで段階的に出す機能をここで一元管理する。
enum AppFeatureFlags {
    /// 友達機能を有効にするか。
    ///
    /// v1 では **本番(Release)で非表示**。理由: 現状の友達バックエンドは
    /// `MockFriendsService` (端末ローカルのみ) で、本番では実際に友達と
    /// つながらない。CloudKit 実装が済むまで出すと「動かない機能を出す」
    /// 事故になるため隠す (QA チェックリスト L)。
    ///
    /// - Release: 常に `false`。外部から有効化する手段は無い。
    /// - DEBUG: 既定 `false` (スクショ/デモでも誤って写り込まないように)。
    ///   UI テストや手動確認で friends 画面を見たいときだけ
    ///   `--enable-friends` 起動引数で opt-in する。
    ///
    /// CloudKit 実装後は `true` 固定 (または本フラグ自体を撤去) する。
    static let friendsEnabled: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--enable-friends")
        #else
        return false
        #endif
    }()

    /// 友達機能が無効なときに到達してはいけないルートを `.home` に振り替える。
    /// ディープリンク (`goexercise://friends` 等) や `--initial-route` で
    /// friends/weeklyRanking に飛ばされても、隠している間はホームに着地させる。
    static func resolvedRoute(_ route: AppRoute, friendsEnabled: Bool = AppFeatureFlags.friendsEnabled) -> AppRoute {
        guard !friendsEnabled else { return route }
        switch route {
        case .friends, .weeklyRanking:
            return .home
        default:
            return route
        }
    }
}
