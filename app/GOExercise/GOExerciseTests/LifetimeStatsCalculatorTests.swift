import XCTest
@testable import GOExercise

final class LifetimeStatsCalculatorTests: XCTestCase {
    private let calendar = Calendar.mondayFirst

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
    }

    private func record(_ y: Int, _ m: Int, _ d: Int, exercises: [ExerciseItem]? = nil) -> WorkoutRecord {
        WorkoutRecord(
            date: date(y, m, d),
            category: .strength,
            exercises: exercises ?? [ExerciseItem(name: "test")],
            calendar: calendar
        )
    }

    func testUsedDaysIsAtLeastOne() {
        let today = date(2026, 5, 24)
        let stats = LifetimeStatsCalculator.calculate(records: [], firstUseDate: today, today: today, calendar: calendar)
        XCTAssertEqual(stats.usedDays, 1)
        XCTAssertEqual(stats.achievedDays, 0)
    }

    func testUsedDaysIsInclusive() {
        let firstUse = date(2026, 5, 1)
        let today = date(2026, 5, 24)
        let stats = LifetimeStatsCalculator.calculate(records: [], firstUseDate: firstUse, today: today, calendar: calendar)
        // 5/1 ~ 5/24 inclusive = 24 days.
        XCTAssertEqual(stats.usedDays, 24)
    }

    func testAchievedDaysCountsUniqueDates() {
        let firstUse = date(2026, 5, 1)
        let today = date(2026, 5, 24)
        let records = [
            record(2026, 5, 1),
            record(2026, 5, 1),
            record(2026, 5, 5),
            record(2026, 5, 10)
        ]
        let stats = LifetimeStatsCalculator.calculate(records: records, firstUseDate: firstUse, today: today, calendar: calendar)
        XCTAssertEqual(stats.achievedDays, 3, "Same-day records should count once")
    }

    func testNotAchievedRecordIsExcluded() {
        let firstUse = date(2026, 5, 1)
        let today = date(2026, 5, 24)
        // Empty exercises array would not be achieved (no exercises, no duration).
        // Build manually.
        let unachieved = WorkoutRecord(
            date: date(2026, 5, 2),
            category: .strength,
            exercises: [],
            calendar: calendar
        )
        let achieved = record(2026, 5, 3)
        let stats = LifetimeStatsCalculator.calculate(records: [unachieved, achieved], firstUseDate: firstUse, today: today, calendar: calendar)
        XCTAssertEqual(stats.achievedDays, 1)
    }

    func testRatePercentage() {
        let firstUse = date(2026, 5, 1)
        let today = date(2026, 5, 10)  // 10 days
        let records = (1...4).map { record(2026, 5, $0) }
        let stats = LifetimeStatsCalculator.calculate(records: records, firstUseDate: firstUse, today: today, calendar: calendar)
        XCTAssertEqual(stats.usedDays, 10)
        XCTAssertEqual(stats.achievedDays, 4)
        XCTAssertEqual(stats.rate, 0.4, accuracy: 0.001)
    }
}
