import XCTest
@testable import GOExercise

/// CAPTCHA の config-gating とトークン取得の抽象を検証する。
/// 実 Turnstile webview 経路は実機 + 実キーでの手動確認 (ここでは到達しない)。
final class CaptchaTests: XCTestCase {

    // MARK: - config gating

    func testCaptchaDisabledWhenSiteKeyEmpty() {
        XCTAssertFalse(SupabaseConfig.isCaptchaEnabled(siteKey: ""))
        XCTAssertFalse(SupabaseConfig.isCaptchaEnabled(siteKey: "   "))
        XCTAssertFalse(SupabaseConfig.isCaptchaEnabled(siteKey: "\n\t"))
    }

    func testCaptchaEnabledWhenSiteKeyPresent() {
        XCTAssertTrue(SupabaseConfig.isCaptchaEnabled(siteKey: "0x4AAA..."))
        // 前後空白は無視して有効判定。
        XCTAssertTrue(SupabaseConfig.isCaptchaEnabled(siteKey: "  0x4AAA...  "))
    }

    // MARK: - no-op provider (現行ビルドの既定)

    func testNoCaptchaProviderReturnsNil() async throws {
        let token = try await NoCaptchaTokenProvider().obtainTokenIfNeeded()
        XCTAssertNil(token, "CAPTCHA 無効時は nil = signInAnonymously(captchaToken: nil) で従来挙動")
    }

    // MARK: - provider 抽象が token を返せること (スタブ)

    func testStubProviderReturnsToken() async throws {
        struct StubProvider: CaptchaTokenProviding {
            let value: String?
            func obtainTokenIfNeeded() async throws -> String? { value }
        }
        let token = try await StubProvider(value: "tok-123").obtainTokenIfNeeded()
        XCTAssertEqual(token, "tok-123")
        let none = try await StubProvider(value: nil).obtainTokenIfNeeded()
        XCTAssertNil(none)
    }

    // MARK: - エラー文言

    func testCaptchaErrorDescriptions() {
        XCTAssertNotNil(CaptchaError.cancelled.errorDescription)
        XCTAssertNotNil(CaptchaError.timedOut.errorDescription)
        XCTAssertNotNil(CaptchaError.presentationUnavailable.errorDescription)
        XCTAssertNotNil(CaptchaError.challengeFailed("x").errorDescription)
    }
}
