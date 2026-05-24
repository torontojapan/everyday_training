import Foundation

@MainActor
final class LifetimeUsageTracker {
    static let firstUseDateKey = "app.firstUsedDate"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func firstUseDate(records: [WorkoutRecord], fallback today: Date) -> Date {
        if let saved = defaults.object(forKey: Self.firstUseDateKey) as? Date {
            return saved
        }
        let earliest = records.map(\.date).min() ?? today
        defaults.set(earliest, forKey: Self.firstUseDateKey)
        return earliest
    }

    func reset() {
        defaults.removeObject(forKey: Self.firstUseDateKey)
    }
}
