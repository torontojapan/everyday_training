import XCTest
@testable import GOExercise

final class WidgetTimelineDatesTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        var components = DateComponents()
        components.year = y; components.month = m; components.day = d
        components.hour = h; components.minute = min
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return calendar.date(from: components) ?? Date()
    }

    func testEntryDatesReturnsThreeEntriesStartingWithNow() {
        let now = date(2026, 5, 24, 10, 0)
        let entries = WidgetTimelineDates.entryDates(from: now, calendar: calendar)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0], now)
    }

    func testEntryDatesSecondEntryIsOneHourLater() {
        let now = date(2026, 5, 24, 10, 0)
        let entries = WidgetTimelineDates.entryDates(from: now, calendar: calendar)
        let expected = calendar.date(byAdding: .hour, value: 1, to: now)
        XCTAssertEqual(entries[1], expected)
    }

    func testEntryDatesThirdEntryIsEndOfDayMinusOneMinute() {
        let now = date(2026, 5, 24, 10, 0)
        let entries = WidgetTimelineDates.entryDates(from: now, calendar: calendar)
        XCTAssertEqual(entries[2], date(2026, 5, 24, 23, 59))
    }

    func testEndOfDayMinusOneMinuteFromMidnightIsSameDay2359() {
        let midnight = date(2026, 5, 24, 0, 0)
        let end = WidgetTimelineDates.endOfDayMinusOneMinute(from: midnight, calendar: calendar)
        XCTAssertEqual(end, date(2026, 5, 24, 23, 59))
    }

    func testEndOfDayMinusOneMinuteFromLateEveningStaysInSameDay() {
        let late = date(2026, 5, 24, 23, 45)
        let end = WidgetTimelineDates.endOfDayMinusOneMinute(from: late, calendar: calendar)
        XCTAssertEqual(end, date(2026, 5, 24, 23, 59))
    }

    func testEntryDatesAreMonotonicallyIncreasing() {
        let now = date(2026, 5, 24, 14, 30)
        let entries = WidgetTimelineDates.entryDates(from: now, calendar: calendar)
        XCTAssertLessThan(entries[0], entries[1])
        XCTAssertLessThan(entries[1], entries[2])
    }
}
