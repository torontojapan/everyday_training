import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class MenstrualStore {
    private let context: ModelContext
    private let calendar: Calendar

    private(set) var entries: [MenstrualEntry] = []

    init(context: ModelContext, calendar: Calendar = .mondayFirst) {
        self.context = context
        self.calendar = calendar
        fetchEntries()
    }

    func fetchEntries() {
        let descriptor = FetchDescriptor<MenstrualEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        entries = (try? context.fetch(descriptor)) ?? []
    }

    func isMarked(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        return entries.contains { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// Idempotent: ensures (or removes) a record for the given day to match `isOn`.
    func set(_ isOn: Bool, on date: Date) {
        let day = calendar.startOfDay(for: date)
        if isOn {
            guard !isMarked(day) else { return }
            let entry = MenstrualEntry(date: day, calendar: calendar)
            context.insert(entry)
        } else {
            let toDelete = entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
            for entry in toDelete {
                context.delete(entry)
            }
        }
        try? context.save()
        fetchEntries()
    }

    func markedDates() -> Set<Date> {
        Set(entries.map { calendar.startOfDay(for: $0.date) })
    }
}

@MainActor
final class CycleTrackingSettings {
    static let isEnabledKey = "cycle.tracking.enabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.isEnabledKey) }
        set { defaults.set(newValue, forKey: Self.isEnabledKey) }
    }
}
