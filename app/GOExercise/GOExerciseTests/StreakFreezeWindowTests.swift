import XCTest
@testable import GOExercise

final class StreakFreezeWindowTests: XCTestCase {
    private let cal: Calendar = .mondayFirst
    private func rec(_ daysAgo: Int, from today: Date) -> WorkoutRecord {
        WorkoutRecord(date: cal.date(byAdding: .day, value: -daysAgo, to: today)!,
                      category: .strength,
                      exercises: [ExerciseItem(id: UUID(), name: "スクワット", durationSeconds: 120, reps: nil, sets: nil, memo: nil)],
                      memo: nil, calendar: cal)
    }
    private func saturday() -> Date {
        var d = cal.startOfDay(for: Date())
        for _ in 0...7 { if cal.component(.weekday, from: d) == 7 { return d }; d = cal.date(byAdding: .day, value: 1, to: d)! }
        return d
    }
    func test_pure_decision_boundaries() {
        let r4 = StreakFreezeWindow.Decision.evaluate(statuses: [.missed,.missed,.missed,.achieved], remainingFreezes: 4, lookback: 4)
        XCTAssertTrue(r4.revivable); XCTAssertEqual(r4.freezesNeeded, 3)
        let r5 = StreakFreezeWindow.Decision.evaluate(statuses: [.missed,.missed,.missed,.missed,.achieved], remainingFreezes: 5, lookback: 4)
        XCTAssertFalse(r5.revivable)
        let rest = StreakFreezeWindow.Decision.evaluate(statuses: [.missed,.rest,.achieved], remainingFreezes: 1, lookback: 4)
        XCTAssertTrue(rest.revivable); XCTAssertEqual(rest.freezesNeeded, 1)
        let zero = StreakFreezeWindow.Decision.evaluate(statuses: [.missed,.achieved], remainingFreezes: 0, lookback: 4)
        XCTAssertTrue(zero.revivable); XCTAssertFalse(zero.hasEnough)
    }
    func test_records_entry_yesterdayMissed_priorStreak() {
        let today = saturday()
        let records = (2...9).map { rec($0, from: today) }
        let r = StreakFreezeWindow.evaluate(records: records, today: today, rescuedDates: [], remainingFreezes: 1)
        XCTAssertTrue(r.revivable)
        XCTAssertEqual(r.freezesNeeded, 1)
        let dates = StreakFreezeWindow.missedDates(forOffsets: r.missedOffsets, today: today)
        XCTAssertEqual(dates.first, cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: today)))
    }
    func test_records_entry_rescuedYesterday_notRevivable() {
        let today = saturday()
        let records = (2...9).map { rec($0, from: today) }
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: today))!
        let r = StreakFreezeWindow.evaluate(records: records, today: today, rescuedDates: [yesterday], remainingFreezes: 1)
        XCTAssertFalse(r.revivable, "昨日 rescue 済み=achieved → 切れてない")
    }
}
