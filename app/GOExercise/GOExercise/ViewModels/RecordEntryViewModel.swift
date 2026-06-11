import Foundation
import Observation

@MainActor
@Observable
final class RecordEntryViewModel {
    struct ExerciseDraft: Identifiable, Hashable {
        let id: UUID
        var name: String
        /// この種目のカテゴリ。種目ごとに選べるので 1 回の記録に複数カテゴリを混在できる。
        var category: WorkoutCategory
        /// 運動時間 (分)。プルダウン選択。0 = 未設定 (= durationSeconds なし)。
        var minutes: Int
        /// 回数。プルダウン選択。0 = 未設定。
        var reps: Int
        /// セット数。プルダウン選択。0 = 未設定。
        var sets: Int
        var memo: String
        /// 重さ(kg)。フリー入力(空=未設定)。
        var loadText: String

        init(
            id: UUID = UUID(),
            name: String = "",
            category: WorkoutCategory = .strength,
            minutes: Int = 0,
            reps: Int = 0,
            sets: Int = 0,
            memo: String = "",
            loadText: String = ""
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.minutes = minutes
            self.reps = reps
            self.sets = sets
            self.memo = memo
            self.loadText = loadText
        }
    }

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

            let duration = draft.minutes * 60
            let trimmedMemo = draft.memo.trimmingCharacters(in: .whitespacesAndNewlines)

            return ExerciseItem(
                id: draft.id,
                name: name,
                durationSeconds: duration > 0 ? duration : nil,
                reps: draft.reps > 0 ? draft.reps : nil,
                sets: draft.sets > 0 ? draft.sets : nil,
                memo: trimmedMemo.isEmpty ? nil : trimmedMemo,
                loadKilograms: Self.parsedLoad(draft.loadText),
                category: draft.category
            )
        }
    }

    /// 重さ(kg)のフリー入力をパース。空/非数値/範囲外(0〜1000)は nil = 未設定。
    static func parsedLoad(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let v = Double(trimmed), v > 0, v < 1000 else { return nil }
        return v
    }

    func addExercise() {
        // 直前の種目のカテゴリを引き継ぐ (同カテゴリを続けて足すことが多いため)。
        drafts.append(ExerciseDraft(category: drafts.last?.category ?? .strength))
    }

    /// 同じ種目でもう1セットぶんの行を直下に複製追加する(重さ・回数を変えて
    /// 複数セットやる時に、種目を選び直す手間を無くすワンタップ導線)。
    /// 名前・カテゴリ・重さを引き継ぎ、時間/回数/セット/メモは空で始める。
    /// 戻り値 = 新しい行の id(呼び出し側がその行へ展開を切り替える)。nil = 元の行が見つからない。
    @discardableResult
    func addSet(after id: UUID) -> UUID? {
        guard let index = drafts.firstIndex(where: { $0.id == id }) else { return nil }
        let source = drafts[index]
        let copy = ExerciseDraft(name: source.name, category: source.category, loadText: source.loadText)
        drafts.insert(copy, at: index + 1)
        return copy.id
    }

    /// 記録全体の代表カテゴリ (先頭種目)。履歴グルーピング・ウィジェット等の
    /// 「1 記録 = 1 カテゴリ」前提の箇所に渡す後方互換用。
    var primaryCategory: WorkoutCategory {
        validExercises.first?.category ?? drafts.first?.category ?? .strength
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

        let primaryCategory = exercises.first?.category ?? .strength
        let trimmedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = store.add(category: primaryCategory, exercises: exercises, memo: trimmedMemo.isEmpty ? nil : trimmedMemo)
        // store.add は throw せず失敗を lastErrorMessage で表す。保存に失敗していたら
        // 計測・体重などの後続副作用を全て止め、nil を返して呼び出し側に「成功ダイアログを
        // 出さない / 警告ハプティクス」を選ばせる。これが無いと SwiftData 保存失敗時でも
        // 「保存しました」と表示し、体重・生理データだけ別途書かれていた (3 LLM 監査 / Codex 指摘)。
        if let errorMessage = store.lastErrorMessage {
            validationMessage = errorMessage
            return nil
        }
        Analytics.track(.recordCreated(category: primaryCategory.rawValue))

        // Persist optional weight entry alongside the workout record.
        // 同日複数記録 (P0-4) に対応するため **現在時刻** を渡す。
        // store.today だと startOfDay になり、同日 2 回目の記録が時刻で識別できない (Codex round5)。
        if let weightStore, let weight = parsedWeight {
            _ = weightStore.add(date: Date(), weightKilograms: weight, memo: nil)
        }

        validationMessage = nil
        return record
    }
}
