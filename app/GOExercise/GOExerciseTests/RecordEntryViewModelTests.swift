import SwiftData
import XCTest
@testable import GOExercise

@MainActor
final class RecordEntryViewModelTests: XCTestCase {
    private var container: ModelContainer?

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: WorkoutRecord.self, configurations: config)
    }

    override func tearDown() async throws {
        container = nil
    }

    private func makeStore() throws -> WorkoutStore {
        let container = try XCTUnwrap(container)
        return WorkoutStore(context: ModelContext(container))
    }

    func testCanSaveBecomesTrueAfterNameEntered() {
        let vm = RecordEntryViewModel()
        XCTAssertFalse(vm.canSave)
        vm.drafts[0].name = "スクワット"
        XCTAssertTrue(vm.canSave)
    }

    func testResetAfterSaveResetsDraftsAndKeepsCanSaveBehavior() {
        let vm = RecordEntryViewModel()
        vm.drafts[0].name = "スクワット"
        vm.drafts[0].minutes = 5
        XCTAssertTrue(vm.canSave)

        vm.resetAfterSave()
        XCTAssertEqual(vm.drafts.count, 1)
        XCTAssertEqual(vm.drafts[0].name, "")
        XCTAssertEqual(vm.drafts[0].minutes, 0)
        XCTAssertFalse(vm.canSave, "After reset, no name → not saveable")

        vm.drafts[0].name = "腕立て伏せ"
        XCTAssertTrue(vm.canSave, "After entering a new name post-reset, should be saveable again")
    }

    func testResetPreservesFirstDraftIdToAvoidForEachReinit() {
        let vm = RecordEntryViewModel()
        let firstId = vm.drafts[0].id
        vm.drafts[0].name = "before"
        vm.resetAfterSave()
        XCTAssertEqual(vm.drafts[0].id, firstId, "Reset must keep the first id so SwiftUI ForEach does not invalidate the row's binding")
    }

    func testMinutesOnlyDurationIsConvertedToSeconds() {
        let vm = RecordEntryViewModel()
        vm.drafts[0].name = "プランク"
        vm.drafts[0].minutes = 2
        let exercises = vm.validExercises
        XCTAssertEqual(exercises.count, 1)
        XCTAssertEqual(exercises[0].durationSeconds, 120, "2 minutes -> 120 seconds")
    }

    func testNoMinutesProducesNilDuration() {
        let vm = RecordEntryViewModel()
        vm.drafts[0].name = "腹筋"
        vm.drafts[0].reps = 20
        let exercises = vm.validExercises
        XCTAssertEqual(exercises[0].durationSeconds, nil)
        XCTAssertEqual(exercises[0].reps, 20)
    }

    func testSuggestionsIncludeDefaultsForStrength() {
        let vm = RecordEntryViewModel()
        let suggestions = vm.suggestions(for: .strength)
        XCTAssertTrue(suggestions.contains("プランク"))
        XCTAssertTrue(suggestions.contains("スクワット"))
        XCTAssertTrue(suggestions.contains("バーピー"))
    }

    func testSuggestionsForOtherIsEmptyByDefault() {
        let vm = RecordEntryViewModel()
        XCTAssertTrue(vm.suggestions(for: .other).isEmpty)
    }

    func testSuggestionsMergedHistoryFirstThenDefaults() throws {
        let store = try makeStore()
        store.add(
            category: .strength,
            exercises: [ExerciseItem(name: "カスタム筋トレ", reps: 10)],
            memo: nil
        )
        let vm = RecordEntryViewModel()
        vm.updateHistoryProvider(store: store)
        let suggestions = vm.suggestions(for: .strength)
        XCTAssertEqual(suggestions.first, "カスタム筋トレ", "History exercise should rank first")
        XCTAssertTrue(suggestions.contains("プランク"), "Defaults should still be included after history")
    }

    func testSaveWithoutAnyNameSetsValidationMessage() throws {
        let store = try makeStore()
        let vm = RecordEntryViewModel()
        let record = vm.save(to: store)
        XCTAssertNil(record)
        XCTAssertNotNil(vm.validationMessage)
    }
}
