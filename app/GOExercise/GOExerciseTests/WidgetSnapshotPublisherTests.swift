import SwiftData
import XCTest
@testable import GOExercise

@MainActor
final class WidgetSnapshotPublisherTests: XCTestCase {
    private var container: ModelContainer?

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: WorkoutRecord.self, configurations: config)
    }

    override func tearDown() async throws {
        container = nil
        UserDefaults().removePersistentDomain(forName: SharedSnapshotStore.appGroupIdentifier)
    }

    private func makeStore() throws -> WorkoutStore {
        let container = try XCTUnwrap(container)
        return WorkoutStore(context: ModelContext(container))
    }

    func testPublishWritesSnapshotReflectingTodayAchievement() throws {
        let store = try makeStore()
        let today = Calendar.mondayFirst.startOfDay(for: Date())
        store.add(category: .strength, exercises: [ExerciseItem(name: "プランク", durationSeconds: 120)], memo: nil)

        WidgetSnapshotPublisher.publish(from: store, today: today)

        let snapshot = SharedSnapshotStore().read()
        XCTAssertTrue(snapshot.todayAchieved, "Today should be marked achieved when there is a record")
        XCTAssertGreaterThanOrEqual(snapshot.currentStreak, 1)
        XCTAssertFalse(snapshot.message.isEmpty)
    }

    func testPublishWritesSnapshotWithFallbackWhenEmpty() throws {
        let store = try makeStore()
        let today = Calendar.mondayFirst.startOfDay(for: Date())

        WidgetSnapshotPublisher.publish(from: store, today: today)

        let snapshot = SharedSnapshotStore().read()
        XCTAssertFalse(snapshot.todayAchieved)
        XCTAssertEqual(snapshot.currentStreak, 0)
        XCTAssertEqual(snapshot.weeklyTotal, 7)
    }

    func testPublishPreservesCatStateRawValueAndIsDecodableAsEnum() throws {
        let store = try makeStore()
        store.add(category: .cardio, exercises: [ExerciseItem(name: "ジョギング", durationSeconds: 600)], memo: nil)

        WidgetSnapshotPublisher.publish(from: store)

        let snapshot = SharedSnapshotStore().read()
        XCTAssertNotNil(CatState(rawValue: snapshot.catState),
                        "catState raw value must round-trip back to a CatState case")
    }
}
