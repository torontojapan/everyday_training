import XCTest
@testable import GOExercise

/// Phase 2 アカウント連携(機種変復旧)の config-gating と結果マッピングを検証する。
/// 実 Apple/Supabase 連携フローは実機 + プロバイダ設定での手動確認 (ここでは到達しない)。
@MainActor
final class AccountLinkingTests: XCTestCase {

    // MARK: - config gating (既定は無効 = 現挙動維持)

    func testLinkingDisabledByDefault() {
        // テスト host の Info.plist に Friends*LinkEnabled は無いので false。
        XCTAssertFalse(SupabaseConfig.appleLinkEnabled)
        XCTAssertFalse(SupabaseConfig.googleLinkEnabled)
        XCTAssertFalse(SupabaseConfig.isAccountLinkingEnabled)
    }

    // MARK: - エラー文言

    func testAccountLinkErrorDescriptions() {
        XCTAssertNotNil(AccountLinkError.alreadyLinkedToAnotherAccount.errorDescription)
        XCTAssertNotNil(AccountLinkError.providerUnavailable.errorDescription)
        XCTAssertNotNil(AccountLinkError.cancelled.errorDescription)
        XCTAssertNotNil(AccountLinkError.backendUnavailable.errorDescription)
        XCTAssertNotNil(AccountLinkError.failed.errorDescription)
    }

    func testBackupStatusDefaultsAnonymous() {
        XCTAssertFalse(AccountBackupStatus.anonymous.isBackedUp)
        XCTAssertNil(AccountBackupStatus.anonymous.providerName)
    }

    // MARK: - FriendsStore のマッピング

    func testStoreDefaultBackupStatusIsAnonymous() async {
        let store = FriendsStore(service: MockFriendsService(defaults: makeDefaults()))
        XCTAssertFalse(store.isBackedUp)
        await store.refreshBackupStatus()
        XCTAssertFalse(store.isBackedUp, "Mock は連携未対応 = 匿名のまま")
    }

    func testLinkAppleMapsCollision() async {
        let store = FriendsStore(service: LinkStubService(linkError: .alreadyLinkedToAnotherAccount))
        let result = await store.linkApple(idToken: "t", nonce: "n")
        XCTAssertEqual(result, .collision, "identity_already_exists 相当は collision に写像")
    }

    func testLinkAppleMapsFailure() async {
        let store = FriendsStore(service: LinkStubService(linkError: .providerUnavailable))
        let result = await store.linkApple(idToken: "t", nonce: "n")
        if case .failed = result { } else { XCTFail("provider 不可は failed に写像されるはず") }
    }

    func testLinkAppleSuccess() async {
        let store = FriendsStore(service: LinkStubService(linkError: nil, linkedStatus:
            AccountBackupStatus(isBackedUp: true, providerName: "apple")))
        let result = await store.linkApple(idToken: "t", nonce: "n")
        XCTAssertEqual(result, .linked)
        XCTAssertTrue(store.isBackedUp)
    }

    // MARK: - 復元入口 (restoreWithApple)

    func testRestoreRestoredLoadsProfile() async {
        let restored = Self.sampleProfile(code: "ABC123")
        let store = FriendsStore(service: RestoreStubService(outcome: .restored, restoredProfile: restored))
        let result = await store.restoreWithApple(idToken: "t", nonce: "n")
        XCTAssertEqual(result, .restored)
        XCTAssertEqual(store.profile?.friendCode, "ABC123", "復元成功で既存プロフィールが反映される")
        XCTAssertTrue(store.isBackedUp)
    }

    func testRestoreCreatedWhenNoExistingData() async {
        let store = FriendsStore(service: RestoreStubService(outcome: .created,
                                                             restoredProfile: Self.sampleProfile(code: "NEW001")))
        let result = await store.restoreWithApple(idToken: "t", nonce: "n")
        XCTAssertEqual(result, .created, "既存データ無しは created に写像")
        XCTAssertTrue(store.isBackedUp)
    }

    func testRestoreFailureSetsLastError() async {
        let store = FriendsStore(service: RestoreStubService(error: .backendUnavailable))
        let result = await store.restoreWithApple(idToken: "t", nonce: "n")
        if case .failed = result {} else { XCTFail("失敗は .failed に写像されるはず") }
        XCTAssertNotNil(store.lastError)
        XCTAssertNil(store.profile, "失敗時は profile を変えない")
    }

    func testRestoreDefaultUnavailableForMock() async {
        // Mock は連携未対応 = protocol default で providerUnavailable を throw → failed。
        let store = FriendsStore(service: MockFriendsService(defaults: makeDefaults()))
        let result = await store.restoreWithApple(idToken: "t", nonce: "n")
        if case .failed = result {} else { XCTFail("未対応サービスは failed") }
    }

    func testAnonymousSessionHasDataDefaultsFalse() async {
        let store = FriendsStore(service: MockFriendsService(defaults: makeDefaults()))
        let hasData = await store.anonymousSessionHasData()
        XCTAssertFalse(hasData, "既定 (未対応/未サインイン) は確認不要 = false")
    }

    func testAnonymousSessionHasDataReflectsService() async {
        let store = FriendsStore(service: RestoreStubService(hasData: true))
        let hasData = await store.anonymousSessionHasData()
        XCTAssertTrue(hasData)
    }

    // MARK: - helpers

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "account.linking.tests.\(UUID().uuidString)")!
    }

    static func sampleProfile(code: String) -> FriendProfile {
        FriendProfile(
            id: code, friendCode: code, username: code.lowercased(),
            displayName: code, currentStreak: 0, totalAchievedDays: 0,
            todayAchieved: false, todayCategoryName: nil, todayExerciseNames: [],
            decorationTier: 0, lastUpdated: Date(),
            weeklyAchievements: nil, connectedSince: nil
        )
    }
}

/// 復元/切替の結果だけを差し替える最小スタブ。`restoreWithApple` と
/// `anonymousSessionHasData` のみ意味を持ち、他は no-op。
@MainActor
private final class RestoreStubService: FriendsService {
    private let outcome: AppleRestoreOutcome
    private let error: AccountLinkError?
    private let hasData: Bool
    private(set) var myProfile: FriendProfile?
    private(set) var backupStatus: AccountBackupStatus = .anonymous

    init(outcome: AppleRestoreOutcome = .created, error: AccountLinkError? = nil,
         hasData: Bool = false, restoredProfile: FriendProfile? = nil) {
        self.outcome = outcome
        self.error = error
        self.hasData = hasData
        self.myProfile = restoredProfile
    }

    func restoreWithApple(idToken: String, nonce: String) async throws -> AppleRestoreOutcome {
        if let error { throw error }
        backupStatus = AccountBackupStatus(isBackedUp: true, providerName: "apple")
        return outcome
    }
    func anonymousSessionHasData() async -> Bool { hasData }

    func signIn(displayName: String, username: String) async throws {}
    func signOut() async {}
    func refreshFriends() async throws -> [FriendProfile] { [] }
    func pendingRequests() async throws -> [FriendRequest] { [] }
    func sendRequest(to code: String) async throws {}
    func acceptRequest(_ request: FriendRequest) async throws {}
    func declineRequest(_ request: FriendRequest) async throws {}
    func removeFriend(_ profile: FriendProfile) async throws {}
    func searchByUsername(_ query: String) async throws -> [FriendProfile] { [] }
    func publishMyProfile(_ profile: FriendProfile) async throws {}
    func sendCheer(_ kind: CheerKind, to friendCode: String) async throws {}
    func refreshBackupStatus() async {}
}

/// 連携の結果だけを差し替えられる最小スタブ。他メソッドは未使用なので no-op/空。
@MainActor
private final class LinkStubService: FriendsService {
    private let linkError: AccountLinkError?
    private var linkedStatus: AccountBackupStatus
    private(set) var backupStatus: AccountBackupStatus = .anonymous

    init(linkError: AccountLinkError?, linkedStatus: AccountBackupStatus = AccountBackupStatus(isBackedUp: true, providerName: "apple")) {
        self.linkError = linkError
        self.linkedStatus = linkedStatus
    }

    var myProfile: FriendProfile? { nil }
    func signIn(displayName: String, username: String) async throws {}
    func signOut() async {}
    func refreshFriends() async throws -> [FriendProfile] { [] }
    func pendingRequests() async throws -> [FriendRequest] { [] }
    func sendRequest(to code: String) async throws {}
    func acceptRequest(_ request: FriendRequest) async throws {}
    func declineRequest(_ request: FriendRequest) async throws {}
    func removeFriend(_ profile: FriendProfile) async throws {}
    func searchByUsername(_ query: String) async throws -> [FriendProfile] { [] }
    func publishMyProfile(_ profile: FriendProfile) async throws {}
    func sendCheer(_ kind: CheerKind, to friendCode: String) async throws {}

    func refreshBackupStatus() async {}
    func linkApple(idToken: String, nonce: String) async throws {
        if let linkError { throw linkError }
        backupStatus = linkedStatus
    }
}
