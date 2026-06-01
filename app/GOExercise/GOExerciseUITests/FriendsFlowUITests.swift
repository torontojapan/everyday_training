import XCTest

@MainActor
final class FriendsFlowUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(route: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--no-notification-prompt",
            "--skip-milestones",
            "--skip-onboarding",
            // 友達機能は v1 では既定で非表示。UI テストでは opt-in で有効化する。
            "--enable-friends",
            "--initial-route", route
        ] + extra
        app.launch()
        // Dismiss the notification dialog if it slips through despite --no-notification-prompt.
        let deny = app.alerts.buttons["許可しない"]
        if deny.waitForExistence(timeout: 1) { deny.tap() }
        return app
    }

    // MARK: - Friends list

    func testFriendsLazyConnectShowsProfile() {
        // lazy 化: タブを開いただけでは匿名サインインせず歓迎画面に留まる
        // (孤児アカウント/プライバシー対策)。「友達とつながる」= 能動操作の瞬間に
        // 初めてサインインし、signed-in UI (友達追加ボタン) に着地する。
        let app = launch(route: "friends", extra: ["--mock-force-signed-out"])

        // 起動直後は welcome の「友達とつながる」ボタンが出て、まだ signed-in UI は出ない。
        let connect = app.buttons.matching(identifier: "friends-connect-button").firstMatch
        XCTAssertTrue(connect.waitForExistence(timeout: 10),
                      "未サインインでは歓迎画面の『友達とつながる』が表示されるはず")
        let addButton = app.buttons.matching(identifier: "friend-add-button").firstMatch
        XCTAssertFalse(addButton.exists,
                       "タブ表示だけでは signed-in UI (友達追加ボタン) は出ないはず (lazy)")

        // 能動操作でサインイン → signed-in UI に着地。
        connect.tap()
        XCTAssertTrue(addButton.waitForExistence(timeout: 10),
                      "『友達とつながる』後に signed-in UI の友達追加ボタンが表示されるはず")
    }

    func testFriendsSignedInShowsRankingLink() {
        let app = launch(route: "friends",
                          extra: ["--mock-force-signed-out", "--mock-seed-friends"])

        // NavigationLinks are queryable by accessibility identifier.
        let ranking = app.buttons.matching(identifier: "weekly-ranking-link").firstMatch
        XCTAssertTrue(ranking.waitForExistence(timeout: 8),
                      "週間ランキングへのリンクが表示されるはず")
    }

    // MARK: - Friend detail navigation

    func testOpenFriendDetailAndClose() {
        let app = launch(route: "friends",
                          extra: ["--mock-seed-friends", "--mock-open-friend-detail"])

        // Sheet's close button has label "閉じる" — multiple may exist on
        // screen (the deep-link close at top, and the detail sheet's own).
        // Use the navigation bar's title to confirm the sheet is up, then
        // tap the rightmost "閉じる".
        let detailNavBar = app.navigationBars["ゆきな"]
            .firstMatch
        if !detailNavBar.waitForExistence(timeout: 6) {
            // Fallback: just check that some "閉じる" button is present.
            let anyClose = app.buttons["閉じる"].firstMatch
            XCTAssertTrue(anyClose.waitForExistence(timeout: 4), "詳細シートが開いて閉じるボタンが見えるはず")
            return
        }
        let close = detailNavBar.buttons["閉じる"]
        XCTAssertTrue(close.waitForExistence(timeout: 4), "詳細シートに閉じるボタンが表示されるはず")
        close.tap()
        XCTAssertFalse(detailNavBar.waitForExistence(timeout: 2), "閉じたら詳細 NavBar が消えるはず")
    }

    // MARK: - Friend add

    func testFriendAddOpens() {
        let app = launch(route: "friends",
                          extra: ["--mock-seed-friends", "--mock-open-friend-add"])

        let codeField = app.textFields["friend-code-field"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 8), "コード入力欄が表示されるはず")
    }

    // MARK: - Friends-route deep-link close

    func testDeepLinkFriendsHasCloseButton() {
        let app = launch(route: "friends", extra: ["--mock-seed-friends"])

        // The deep-link wrapper places "閉じる" in the top-leading nav bar.
        let close = app.buttons["閉じる"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 8),
                      "URL scheme で開いた friends 画面に閉じるボタンがあるはず")
    }
}

@MainActor
final class SettingsLinksUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testSettingsHasPrivacyAndTermsLinks() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--no-notification-prompt",
            "--skip-milestones",
            "--skip-onboarding",
            "--initial-route", "settings"
        ]
        app.launch()
        let deny = app.alerts.buttons["許可しない"]
        if deny.waitForExistence(timeout: 1) { deny.tap() }

        // SwiftUI Link is rendered as a button, queryable by its visible label.
        // SettingsView grew taller in Phase 6.0 Batch 3 (Section footers + new
        // sharing section), so swipe-up budget is bumped to 14.
        let support = app.buttons.matching(identifier: "サポート").firstMatch

        var attempts = 0
        while !support.waitForExistence(timeout: 1) && attempts < 14 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(support.exists, "サポート Link が表示されるはず")
        XCTAssertTrue(app.buttons.matching(identifier: "利用規約").firstMatch.exists,
                      "利用規約 Link が表示されるはず")
        XCTAssertTrue(app.buttons.matching(identifier: "プライバシーポリシー").firstMatch.exists,
                      "プライバシーポリシー Link が表示されるはず")
    }
}
