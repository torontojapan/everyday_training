import XCTest

@MainActor
final class StreakShareCloseUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testTappingStreakBadgeOpensShareSheetAndCloseDismissesIt() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--seed-demo-data",
            "--no-notification-prompt",
            "--seed-scenario", "long-streak"
        ]
        app.launch()

        // Find the streak badge by its label containing "日連続".
        let streakBadge = app.buttons
            .containing(NSPredicate(format: "label CONTAINS '日連続'"))
            .firstMatch
        XCTAssertTrue(
            streakBadge.waitForExistence(timeout: 10),
            "Streak badge should appear on home screen"
        )

        streakBadge.tap()

        // Share sheet should appear with a close button labeled "閉じる".
        let closeButton = app.buttons["閉じる"]
        XCTAssertTrue(
            closeButton.waitForExistence(timeout: 5),
            "Close button (X) should appear after tapping streak badge"
        )

        // The share card should also be visible: look for the share action.
        let shareLink = app.buttons.containing(NSPredicate(format: "label CONTAINS 'SNS'")).firstMatch
        XCTAssertTrue(shareLink.exists, "Share link should be visible on the share sheet")

        // Tap close.
        closeButton.tap()

        // Wait for the sheet to dismiss: the close button should no longer be hittable.
        let predicate = NSPredicate(format: "exists == false OR isHittable == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: closeButton)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        XCTAssertEqual(
            result, .completed,
            "Close button should disappear after tapping it (sheet dismissed)"
        )

        // Streak badge should be visible again on home.
        XCTAssertTrue(
            streakBadge.waitForExistence(timeout: 5),
            "Streak badge should be visible after returning to home"
        )
    }
}
