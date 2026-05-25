import Foundation
import Observation

@MainActor
@Observable
final class RecordEntryViewModel {
    struct ExerciseDraft: Identifiable, Hashable {
        let id: UUID
        var name: String
        var minutes: String
        var reps: String
        var sets: String
        var memo: String

        init(
            id: UUID = UUID(),
            name: String = "",
            minutes: String = "",
            reps: String = "",
            sets: String = "",
            memo: String = ""
        ) {
            self.id = id
            self.name = name
            self.minutes = minutes
            self.reps = reps
            self.sets = sets
            self.memo = memo
        }
    }

    var selectedCategory: WorkoutCategory = .strength
    var drafts: [ExerciseDraft] = [ExerciseDraft()]
    var memo = ""
    var weightInput = ""
    var validationMessage: String?
    private var historyProvider: ExerciseHistoryProvider?

    var parsedWeight: Double? {
        let trimmed = weightInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed), value > 0, value < 500 else { return nil }
        return value
    }

    /// True if the user typed something into the weight field but it doesn't
    /// parse as a valid kg value. Shown as inline guidance so users don't lose
    /// their input silently when the record saves.
    var hasWeightInputButInvalid: Bool {
        let trimmed = weightInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return parsedWeight == nil
    }

    var canSave: Bool {
        !validExercises.isEmpty && !hasWeightInputButInvalid
    }

    /// One-line explanation of why the Save button is disabled. nil when
    /// canSave == true. Surfaced under the save button so users aren't left
    /// staring at a grayed-out control with no hint.
    var disabledReason: String? {
        if validExercises.isEmpty {
            return "種目名を1つ以上入力してください"
        }
        if hasWeightInputButInvalid {
            return "体重は 0〜500 kg の数値で入力してください"
        }
        return nil
    }

    var validExercises: [ExerciseItem] {
        drafts.compactMap { draft in
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }

            let minutes = Int(draft.minutes.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            let duration = minutes * 60
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

    func resetAfterSave() {
        // Keep the first draft's id so the ForEach in RecordEntryView does not
        // re-create the row (which would invalidate text-field bindings and
        // leave the Save button visually stuck).
        let firstId = drafts.first?.id ?? UUID()
        drafts = [ExerciseDraft(id: firstId)]
        memo = ""
        weightInput = ""
        validationMessage = nil
    }

    func updateHistoryProvider(store: WorkoutStore) {
        historyProvider = ExerciseHistoryProvider(store: store)
    }

    func suggestions(for category: WorkoutCategory) -> [String] {
        let history = historyProvider?.topExerciseNames(for: category, limit: 12) ?? []
        return DefaultExerciseSuggestions.merged(history: history, category: category, limit: 12)
    }

    func removeExercise(id: UUID) {
        guard drafts.count > 1 else { return }
        drafts.removeAll { $0.id == id }
    }

    func save(to store: WorkoutStore, weightStore: WeightStore? = nil) -> WorkoutRecord? {
        let exercises = validExercises
        guard !exercises.isEmpty else {
            validationMessage = "種目名を1つ以上入力してください"
            return nil
        }

        let trimmedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = store.add(category: selectedCategory, exercises: exercises, memo: trimmedMemo.isEmpty ? nil : trimmedMemo)

        // Persist optional weight entry alongside the workout record.
        if let weightStore, let weight = parsedWeight {
            _ = weightStore.add(date: store.today, weightKilograms: weight, memo: nil)
        }

        validationMessage = nil
        return record
    }

    private func positiveInt(from text: String) -> Int? {
        let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        return value > 0 ? value : nil
    }
}
