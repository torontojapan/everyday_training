import XCTest
@testable import CerealExercise

final class WeeklyProgressCalculatorTests: XCTestCase {
    private let calendar = Calendar.mondayFirst

    func testStatusesAlwaysReturnSevenDays() {
        let today = date(day: 20)

        let statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: [], today: today, calendar: calendar)

        XCTAssertEqual(statuses.count, 7)
    }

    func testWeekStartsOnMonday() {
        let today = date(day: 20)

        let statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: [], today: today, calendar: calendar)

        XCTAssertEqual(statuses.first?.date, date(day: 18))
    }

    func testProgressCountsAchievedRestAndTodayAchieved() {
        let entries = [
            DailyStatusEntry(date: date(day: 18), status: .achieved, recordIds: []),
            DailyStatusEntry(date: date(day: 19), status: .rest, recordIds: []),
            DailyStatusEntry(date: date(day: 20), status: .todayAchieved, recordIds: []),
            DailyStatusEntry(date: date(day: 21), status: .missed, recordIds: []),
            DailyStatusEntry(date: date(day: 22), status: .future, recordIds: []),
            DailyStatusEntry(date: date(day: 23), status: .future, recordIds: []),
            DailyStatusEntry(date: date(day: 24), status: .future, recordIds: [])
        ]

        let progress = WeeklyProgressCalculator.progress(from: entries)

        XCTAssertEqual(progress.achievedCount, 3)
        XCTAssertEqual(progress.totalDays, 7)
        XCTAssertEqual(progress.rate, 3.0 / 7.0, accuracy: 0.0001)
    }

    func testStatusesMarkTodayAchievedWhenTodayHasRecord() {
        let today = date(day: 20)
        let records = [record(day: 20)]

        let statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: records, today: today, calendar: calendar)

        XCTAssertEqual(statuses[2].status, .todayAchieved)
    }

    func testStatusesMarkFutureDays() {
        let today = date(day: 20)

        let statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: [], today: today, calendar: calendar)

        XCTAssertEqual(statuses[3].status, .future)
        XCTAssertEqual(statuses[6].status, .future)
    }

    func testWeeklyProgressIncludesRestDaysFromResolver() {
        let today = date(day: 20)
        let records = [record(day: 18), record(day: 20)]

        let statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: records, today: today, calendar: calendar)
        let progress = WeeklyProgressCalculator.progress(from: statuses)

        XCTAssertEqual(statuses[1].status, .rest)
        XCTAssertEqual(progress.achievedCount, 3)
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
