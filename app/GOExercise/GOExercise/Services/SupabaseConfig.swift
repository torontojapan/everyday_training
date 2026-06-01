import Foundation

/// Supabase 接続情報。値は Secrets.xcconfig (gitignore) → Info.plist 経由で注入。
/// 空の間は `isConfigured == false` で friends は Mock にフォールバックする。
enum SupabaseConfig {
    static var host: String {
        (Bundle.main.object(forInfoDictionaryKey: "SupabaseHost") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static var anonKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /// xcconfig は scheme を書けない (`//` がコメント) ため host のみ保存し、ここで https を付与。
    static var url: URL? {
        guard !host.isEmpty else { return nil }
        return URL(string: "https://\(host)")
    }
    static var isConfigured: Bool { url != nil && !anonKey.isEmpty }

    /// Cloudflare Turnstile の site key。Secrets.xcconfig (`TURNSTILE_SITE_KEY`) → Info.plist
    /// (`TurnstileSiteKey`) 経由で注入。空の間は CAPTCHA 無効 = 匿名サインインは
    /// captchaToken なし (従来挙動)。値が入った時のみ [[TurnstileCaptchaTokenProvider]] を使う。
    static var turnstileSiteKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "TurnstileSiteKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /// site key が設定されているときだけ CAPTCHA を要求する。
    static var isCaptchaEnabled: Bool { isCaptchaEnabled(siteKey: turnstileSiteKey) }
    /// テスト可能な純粋判定 (Info.plist に依存しない)。
    static func isCaptchaEnabled(siteKey: String) -> Bool {
        !siteKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - アカウント連携 (Phase 2: 機種変復旧。config-gated)

    /// Apple 連携を有効にするか。Info.plist `FriendsAppleLinkEnabled` (Bool)。
    /// 既定 false。capability 追加 + Supabase の Apple provider 設定が済んだら true にする。
    static var appleLinkEnabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "FriendsAppleLinkEnabled") as? Bool) ?? false
    }
    /// Google 連携を有効にするか。Info.plist `FriendsGoogleLinkEnabled` (Bool)。
    /// 既定 false。Supabase の Google provider + redirect URL 設定が済んだら true にする。
    static var googleLinkEnabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "FriendsGoogleLinkEnabled") as? Bool) ?? false
    }
    /// いずれかの連携が有効か (バックアップカードの表示ゲート)。
    static var isAccountLinkingEnabled: Bool { appleLinkEnabled || googleLinkEnabled }
}
