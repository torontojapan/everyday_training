import XCTest
@testable import GOExercise

@MainActor
final class ReferralStoreTests: XCTestCase {

    private func makeMock() -> MockFriendsService {
        let suite = "referral.tests.\(UUID().uuidString)"
        return MockFriendsService(defaults: UserDefaults(suiteName: suite)!)
    }

    func test_submitInviteCode_autoFriends_andSetsHasReferrer() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "新規", username: "newbie")
        try await svc.submitInviteCode("AKIRA1")
        let has = try await svc.hasReferrer()
        XCTAssertTrue(has)
        let friends = try await svc.refreshFriends()
        XCTAssertTrue(friends.contains { $0.friendCode == "AKIRA1" })
    }

    func test_submitInviteCode_rejectsDuplicate() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "新規", username: "newbie")
        try await svc.submitInviteCode("AKIRA1")
        do { try await svc.submitInviteCode("YUKINA"); XCTFail("should throw") }
        catch { XCTAssertTrue(error is FriendsServiceError) }
    }

    func test_confirm_returnsRefereePop_thenNilSecondTime() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "新規", username: "newbie")
        try await svc.submitInviteCode("AKIRA1")
        let pop = try await svc.confirmReferralIfEligible(hasFirstRecord: true)
        XCTAssertEqual(pop?.role, .referee)
        let again = try await svc.confirmReferralIfEligible(hasFirstRecord: true)
        XCTAssertNil(again)
    }

    func test_confirm_noFirstRecord_returnsNil() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "新規", username: "newbie")
        try await svc.submitInviteCode("AKIRA1")
        let pop = try await svc.confirmReferralIfEligible(hasFirstRecord: false)
        XCTAssertNil(pop)
    }

    func test_unseenReferrerConfirmations_markSeen() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "紹介者", username: "host")
        svc._seedInboundConfirmation(refereeName: "ともだちA", at: Date())
        let first = try await svc.unseenReferrerConfirmations()
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first.first?.role, .referrer)
        let second = try await svc.unseenReferrerConfirmations()
        XCTAssertTrue(second.isEmpty)
    }

    func test_referralSummary_starsAndMonthlyBonus() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "紹介者", username: "host")
        svc._seedInboundConfirmation(refereeName: "A", at: Date())
        svc._seedInboundConfirmation(refereeName: "B", at: Date())
        let s = try await svc.referralSummary()
        XCTAssertEqual(s.starBadges, 2)
        XCTAssertEqual(s.freezeBonusThisMonth, 2)
    }

    func test_store_submit_setsHasReferrer_andRefreshes() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "新規", username: "newbie")
        let store = ReferralStore(service: svc,
                                  defaults: UserDefaults(suiteName: "rs.\(UUID().uuidString)")!,
                                  isSignedIn: { true })
        let ok = await store.submitCode("akira1")   // 小文字でも sanitize で大文字化
        XCTAssertTrue(ok)
        XCTAssertTrue(store.hasReferrer)
    }

    func test_store_submit_invalidCode_setsError() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "新規", username: "newbie")
        let store = ReferralStore(service: svc,
                                  defaults: UserDefaults(suiteName: "rs.\(UUID().uuidString)")!,
                                  isSignedIn: { true })
        let ok = await store.submitCode("xx")        // 6文字未満
        XCTAssertFalse(ok)
        XCTAssertNotNil(store.lastError)
    }

    func test_store_confirmFirstRecord_setsWelcomePop() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "新規", username: "newbie")
        let store = ReferralStore(service: svc,
                                  defaults: UserDefaults(suiteName: "rs.\(UUID().uuidString)")!,
                                  isSignedIn: { true })
        _ = await store.submitCode("AKIRA1")
        await store.confirmFirstRecordIfNeeded(hasFirstRecord: true)
        XCTAssertEqual(store.pendingWelcome?.role, .referee)
    }

    func test_store_notSignedIn_refreshIsNoop() async {
        let svc = makeMock()
        let store = ReferralStore(service: svc,
                                  defaults: UserDefaults(suiteName: "rs.\(UUID().uuidString)")!,
                                  isSignedIn: { false })
        await store.refresh()
        XCTAssertEqual(store.summary, .empty)
    }
}
