import Foundation

@MainActor
final class MonthlyReviewTracker {
    static let lastShownMonthKey = "monthlyReview.lastShownMonth"

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .mondayFirst) {
        self.defaults = defaults
        self.calendar = calendar
    }

    /// Returns true if the previous-month review hasn't been shown yet this month.
    func shouldAutoPresent(today: Date) -> Bool {
        let currentMonthKey = monthKey(for: today)
        let lastShown = defaults.string(forKey: Self.lastShownMonthKey)
        return lastShown != currentMonthKey
    }

    func markPresented(today: Date) {
        defaults.set(monthKey(for: today), forKey: Self.lastShownMonthKey)
    }

    func reset() {
        defaults.removeObject(forKey: Self.lastShownMonthKey)
    }

    private func monthKey(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)"
    }
}
