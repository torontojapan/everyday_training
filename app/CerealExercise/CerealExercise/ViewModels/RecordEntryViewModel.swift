import Foundation
import Observation

@MainActor
@Observable
final class RecordEntryViewModel {
    struct ExerciseDraft: Identifiable, Hashable {
        let id: UUID
        var name: String
        var minutes: String
        var seconds: String
        var reps: String
        var sets: String
        var memo: String

        init(
            id: UUID = UUID(),
            name: String = "",
            minutes: String = "",
            seconds: String = "",
            reps: String = "",
            sets: String = "",
            memo: String = ""
        ) {
            self.id = id
            self.name = name
            self.minutes = minutes
            self.seconds = seconds
            self.reps = reps
            self.sets = sets
            self.memo = memo
        }
    }

    var selectedCategory: WorkoutCategory = .strength
    var drafts: [ExerciseDraft] = [ExerciseDraft()]
    var memo = ""
    var validationMessage: String?
    private var historyProvider: ExerciseHistoryProvider?

    var canSave: Bool {
        !validExercises.isEmpty
    }

    var validExercises: [ExerciseItem] {
        drafts.compactMap { draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }

            let minutes = Int(draft.minutes.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let seconds = Int(draft.seconds.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let duration = minutes * 60 + seconds
            let trimmedMemo = draft.memo.trimmingCharacters(in: .whitespacesAndNewlines)

            return ExerciseItem(
                id: draft.id,
                name: name,
                durationSeconds: duration > 0 ? duration : nil,
                reps: positiveInt(from: draft.reps),
                sets: positiveInt(from: draft.sets),
                memo: trimmedMemo.isEmpty ? nil : trimmedMemo
            )
        }
    }

    func addExercise() {
        drafts.append(ExerciseDraft())
    }

    func updateHistoryProvider(store: WorkoutStore) {
        historyProvider = ExerciseHistoryProvider(store: store)
    }

    func suggestions(for category: WorkoutCategory) -> [String] {
        historyProvider?.topExerciseNames(for: category, limit: 8) ?? []
    }

    func removeExercise(id: UUID) {
        guard drafts.count > 1 else { return }
        drafts.removeAll { $0.id == id }
    }

    func save(to store: WorkoutStore) -> WorkoutRecord? {
        let exercises = validExercises
        guard !exercises.isEmpty else {
            validationMessage = "種目名を1つ以上入力してください"
            return nil
        }

        let trimmedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = store.add(category: selectedCategory, exercises: exercises, memo: trimmedMemo.isEmpty ? nil : trimmedMemo)
        validationMessage = nil
        return record
    }

    private func positiveInt(from text: String) -> Int? {
        let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        return value > 0 ? value : nil
    }
}
