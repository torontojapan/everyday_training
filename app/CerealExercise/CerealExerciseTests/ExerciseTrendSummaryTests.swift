import XCTest
@testable import CerealExercise

@MainActor
final class ExerciseTrendSummaryTests: XCTestCase {
    private let calendar = Calendar.mondayFirst

    func testTodayCountsCategoriesForMatchingDayOnly() {
        let today = date(day: 20)
        let records = [
            record(day: 20, category: .strength, exercises: [exercise("スクワット")]),
            record(day: 20, category: .strength, exercises: [exercise("腕立て")]),
            record(day: 20, category: .yoga, exercises: [exercise("太陽礼拝")]),
            record(day: 19, category: .cardio, exercises: [exercise("散歩")])
        ]

        let summary = ExerciseTrendSummary.today(records: records, today: today, calendar: calendar)

        XCTAssertEqual(summary.categoryCounts[.strength], 2)
        XCTAssertEqual(summary.categoryCounts[.yoga], 1)
        XCTAssertNil(summary.categoryCounts[.cardio])
    }

    func testTodayCountsAllExercisesInMatchingRecords() {
        let today = date(day: 20)
        let records = [
            record(day: 20, exercises: [exercise("スクワット"), exercise("腕立て")]),
            record(day: 20, exercises: [exercise("プランク")]),
            record(day: 21, exercises: [exercise("未来")])
        ]

        let summary = ExerciseTrendSummary.today(records: records, today: today, calendar: calendar)

        XCTAssertEqual(summary.exerciseCount, 3)
    }

    func testTodaySumsExerciseDurationsIgnoringNilDurations() {
        let today = date(day: 20)
        let records = [
            record(day: 20, exercises: [exercise("スクワット", duration: 60), exercise("腕立て", duration: nil)]),
            record(day: 20, exercises: [exercise("散歩", duration: 180)]),
            record(day: 19, exercises: [exercise("前日", duration: 999)])
        ]

        let summary = ExerciseTrendSummary.today(records: records, today: today, calendar: calendar)

        XCTAssertEqual(summary.totalDurationSeconds, 240)
    }

    func testWeekReturnsUsedCategoriesInWorkoutCategoryOrder() {
        let week = weekInterval(containing: date(day: 20))
        let records = [
            record(day: 20, category: .yoga, exercises: [exercise("ヨガ")]),
            record(day: 21, category: .strength, exercises: [exercise("筋トレ")]),
            record(day: 22, category: .yoga, exercises: [exercise("ヨガ2")]),
            record(day: 25, category: .cardio, exercises: [exercise("翌週")])
        ]

        let summary = ExerciseTrendSummary.week(records: records, week: week, calendar: calendar)

        XCTAssertEqual(summary.usedCategories, [.strength, .yoga])
    }

    func testWeekSumsDurationsWithinInterval() {
        let week = weekInterval(containing: date(day: 20))
        let records = [
            record(day: 18, exercises: [exercise("散歩", duration: 300)]),
            record(day: 20, exercises: [exercise("ヨガ", duration: 120), exercise("呼吸", duration: 30)]),
            record(day: 25, exercises: [exercise("翌週", duration: 999)])
        ]

        let summary = ExerciseTrendSummary.week(records: records, week: week, calendar: calendar)

        XCTAssertEqual(summary.totalDurationSeconds, 450)
    }

    func testWeekReturnsTopExerciseNamesByFrequencyThenName() {
        let week = weekInterval(containing: date(day: 20))
        let records = [
            record(day: 18, exercises: [exercise("スクワット"), exercise("プランク"), exercise("スクワット")]),
            record(day: 19, exercises: [exercise("スクワット"), exercise("散歩")]),
            record(day: 20, exercises: [exercise("腕立て")]),
            record(day: 21, exercises: [exercise("プランク")]),
            record(day: 25, exercises: [exercise("翌週"), exercise("翌週")])
        ]

        let summary = ExerciseTrendSummary.week(records: records, week: week, calendar: calendar)

        XCTAssertEqual(summary.topExerciseNames, ["スクワット", "プランク", "散歩"])
    }

    private func record(day: Int, category: WorkoutCategory = .strength, exercises: [ExerciseItem]) -> WorkoutRecord {
        WorkoutRecord(
            date: date(day: day),
            category: category,
            exercises: exercises,
            calendar: calendar
        )
    }

    private func exercise(_ name: String, duration: Int? = nil) -> ExerciseItem {
        ExerciseItem(name: name, durationSeconds: duration)
    }

    private func date(day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 5, day: day))!
    }

    private func weekInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date)!
    }
}
