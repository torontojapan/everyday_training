import Foundation

struct ExerciseHistorySuggestion: Codable, Hashable, Sendable {
    let name: String
    let lastUsedDate: Date
    let count: Int
}
