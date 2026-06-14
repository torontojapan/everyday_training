import XCTest
@testable import GOExercise

final class RankUpDetectorTests: XCTestCase {
    private func makeDetector() -> (RankUpDetector, UserDefaults) {
        let d = UserDefaults(suiteName: "rankup.test.\(UUID().uuidString)")!
        return (RankUpDetector(defaults: d), d)
    }
    func test_firstRankUpAndWeekly() {
        let (det, _) = makeDetector()
        let ev = det.evaluate(currentStreak: 7)
        XCTAssertTrue(ev.contains(.rankUp(to: 1)))
        XCTAssertTrue(ev.contains(.weekly(streak: 7)))
    }
    func test_noRefireOnSameStreak() {
        let (det, _) = makeDetector()
        _ = det.evaluate(currentStreak: 7)
        XCTAssertTrue(det.evaluate(currentStreak: 7).isEmpty)
    }
    func test_refireAfterReset() {
        let (det, _) = makeDetector()
        _ = det.evaluate(currentStreak: 14)
        XCTAssertTrue(det.evaluate(currentStreak: 0).isEmpty)
        let ev = det.evaluate(currentStreak: 7)
        XCTAssertTrue(ev.contains(.rankUp(to: 1)))
        XCTAssertTrue(ev.contains(.weekly(streak: 7)))
    }
    func test_weeklyOnlyWhenRankUnchanged() {
        let (det, _) = makeDetector()
        _ = det.evaluate(currentStreak: 30)
        let ev = det.evaluate(currentStreak: 35)
        XCTAssertTrue(ev.contains(.weekly(streak: 35)))
        XCTAssertFalse(ev.contains { if case .rankUp = $0 { return true } else { return false } })
    }
}
