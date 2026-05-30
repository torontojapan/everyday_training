import Foundation

struct ExerciseItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var durationSeconds: Int?
    var reps: Int?
    var sets: Int?
    var memo: String?
    /// この種目のカテゴリ。1 回の記録に複数カテゴリを混在できるよう種目ごとに保持する。
    /// 旧データ (フィールドなし) は nil にデコードされ、表示時は記録全体の category に
    /// フォールバックする (後方互換)。
    var category: WorkoutCategory?

    init(
        id: UUID = UUID(),
        name: String,
        durationSeconds: Int? = nil,
        reps: Int? = nil,
        sets: Int? = nil,
        memo: String? = nil,
        category: WorkoutCategory? = nil
    ) {
        self.id = id
        self.name = name
        self.durationSeconds = durationSeconds
        self.reps = reps
        self.sets = sets
        self.memo = memo
        self.category = category
    }
}
