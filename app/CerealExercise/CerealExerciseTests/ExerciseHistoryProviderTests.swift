import XCTest
@testable import CerealExercise

@MainActor
final class ExerciseHistoryProviderTests: XCTestCase {
    private let calendar = Calendar.mondayFirst

    func testTopExerciseNamesPrioritizesFrequency() {
        let provider = ExerciseHistoryProvider(records: [
            record(day: 1, category: .strength, names: ["スクワット", "腕立て伏せ"]),
            record(day: 2, category: .strength, names: ["スクワット"]),
            record(day: 3, category: .strength, names: ["プランク"])
        ], calendar: calendar, now: date(day: 10))

        let names = provider.topExerciseNames(for: .strength, limit: 3)

        XCTAssertEqual(names.first, "スクワット")
    }

    func testTopExerciseNamesUsesRecencyWhenFrequencyIsTied() {
        let provider = ExerciseHistoryProvider(records: [
            record(day: 1, category: .strength, names: ["スクワット"]),
            record(day: 9, category: .strength, names: ["プランク"])
        ], calendar: calendar, now: date(day: 10))

        let names = provider.topExerciseNames(for: .strength, limit: 2)

        XCTAssertEqual(names, ["プランク", "スクワット"])
    }

    func testTopExerciseNamesFiltersByCategory() {
        let provider = ExerciseHistoryProvider(records: [
            record(day: 8, category: .cardio, names: ["ランニング"]),
            record(day: 9, category: .strength, names: ["スクワット"])
        ], calendar: calendar, now: date(day: 10))

        let names = provider.topExerciseNames(for: .cardio, limit: 5)

        XCTAssertEqual(names, ["ランニング"])
    }

    func testTopExerciseNamesReturnsEmptyWhenNoRecords() {
        let provider = ExerciseHistoryProvider(records: [], calendar: calendar, now: date(day: 10))

        let names = provider.topExerciseNames(for: .strength, limit: 5)

        XCTAssertTrue(names.isEmpty)
    }

    func testTopExerciseNamesRespectsLimit() {
        let provider = ExerciseHistoryProvider(records: [
            record(day: 7, category: .strength, names: ["A", "B", "C"])
        ], calendar: calendar, now: date(day: 10))

        let names = provider.topExerciseNames(for: .strength, limit: 2)

        XCTAssertEqual(names.count, 2)
    }

    private func record(day: Int, category: WorkoutCategory, names: [String]) -> WorkoutRecord {
        WorkoutRecord(
            date: date(day: day),
            category: category,
            exercises: names.map { ExerciseItem(name: $0) },
            calendar: calendar
        )
    }

    private func date(day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 5, day: day))!
    }
}
