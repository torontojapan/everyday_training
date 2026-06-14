import XCTest
@testable import GOExercise

final class CatRankTests: XCTestCase {
    func test_rankBoundaries() {
        let cases: [(Int, Int)] = [
            (0,0),(6,0),(7,1),(13,1),(14,2),(29,2),(30,3),(49,3),(50,4),
            (74,4),(75,5),(99,5),(100,6),(149,6),(150,7),(199,7),(200,8),
            (299,8),(300,9),(364,9),(365,10),(499,10),(500,11),(99999,11)
        ]
        for (streak, rank) in cases {
            XCTAssertEqual(CatRank(currentStreak: streak).rank, rank, "streak \(streak)")
        }
    }
    func test_reset_isRank0() {
        XCTAssertEqual(CatRank(currentStreak: 0).rank, 0)
        XCTAssertNil(CatRank(currentStreak: 0).title)
        XCTAssertNil(CatRank(currentStreak: 0).metalKind)
        XCTAssertEqual(CatRank(currentStreak: -3).rank, 0)
    }
    func test_titleAndMetal() {
        XCTAssertEqual(CatRank(currentStreak: 7).title, "みならいネコ")
        XCTAssertEqual(CatRank(currentStreak: 7).metalKind, .bronze)
        XCTAssertEqual(CatRank(currentStreak: 30).metalKind, .silver)
        XCTAssertEqual(CatRank(currentStreak: 100).metalKind, .gold)
        XCTAssertEqual(CatRank(currentStreak: 365).metalKind, .platinum)
        XCTAssertEqual(CatRank(currentStreak: 500).title, "ぬしネコ")
        XCTAssertEqual(CatRank(currentStreak: 500).metalKind, .rainbow)
    }
    func test_richness() {
        XCTAssertEqual(CatRank(currentStreak: 0).richness, 0, accuracy: 0.0001)
        XCTAssertEqual(CatRank(currentStreak: 500).richness, 1, accuracy: 0.0001)
    }
}
