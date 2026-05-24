import XCTest
@testable import CerealExercise

final class StreakLevelTests: XCTestCase {
    func testBoundaryAssignments() {
        XCTAssertEqual(StreakLevel(streak: 0), .zero)
        XCTAssertEqual(StreakLevel(streak: 1), .sprout)
        XCTAssertEqual(StreakLevel(streak: 6), .sprout)
        XCTAssertEqual(StreakLevel(streak: 7), .week)
        XCTAssertEqual(StreakLevel(streak: 13), .week)
        XCTAssertEqual(StreakLevel(streak: 14), .twoWeeks)
        XCTAssertEqual(StreakLevel(streak: 29), .twoWeeks)
        XCTAssertEqual(StreakLevel(streak: 30), .month)
        XCTAssertEqual(StreakLevel(streak: 99), .month)
        XCTAssertEqual(StreakLevel(streak: 100), .century)
        XCTAssertEqual(StreakLevel(streak: 364), .century)
        XCTAssertEqual(StreakLevel(streak: 365), .legend)
        XCTAssertEqual(StreakLevel(streak: 9999), .legend)
    }

    func testNegativeStreakFallsToZero() {
        XCTAssertEqual(StreakLevel(streak: -5), .zero)
    }

    func testFireCountIncreasesWithLevel() {
        XCTAssertEqual(StreakLevel(streak: 0).fireCount, 0)
        XCTAssertLessThan(StreakLevel(streak: 5).fireCount, StreakLevel(streak: 50).fireCount)
        XCTAssertLessThan(StreakLevel(streak: 50).fireCount, StreakLevel(streak: 500).fireCount)
    }

    func testSparkleCountIncreasesWithLevel() {
        XCTAssertLessThan(StreakLevel(streak: 5).sparkleCount, StreakLevel(streak: 50).sparkleCount)
        XCTAssertLessThan(StreakLevel(streak: 50).sparkleCount, StreakLevel(streak: 500).sparkleCount)
    }

    func testBadgeText() {
        XCTAssertNil(StreakLevel(streak: 5).badgeText)
        XCTAssertEqual(StreakLevel(streak: 7).badgeText, "1 WEEK")
        XCTAssertEqual(StreakLevel(streak: 100).badgeText, "CENTURY")
        XCTAssertEqual(StreakLevel(streak: 365).badgeText, "LEGEND")
    }

    func testShareMessageContainsAppName() {
        for streak in [1, 7, 14, 30, 100, 365] {
            XCTAssertTrue(
                StreakLevel(streak: streak).shareMessage.contains("GOエクササイズ"),
                "streak=\(streak) message must mention app name"
            )
        }
    }
}

extension StreakLevel: Equatable {
    public static func == (lhs: StreakLevel, rhs: StreakLevel) -> Bool {
        switch (lhs, rhs) {
        case (.zero, .zero), (.sprout, .sprout), (.week, .week),
             (.twoWeeks, .twoWeeks), (.month, .month),
             (.century, .century), (.legend, .legend):
            return true
        default:
            return false
        }
    }
}
