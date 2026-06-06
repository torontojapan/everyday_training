import XCTest
@testable import GOExercise

final class MilestoneBackdropStyleTests: XCTestCase {
    func test_zeroDays_isPlain() {
        let s = MilestoneBackdropStyle(totalAchievedDays: 0)
        XCTAssertEqual(s.tier, 0)
        XCTAssertEqual(s.richness, 0, accuracy: 0.0001)
        XCTAssertEqual(s.glowOpacity, 0, accuracy: 0.0001)
        XCTAssertEqual(s.sparkleCount, 0)
        XCTAssertFalse(s.animated)
    }
    func test_sevenDays_tier1() {
        let s = MilestoneBackdropStyle(totalAchievedDays: 7)
        XCTAssertEqual(s.tier, 1)
        XCTAssertEqual(s.sparkleCount, 6) // 4 + 1*2
        XCTAssertFalse(s.animated)
    }
    func test_hundredDays_tier6() {
        XCTAssertEqual(MilestoneBackdropStyle(totalAchievedDays: 100).tier, 6)
    }
    func test_yearDays_animated() {
        let s = MilestoneBackdropStyle(totalAchievedDays: 365)
        XCTAssertEqual(s.tier, 10)
        XCTAssertTrue(s.animated)
    }
    func test_maxDays_sparkleCapped() {
        let s = MilestoneBackdropStyle(totalAchievedDays: 500)
        XCTAssertEqual(s.tier, 11)
        XCTAssertEqual(s.sparkleCount, 24) // min(4+11*2, 24) = 24
        XCTAssertEqual(s.richness, 1, accuracy: 0.0001)
        XCTAssertTrue(s.animated)
    }
}
