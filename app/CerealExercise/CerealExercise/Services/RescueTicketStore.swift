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

    /// Returns true if the month for `today` still has a ticket left, given `allowance`.
    /// Default allowance is 1 (baseline). Pass 2 when cycle tracking is enabled.
    func hasTicketAvailable(today: Date, allowance: Int = 1) -> Bool {
        usedCount(inMonthOf: today) < allowance
    }

    func usedCount(inMonthOf date: Date) -> Int {
        let key = monthKey(for: date)
        return rescuedDates().filter { monthKey(for: $0) == key }.count
    }

    func remainingTickets(today: Date, allowance: Int = 1) -> Int {
        max(0, allowance - usedCount(inMonthOf: today))
    }

    /// Returns the set of dates (start-of-day) on which a rescue ticket was used.
    func rescuedDates() -> Set<Date> {
        let raw = (defaults.array(forKey: Self.usedDatesKey) as? [Double]) ?? []
        return Set(raw.map { Date(timeIntervalSince1970: $0) })
    }

    /// Adds `date` to the rescued set if the month's allowance is not exhausted.
    @discardableResult
    func useTicket(on date: Date, allowance: Int = 1) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        guard hasTicketAvailable(today: dayStart, allowance: allowance) else { return false }
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
}

@MainActor
enum RescueTicketAllowance {
    /// Cycle tracking グラント: ONなら 2 枚、OFFなら 1 枚。
    static func current(cycleSettings: CycleTrackingSettings = CycleTrackingSettings()) -> Int {
        cycleSettings.isEnabled ? 2 : 1
    }
}
