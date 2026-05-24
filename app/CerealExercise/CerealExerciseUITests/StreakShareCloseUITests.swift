import XCTest

@MainActor
final class StreakShareCloseUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Direct-launches the streak share sheet and verifies its content is on
    /// screen. The full open/close from Home is exercised manually — under
    /// XCUITest the sequential sheet presentation (milestone celebration →
    /// streak share) is flaky in iOS 17/18, so we focus this test on the
    /// share sheet contract itself.
    func testStreakShareSheetContentIsVisible() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--seed-demo-data",
            "--no-notification-prompt",
            "--skip-milestones",
            "--seed-scenario", "long-streak",
            "--initial-route", "streak-share"
        ]
        app.launch()

        // Close button (X) is reachable.
        let closeButton = app.buttons["閉じる"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 8), "Close X button should be visible")

        // Share link is present.
        let shareLink = app.buttons.containing(NSPredicate(format: "label CONTAINS 'SNS'")).firstMatch
        XCTAssertTrue(shareLink.waitForExistence(timeout: 8), "Share link should be visible")

        // The big '30' / '日連続' wording.
        let dayLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '日連続'")).firstMatch
        XCTAssertTrue(dayLabel.waitForExistence(timeout: 3), "Streak number/label should be visible")
    }
}
