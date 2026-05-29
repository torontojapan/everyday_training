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
    }
}

@MainActor
final class NotificationDeepLinkTests: XCTestCase {

    /// Verifies the scheduler ships `route` in userInfo so AppDelegate can
    /// route notification taps. Without this, tapping a daily reminder
    /// would just open the home screen — losing the intent.
    func testScheduledNotificationCarriesRecordRoute() async throws {
        let recorder = NotificationRecorder()
        let scheduler = NotificationScheduler(
            center: recorder,
            settings: NotificationSettings(isEnabled: true, notificationCount: 1),
            calendar: .mondayFirst
        )

        await scheduler.scheduleDaily(todayAchieved: false, currentStreak: 3, weeklyProgressRate: 0.5)

        XCTAssertFalse(recorder.added.isEmpty)
        let first = try XCTUnwrap(recorder.added.first)
        XCTAssertEqual(first.content.userInfo["route"] as? String, AppRoute.record.rawValue)
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
