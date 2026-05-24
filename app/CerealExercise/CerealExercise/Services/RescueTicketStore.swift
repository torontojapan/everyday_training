import Foundation

@MainActor
final class RescueTicketStore {
    static let usedDatesKey = "rescue.usedDates"

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .mondayFirst) {
        self.defaults = defaults
        self.calendar = calendar
    }

    /// One ticket per calendar month. Returns true if today's month has a ticket left.
    func hasTicketAvailable(today: Date) -> Bool {
        let key = monthKey(for: today)
        return !usedMonthKeys().contains(key)
    }

    /// Returns the set of dates (start-of-day) on which a rescue ticket was used.
    func rescuedDates() -> Set<Date> {
        let raw = (defaults.array(forKey: Self.usedDatesKey) as? [Double]) ?? []
        return Set(raw.map { Date(timeIntervalSince1970: $0) })
    }

    /// Marks today as rescued. No-op if the month's ticket is already used.
    @discardableResult
    func useTicket(on date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        guard hasTicketAvailable(today: dayStart) else { return false }
        var dates = rescuedDates()
        dates.insert(dayStart)
        defaults.set(dates.map(\.timeIntervalSince1970), forKey: Self.usedDatesKey)
        return true
    }

    func clear() {
        defaults.removeObject(forKey: Self.usedDatesKey)
    }

    // MARK: - Private

    private func monthKey(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)"
    }

    private func usedMonthKeys() -> Set<String> {
        let dates = rescuedDates()
        return Set(dates.map { monthKey(for: $0) })
    }
}
