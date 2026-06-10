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
    private func wednesday() -> Date {
        var d = cal.startOfDay(for: Date())
        for _ in 0...7 { if cal.component(.weekday, from: d) == 4 { return d }; d = cal.date(byAdding: .day, value: 1, to: d)! }
        return d
    }
    func test_pure_decision_boundaries() {
        let r4 = StreakFreezeWindow.Decision.evaluate(statuses: [.missed,.missed,.missed,.achieved], remainingFreezes: 4, lookback: 4)
        XCTAssertTrue(r4.revivable); XCTAssertEqual(r4.freezesNeeded, 3)
        // 丁度 lookback(4)日欠け + offset5 が achieved = 4日グレース内の break → 復活可(4枚必要)。
        let r4exact = StreakFreezeWindow.Decision.evaluate(statuses: [.missed,.missed,.missed,.missed,.achieved], remainingFreezes: 5, lookback: 4)
        XCTAssertTrue(r4exact.revivable); XCTAssertEqual(r4exact.freezesNeeded, 4)
        XCTAssertEqual(r4exact.missedOffsets, [1,2,3,4])
        // 5日欠け(offset5 も missed)= グレース超過 → 復活不可。
        let r5 = StreakFreezeWindow.Decision.evaluate(statuses: [.missed,.missed,.missed,.missed,.missed,.achieved], remainingFreezes: 5, lookback: 4)
        XCTAssertFalse(r5.revivable)
        let rest = StreakFreezeWindow.Decision.evaluate(statuses: [.missed,.rest,.achieved], remainingFreezes: 1, lookback: 4)
        XCTAssertTrue(rest.revivable); XCTAssertEqual(rest.freezesNeeded, 1)
        let zero = StreakFreezeWindow.Decision.evaluate(statuses: [.missed,.achieved], remainingFreezes: 0, lookback: 4)
        XCTAssertTrue(zero.revivable); XCTAssertFalse(zero.hasEnough)
    }
    func test_records_entry_yesterdayMissed_priorStreak() {
        // offsets 4..12 = 今週 Tue/Mon + 先週。Wed(3)/Thu(2)/Fri(1) 空白 → Wed/Thu が週前半
        // rest 枠で埋まり、**金曜が真の missed**。前の連続(Tue 以前)があるので復活可能。
        let today = saturday()
        let records = (4...12).map { rec($0, from: today) }
        let r = StreakFreezeWindow.evaluate(records: records, today: today, rescuedDates: [], remainingFreezes: 1)
        XCTAssertTrue(r.revivable)
        XCTAssertEqual(r.freezesNeeded, 1, "rest の Wed/Thu は不要、金曜の1枚のみ")
        let dates = StreakFreezeWindow.missedDates(forOffsets: r.missedOffsets, today: today)
        XCTAssertEqual(dates.first, cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: today)))
    }
    func test_records_entry_rescuedYesterday_notRevivable() {
        let today = saturday()
        let records = (4...12).map { rec($0, from: today) }
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: today))!
        let r = StreakFreezeWindow.evaluate(records: records, today: today, rescuedDates: [yesterday], remainingFreezes: 1)
        XCTAssertFalse(r.revivable, "金曜(=唯一の missed)を rescue 済み=achieved → 切れてない")
    }

    // 回帰(監査 P1): missed と連続の頭(achieved)の間に自動休養が挟まり、anchor が
    // 旧 lookback+1(=5)窓の外(offset 6)へ押し出されるケース。旧実装は固定5件しか
    // status を作らず anchor を見失い revivable=false にしていた。動的延長で復活可能を検出する。
    func test_pure_decision_restBeyondLookback_findsAnchor() {
        // [rest,rest,missed,rest,rest,achieved] = anchor が offset6。missed は offset3(grace内)。
        let r = StreakFreezeWindow.Decision.evaluate(
            statuses: [.rest, .rest, .missed, .rest, .rest, .achieved],
            remainingFreezes: 1, lookback: 4)
        XCTAssertTrue(r.revivable, "rest は lookback 枠を消費しない。offset6 の achieved を anchor に拾う")
        XCTAssertEqual(r.freezesNeeded, 1)
        XCTAssertEqual(r.missedOffsets, [3])
    }

    func test_records_entry_restBridgesToAnchorBeyondWindow() {
        // today=水。先週 Mon–Thu 達成(daysAgo 6,7,8,9)。Fri/Sat/Sun と今週 Mon/Tue は空白で
        // 自動休養が橋渡しし、真の missed は1日だけ。anchor(木)は offset6 にある。
        let today = wednesday()
        let records = [6, 7, 8, 9].map { rec($0, from: today) }
        let r = StreakFreezeWindow.evaluate(records: records, today: today, rescuedDates: [], remainingFreezes: 1)
        XCTAssertTrue(r.revivable, "rest が anchor を5件窓の外へ押し出しても復活可能を検出する")
        XCTAssertFalse(r.missedOffsets.isEmpty)
        XCTAssertEqual(r.freezesNeeded, r.missedOffsets.count)
        XCTAssertTrue(r.missedOffsets.allSatisfy { $0 <= 4 }, "missed は4日グレース内")
    }
}

final class ReviveDismissStoreTests: XCTestCase {
    private let cal: Calendar = .mondayFirst
    func test_markAndQuery() {
        let d = UserDefaults(suiteName: "revive-dismiss-\(UUID())")!
        let store = ReviveDismissStore(defaults: d)
        let dates = [cal.date(byAdding: .day, value: -1, to: Date())!, cal.date(byAdding: .day, value: -2, to: Date())!]
        let key = ReviveDismissStore.breakKey(missedDates: dates)!
        XCTAssertFalse(store.isHandled(key))
        store.markHandled(key)
        XCTAssertTrue(store.isHandled(key))
        store.markHandled(key) // idempotent
        XCTAssertEqual(store.handled().filter { $0 == key }.count, 1)
    }
    func test_breakKey_usesOldestDate_stable() {
        let base = cal.startOfDay(for: Date())
        let a = cal.date(byAdding: .day, value: -1, to: base)!
        let b = cal.date(byAdding: .day, value: -3, to: base)!
        XCTAssertEqual(ReviveDismissStore.breakKey(missedDates: [a, b]), ReviveDismissStore.breakKey(missedDates: [b, a]))
        XCTAssertEqual(ReviveDismissStore.breakKey(missedDates: [a, b]), String(Int(b.timeIntervalSince1970)))
    }
}
