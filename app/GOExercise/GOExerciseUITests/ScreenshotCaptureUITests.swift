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

    /// サブ画面 golden(Android パリティ照合用): 友達詳細 / 友達追加 / 生理日入力 / 記録完了 / 日詳細シート。
    /// in-sim タップ(accessibility id / label)で到達するため表示座標問題なし。
    func testCaptureSubScreens() {
        // sub) 友達詳細(--mock-open-friend-detail で自動 push)。
        let detail = launch(["--skip-onboarding", "--mock-seed-friends", "--mock-open-friend-detail", "--initial-tab", "friends"] + seed)
        sleep(3); shoot(detail, "sub_friend_detail")

        // sub) 友達追加シート(--mock-open-friend-add)。
        let add = launch(["--skip-onboarding", "--mock-seed-friends", "--mock-open-friend-add", "--initial-tab", "friends"] + seed)
        sleep(2); shoot(add, "sub_friend_add")

        // sub) 生理日入力(yearly seed で周期 ON → 履歴の menstrual-link-stats を tap)。
        let men = launch(["--skip-onboarding", "--initial-tab", "stats"] + seed)
        sleep(2)
        let link = men.descendants(matching: .any).matching(identifier: "menstrual-link-stats").firstMatch
        var t = 0
        while !link.exists && t < 6 { men.swipeUp(); t += 1; sleep(1) }
        if link.waitForExistence(timeout: 4) { link.tap(); sleep(2); shoot(men, "sub_menstrual") }
        else { shoot(men, "sub_menstrual_MISSING") }

        // sub) 記録完了(home CTA → よく使う種目チップで種目名を埋める → 保存 → 完了画面)。
        let rec = launch(["--skip-onboarding", "--initial-tab", "home"] + seed)
        let cta = rec.buttons.matching(NSPredicate(format: "label CONTAINS '記録' OR label CONTAINS '種目'")).firstMatch
        if cta.waitForExistence(timeout: 6) {
            cta.tap(); sleep(2)
            // よく使う種目チップ(suggestion ボタン)をタップして種目名を埋める → canSave 成立。
            let chip = rec.buttons.matching(NSPredicate(format: "label IN {'スクワット','腕立て伏せ','プランク','腹筋','ランニング'}")).firstMatch
            if chip.waitForExistence(timeout: 4) { chip.tap(); sleep(1) }
            else {
                let nameField = rec.textFields.firstMatch
                if nameField.waitForExistence(timeout: 3) { nameField.tap(); nameField.typeText("Squat") }
            }
            // 保存ボタンは下端 → スクロールで可視化してからタップ。
            rec.swipeUp(); sleep(1); rec.swipeUp(); sleep(1)
            let save = rec.buttons.matching(NSPredicate(format: "label CONTAINS '保存'")).firstMatch
            if save.waitForExistence(timeout: 3) { save.tap(); sleep(3); shoot(rec, "sub_record_completion") }
            else { shoot(rec, "sub_record_completion_NOSAVE") }
        }

        // sub) 日詳細シート(履歴カレンダーの活動日を tap)。座標タップ(カレンダー領域 中央上寄り)。
        let day = launch(["--skip-onboarding", "--initial-tab", "stats"] + seed)
        sleep(2)
        day.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30)).tap()
        sleep(2); shoot(day, "sub_day_detail")
    }

    /// ランキングの期間別状態(今週/今月)golden。友達 → 順位 → セグメントで切替。
    func testCaptureRankingStates() {
        let friends = launch(["--skip-onboarding", "--mock-seed-friends", "--initial-tab", "friends"] + seed)
        sleep(2)
        let ranking = friends.buttons["weekly-ranking-link"].firstMatch
        var tries = 0
        while !ranking.exists && tries < 5 { friends.swipeUp(); tries += 1 }
        guard ranking.waitForExistence(timeout: 4) else { shoot(friends, "rank_LINK_MISSING"); return }
        ranking.tap(); sleep(2)
        shoot(friends, "rank_weekly")
        // 「今月」セグメントをタップ。segmented picker 内のボタン。
        let monthly = friends.buttons["今月"].firstMatch
        if monthly.waitForExistence(timeout: 4) { monthly.tap(); sleep(2); shoot(friends, "rank_monthly") }
        else { shoot(friends, "rank_monthly_MISSING") }
    }

    /// 友達タブの状態別 golden: 空(サインイン済・友達0)/ 友達詳細(名前フォント測定用)。
    func testCaptureFriendsStates() {
        // 空状態: force-signed-out → タブ .task が匿名サインイン(0友達)→ friendsEmptyState。
        let empty = launch(["--skip-onboarding", "--mock-force-signed-out", "--initial-tab", "friends"] + seed)
        sleep(3); shoot(empty, "friends_empty")

        // 友達詳細(hero 名前のフォント比較用)。
        let detail = launch(["--skip-onboarding", "--mock-seed-friends", "--mock-open-friend-detail", "--initial-tab", "friends"] + seed)
        sleep(3); shoot(detail, "friends_detail")
    }

    /// 設定のサブページ群(iOS は NavigationLink で push する階層型)。各行をタップして撮影→戻る。
    func testCaptureSettingsSubpages() {
        let app = launch(["--skip-onboarding", "--mock-premium", "--initial-tab", "settings"] + seed)
        sleep(2)
        // (行ラベル, ショット名)。iOS Label の文言に厳密一致。
        let pages: [(String, String)] = [
            ("カスタマイズ", "set_customize"),
            ("記録と共有", "set_record_sharing"),
            ("通知設定", "set_notifications"),
            ("データ & プライバシー", "set_data_privacy"),
            ("情報・サポート", "set_info"),
            ("プレミアム特典・称号一覧", "set_perks"),
        ]
        for (label, name) in pages {
            // 行が見えるまでスクロール(buttons / staticTexts どちらでも)。
            var tries = 0
            func row() -> XCUIElement {
                let b = app.buttons[label]
                return b.exists ? b : app.staticTexts[label]
            }
            while !row().exists && tries < 6 { app.swipeUp(); tries += 1; sleep(1) }
            if row().waitForExistence(timeout: 3) {
                row().tap(); sleep(2)
                shoot(app, name)
                // 戻る(ナビバー先頭ボタン)。
                let back = app.navigationBars.buttons.element(boundBy: 0)
                if back.exists { back.tap() } else { app.swipeRight() }
                sleep(1)
                // 戻った後はトップへスクロールし直す。
                app.swipeDown(); app.swipeDown(); sleep(1)
            } else {
                shoot(app, name + "_MISSING")
            }
        }
    }
}
