import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class WeightStore {
    private let context: ModelContext
    private let calendar: Calendar

    private(set) var entries: [WeightEntry] = []
    private(set) var lastErrorMessage: String?

    init(context: ModelContext, calendar: Calendar = .mondayFirst) {
        self.context = context
        self.calendar = calendar
        fetchEntries()
    }

    func fetchEntries() {
        let descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        do {
            entries = try context.fetch(descriptor)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "体重記録の読み込みに失敗しました"
            entries = []
        }
    }

    @discardableResult
    func add(date: Date, weightKilograms: Double, memo: String? = nil) -> WeightEntry {
        let normalizedDate = calendar.startOfDay(for: date)
        // If a record for the same day already exists, update it.
        if let existing = entries.first(where: { calendar.isDate($0.date, inSameDayAs: normalizedDate) }) {
            existing.weightKilograms = weightKilograms
            existing.memo = memo
            existing.updatedAt = Date()
            save()
            return existing
        }
        let entry = WeightEntry(date: normalizedDate, weightKilograms: weightKilograms, memo: memo, calendar: calendar)
        context.insert(entry)
        save()
        return entry
    }

    func delete(_ entry: WeightEntry) {
        context.delete(entry)
        save()
    }

    var latest: WeightEntry? { entries.first }

    var change30Days: Double? {
        guard let latest else { return nil }
        let cutoff = calendar.date(byAdding: .day, value: -30, to: latest.date) ?? latest.date
        let earlier = entries.first { $0.date <= cutoff }
        guard let earlier else { return nil }
        return latest.weightKilograms - earlier.weightKilograms
    }

    private func save() {
        do {
            try context.save()
            fetchEntries()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "保存に失敗しました"
        }
    }
}
