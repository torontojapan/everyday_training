import Foundation
import SwiftData
import Testing
@testable import CerealExercise

@MainActor
struct DataManagementServiceTests {
    /// 3 つの @Model を含む in-memory コンテナを作る (本番と同じ schema)。
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkoutRecord.self, WeightEntry.self, MenstrualEntry.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func seed(_ context: ModelContext) throws {
        let today = Date()
        context.insert(WorkoutRecord(
            date: today,
            category: .cardio,
            exercises: [ExerciseItem(name: "ランニング", durationSeconds: 600, reps: nil, sets: nil)],
            memo: "朝ラン"
        ))
        context.insert(WeightEntry(date: today, weightKilograms: 64.5, memo: "起床後"))
        context.insert(MenstrualEntry(date: today))
        try context.save()
    }

    @Test
    func makeExport_capturesAllEntities() throws {
        let context = try makeContext()
        try seed(context)
        let service = DataManagementService(context: context)

        let export = try service.makeExport()

        #expect(export.schemaVersion == 1)
        #expect(export.workouts.count == 1)
        #expect(export.weights.count == 1)
        #expect(export.menstrualDays.count == 1)
        #expect(export.workouts.first?.exercises.first?.name == "ランニング")
        #expect(export.weights.first?.weightKilograms == 64.5)
    }

    @Test
    func exportJSON_isRoundTrippable() throws {
        let context = try makeContext()
        try seed(context)
        let service = DataManagementService(context: context)

        let data = try service.exportJSONData()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DataExport.self, from: data)

        #expect(decoded.workouts.count == 1)
        #expect(decoded.weights.first?.memo == "起床後")
        #expect(decoded.menstrualDays.count == 1)
    }

    @Test
    func writeExportFile_createsReadableJSONFile() throws {
        let context = try makeContext()
        try seed(context)
        let service = DataManagementService(context: context)

        let url = try service.writeExportFile()
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(url.pathExtension == "json")
        let reread = try Data(contentsOf: url)
        #expect(!reread.isEmpty)
    }

    @Test
    func deleteAllRecords_removesEverythingAndReturnsCount() throws {
        let context = try makeContext()
        try seed(context)
        let service = DataManagementService(context: context)

        let deleted = try service.deleteAllRecords()

        #expect(deleted == 3)
        #expect(try context.fetch(FetchDescriptor<WorkoutRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WeightEntry>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MenstrualEntry>()).isEmpty)
    }

    @Test
    func deleteAllRecords_onEmptyStore_returnsZero() throws {
        let context = try makeContext()
        let service = DataManagementService(context: context)

        #expect(try service.deleteAllRecords() == 0)
    }
}
