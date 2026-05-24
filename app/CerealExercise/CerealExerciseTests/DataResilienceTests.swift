import SwiftData
import XCTest
@testable import CerealExercise

@MainActor
final class DataResilienceTests: XCTestCase {
    private var container: ModelContainer?

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: WorkoutRecord.self, configurations: config)
    }

    override func tearDown() async throws {
        container = nil
    }

    private func context() throws -> ModelContext {
        let container = try XCTUnwrap(container)
        return ModelContext(container)
    }

    // MARK: - WorkoutRecord.exercisesData corruption

    func testCorruptedExercisesDataReturnsEmptyArray() throws {
        let record = WorkoutRecord(
            date: Date(),
            category: .strength,
            exercises: [ExerciseItem(name: "test", reps: 10)]
        )
        // Simulate corruption by writing invalid JSON bytes directly.
        record.exercisesData = Data([0x00, 0x01, 0xFF, 0xFE])
        XCTAssertEqual(record.exercises, [], "Corrupt JSON must decode to []")
    }

    func testEmptyExercisesDataReturnsEmptyArray() throws {
        let record = WorkoutRecord(
            date: Date(),
            category: .strength,
            exercises: [ExerciseItem(name: "test")]
        )
        record.exercisesData = Data()
        XCTAssertEqual(record.exercises, [])
    }

    func testCorruptRecordIsNotAchieved() throws {
        let record = WorkoutRecord(date: Date(), category: .strength, exercises: [])
        record.exercisesData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        XCTAssertFalse(
            AchievementEvaluator.isAchieved(record: record),
            "A record whose exercises fail to decode should not count as achieved"
        )
    }

    // MARK: - WorkoutCategory raw unknown

    func testUnknownCategoryRawFallsBackToOther() throws {
        let record = WorkoutRecord(
            date: Date(),
            category: .strength,
            exercises: [ExerciseItem(name: "x")]
        )
        record.categoryRaw = "totally-not-a-real-category"
        XCTAssertEqual(record.category, .other, "Unknown rawValue must fall back to .other")
    }

    // MARK: - SharedSnapshotStore resilience

    func testSharedSnapshotStoreReturnsFallbackWhenSuiteUnavailable() {
        // Force unavailable suite (using empty defaults).
        let store = SharedSnapshotStore(defaults: nil)
        let snapshot = store.read()
        XCTAssertEqual(snapshot.currentStreak, 0)
        XCTAssertFalse(snapshot.todayAchieved)
    }

    func testSharedSnapshotStoreReturnsFallbackOnCorruptData() {
        let suiteName = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.set(Data([0x00, 0xFF, 0x42]), forKey: SharedSnapshotStore.snapshotKey)
        let store = SharedSnapshotStore(defaults: defaults)
        let snapshot = store.read()
        XCTAssertEqual(snapshot.currentStreak, 0, "Corrupt snapshot data must fall back to defaults")
        XCTAssertEqual(snapshot.weeklyTotal, 7)
    }

    // MARK: - SwiftData empty container

    func testStreakOnEmptyDatabaseIsZero() throws {
        let today = Calendar.mondayFirst.startOfDay(for: Date())
        let streak = StreakCalculator.currentStreak(records: [], today: today)
        XCTAssertEqual(streak, 0)
    }

    func testWeeklyProgressOnEmptyDatabaseHandlesRestDays() throws {
        let today = Calendar.mondayFirst.startOfDay(for: Date())
        let statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: [], today: today)
        XCTAssertEqual(statuses.count, 7)
        let progress = WeeklyProgressCalculator.progress(from: statuses)
        XCTAssertGreaterThanOrEqual(progress.achievedCount, 0)
        XCTAssertLessThanOrEqual(progress.achievedCount, 7)
    }
}
