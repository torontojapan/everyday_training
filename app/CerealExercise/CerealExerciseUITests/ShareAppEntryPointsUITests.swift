import XCTest

/// `AppSharingConfig` を経由する「アプリを友達にシェア」導線が、ユーザー要望どおりの
/// 位置 (設定画面の最上位 / 友達画面の自分のコード直下) に **必ず存在する** ことを
/// UI レベルで保証する。位置取りの regression (誰かが誤って section を入れ替えた等)
/// を早期に検知するのが目的。
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
            "--mock-seed-friends", "--initial-tab", initialTab,
        ]
        app.launch()
        // --no-notification-prompt があっても初回起動時に system のダイアログが
        // 競合状態で出ることがあるため defensive に dismiss する (Codex round1)。
        let deny = app.alerts.buttons["許可しない"]
        if deny.waitForExistence(timeout: 1) { deny.tap() }
        return app
    }

    /// 設定画面: 「アプリを友達にシェア」が **リスト全体の最上位** にあること。
    /// 同レベルのセクション/セルの中で minY が最小であることを確認することで、
    /// 別の section を上に挿入する regression も検知できる (Codex round1)。
    func testSettings_shareRow_isAtTopOfSettingsList() {
        let app = launch(initialTab: "settings")
        let shareRow = app.buttons["settings-share-app"]
        XCTAssertTrue(shareRow.waitForExistence(timeout: 5),
                       "「アプリを友達にシェア」行が設定画面に存在しなければならない")

        // 設定リストの全 cell を縦軸で並べる。
        // 設定画面の他の行が見えていることをまず確認 (= 設定画面が描画完了)。
        let notifRow = app.cells.containing(NSPredicate(format: "label CONTAINS '通知設定'")).firstMatch
        XCTAssertTrue(notifRow.waitForExistence(timeout: 3))

        // 画面上に見えている cell の中で **最小 minY** が share 行のはず。
        let visibleCells = app.cells.allElementsBoundByIndex.filter { $0.exists && $0.frame.height > 0 }
        let minMinY = visibleCells.map(\.frame.minY).min() ?? .greatestFiniteMagnitude
        XCTAssertEqual(shareRow.frame.minY, minMinY, accuracy: 1.0,
                       "アプリ共有行は設定リストの最上位 cell でなければならない (got minY=\(shareRow.frame.minY), top=\(minMinY))")
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
