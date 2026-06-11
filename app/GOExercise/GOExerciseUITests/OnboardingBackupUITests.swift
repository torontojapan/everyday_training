import XCTest

/// オンボーディングのバックアップ・サインインステップ(任意・スキップ可)の UI 検証。
@MainActor
final class OnboardingBackupUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// 猫選択 →「つぎへ」→ バックアップ案内が出て、「あとで」でアプリに入れる。
    func testOnboardingShowsBackupStepThenSkip() {
        let app = XCUIApplication()
        // --skip-onboarding を渡さない = オンボーディングを実際に出す。
        app.launchArguments = ["--no-notification-prompt", "--skip-milestones", "--enable-friends"]
        app.launch()
        let deny = app.alerts.buttons["許可しない"]
        if deny.waitForExistence(timeout: 1) { deny.tap() }

        // 猫選択画面の「つぎへ」
        let next = app.buttons["user-cat-confirm"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 12), "オンボーディングの猫選択が出るはず")
        next.tap()

        // バックアップ案内 + スキップ
        let skip = app.buttons["backup-signin-skip"].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 8),
                      "猫選択の後にバックアップ・サインインのステップが出るはず")
        // Apple サインインボタンも存在する(連携有効ビルド)。
        XCTAssertTrue(app.buttons["backup-signin-apple"].firstMatch.exists ||
                      app.descendants(matching: .any)["backup-signin-apple"].firstMatch.exists,
                      "Apple サインインボタンが出るはず")
        skip.tap()

        // スキップでオンボーディング完了 → ホーム(タブバー)に着地。
        XCTAssertTrue(app.tabBars.buttons["ホーム"].waitForExistence(timeout: 8),
                      "「あとで」でホームに入れるはず")
    }
}
