import Foundation

/// アプリ全体の機能フラグ。リリースで段階的に出す機能をここで一元管理する。
enum AppFeatureFlags {
    /// 友達機能を有効にするか。
    ///
    /// 友達機能の有効化フラグ。
    ///
    /// **2026-05-31 (v1.1) で解禁**: 友達バックエンドを CloudKit から
    /// プラットフォーム中立な **Supabase** へ移行し、REST 疎通 + iOS 実コード
    /// 書込 + 3LLM 監査 + Codex レビューを通過したため `true` に変更。
    /// これ1つでタブ/iPad sidebar/設定/通知/オンボ/ディープリンクの全導線が復帰する。
    ///
    /// v1.0 (友達非表示) では `false` だった。解禁に伴い App Privacy ラベルを
    /// 「収集なし → User Content / Identifiers (App機能・トラッキングなし)」に更新する。
    static let friendsEnabled = true

    /// 友達紹介(リファラル)を有効にするか。友達 BE 前提なので friendsEnabled と AND で使う。
    /// 単独で false にすれば紹介 UI/ポーリングだけを止められる(キルスイッチ)。
    static let referralEnabled = true

    /// 紹介機能を出してよいか(友達が有効 かつ 紹介が有効)。
    static var isReferralActive: Bool { friendsEnabled && referralEnabled }

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
