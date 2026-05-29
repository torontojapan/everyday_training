import Foundation

@MainActor
final class ExerciseHistoryProvider {
    private let recordsProvider: @MainActor () -> [WorkoutRecord]
    private let calendar: Calendar
    private let nowProvider: () -> Date

    init(store: WorkoutStore, calendar: Calendar = .mondayFirst, now: @escaping () -> Date = Date.init) {
        self.recordsProvider = { store.records }
        self.calendar = calendar
        self.nowProvider = now
    }

    init(records: [WorkoutRecord], calendar: Calendar = .mondayFirst, now: Date = Date()) {
        self.recordsProvider = { records }
        self.calendar = calendar
        self.nowProvider = { now }
    }

    func topExerciseNames(for category: WorkoutCategory, limit: Int = 8) -> [String] {
        guard limit > 0 else { return [] }

        let suggestions = recordsProvider()
            .filter { $0.category == category }
            .flatMap { record in
                record.exercises.compactMap { item -> (String, Date)? in
                    let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    return name.isEmpty ? nil : (name, record.date)
                }
            }
            .reduce(into: [String: ExerciseHistorySuggestion]()) { partialResult, pair in
                let current = partialResult[pair.0]
                let lastUsedDate = max(current?.lastUsedDate ?? pair.1, pair.1)
                partialResult[pair.0] = ExerciseHistorySuggestion(
                    name: pair.0,
                    lastUsedDate: lastUsedDate,
                    count: (current?.count ?? 0) + 1
                )
            }
            .values
            .sorted { lhs, rhs in
                let lhsScore = score(for: lhs)
                let rhsScore = score(for: rhs)
                if lhsScore == rhsScore {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhsScore > rhsScore
            }

        return Array(suggestions.prefix(limit)).map(\.name)
    }

    private func score(for suggestion: ExerciseHistorySuggestion) -> Double {
        let days = max(
            0,
            calendar.dateComponents([.day], from: suggestion.lastUsedDate, to: nowProvider()).day ?? 0
        )
        let recency = exp(-Double(days) / 30.0)
        return Double(suggestion.count) + recency
    }
}
