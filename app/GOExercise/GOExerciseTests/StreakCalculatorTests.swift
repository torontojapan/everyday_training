import XCTest
@testable import GOExercise

final class StreakCalculatorTests: XCTestCase {
    private let calendar = Calendar.mondayFirst

    func testCurrentStreakCountsOnlyAchievedDays() {
        let today = date(day: 20)
        let records = [record(day: 20), record(day: 19)]

        let streak = StreakCalculator.currentStreak(records: records, today: today, calendar: calendar)

        XCTAssertEqual(streak, 2, "Only actual workout days are counted")
    }

    func testCurrentStreakStopsAtThirdMissedDayInWeek() {
        let today = date(day: 22)
        let records = [record(day: 22)]

        let streak = StreakCalculator.currentStreak(records: records, today: today, calendar: calendar)

        XCTAssertEqual(streak, 1)
    }

    func testRestDaysAreSkippedButStreakIsPreserved() {
        // 5/20 achieved, 5/19 rest (auto), 5/18 achieved
        // Streak = 2 (rest days do not count, but they do not break the streak)
        let today = date(day: 20)
        let records = [record(day: 20), record(day: 18)]

        let streak = StreakCalculator.currentStreak(records: records, today: today, calendar: calendar)

        XCTAssertEqual(streak, 2)
    }

    func testPendingTodayReturnsZeroWhenNoRecord() {
        let today = date(day: 20)
        let records = [record(day: 19)]

        let streak = StreakCalculator.currentStreak(records: records, today: today, calendar: calendar)

        XCTAssertEqual(streak, 0)
    }

    func testStreakStateTracksLongestStreakAndLastAchievedDate() {
        // 5/18, 5/20, 5/21 achieved; 5/19 rest (skipped).
        // Streak preserved across the rest day → current=3, longest=3.
        let today = date(day: 21)
        let records = [record(day: 18), record(day: 20), record(day: 21)]

        let state = StreakCalculator.streakState(records: records, today: today, lookbackDays: 7, calendar: calendar)

        XCTAssertEqual(state.currentStreak, 3)
        XCTAssertEqual(state.longestStreak, 3)
        XCTAssertEqual(state.lastAchievedDate, today)
    }

    private func record(day: Int) -> WorkoutRecord {
        WorkoutRecord(
            date: date(day: day),
            category: .strength,
            exercises: [ExerciseItem(name: "運動")],
            calendar: calendar
        )
    }

    private func date(day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 5, day: day))!
    }
}
