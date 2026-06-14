import XCTest

/// App Store 提出用スクリーンショットを最新ビルドで一括撮影する(6.9" / 日本語 / デモデータ)。
/// 各画面を app.screenshot() で .keepAlways 添付。xcresult から PNG を取り出して採用する。
/// 実 Supabase は使わず Mock(--mock-seed-friends)とデモseed(--seed-scenario yearly=体重グラフ込み)で撮る。
/// 注意: SwiftData は relaunch 間で永続するため最初の seed が勝つ → 全ショットを同一 yearly シナリオに統一。
@MainActor
final class ScreenshotCaptureUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    // 体重グラフ・連続記録・周期まで埋まる yearly シナリオで統一。
    private let seed = ["--seed-demo-data", "--seed-scenario", "yearly"]
    private let common = ["--no-notification-prompt", "--no-review-prompt", "--skip-milestones"]

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let att = XCTAttachment(screenshot: app.screenshot())
        att.name = name; att.lifetime = .keepAlways
        add(att); print("SHOT \(name)")
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = common + extra
        app.launch()
        // 通知ダイアログ等の取りこぼしを閉じる。
        let deny = app.alerts.buttons["許可しない"]
        if deny.waitForExistence(timeout: 1.0) { deny.tap() }
        // StoreKit の Apple Account サインインダイアログが残っていたらキャンセル。
        let cancel = app.buttons["キャンセル"]
        if cancel.exists { cancel.tap() }
        return app
    }

    func testCaptureAppStoreScreenshots() {
        // 01) 猫を選べる(オンボーディング)。fresh install 前提(事前に simctl uninstall 済み)。
        let app1 = launch([])
        if app1.buttons["user-cat-confirm"].waitForExistence(timeout: 12) { sleep(1) }
        shoot(app1, "01_cat_picker")

        // 02) ホーム + 03) 連続記録シェア(同一インスタンス)。
        let home = launch(["--skip-onboarding", "--initial-tab", "home"] + seed)
        sleep(2)
        shoot(home, "02_home")
        let badge = home.buttons.matching(NSPredicate(format: "label CONTAINS '連続'")).firstMatch
        if badge.waitForExistence(timeout: 5) {
            badge.tap(); sleep(2)
            shoot(home, "03_streak_share")
            let close = home.buttons["閉じる"].firstMatch
            if close.exists { close.tap() }
        }

        // 04) 記録入力(CTA は「今日の運動を記録する」/「もう一種目する」)。
        let h2 = launch(["--skip-onboarding", "--initial-tab", "home"] + seed)
        let cta = h2.buttons.matching(NSPredicate(format: "label CONTAINS '記録' OR label CONTAINS '種目'")).firstMatch
        if cta.waitForExistence(timeout: 6) { cta.tap(); sleep(2); shoot(h2, "04_record") }

        // 05) 履歴。
        let stats = launch(["--skip-onboarding", "--initial-tab", "stats"] + seed)
        sleep(2); shoot(stats, "05_history")

        // 06) 体重(プレミアム解放 + 推移グラフを展開)。
        let weight = launch(["--skip-onboarding", "--mock-premium", "--initial-tab", "weight"] + seed)
        sleep(2)
        let trend = weight.buttons.matching(NSPredicate(format: "label CONTAINS '推移'")).firstMatch
        if trend.waitForExistence(timeout: 4) { trend.tap(); sleep(2) }
        shoot(weight, "06_weight_premium")

        // 07) ペイウォール(設定の upsell 行 → シートだけ開く。購入は踏まない)。
        let pay = launch(["--skip-onboarding", "--mock-premium-off", "--initial-tab", "settings"] + seed)
        sleep(1)
        let upsell = pay.descendants(matching: .any).matching(identifier: "premium-upsell-row").firstMatch
        if upsell.waitForExistence(timeout: 5) { upsell.tap(); sleep(2); shoot(pay, "07_paywall") }
        else { shoot(pay, "07_settings_premium") }

        // 08) 友達一覧 + 09) 週間ランキング(同一インスタンス)。
        let friends = launch(["--skip-onboarding", "--mock-seed-friends", "--initial-tab", "friends"] + seed)
        sleep(2); shoot(friends, "08_friends")
        let ranking = friends.buttons["weekly-ranking-link"].firstMatch
        var tries = 0
        while !ranking.exists && tries < 5 { friends.swipeUp(); tries += 1 }
        if ranking.waitForExistence(timeout: 4) { ranking.tap(); sleep(2); shoot(friends, "09_ranking") }

        // 10) 友達詳細(応援)。
        let detail = launch(["--skip-onboarding", "--mock-seed-friends", "--mock-open-friend-detail", "--initial-tab", "friends"] + seed)
        sleep(3); shoot(detail, "10_friend_detail")

        // 11) 設定(称号/装飾/バックアップ。予備)。
        let settings = launch(["--skip-onboarding", "--initial-tab", "settings"] + seed)
        sleep(2); shoot(settings, "11_settings")
    }
}
