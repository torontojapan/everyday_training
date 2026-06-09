import Foundation

/// 友達アカウントの「バックアップ(永続化)」連携プロバイダ。
/// 匿名 uid を保持したまま Apple/Google identity を連結し、機種変・再インストールでも復旧可能にする
/// (懸念①の根治)。連携は任意で、匿名のままでも全機能使える。
enum FriendsLinkProvider: String, Sendable, CaseIterable {
    case apple
    case google

    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        }
    }
}

/// アカウント連携の結果/エラー。
enum AccountLinkError: LocalizedError, Equatable {
    /// その Apple/Google ID が既に別アカウントに紐付いている (identity_already_exists)。
    /// マージはせず「既存アカウントに切替 / 中止」の二択を提示する。
    case alreadyLinkedToAnotherAccount
    /// サーバ側でそのプロバイダが未設定/無効 (provider_disabled 等)。誤設定の保険。
    case providerUnavailable
    /// ユーザーがキャンセルした。
    case cancelled
    /// バックエンド未接続。
    case backendUnavailable
    /// その他 (やさしい固定文で表示し、生エラーは出さない)。
    case failed

    var errorDescription: String? {
        switch self {
        case .alreadyLinkedToAnotherAccount:
            return "このアカウントは既に別のデータに紐づいています。"
        case .providerUnavailable:
            return "ただいまこの方法は利用できません。"
        case .cancelled:
            return "キャンセルされました。"
        case .backendUnavailable:
            return "友達機能につながれませんでした。"
        case .failed:
            return "バックアップに失敗しました。通信状況を確認してお試しください。"
        }
    }
}

/// 復元 (`restoreWithApple` / `restoreWithGoogle`) の成否内訳。新端末/再インストールで
/// welcome から実行する。`Store` 側でこれに `failed`/`cancelled` を足して UI へ渡す
/// ([[FriendsStore]].RestoreResult)。Apple/Google で意味は同一なので provider-neutral。
enum RestoreOutcome: Equatable, Sendable {
    /// その Apple/Google ID に紐づく既存プロフィールが見つかり、ロードした (友達/コードが戻る)。
    case restored
    /// 既存データが無く、新規アカウントとして作成した (実質サインアップ)。
    case created
}

/// Google 連携 (web/PKCE) の認可フロー。認可 URL を ASWebAuthenticationSession で開き、
/// `goexercise://` のコールバック URL を返す。View が [[GoogleSignInCoordinator]] を渡し、
/// Service 側 (Supabase) が前後で認可 URL 生成と PKCE code 交換 (`session(from:)`) を行う。
/// Apple はネイティブ id_token なので不要 (経路が違う)。
typealias WebAuthFlow = @MainActor (_ url: URL) async throws -> URL

/// 連携状態 (UI 表示用)。
struct AccountBackupStatus: Equatable, Sendable {
    /// 永続アカウントに連携済み (= 匿名でない)。
    var isBackedUp: Bool
    /// 連携済みプロバイダ名 (表示用、任意)。
    var providerName: String?

    static let anonymous = AccountBackupStatus(isBackedUp: false, providerName: nil)
}
