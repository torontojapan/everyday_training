import XCTest
@testable import CerealExercise

@MainActor
final class LeagueRulesTests: XCTestCase {

    func testTopRankPromotes() {
        let outcome = LeagueRules.outcome(from: .silver, myRank: 1, cohortSize: 5)
        XCTAssertEqual(outcome, .promoted(from: .silver, to: .gold))
    }

    func testSecondRankAlsoPromotes() {
        // promotionCount = 2
        let outcome = LeagueRules.outcome(from: .bronze, myRank: 2, cohortSize: 5)
        XCTAssertEqual(outcome, .promoted(from: .bronze, to: .silver))
    }

    func testThirdRankIsNeutralIn5PersonCohort() {
        // 5 people, top 2 promote, bottom 1 demotes (rank 5), rank 3 + 4 = neutral
        let outcome = LeagueRules.outcome(from: .gold, myRank: 3, cohortSize: 5)
        XCTAssertEqual(outcome, .held(at: .gold))
    }

    func testLastRankDemotes() {
        let outcome = LeagueRules.outcome(from: .gold, myRank: 5, cohortSize: 5)
        XCTAssertEqual(outcome, .demoted(from: .gold, to: .silver))
    }

    func testDiamondCannotPromote() {
        let outcome = LeagueRules.outcome(from: .diamond, myRank: 1, cohortSize: 5)
        XCTAssertEqual(outcome, .held(at: .diamond))
    }

    func testBronzeCannotDemote() {
        let outcome = LeagueRules.outcome(from: .bronze, myRank: 5, cohortSize: 5)
        XCTAssertEqual(outcome, .held(at: .bronze))
    }

    func testSinglePersonCohortAlwaysPromotes() {
        // Cohort of 1: rank 1 < promotionCount, so it promotes.
        let outcome = LeagueRules.outcome(from: .silver, myRank: 1, cohortSize: 1)
        XCTAssertEqual(outcome, .promoted(from: .silver, to: .gold))
    }
}

@MainActor
final class LeagueStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "LeagueStoreTests")!
        defaults.removePersistentDomain(forName: "LeagueStoreTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "LeagueStoreTests")
        defaults = nil
        super.tearDown()
    }

    func testDefaultsToBronze() {
        let store = LeagueStore(defaults: defaults, today: Date())
        XCTAssertEqual(store.currentLeague, .bronze)
    }

    func testTogglingPersists() {
        let store = LeagueStore(defaults: defaults, today: Date())
        store.currentLeague = .platinum

        let reloaded = LeagueStore(defaults: defaults, today: Date())
        XCTAssertEqual(reloaded.currentLeague, .platinum)
    }

    func testMonthTransitionAppliesOutcome() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)   // 2023-11-14
        let nextMonth = Date(timeIntervalSince1970: 1_703_000_000) // 2023-12-19
        let store = LeagueStore(defaults: defaults, today: today)
        store.currentLeague = .silver

        let outcome = store.applyMonthlyOutcomeIfNeeded(today: nextMonth) { league in
            .promoted(from: league, to: .gold)
        }

        XCTAssertEqual(outcome, .promoted(from: .silver, to: .gold))
        XCTAssertEqual(store.currentLeague, .gold)
    }

    func testSameMonthDoesNotTrigger() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)   // 2023-11-14
        let sameMonth = today.addingTimeInterval(60 * 60 * 24)   // 2023-11-15
        let store = LeagueStore(defaults: defaults, today: today)
        store.currentLeague = .silver

        let outcome = store.applyMonthlyOutcomeIfNeeded(today: sameMonth) { _ in
            .promoted(from: .silver, to: .gold)
        }

        XCTAssertNil(outcome, "no-op when month hasn't changed")
        XCTAssertEqual(store.currentLeague, .silver)
    }
}

@MainActor
final class MonthlyRankingCalculatorTests: XCTestCase {

    private func make(_ code: String, monthly: Int, streak: Int = 0) -> FriendProfile {
        FriendProfile(
            id: code, friendCode: code, username: code.lowercased(),
            displayName: code, currentStreak: streak, totalAchievedDays: 0,
            todayAchieved: false, todayCategoryName: nil, todayExerciseNames: [],
            decorationTier: 0, lastUpdated: Date(),
            weeklyAchievements: nil, connectedSince: nil,
            todayExerciseDetails: nil, monthlyAchievedDays: monthly
        )
    }

    func testSortsDescByMonthlyDays() {
        let a = make("A", monthly: 10)
        let b = make("B", monthly: 25)
        let c = make("C", monthly: 17)
        let ranked = MonthlyRankingCalculator.rank(friends: [a, b, c], myProfile: nil)
        XCTAssertEqual(ranked.map(\.profile.friendCode), ["B", "C", "A"])
    }

    func testTieBreakerStreak() {
        let a = make("A", monthly: 20, streak: 3)
        let b = make("B", monthly: 20, streak: 30)
        let ranked = MonthlyRankingCalculator.rank(friends: [a, b], myProfile: nil)
        XCTAssertEqual(ranked.map(\.profile.friendCode), ["B", "A"])
    }

    func testIncludesAndFlagsMe() {
        let a = make("A", monthly: 5)
        let me = make("ME", monthly: 12)
        let ranked = MonthlyRankingCalculator.rank(friends: [a], myProfile: me)
        XCTAssertEqual(ranked.first?.profile.friendCode, "ME")
        XCTAssertTrue(ranked.first?.isMe ?? false)
    }

    func testNilMonthlyTreatedAsZero() {
        var bare = make("BARE", monthly: 0)
        bare.monthlyAchievedDays = nil
        let other = make("OTHER", monthly: 3)
        let ranked = MonthlyRankingCalculator.rank(friends: [bare, other], myProfile: nil)
        XCTAssertEqual(ranked.last?.monthlyAchievedDays, 0)
    }
}
