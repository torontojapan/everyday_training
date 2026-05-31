import XCTest
@testable import GOExercise

@MainActor
final class DeepLinkRouterTests: XCTestCase {

    func testHostParsedAsRoute() {
        for raw in ["home", "record", "history", "settings", "friends",
                    "notification-settings", "streak-share"] {
            let url = URL(string: "goexercise://\(raw)")!
            XCTAssertEqual(DeepLinkRouter.route(from: url)?.rawValue, raw,
                           "host '\(raw)' should map to AppRoute(rawValue: '\(raw)')")
        }
    }

    func testUppercaseSchemeAccepted() {
        let url = URL(string: "GOEXERCISE://record")!
        XCTAssertEqual(DeepLinkRouter.route(from: url), .record)
    }

    func testUnknownSchemeReturnsNil() {
        let url = URL(string: "https://example.com/record")!
        XCTAssertNil(DeepLinkRouter.route(from: url))
    }

    func testUnknownHostReturnsNil() {
        let url = URL(string: "goexercise://nope")!
        XCTAssertNil(DeepLinkRouter.route(from: url))
    }

    func testRouteStateOverrideStartsNil() {
        let state = RouteState()
        XCTAssertNil(state.override)
    }

    func testPendingRouteInitiallyNil() {
        let router = DeepLinkRouter()
        XCTAssertNil(router.pendingRoute)
        XCTAssertNil(router.pendingFriendCode)
    }

    // MARK: - friendCode(from:) 抽出 + 検証 (Codex#6)

    func testFriendCodeExtractionAndValidation() {
        func code(_ s: String) -> String? { DeepLinkRouter.friendCode(from: URL(string: s)!) }
        XCTAssertEqual(code("goexercise://friends?code=ABC234"), "ABC234")
        XCTAssertEqual(code("goexercise://friends?code=abc234"), "ABC234", "小文字は大文字化される")
        XCTAssertNil(code("goexercise://friends"), "code 無しは nil")
        XCTAssertNil(code("goexercise://friends?code=AB"), "桁不足は nil")
        XCTAssertNil(code("goexercise://friends?code=O0I1AB"), "曖昧文字除去で桁不足 → nil")
    }

    // MARK: - resolve(url:friendsEnabled:) ゲート (Codex#1/#5)

    func testResolveKeepsCodeWhenFriendsEnabled() {
        let (route, code) = DeepLinkRouter.resolve(url: URL(string: "goexercise://friends?code=ABC234")!,
                                                   friendsEnabled: true)
        XCTAssertEqual(route, .friends)
        XCTAssertEqual(code, "ABC234")
    }

    func testResolveDropsCodeWhenFriendsDisabled() {
        // v1 ゲート: friends→home 振替時に code を破棄
        let (route, code) = DeepLinkRouter.resolve(url: URL(string: "goexercise://friends?code=ABC234")!,
                                                   friendsEnabled: false)
        XCTAssertEqual(route, .home)
        XCTAssertNil(code)
    }

    func testResolveNonFriendsRouteHasNoCode() {
        let (route, code) = DeepLinkRouter.resolve(url: URL(string: "goexercise://settings?code=ABC234")!,
                                                   friendsEnabled: true)
        XCTAssertEqual(route, .settings)
        XCTAssertNil(code, "friends 以外に着地するコードは保持しない")
    }
}

@MainActor
final class NotificationDeepLinkTests: XCTestCase {

    /// Verifies the scheduler ships `route` in userInfo so AppDelegate can
    /// route notification taps. タップ先はホーム (猫劇場) に統一 (記録は CTA から起こせる)。
    func testScheduledNotificationCarriesHomeRoute() async throws {
        let recorder = NotificationRecorder()
        let scheduler = NotificationScheduler(
            center: recorder,
            settings: NotificationSettings(isEnabled: true, notificationCount: 1),
            calendar: .mondayFirst
        )

        await scheduler.scheduleDaily(todayAchieved: false, currentStreak: 3, weeklyProgressRate: 0.5)

        XCTAssertFalse(recorder.added.isEmpty)
        let first = try XCTUnwrap(recorder.added.first)
        XCTAssertEqual(first.content.userInfo["route"] as? String, AppRoute.home.rawValue)
    }
}

final class NotificationRecorder: @unchecked Sendable, NotificationScheduling {
    var added: [UNNotificationRequest] = []
    func add(_ request: UNNotificationRequest) async throws {
        added.append(request)
    }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
    func removeAllPendingNotificationRequests() {}
}

import UserNotifications
