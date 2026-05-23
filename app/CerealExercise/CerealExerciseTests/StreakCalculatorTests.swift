import XCTest
@testable import CerealExercise

final class StreakCalculatorTests: XCTestCase {
    private let calendar = Calendar.mondayFirst

    func testCurrentStreakCountsTodayAchievement() {
        let today = date(day: 20)
        let records = [record(day: 20), record(day: 19)]

        let streak = StreakCalculator.currentStreak(records: records, today: today, calendar: calendar)

        XCTAssertEqual(streak, 3)
    }

    func testCurrentStreakStopsAtThirdMissedDayInWeek() {
        let today = date(day: 22)
        let records = [record(day: 22)]

        let streak = StreakCalculator.currentStreak(records: records, today: today, calendar: calendar)

        XCTAssertEqual(streak, 1)
    }

    func testRestDaysMaintainStreak() {
        let today = date(day: 20)
        let records = [record(day: 20), record(day: 18)]

        let streak = StreakCalculator.currentStreak(records: records, today: today, calendar: calendar)

        XCTAssertEqual(streak, 3)
    }

    func testPendingTodayReturnsZeroWhenNoRecord() {
        let today = date(day: 20)
        let records = [record(day: 19)]

        let streak = StreakCalculator.currentStreak(records: records, today: today, calendar: calendar)

        XCTAssertEqual(streak, 0)
    }

    func testStreakStateTracksLongestStreakAndLastAchievedDate() {
        let today = date(day: 21)
        let records = [record(day: 18), record(day: 20), record(day: 21)]

        let state = StreakCalculator.streakState(records: records, today: today, lookbackDays: 7, calendar: calendar)

        XCTAssertEqual(state.currentStreak, 4)
        XCTAssertEqual(state.longestStreak, 4)
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
