import Foundation

struct ExerciseItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var durationSeconds: Int?
    var reps: Int?
    var sets: Int?
    var memo: String?

    init(
        id: UUID = UUID(),
        name: String,
        durationSeconds: Int? = nil,
        reps: Int? = nil,
        sets: Int? = nil,
        memo: String? = nil
    ) {
        self.id = id
        self.name = name
        self.durationSeconds = durationSeconds
        self.reps = reps
        self.sets = sets
        self.memo = memo
    }
}
