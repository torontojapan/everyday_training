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

    /// 残タスク一括 golden: 記録空/体重paywall/体重chart/設定premium/連続share/ハイライト3種/rescue/revive/referral/milestone。
    func testCaptureRemainingStates() {
        // 1) 記録入力 空/初期(seed 無し → 履歴も空・入力欄初期)。
        let rec = launch(["--skip-onboarding", "--initial-tab", "home"])
        let cta = rec.buttons.matching(NSPredicate(format: "label CONTAINS '記録' OR label CONTAINS '種目'")).firstMatch
        if cta.waitForExistence(timeout: 6) { cta.tap(); sleep(2); shoot(rec, "rem_record_empty") }

        // 2) 体重 paywall(無料)。
        let wpay = launch(["--skip-onboarding", "--mock-premium-off", "--initial-tab", "weight"] + seed)
        sleep(2); shoot(wpay, "rem_weight_paywall")

        // 3) 体重 premium chart。
        let wc = launch(["--skip-onboarding", "--mock-premium", "--initial-tab", "weight"] + seed)
        sleep(2)
        let trend = wc.buttons.matching(NSPredicate(format: "label CONTAINS '推移'")).firstMatch
        if trend.waitForExistence(timeout: 4) { trend.tap(); sleep(2) }
        shoot(wc, "rem_weight_chart")

        // 4) 設定 premium。
        let setp = launch(["--skip-onboarding", "--mock-premium", "--initial-tab", "settings"] + seed)
        sleep(2); shoot(setp, "rem_settings_premium")

        // 5) 連続シェアカード。
        let ss = launch(["--skip-onboarding", "--initial-route", "streak-share"] + seed)
        sleep(3); shoot(ss, "rem_streak_share")

        // 6-8) ハイライト Weekly / Monthly / All-time。
        for (idn, name) in [("weekly-highlight-entry","rem_hl_weekly"),
                            ("monthly-review-stats-button","rem_hl_monthly"),
                            ("lifetime-stats-entry","rem_hl_alltime")] {
            let st = launch(["--skip-onboarding", "--initial-tab", "stats"] + seed)
            sleep(2)
            let e = st.descendants(matching: .any).matching(identifier: idn).firstMatch
            var t = 0
            while !e.exists && t < 6 { st.swipeUp(); t += 1; sleep(1) }
            if e.waitForExistence(timeout: 4) { e.tap(); sleep(3); shoot(st, name) }
            else { shoot(st, name + "_MISSING") }
        }

        // 9) フリーズ(rescue)使用画面。
        let rsc = launch(["--skip-onboarding", "--initial-tab", "stats"] + seed)
        sleep(2)
        let hdr = rsc.buttons.matching(NSPredicate(format: "label CONTAINS '保険チケット'")).firstMatch
        var rt = 0
        while !hdr.exists && rt < 6 { rsc.swipeUp(); rt += 1; sleep(1) }
        if hdr.waitForExistence(timeout: 4) {
            hdr.tap(); sleep(1)
            let use = rsc.descendants(matching: .any).matching(identifier: "rescue-use-link").firstMatch
            if use.waitForExistence(timeout: 3) { use.tap(); sleep(2); shoot(rsc, "rem_rescue_use") }
            else { shoot(rsc, "rem_rescue_use_MISSING") }
        }

        // 10) ホーム revive overlay(seed revive)。
        let rev = launch(["--skip-onboarding", "--seed-scenario", "revive", "--initial-tab", "home"])
        sleep(3); shoot(rev, "rem_home_revive")

        // 11) ホーム referral スター行。
        let ref = launch(["--skip-onboarding", "--mock-seed-friends", "--mock-referral-stars", "5", "--initial-tab", "home"] + seed)
        sleep(3); shoot(ref, "rem_home_referral")

        // 12) 節目ダイアログ(milestone-eve → 記録 → milestone)。
        let mil = launch(["--skip-onboarding", "--seed-scenario", "milestone-eve", "--initial-tab", "home"])
        let mcta = mil.buttons.matching(NSPredicate(format: "label CONTAINS '記録' OR label CONTAINS '種目'")).firstMatch
        if mcta.waitForExistence(timeout: 6) {
            mcta.tap(); sleep(2)
            let chip = mil.buttons.matching(NSPredicate(format: "label IN {'スクワット','腕立て伏せ','プランク','腹筋','ランニング'}")).firstMatch
            if chip.waitForExistence(timeout: 4) { chip.tap(); sleep(1) }
            mil.swipeUp(); sleep(1); mil.swipeUp(); sleep(1)
            let save = mil.buttons.matching(NSPredicate(format: "label CONTAINS '保存'")).firstMatch
            if save.waitForExistence(timeout: 3) { save.tap(); sleep(4); shoot(mil, "rem_dialog_milestone") }
            else { shoot(mil, "rem_dialog_milestone_NOSAVE") }
        }
    }

    /// フリーズ(rescue)使用画面 golden。履歴→保険チケット展開→使う日を選んで適用。
    func testCaptureRescueUse() {
        let app = launch(["--skip-onboarding", "--initial-tab", "stats"] + seed)
        sleep(2)
        let hdr = app.buttons.matching(NSPredicate(format: "label CONTAINS '保険チケット'")).firstMatch
        var t = 0
        while !hdr.exists && t < 6 { app.swipeUp(); t += 1; sleep(1) }
        guard hdr.waitForExistence(timeout: 4) else { shoot(app, "rescueuse_HDR_MISSING"); return }
        hdr.tap(); sleep(1)
        let use = app.descendants(matching: .any).matching(identifier: "rescue-use-link").firstMatch
        var u = 0
        while !use.exists && u < 4 { app.swipeUp(); u += 1; sleep(1) }
        if use.waitForExistence(timeout: 4) { use.tap(); sleep(2); shoot(app, "rescueuse") }
        else { shoot(app, "rescueuse_LINK_MISSING") }
    }

    /// 履歴: 保険チケット CollapsibleSection を展開して golden 撮影。
    func testCaptureRescueTicketExpanded() {
        let app = launch(["--skip-onboarding", "--initial-tab", "stats"] + seed)
        sleep(2)
        // 「保険チケット」ヘッダ(Button・label に保険チケットを含む)をタップして展開。
        let header = app.buttons.matching(NSPredicate(format: "label CONTAINS '保険チケット'")).firstMatch
        var tries = 0
        while !header.exists && tries < 6 { app.swipeUp(); tries += 1; sleep(1) }
        if header.waitForExistence(timeout: 4) { header.tap(); sleep(2); shoot(app, "rescue_expanded") }
        else { shoot(app, "rescue_expanded_MISSING") }
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
