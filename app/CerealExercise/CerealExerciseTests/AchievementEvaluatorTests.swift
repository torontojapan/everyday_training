import XCTest
@testable import CerealExercise

final class AchievementEvaluatorTests: XCTestCase {
    private let calendar = Calendar.mondayFirst

    func testRecordWithOneExerciseIsAchievedWithoutDuration() {
        let record = makeRecord(exercises: [ExerciseItem(name: "スクワット")])

        XCTAssertTrue(AchievementEvaluator.isAchieved(record: record))
    }

    func testRecordWithSixtySecondsIsAchieved() {
        let record = makeRecord(exercises: [ExerciseItem(name: "プランク", durationSeconds: 60)])

        XCTAssertTrue(AchievementEvaluator.isAchieved(record: record))
    }

    func testRecordWithMultipleDurationsCountsTotalSeconds() {
        let record = makeRecord(exercises: [
            ExerciseItem(name: "散歩", durationSeconds: 30),
            ExerciseItem(name: "ストレッチ", durationSeconds: 30)
        ])

        XCTAssertTrue(AchievementEvaluator.isAchieved(record: record))
    }

    func testRecordWithNoExercisesIsNotAchieved() {
        let record = makeRecord(exercises: [])

        XCTAssertFalse(AchievementEvaluator.isAchieved(record: record))
    }

    func testDailyStatusReturnsTodayAchievedForTodayWithRecord() {
        let today = date(year: 2026, month: 5, day: 20)
        let record = makeRecord(date: today, exercises: [ExerciseItem(name: "ヨガ")])

        let status = AchievementEvaluator.dailyStatus(for: today, records: [record], restDays: [], today: today, calendar: calendar)

        XCTAssertEqual(status, .todayAchieved)
    }

    func testDailyStatusReturnsFutureForFutureDate() {
        let today = date(year: 2026, month: 5, day: 20)
        let future = date(year: 2026, month: 5, day: 21)

        let status = AchievementEvaluator.dailyStatus(for: future, records: [], restDays: [], today: today, calendar: calendar)

        XCTAssertEqual(status, .future)
    }

    private func makeRecord(date: Date = Date(), exercises: [ExerciseItem]) -> WorkoutRecord {
        WorkoutRecord(date: date, category: .strength, exercises: exercises, calendar: calendar)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
