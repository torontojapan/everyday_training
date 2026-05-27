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
        return app
    }

    /// 設定画面: 「アプリを友達にシェア」が **通知より上に存在** すること。
    /// 通知 row より上端側に Y 座標があれば最上位セクションに置かれているとみなす。
    func testSettings_shareRow_isAboveNotificationRow() {
        let app = launch(initialTab: "settings")
        let shareRow = app.buttons["settings-share-app"]
        XCTAssertTrue(shareRow.waitForExistence(timeout: 5),
                       "「アプリを友達にシェア」行が設定画面に存在しなければならない")

        // 通知設定行が見えていること (設定画面のはず) を確認しつつ、Y 順を検証。
        let notifRow = app.cells.containing(NSPredicate(format: "label CONTAINS '通知設定'")).firstMatch
        XCTAssertTrue(notifRow.waitForExistence(timeout: 3))

        XCTAssertLessThan(shareRow.frame.minY, notifRow.frame.minY,
                          "アプリ共有行は通知設定より上に置かれているべき (現在 share=\(shareRow.frame.minY), notif=\(notifRow.frame.minY))")
    }

    /// 友達画面 (signed in): 「このアプリを友達にシェア」が **友達コード行直下** にあること。
    /// 友達コードを示すラベルより Y 座標が下、かつサインアウト行 (=ボディ末尾) より上に位置する
    /// ことで「プロフィール直下に固定」を保証する。
    func testFriends_shareCard_isBelowFriendCode_andAboveSignOut() {
        let app = launch(initialTab: "friends")
        let shareCard = app.buttons["share-app-button"]
        XCTAssertTrue(shareCard.waitForExistence(timeout: 5),
                       "「このアプリを友達にシェア」カードが友達画面に存在しなければならない")

        let friendCodeLabel = app.staticTexts["あなたの友達コード"]
        XCTAssertTrue(friendCodeLabel.waitForExistence(timeout: 3),
                       "友達コード見出しが見つからない")

        let signOut = app.buttons.containing(NSPredicate(format: "label CONTAINS 'サインアウト'")).firstMatch
        XCTAssertTrue(signOut.waitForExistence(timeout: 3))

        XCTAssertGreaterThan(shareCard.frame.minY, friendCodeLabel.frame.minY,
                             "シェアカードは友達コードより下にあるべき")
        XCTAssertLessThan(shareCard.frame.minY, signOut.frame.minY,
                          "シェアカードはサインアウトより上にあるべき (プロフィール直下に固定)")
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
