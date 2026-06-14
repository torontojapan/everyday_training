import XCTest
@testable import GOExercise

/// 分析オプトアウトの gate / teardown 回帰テスト(MEDIUM 3_privacy)。
/// 旧実装は track の gate のみで、OFF にしても初期化済み SDK がセッション中 live のままだった。
@MainActor
final class AnalyticsOptOutTests: XCTestCase {

    private final class SpyAnalytics: AnalyticsService, @unchecked Sendable {
        private(set) var count = 0
        func track(_ event: AnalyticsEvent) { count += 1 }
    }

    override func setUp() {
        super.setUp()
        Analytics.isEnabled = true
        Analytics.service = NoopAnalytics()
    }

    override func tearDown() {
        Analytics.isEnabled = true
        Analytics.service = NoopAnalytics()
        super.tearDown()
    }

    func test_track_suppressedWhileDisabled_resumesWhenEnabled() {
        let spy = SpyAnalytics()
        Analytics.service = spy
        Analytics.isEnabled = false
        Analytics.track(.appOpen)
        XCTAssertEqual(spy.count, 0, "オプトアウト中は track が転送されない")
        Analytics.isEnabled = true
        Analytics.track(.appOpen)
        XCTAssertEqual(spy.count, 1, "再許可で転送が再開する")
    }

    func test_setEnabledFalse_tearsDownToNoop() {
        // OFF にしたら **その場で** 実体を Noop に戻し、セッション中の残留送信を止める。
        Analytics.service = SpyAnalytics()
        Analytics.setEnabled(false)
        XCTAssertTrue(Analytics.service is NoopAnalytics, "OFF で SDK 実体が Noop に置換される(teardown)")
        XCTAssertFalse(Analytics.isEnabled)
    }
}
