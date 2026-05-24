import Foundation

enum WidgetTimelineDates {
    static func entryDates(from now: Date, calendar: Calendar = .current) -> [Date] {
        let oneHourLater = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        let endOfDay = endOfDayMinusOneMinute(from: now, calendar: calendar)
        return [now, oneHourLater, endOfDay]
    }

    static func endOfDayMinusOneMinute(from date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return calendar.date(byAdding: .minute, value: -1, to: tomorrow) ?? date
    }
}
