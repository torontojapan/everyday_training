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

    // MARK: - helpers

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "account.linking.tests.\(UUID().uuidString)")!
    }
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
