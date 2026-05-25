import XCTest
@testable import CerealExercise

@MainActor
final class WeeklyRankingCalculatorTests: XCTestCase {

    private func make(_ code: String,
                      weeklyDays: Int,
                      streak: Int = 0) -> FriendProfile {
        var weekly = Array(repeating: false, count: 7)
        for i in 0..<min(weeklyDays, 7) { weekly[i] = true }
        return FriendProfile(
            id: code, friendCode: code, username: code.lowercased(),
            displayName: code, currentStreak: streak, totalAchievedDays: 0,
            todayAchieved: false, todayCategoryName: nil, todayExerciseNames: [],
            decorationTier: 0, lastUpdated: Date(),
            weeklyAchievements: weekly, connectedSince: nil,
            todayExerciseDetails: nil
        )
    }

    func testRanksByWeeklyAchievedDescending() {
        let a = make("A", weeklyDays: 3)
        let b = make("B", weeklyDays: 7)
        let c = make("C", weeklyDays: 5)
        let ranked = WeeklyRankingCalculator.rank(friends: [a, b, c], myProfile: nil)
        XCTAssertEqual(ranked.map(\.profile.friendCode), ["B", "C", "A"])
        XCTAssertEqual(ranked.map(\.rank), [1, 2, 3])
    }

    func testIncludesMyProfile() {
        let a = make("A", weeklyDays: 4)
        let me = make("ME", weeklyDays: 6)
        let ranked = WeeklyRankingCalculator.rank(friends: [a], myProfile: me)
        XCTAssertEqual(ranked.count, 2)
        XCTAssertEqual(ranked.first?.profile.friendCode, "ME")
        XCTAssertTrue(ranked.first?.isMe ?? false)
    }

    func testTiebreakOnStreak() {
        let a = make("A", weeklyDays: 5, streak: 3)
        let b = make("B", weeklyDays: 5, streak: 12)
        let ranked = WeeklyRankingCalculator.rank(friends: [a, b], myProfile: nil)
        XCTAssertEqual(ranked.map(\.profile.friendCode), ["B", "A"])
    }

    func testDenseRankingForFullTie() {
        // Two friends fully tied (same weekly count + same streak) share rank
        // 1; the next one is rank 3, not rank 2.
        let a = make("AAA", weeklyDays: 7, streak: 10)
        let b = make("BBB", weeklyDays: 7, streak: 10)
        let c = make("CCC", weeklyDays: 5, streak: 5)
        let ranked = WeeklyRankingCalculator.rank(friends: [a, b, c], myProfile: nil)
        XCTAssertEqual(ranked.map(\.rank), [1, 1, 3])
    }

    func testEmptyInputYieldsEmptyRanking() {
        let ranked = WeeklyRankingCalculator.rank(friends: [], myProfile: nil)
        XCTAssertTrue(ranked.isEmpty)
    }

    func testOnlyMeYieldsRank1() {
        let me = make("ME", weeklyDays: 2)
        let ranked = WeeklyRankingCalculator.rank(friends: [], myProfile: me)
        XCTAssertEqual(ranked.count, 1)
        XCTAssertEqual(ranked.first?.rank, 1)
        XCTAssertTrue(ranked.first?.isMe ?? false)
    }

    func testWeeklyAchievedCountIsCorrect() {
        let p = make("P", weeklyDays: 4)
        let ranked = WeeklyRankingCalculator.rank(friends: [p], myProfile: nil)
        XCTAssertEqual(ranked.first?.weeklyAchievedCount, 4)
    }

    func testProfilesMissingWeeklyAchievementsAreTreatedAsZero() {
        var bare = make("BARE", weeklyDays: 0)
        bare.weeklyAchievements = nil
        let other = make("OTHER", weeklyDays: 3)
        let ranked = WeeklyRankingCalculator.rank(friends: [bare, other], myProfile: nil)
        XCTAssertEqual(ranked.map(\.profile.friendCode), ["OTHER", "BARE"])
        XCTAssertEqual(ranked.last?.weeklyAchievedCount, 0)
    }
}
