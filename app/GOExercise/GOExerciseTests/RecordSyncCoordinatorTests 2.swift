import XCTest
@testable import GOExercise

/// クラウドバックアップ正本(RecordSyncCoordinator)の回帰テスト。
/// 監査で「テスト皆無」と指摘された箇所(#12)。UserDefaults suite を毎回新規にして isolation する。
@MainActor
final class RecordSyncCoordinatorTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "rsc-test-\(UUID().uuidString)")!
    }

    private func makeCoordinator(defaults: UserDefaults) -> (RecordSyncCoordinator, MockFriendsService) {
        let mock = MockFriendsService(defaults: defaults)
        let coord = RecordSyncCoordinator(
            service: mock,
            defaults: defaults,
            rescueStore: RescueTicketStore(defaults: defaults),
        )
        return (coord, mock)
    }

    func testResetForIdentityChangeClearsWatermark() {
        let defaults = freshDefaults()
        defaults.set(Date().timeIntervalSince1970, forKey: RecordSyncCoordinator.lastSyncKey)
        let (coord, _) = makeCoordinator(defaults: defaults)
        XCTAssertNotNil(coord.lastSyncAt, "init で watermark をロードする")
        coord.resetForIdentityChange()
        XCTAssertNil(coord.lastSyncAt, "identity 変更で watermark を破棄する(口座跨ぎ防止)")
        XCTAssertNil(defaults.object(forKey: RecordSyncCoordinator.lastSyncKey))
    }

    func testEnableBackupSignsInAndEnables() async {
        let defaults = freshDefaults()
        let (coord, mock) = makeCoordinator(defaults: defaults)
        XCTAssertNil(mock.myProfile)
        await coord.enableBackup()
        XCTAssertNotNil(mock.myProfile, "未サインインなら匿名アカウントを発行する")
        XCTAssertTrue(coord.isEnabled)
    }

    func testDisableBackupStopsSyncButKeepsEnabledFlagOff() {
        let defaults = freshDefaults()
        let (coord, _) = makeCoordinator(defaults: defaults)
        coord.isEnabled = true
        coord.disableBackup()
        XCTAssertFalse(coord.isEnabled, "OFF は同期を止めるだけ(クラウド側は残す)")
    }

    func testSyncNowIsNoopWithoutModelContext() async {
        // attach 前(modelContext==nil)は syncNow が破壊的操作をせず早期 return する。
        let defaults = freshDefaults()
        let (coord, mock) = makeCoordinator(defaults: defaults)
        try? await mock.signIn(displayName: "t", username: "t")
        coord.isEnabled = true
        await coord.syncNow()
        XCTAssertFalse(coord.isSyncing, "context 未 attach では同期に入らない")
    }
}
