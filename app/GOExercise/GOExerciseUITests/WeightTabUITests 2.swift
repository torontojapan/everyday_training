import XCTest

/// 体重タブの機能 UI テスト(ユーザー要望: 「細かいところまでちゃんと機能するか」)。
/// `--mock-premium` でロック解除し、`--seed-demo-data --seed-scenario monthly` の
/// 30日分データ(身長/目標体重/開始体重も設定済み)を土台に検証する。
///
/// 注意: 体重タブは「記録する/レポート/推移/履歴」が `CollapsibleSection` で**既定は折りたたみ**。
/// 入力欄・履歴行はセクションを展開するまでアクセシビリティツリーに出ないため、
/// 操作前にセクション見出し(ボタン)をタップして開く。
@MainActor
final class WeightTabUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchToWeightTab(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--no-notification-prompt",
            "--skip-milestones",
            "--skip-onboarding",
            "--mock-premium",
            "--seed-demo-data", "--seed-scenario", "monthly",
        ] + extra
        app.launch()
        let deny = app.alerts.buttons["許可しない"]
        if deny.waitForExistence(timeout: 1) { deny.tap() }

        let weightTab = app.tabBars.buttons["体重"]
        XCTAssertTrue(weightTab.waitForExistence(timeout: 10), "タブバーに体重タブがあるはず")
        weightTab.tap()
        return app
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        var attempts = 0
        while !element.exists && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
    }

    /// 折りたたみセクションを「probe が見えるまで」開く冪等ヘルパー。
    /// CollapsibleSection は展開状態を UserDefaults に永続化するため、前テストの状態が
    /// 残る。isSelected は .combine で不正確なので、probe の有無で開閉を判断する。
    private func ensureExpanded(_ title: String, probe: XCUIElement, in app: XCUIApplication) {
        if probe.exists { return }
        // **重要**: 見出しは scrollView 内に限定する。`app.buttons` 全体だと「履歴」が
        // 画面下のタブバー『履歴』ボタンと衝突し、タップで履歴タブへ飛んでしまう。
        let header = app.scrollViews.buttons
            .containing(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        scrollTo(header, in: app)
        XCTAssertTrue(header.waitForExistence(timeout: 6), "『\(title)』セクション見出しがあるはず")
        header.tap()
        if probe.waitForExistence(timeout: 2) { return }
        if header.exists { header.tap() }
    }

    // MARK: - 表示(ヒーロー / BMI / チャート)

    func testHeroDashboardAndBMIVisible() {
        let app = launchToWeightTab()

        // プレミアム解除済みなのでペイウォールではなくヒーローが出る。
        let hero = app.otherElements["weight-hero-dashboard"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 10),
                      "mock-premium でロック解除され、ヒーローダッシュボードが表示されるはず")

        // BMI ストリップは .accessibilityElement(.combine) のため型が一定しない。
        // どの要素型でも拾えるよう descendants 全体から identifier で探す。
        let bmi = app.descendants(matching: .any)["bmi-info-strip"].firstMatch
        scrollTo(bmi, in: app, maxSwipes: 3)
        XCTAssertTrue(bmi.exists, "BMI ストリップが表示されるはず")
    }

    func testTargetEditDialogOpensAndAcceptsInput() {
        let app = launchToWeightTab()

        let editTarget = app.buttons["hero-edit-target"].firstMatch
        XCTAssertTrue(editTarget.waitForExistence(timeout: 10), "目標体重の編集ボタンがあるはず")
        editTarget.tap()

        let field = app.textFields["例: 60.0"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "目標体重の入力ダイアログが開くはず")
        field.tap()
        field.typeText("58.5")
        app.buttons["保存"].firstMatch.tap()

        XCTAssertTrue(app.otherElements["weight-hero-dashboard"].firstMatch
            .waitForExistence(timeout: 5), "保存後にヒーローへ戻るはず")
    }

    // MARK: - 記録の追加 / 削除

    func testAddWeightEntryShowsInList() {
        let app = launchToWeightTab()
        let weightField = app.textFields["体重 (kg)"]
        ensureExpanded("記録する", probe: weightField, in: app)
        scrollTo(weightField, in: app)
        XCTAssertTrue(weightField.waitForExistence(timeout: 6), "体重入力欄が見つかるはず")
        weightField.tap()
        weightField.typeText("61.3")   // %.1f 表示で丸め揺れしない値

        let done = app.buttons["完了"].firstMatch
        if done.exists { done.tap() }
        let save = app.buttons["保存"].firstMatch
        scrollTo(save, in: app, maxSwipes: 3)
        XCTAssertTrue(save.waitForExistence(timeout: 5), "保存ボタンがあるはず")
        save.tap()

        // 履歴セクションを開いて反映を確認(行は "61.3 kg" 形式)。
        let added = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '61.3'")).firstMatch
        ensureExpanded("履歴", probe: added, in: app)
        scrollTo(added, in: app, maxSwipes: 6)
        XCTAssertTrue(added.waitForExistence(timeout: 8), "保存した体重 61.3 が一覧に出るはず")
    }

    func testAddEntryWithMemo() {
        let app = launchToWeightTab()
        let weightField = app.textFields["体重 (kg)"]
        ensureExpanded("記録する", probe: weightField, in: app)
        scrollTo(weightField, in: app)
        XCTAssertTrue(weightField.waitForExistence(timeout: 6), "体重入力欄が見つかるはず")
        weightField.tap()
        weightField.typeText("60.2")

        let memoField = app.textFields["メモ (任意)"]
        if memoField.exists {
            memoField.tap()
            memoField.typeText("UIテストメモ")
        }
        let done = app.buttons["完了"].firstMatch
        if done.exists { done.tap() }
        let save = app.buttons["保存"].firstMatch
        scrollTo(save, in: app, maxSwipes: 3)
        save.tap()

        let added = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'UIテストメモ'")).firstMatch
        ensureExpanded("履歴", probe: added, in: app)
        scrollTo(added, in: app, maxSwipes: 6)
        XCTAssertTrue(added.waitForExistence(timeout: 8), "メモ付き保存も一覧に反映されるはず")
    }

    func testInvalidWeightKeepsSaveDisabled() {
        let app = launchToWeightTab()
        let weightField = app.textFields["体重 (kg)"]
        ensureExpanded("記録する", probe: weightField, in: app)
        scrollTo(weightField, in: app)
        XCTAssertTrue(weightField.waitForExistence(timeout: 6), "体重入力欄が見つかるはず")
        weightField.tap()
        weightField.typeText("0")   // 範囲外(0 以下)はパース不可扱い

        let done = app.buttons["完了"].firstMatch
        if done.exists { done.tap() }
        let save = app.buttons["保存"].firstMatch
        scrollTo(save, in: app, maxSwipes: 3)
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "無効な体重(0)では保存できないはず")
    }

    func testDeleteEntryViaSwipe() {
        let app = launchToWeightTab()
        let row = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'kg'")).firstMatch
        ensureExpanded("履歴", probe: row, in: app)
        scrollTo(row, in: app)
        guard row.waitForExistence(timeout: 6) else {
            return XCTFail("体重一覧の行が見つからない(シードデータ欠落?)")
        }
        row.swipeLeft()
        let delete = app.buttons["削除"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 4), "スワイプで削除ボタンが出るはず")
        delete.tap()
        let confirm = app.alerts.buttons["削除"].firstMatch
        if confirm.waitForExistence(timeout: 2) { confirm.tap() }
        XCTAssertTrue(app.tabBars.buttons["体重"].exists, "削除後も体重タブが生きているはず")
    }

    // MARK: - プレミアムゲート(解除なしの対照)

    func testWithoutPremiumShowsPaywallGate() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--no-notification-prompt", "--skip-milestones", "--skip-onboarding",
            "--mock-premium-off",
            "--seed-demo-data", "--seed-scenario", "monthly",
        ]
        app.launch()
        let deny = app.alerts.buttons["許可しない"]
        if deny.waitForExistence(timeout: 1) { deny.tap() }
        app.tabBars.buttons["体重"].tap()

        let paywallHint = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'プレミアム'")).firstMatch
        XCTAssertTrue(paywallHint.waitForExistence(timeout: 8),
                      "未課金の体重タブにはプレミアム案内が出るはず")
    }
}
