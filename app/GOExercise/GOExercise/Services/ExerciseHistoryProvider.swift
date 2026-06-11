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
            .flatMap { record in
                // 種目ごとのカテゴリで絞る。複数カテゴリ記録でも有酸素種目が
                // 筋トレ候補に混ざらない。旧データ (item.category 未設定) は
                // 記録全体の category にフォールバックする。
                record.exercises.compactMap { item -> (String, Date)? in
                    let itemCategory = item.category ?? record.category
                    guard itemCategory == category else { return nil }
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
                // 「前回使った種目が手前」: 最後に使った日の新しい順を最優先し、
                // 同日内は使用回数 → 名前順。(旧: 頻度×新しさの合成スコア順)
                if lhs.lastUsedDate != rhs.lastUsedDate { return lhs.lastUsedDate > rhs.lastUsedDate }
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
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
