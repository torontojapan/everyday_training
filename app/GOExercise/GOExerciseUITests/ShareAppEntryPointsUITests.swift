import XCTest

/// `AppSharingConfig` を経由する「アプリを友達にシェア」導線が、ユーザー要望どおりの
/// 位置 (設定画面でスクロール無しに見える / 友達画面の自分のコード直下) に **必ず存在する**
/// ことを UI レベルで保証する。あわせて設定リスト最上位が「アカウントとバックアップ」で
/// あることも検証する (ユーザー要望 2026-06-13)。位置取りの regression を早期検知する。
@MainActor
final class ShareAppEntryPointsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(initialTab: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--skip-onboarding", "--no-notification-prompt", "--skip-milestones",
            // 友達機能は v1 では既定で非表示。UI テストでは opt-in で有効化する。
            "--enable-friends",
            "--mock-seed-friends", "--initial-tab", initialTab,
        ]
        app.launch()
        // --no-notification-prompt があっても初回起動時に system のダイアログが
        // 競合状態で出ることがあるため defensive に dismiss する (Codex round1)。
        let deny = app.alerts.buttons["許可しない"]
        if deny.waitForExistence(timeout: 1) { deny.tap() }
        return app
    }

    /// 設定画面: 「アカウントとバックアップ」(クラウドバックアップのトグル) が
    /// 他の機能行 (シェア/プレミアム) より **上** にあり、「アプリを友達にシェア」が
    /// スクロール無しで見える位置に残っていること(ユーザー要望 2026-06-13:
    /// バックアップ最優先。シェア導線の存在保証は維持)。
    /// 注: 「全 cell の最小 minY」比較は List のヘッダ等が cell として数えられる
    /// 環境差で偽陽性になるため、既知の機能行との順序比較で検証する。
    func testSettings_backupSection_isAtTop_andShareRowVisible() {
        let app = launch(initialTab: "settings")
        let backupRow = app.cells.containing(
            NSPredicate(format: "label CONTAINS 'クラウドにバックアップ'")).firstMatch
        XCTAssertTrue(backupRow.waitForExistence(timeout: 5),
                       "「記録をクラウドにバックアップ」行が設定画面に存在しなければならない")

        let shareRow = app.buttons["settings-share-app"]
        XCTAssertTrue(shareRow.waitForExistence(timeout: 5),
                       "「アプリを友達にシェア」行が設定画面に存在しなければならない")
        XCTAssertTrue(shareRow.isHittable, "シェア行は初期表示でスクロール無しに見えること")

        // バックアップ行は、後続セクションの先頭行 (シェア) と
        // プレミアム行のどちらよりも上に位置すること。
        XCTAssertLessThan(backupRow.frame.minY, shareRow.frame.minY,
                          "アカウントとバックアップはシェア行より上 (最上位セクション) でなければならない")
        let premiumRow = app.cells.containing(
            NSPredicate(format: "label CONTAINS 'GOプレミアム'")).firstMatch
        if premiumRow.exists {
            XCTAssertLessThan(backupRow.frame.minY, premiumRow.frame.minY,
                              "アカウントとバックアップはプレミアム行より上でなければならない")
        }
    }

    /// 友達画面: 「このアプリを友達にシェア」が **友達コード行の直下** にあること。
    /// 「直下」= シェアカードと友達コードの間に他の visible cell/button が無いことを確認。
    /// 単純な「上下比較」だと requestsSection 下や末尾に移されても通る regression が
    /// 発生したので、近接性を assert する (Codex round1)。
    func testFriends_shareCard_isImmediatelyBelowFriendCode() {
        let app = launch(initialTab: "friends")
        let shareCard = app.buttons["share-app-button"]
        XCTAssertTrue(shareCard.waitForExistence(timeout: 5),
                       "「このアプリを友達にシェア」カードが友達画面に存在しなければならない")

        let friendCodeLabel = app.staticTexts["あなたの友達コード"]
        XCTAssertTrue(friendCodeLabel.waitForExistence(timeout: 3))

        // 友達コードの「友達」セクション見出し (= 「友達 (0)」など) は
        // share カードよりも **下** に来ているべき (= share カードが間に挟まる)。
        let friendsListHeader = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '友達 ('")).firstMatch
        XCTAssertTrue(friendsListHeader.waitForExistence(timeout: 3),
                       "友達セクション見出しが見つからない")

        XCTAssertGreaterThan(shareCard.frame.minY, friendCodeLabel.frame.minY,
                             "シェアカードは友達コードより下にあるべき")
        XCTAssertLessThan(shareCard.frame.minY, friendsListHeader.frame.minY,
                          "シェアカードは『友達 (N)』セクションより上にある = プロフィール直下に固定 (got share=\(shareCard.frame.minY), header=\(friendsListHeader.frame.minY))")

        // **物理的隣接検証** (Codex round3): profileSection の末端から shareCard
        // 先頭までの距離が「セクション間 spacing」レベル (= 親 VStack(spacing: 20)
        // + safe-area margin) を超えない (= 直下) ことを保証する。stable な
        // accessibility identifier "friends-profile-section" を anchor にすることで、
        // ラベル文字列の filter (round2 で不十分と指摘) に依存しない。
        let profileSection = app.otherElements["friends-profile-section"]
        XCTAssertTrue(profileSection.waitForExistence(timeout: 3),
                       "profile section accessibility id が見つからない (regression もしくは a11y wrap 漏れ)")
        // 初回のみ「表示名を決めましょう」カードが profile と share の間に正当に挟まる
        // (新規シミュレータ等のクリーン環境)。その場合は名前カードを anchor にする。
        let namePrompt = app.otherElements["friends-name-prompt"]
        let anchorMaxY = namePrompt.exists ? namePrompt.frame.maxY : profileSection.frame.maxY
        let gap = shareCard.frame.minY - anchorMaxY
        XCTAssertGreaterThanOrEqual(gap, 0,
                                     "share card は profile section (または名前カード) より下にあるべき")
        XCTAssertLessThanOrEqual(gap, 40,
                                  "profile/名前カード と share card の間に余計な要素が挟まっていてはいけない (gap=\(gap)pt)")
    }

    /// 設定画面の ShareLink がクラッシュせずタップできること。
    /// 実際のシェアシート (UIActivityViewController) は別プロセス
    /// `SharingUI` 管轄なので XCUIApplication からは見えない。
    /// クラッシュなく操作可能であれば OK とする (内容は AppSharingConfigTests
    /// が静的に検証済み)。
    func testSettings_shareLink_isTappableWithoutCrash() {
        let app = launch(initialTab: "settings")
        let shareRow = app.buttons["settings-share-app"]
        XCTAssertTrue(shareRow.waitForExistence(timeout: 5))
        XCTAssertTrue(shareRow.isHittable, "シェア行がヒット可能でなければならない")
        shareRow.tap()
        // タップ後に app プロセスが生き残っていることを確認する。
        // (ShareLink でクラッシュすると以降の query で predicate timeout する)
        XCTAssertEqual(app.state, .runningForeground, "ShareLink タップ後もアプリは前面で動作していること")
    }
}
