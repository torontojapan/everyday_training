import Foundation

protocol DateProviding: Sendable {
    func currentDate() -> Date
}

struct SystemDateProvider: DateProviding {
    func currentDate() -> Date {
        Date()
    }
}

struct FixedDateProvider: DateProviding {
    let date: Date

    func currentDate() -> Date {
        date
    }
}

extension Calendar {
    static var mondayFirst: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    func weekInterval(containing date: Date) -> DateInterval {
        let start = dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(for: date)
        let end = self.date(byAdding: .day, value: 7, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    func days(in interval: DateInterval) -> [Date] {
        (0..<7).compactMap { offset in
            date(byAdding: .day, value: offset, to: startOfDay(for: interval.start))
        }
    }
}
