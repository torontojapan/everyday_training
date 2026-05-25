import XCTest
@testable import CerealExercise

@MainActor
final class WeeklyRankingCalculatorTests: XCTestCase {

    private func make(_ code: String,
                      streak: Int = 0,
                      minutes: Int = 0,
                      weeklyDays: Int = 0) -> FriendProfile {
        var weekly = Array(repeating: false, count: 7)
        for i in 0..<min(weeklyDays, 7) { weekly[i] = true }
        return FriendProfile(
            id: code, friendCode: code, username: code.lowercased(),
            displayName: code, currentStreak: streak, totalAchievedDays: 0,
            todayAchieved: false, todayCategoryName: nil, todayExerciseNames: [],
            decorationTier: 0, lastUpdated: Date(),
            weeklyAchievements: weekly, connectedSince: nil,
            todayExerciseDetails: nil, weeklyTotalMinutes: minutes
        )
    }

    // MARK: - Primary sort: currentStreak

    func testRanksByStreakDescending() {
        let a = make("A", streak: 5)
        let b = make("B", streak: 30)
        let c = make("C", streak: 10)
        let ranked = WeeklyRankingCalculator.rank(friends: [a, b, c], myProfile: nil)
        XCTAssertEqual(ranked.map(\.profile.friendCode), ["B", "C", "A"])
        XCTAssertEqual(ranked.map(\.rank), [1, 2, 3])
    }

    // MARK: - Secondary sort: weeklyTotalMinutes

    func testStreakTieBrokenByMinutes() {
        let a = make("A", streak: 10, minutes: 60)
        let b = make("B", streak: 10, minutes: 180)
        let ranked = WeeklyRankingCalculator.rank(friends: [a, b], myProfile: nil)
        XCTAssertEqual(ranked.map(\.profile.friendCode), ["B", "A"])
    }

    // MARK: - Tertiary: weeklyAchievedCount

    func testStreakAndMinutesTieBrokenByWeeklyDays() {
        let a = make("AAA", streak: 10, minutes: 100, weeklyDays: 3)
        let b = make("BBB", streak: 10, minutes: 100, weeklyDays: 6)
        let ranked = WeeklyRankingCalculator.rank(friends: [a, b], myProfile: nil)
        XCTAssertEqual(ranked.map(\.profile.friendCode), ["BBB", "AAA"])
    }

    // MARK: - My profile inclusion

    func testIncludesAndFlagsMe() {
        let a = make("A", streak: 4)
        let me = make("ME", streak: 12)
        let ranked = WeeklyRankingCalculator.rank(friends: [a], myProfile: me)
        XCTAssertEqual(ranked.count, 2)
        XCTAssertEqual(ranked.first?.profile.friendCode, "ME")
        XCTAssertTrue(ranked.first?.isMe ?? false)
    }

    func testEntryExposesMinutesAndWeeklyCount() {
        let p = make("P", streak: 7, minutes: 95, weeklyDays: 4)
        let ranked = WeeklyRankingCalculator.rank(friends: [p], myProfile: nil)
        XCTAssertEqual(ranked.first?.weeklyMinutes, 95)
        XCTAssertEqual(ranked.first?.weeklyAchievedCount, 4)
    }

    // MARK: - Edge cases

    func testEmptyInputYieldsEmptyRanking() {
        let ranked = WeeklyRankingCalculator.rank(friends: [], myProfile: nil)
        XCTAssertTrue(ranked.isEmpty)
    }

    func testOnlyMeYieldsRank1() {
        let me = make("ME", streak: 2)
        let ranked = WeeklyRankingCalculator.rank(friends: [], myProfile: me)
        XCTAssertEqual(ranked.count, 1)
        XCTAssertEqual(ranked.first?.rank, 1)
        XCTAssertTrue(ranked.first?.isMe ?? false)
    }

    /// Strict ranking: each tied entry still receives a distinct rank number
    /// (1, 2, 3 ...). We dropped dense ranking on purpose — fitness rivalry
    /// is more motivating when ties get nudged into distinct positions by
    /// the fallback sort (friendCode lex).
    func testFullTieGetsDistinctRanksByFallback() {
        let a = make("AAA", streak: 10, minutes: 60, weeklyDays: 5)
        let b = make("BBB", streak: 10, minutes: 60, weeklyDays: 5)
        let ranked = WeeklyRankingCalculator.rank(friends: [a, b], myProfile: nil)
        XCTAssertEqual(ranked.map(\.rank), [1, 2], "every position is distinct")
        XCTAssertEqual(ranked.map(\.profile.friendCode), ["AAA", "BBB"], "fallback sorts by friendCode")
    }

    func testMissingWeeklyMinutesTreatedAsZero() {
        var bare = make("BARE", streak: 5)
        bare.weeklyTotalMinutes = nil
        let other = make("OTHER", streak: 5, minutes: 30)
        let ranked = WeeklyRankingCalculator.rank(friends: [bare, other], myProfile: nil)
        XCTAssertEqual(ranked.first?.profile.friendCode, "OTHER")
        XCTAssertEqual(ranked.last?.weeklyMinutes, 0)
    }
}
