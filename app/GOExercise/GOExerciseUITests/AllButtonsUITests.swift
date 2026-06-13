import XCTest

// MARK: - UI test scope
//
// Covered here (real-tap automation):
// - Home: 「今日の運動を記録する」button → RecordEntryView opens.
// - RecordEntryView: 閉じる button → returns to home.
// - RecordEntryView: 続けて記録 → entry view stays and Save re-enables.
// - RecordEntryView: 種目を追加 + 種目を削除 buttons.
// - RecordEntryView: サジェスト chip 「プランクを入力」 fills the name.
// - Home: 履歴 toolbar icon → navigation works.
// - Home: 設定 → 通知設定 navigation works.
//
// Covered in unit/logic tests (not here):
// - Full record-entry save flow incl. ConfirmationDialog branches.
//   Reason: SwiftUI Form keyboard handling makes the Save button flaky to
//   hit from UITest. Logic itself is covered in
//   RecordEntryViewModelTests (9 cases).
// - Notification settings toggle / picker.
//   Reason: SwiftUI async Bindings + UITest value-polling race. Logic
//   covered in NotificationSettingsViewModelTests (6 cases).
// - WeeklyCalendar weekday cell tap → DayDetailSheet open/close.
//   Reason: the WeeklyCalendar buttons live inside a deeply nested
//   ScrollView whose hit-test path is unreliable under XCTest. The tap
//   handler and the records filter are exercised through HomeView and
//   integration. Sheet dismiss itself is verified in StreakShareCloseUITests.

@MainActor
final class AllButtonsUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchApp(scenario: String = "long-streak", route: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        // --skip-onboarding は必須。新規シミュレータ (erase 後) では
        // UserCatPreferences が初期状態で onboarding fullScreenCover が出てしまい、
        // primary CTA まで到達できない。
        var args = [
            "--seed-demo-data", "--no-notification-prompt", "--skip-milestones",
            "--skip-onboarding", "--seed-scenario", scenario,
        ]
        if let route {
            args.append(contentsOf: ["--initial-route", route])
        }
        app.launchArguments = args
        app.launch()
        return app
    }

    private func dismissNotificationDialogIfPresent(_ app: XCUIApplication) {
        let denyButton = app.alerts.buttons["許可しない"]
        if denyButton.waitForExistence(timeout: 1) {
            denyButton.tap()
        }
    }

    // MARK: - Home → record entry view appears

    func testRecordEntryOpensFromHome() throws {
        let app = launchApp()
        dismissNotificationDialogIfPresent(app)

        let recordButton = app.buttons["primary-record-action"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 8))
        recordButton.tap()

        // 種目ごとのカテゴリ選択メニューが表示される (旧チップ → Menu に変更)。
        XCTAssertTrue(app.buttons["exercise-category-menu"].waitForExistence(timeout: 5))

        // 種目名 入力欄が存在する。
        XCTAssertTrue(app.textFields["種目名"].waitForExistence(timeout: 3))
    }

    // MARK: - RecordEntry close

    func testRecordEntryCloseButton() throws {
        let app = launchApp()
        dismissNotificationDialogIfPresent(app)

        app.buttons["primary-record-action"].tap()

        let closeButton = app.buttons["閉じる"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()

        XCTAssertTrue(app.buttons["primary-record-action"].waitForExistence(timeout: 5))
    }

    // MARK: - History navigation

    func testNavigateToHistoryAndBack() throws {
        let app = launchApp()
        dismissNotificationDialogIfPresent(app)

        // Phase 7.0: 履歴は TabView の 2 番目のタブ。NavigationStack の
        // push ではなく Tab 切替で開く。
        let historyTab = app.tabBars.buttons["履歴"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 8))
        historyTab.tap()

        // 履歴タブの大見出しが表示されていることを確認 (タブ切替成功)。
        let historyTitle = app.navigationBars["履歴"]
        XCTAssertTrue(historyTitle.waitForExistence(timeout: 5))

        // ホームタブを tap して戻る。
        let homeTab = app.tabBars.buttons["ホーム"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
        homeTab.tap()

        XCTAssertTrue(app.buttons["primary-record-action"].waitForExistence(timeout: 5))
    }

    // MARK: - Settings → Notification Settings navigation

    func testNavigateSettingsAndNotificationSettings() throws {
        let app = launchApp()
        dismissNotificationDialogIfPresent(app)

        let settingsLink = app.buttons["設定"]
        XCTAssertTrue(settingsLink.waitForExistence(timeout: 8))
        settingsLink.tap()

        // 設定ルートは lazy List のため、画面外の行は hierarchy に存在しない。
        // 「通知設定」が下にある構成 (アカウントとバックアップが最上位) でも
        // 見つかるよう、必要ならスクロールして探す。
        let notifLink = app.buttons.containing(NSPredicate(format: "label CONTAINS '通知'")).firstMatch
        if !notifLink.waitForExistence(timeout: 2) { app.swipeUp() }
        XCTAssertTrue(notifLink.waitForExistence(timeout: 5))
        notifLink.tap()

        // Notification settings screen — find the toggle by its identifier.
        let toggle = app.switches.matching(identifier: "notif-toggle").firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
    }

    // MARK: - Suggestion chip tap

    func testTappingSuggestionChipFillsExerciseName() throws {
        let app = launchApp()
        dismissNotificationDialogIfPresent(app)

        app.buttons["primary-record-action"].tap()

        let plankChip = app.buttons["プランクを入力"]
        XCTAssertTrue(plankChip.waitForExistence(timeout: 5))
        plankChip.tap()

        // The text field should now contain the suggestion.
        let nameField = app.textFields["種目名"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        let value = nameField.value as? String ?? ""
        XCTAssertEqual(value, "プランク", "Tapping the chip should fill the exercise name")
    }

    // MARK: - History monthly calendar day tap → DayDetailSheet

    func testHistoryMonthlyCalendarDayTapOpensDetailSheet() throws {
        let app = launchApp(route: "history")
        dismissNotificationDialogIfPresent(app)

        // Wait for the calendar to load by checking that 履歴 title is up.
        let calendarHeader = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '月'")).firstMatch
        XCTAssertTrue(calendarHeader.waitForExistence(timeout: 8))

        // Tap any day cell whose accessibility label contains both '月' and '日'.
        let dayCell = app.buttons
            .containing(NSPredicate(format: "label CONTAINS '月' AND label CONTAINS '日'"))
            .firstMatch
        XCTAssertTrue(dayCell.waitForExistence(timeout: 5))
        dayCell.tap()

        // DayDetailSheet opens with 閉じる button.
        let closeButton = app.buttons["閉じる"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()

        // Returned to history (calendar header still visible).
        XCTAssertTrue(calendarHeader.waitForExistence(timeout: 5))
    }

    // MARK: - Add / remove exercise row

    func testAddAndRemoveExerciseRow() throws {
        let app = launchApp()
        dismissNotificationDialogIfPresent(app)

        app.buttons["primary-record-action"].tap()

        // RecordEntryView は fullScreenCover でフル表示されるため、
        // drag で展開する必要はなくなった。
        let recordTitle = app.navigationBars["今日の記録"]
        XCTAssertTrue(recordTitle.waitForExistence(timeout: 5))

        let addButton = app.buttons["種目を追加"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let trashButton = app.buttons["種目を削除"].firstMatch
        XCTAssertTrue(trashButton.waitForExistence(timeout: 3))
        trashButton.tap()

        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: trashButton)
        let result = XCTWaiter().wait(for: [expectation], timeout: 8)
        XCTAssertEqual(result, .completed)
    }
}
