import Foundation

/// 匿名サインイン時の CAPTCHA トークン取得を抽象化する。
///
/// 設計 (懸念②: 匿名サインインのスクリプト量産を遮断):
/// - **config-gated**: Cloudflare Turnstile の site key (`SupabaseConfig.turnstileSiteKey`,
///   Secrets.xcconfig → Info.plist 経由) が空の間は CAPTCHA 無効。
/// - 無効時は `obtainTokenIfNeeded()` が `nil` を返し、`signInAnonymously(captchaToken: nil)`
///   = **従来挙動を厳密に維持**する (現行ビルドはバイト互換)。
/// - 有効時のみ Turnstile チャレンジを実行してトークンを返す ([[TurnstileCaptchaTokenProvider]])。
///   サーバ側で CAPTCHA を ON にするのは、このトークン送信が動作するビルドの配信後にすること
///   (順序を誤るとサインインが実行時に失敗する。`supabase/schema.sql` の手順参照)。
protocol CaptchaTokenProviding: Sendable {
    /// CAPTCHA が必要ならトークンを取得して返す。無効 (site key 未設定) なら `nil`。
    func obtainTokenIfNeeded() async throws -> String?
}

/// CAPTCHA 無効時の no-op。常に `nil` を返す (= 現行の匿名サインイン挙動)。
struct NoCaptchaTokenProvider: CaptchaTokenProviding {
    func obtainTokenIfNeeded() async throws -> String? { nil }
}

/// CAPTCHA トークン取得時のエラー。
enum CaptchaError: LocalizedError {
    case challengeFailed(String)
    case cancelled
    case timedOut
    case presentationUnavailable

    var errorDescription: String? {
        switch self {
        case .challengeFailed(let m): return "CAPTCHA の確認に失敗しました (\(m))"
        case .cancelled: return "CAPTCHA の確認がキャンセルされました"
        case .timedOut: return "CAPTCHA の確認がタイムアウトしました"
        case .presentationUnavailable: return "CAPTCHA を表示できませんでした"
        }
    }
}
