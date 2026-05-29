import XCTest
@testable import GOExercise

final class RestDayResolverTests: XCTestCase {
    private let calendar = Calendar.mondayFirst

    func testFirstTwoUnrecordedPastDaysBecomeRestDays() {
        let today = date(year: 2026, month: 5, day: 22)
        let week = calendar.weekInterval(containing: today)
        let records = [
            record(day: 18),
            record(day: 21)
        ]

        let restDays = RestDayResolver.restDays(in: week, records: records, today: today, calendar: calendar)

        XCTAssertEqual(restDays, [date(year: 2026, month: 5, day: 19), date(year: 2026, month: 5, day: 20)])
    }

    func testThirdUnrecordedDayIsNotRestDay() {
        let today = date(year: 2026, month: 5, day: 22)
        let week = calendar.weekInterval(containing: today)
        let records = [record(day: 18)]

        let restDays = RestDayResolver.restDays(in: week, records: records, today: today, calendar: calendar)

        XCTAssertFalse(restDays.contains(date(year: 2026, month: 5, day: 21)))
    }

    func testFutureDaysAreNotRestDays() {
        let today = date(year: 2026, month: 5, day: 20)
        let week = calendar.weekInterval(containing: today)
        let records = [record(day: 18)]

        let restDays = RestDayResolver.restDays(in: week, records: records, today: today, calendar: calendar)

        XCTAssertFalse(restDays.contains(date(year: 2026, month: 5, day: 21)))
    }

    func testLimitZeroReturnsNoRestDays() {
        let today = date(year: 2026, month: 5, day: 20)
        let week = calendar.weekInterval(containing: today)

        let restDays = RestDayResolver.restDays(in: week, records: [], today: today, limit: 0, calendar: calendar)

        XCTAssertTrue(restDays.isEmpty)
    }

    func testUnachievedRecordsDoNotBlockRestDay() {
        let today = date(year: 2026, month: 5, day: 20)
        let week = calendar.weekInterval(containing: today)
        let emptyRecord = WorkoutRecord(date: date(year: 2026, month: 5, day: 18), category: .strength, exercises: [], calendar: calendar)

        let restDays = RestDayResolver.restDays(in: week, records: [emptyRecord], today: today, calendar: calendar)

        XCTAssertTrue(restDays.contains(date(year: 2026, month: 5, day: 18)))
    }

    private func record(day: Int) -> WorkoutRecord {
        WorkoutRecord(
            date: date(year: 2026, month: 5, day: day),
            category: .strength,
            exercises: [ExerciseItem(name: "運動")],
            calendar: calendar
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
