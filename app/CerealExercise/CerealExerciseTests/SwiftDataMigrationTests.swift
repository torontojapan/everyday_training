import SwiftData
import XCTest
@testable import CerealExercise

@MainActor
final class SwiftDataMigrationTests: XCTestCase {

    // MARK: - V1 → V2 schema migration sandbox
    //
    // These tests use private @Model classes to demonstrate how a future
    // SwiftData schema migration of WorkoutRecord (e.g. adding `intensity`)
    // would be exercised. They do NOT touch the production WorkoutRecord.

    func testLightweightMigrationV1ToV2PreservesData() throws {
        let storeURL = try uniqueStoreURL()

        // 1. Create V1 store, write a record.
        do {
            let v1Container = try ModelContainer(
                for: TestMigration.V1.WorkoutSample.self,
                migrationPlan: nil,
                configurations: ModelConfiguration(url: storeURL)
            )
            let context = ModelContext(v1Container)
            context.insert(TestMigration.V1.WorkoutSample(name: "スクワット", reps: 20))
            try context.save()
        }

        // 2. Open with V2 schema. SwiftData performs a lightweight migration
        //    because the only change is an optional added property (`intensity`).
        let v2Container = try ModelContainer(
            for: TestMigration.V2.WorkoutSample.self,
            migrationPlan: TestMigration.MigrationPlan.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        let v2Context = ModelContext(v2Container)
        let fetched = try v2Context.fetch(FetchDescriptor<TestMigration.V2.WorkoutSample>())

        XCTAssertEqual(fetched.count, 1, "V1 record must survive migration")
        XCTAssertEqual(fetched.first?.name, "スクワット")
        XCTAssertEqual(fetched.first?.reps, 20)
        XCTAssertNil(fetched.first?.intensity, "Newly added optional should default to nil")
    }

    func testV2CanInsertAndQueryWithNewField() throws {
        let storeURL = try uniqueStoreURL()
        let container = try ModelContainer(
            for: TestMigration.V2.WorkoutSample.self,
            migrationPlan: TestMigration.MigrationPlan.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        let context = ModelContext(container)
        context.insert(TestMigration.V2.WorkoutSample(name: "プランク", reps: 1, intensity: 5))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TestMigration.V2.WorkoutSample>())
        XCTAssertEqual(fetched.first?.intensity, 5)
    }

    func testMigrationPlanStagesAreInOrder() {
        let stages = TestMigration.MigrationPlan.stages
        XCTAssertEqual(stages.count, 1)
        XCTAssertEqual(TestMigration.MigrationPlan.schemas.count, 2)
    }

    // MARK: - Helpers

    private func uniqueStoreURL() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appending(path: "migration-test-\(UUID().uuidString).store")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: tmp)
        }
        return tmp
    }
}

// MARK: - Test-only versioned schema sandbox

private enum TestMigration {
    enum V1: VersionedSchema {
        nonisolated(unsafe) static let versionIdentifier = Schema.Version(1, 0, 0)
        static var models: [any PersistentModel.Type] { [WorkoutSample.self] }

        @Model
        final class WorkoutSample {
            var name: String
            var reps: Int
            init(name: String, reps: Int) {
                self.name = name
                self.reps = reps
            }
        }
    }

    enum V2: VersionedSchema {
        nonisolated(unsafe) static let versionIdentifier = Schema.Version(2, 0, 0)
        static var models: [any PersistentModel.Type] { [WorkoutSample.self] }

        @Model
        final class WorkoutSample {
            var name: String
            var reps: Int
            var intensity: Int?
            init(name: String, reps: Int, intensity: Int? = nil) {
                self.name = name
                self.reps = reps
                self.intensity = intensity
            }
        }
    }

    enum MigrationPlan: SchemaMigrationPlan {
        static var schemas: [any VersionedSchema.Type] { [V1.self, V2.self] }
        static var stages: [MigrationStage] {
            [.lightweight(fromVersion: V1.self, toVersion: V2.self)]
        }
    }
}
