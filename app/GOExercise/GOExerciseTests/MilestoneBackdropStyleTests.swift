import XCTest
@testable import GOExercise

final class MilestoneBackdropStyleTests: XCTestCase {
    func test_zeroStreak_isPlain() {
        let s = MilestoneBackdropStyle(streak: 0)
        XCTAssertEqual(s.rank, 0)
        XCTAssertEqual(s.richness, 0, accuracy: 0.0001)
        XCTAssertEqual(s.glowOpacity, 0, accuracy: 0.0001)
        XCTAssertEqual(s.sparkleCount, 0)
        XCTAssertFalse(s.animated)
        XCTAssertNil(s.metalKind)
    }
    func test_sevenStreak_rank1() {
        let s = MilestoneBackdropStyle(streak: 7)
        XCTAssertEqual(s.rank, 1)
        XCTAssertEqual(s.sparkleCount, 6) // 4 + 1*2
        XCTAssertFalse(s.animated)
        XCTAssertEqual(s.metalKind, .bronze)
    }
    func test_hundredStreak_rank6() {
        XCTAssertEqual(MilestoneBackdropStyle(streak: 100).rank, 6)
    }
    func test_yearStreak_animated() {
        let s = MilestoneBackdropStyle(streak: 365)
        XCTAssertEqual(s.rank, 10)
        XCTAssertTrue(s.animated)
        XCTAssertEqual(s.metalKind, .platinum)
    }
    func test_maxStreak_sparkleCapped() {
        let s = MilestoneBackdropStyle(streak: 500)
        XCTAssertEqual(s.rank, 11)
        XCTAssertEqual(s.sparkleCount, 24) // min(4+11*2, 24)
        XCTAssertEqual(s.richness, 1, accuracy: 0.0001)
        XCTAssertTrue(s.animated)
        XCTAssertEqual(s.metalKind, .rainbow)
    }
}
