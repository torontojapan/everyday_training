import XCTest
@testable import CerealExercise

final class CatStateResolverTests: XCTestCase {
    private let calendar = Calendar.mondayFirst

    func testStreakExtendedHasHighestPriority() {
        let state = CatStateResolver.resolve(
            todayStatus: .todayAchieved,
            now: date(hour: 20),
            yesterdayAchieved: false,
            streakExtendedThisRun: true,
            calendar: calendar
        )

        XCTAssertEqual(state, .streakExtended)
    }

    func testTodayAchievedBecomesCelebrating() {
        let state = CatStateResolver.resolve(
            todayStatus: .todayAchieved,
            now: date(hour: 9),
            yesterdayAchieved: false,
            streakExtendedThisRun: false,
            calendar: calendar
        )

        XCTAssertEqual(state, .celebrating)
    }

    func testRestDayBecomesResting() {
        let state = CatStateResolver.resolve(
            todayStatus: .rest,
            now: date(hour: 13),
            yesterdayAchieved: false,
            streakExtendedThisRun: false,
            calendar: calendar
        )

        XCTAssertEqual(state, .resting)
    }

    func testYesterdayMissedBecomesEncouraging() {
        let state = CatStateResolver.resolve(
            todayStatus: .todayPending,
            now: date(hour: 9),
            yesterdayAchieved: false,
            streakExtendedThisRun: false,
            calendar: calendar
        )

        XCTAssertEqual(state, .encouraging)
    }

    func testMorningPendingBecomesWaitingMorning() {
        let state = CatStateResolver.resolve(
            todayStatus: .todayPending,
            now: date(hour: 11, minute: 59),
            yesterdayAchieved: true,
            streakExtendedThisRun: false,
            calendar: calendar
        )

        XCTAssertEqual(state, .waitingMorning)
    }

    func testNoonPendingBecomesWorriedNoon() {
        let state = CatStateResolver.resolve(
            todayStatus: .todayPending,
            now: date(hour: 12),
            yesterdayAchieved: true,
            streakExtendedThisRun: false,
            calendar: calendar
        )

        XCTAssertEqual(state, .worriedNoon)
    }

    func testNightPendingBecomesBeggingNight() {
        let state = CatStateResolver.resolve(
            todayStatus: .todayPending,
            now: date(hour: 18),
            yesterdayAchieved: true,
            streakExtendedThisRun: false,
            calendar: calendar
        )

        XCTAssertEqual(state, .beggingNight)
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 5, day: 20, hour: hour, minute: minute))!
    }
}
