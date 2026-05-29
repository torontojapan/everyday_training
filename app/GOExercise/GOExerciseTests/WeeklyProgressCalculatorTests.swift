import XCTest
@testable import GOExercise

final class WeeklyProgressCalculatorTests: XCTestCase {
    private let calendar = Calendar.mondayFirst

    func testStatusesAlwaysReturnSevenDays() {
        let today = date(day: 20)

        let statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: [], today: today, calendar: calendar)

        XCTAssertEqual(statuses.count, 7)
    }

    func testWeekStartsOnMonday() {
        let today = date(day: 20)

        let statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: [], today: today, calendar: calendar)

        XCTAssertEqual(statuses.first?.date, date(day: 18))
    }

    func testProgressCountsAchievedRestAndTodayAchieved() {
        let entries = [
            DailyStatusEntry(date: date(day: 18), status: .achieved, recordIds: []),
            DailyStatusEntry(date: date(day: 19), status: .rest, recordIds: []),
            DailyStatusEntry(date: date(day: 20), status: .todayAchieved, recordIds: []),
            DailyStatusEntry(date: date(day: 21), status: .missed, recordIds: []),
            DailyStatusEntry(date: date(day: 22), status: .future, recordIds: []),
            DailyStatusEntry(date: date(day: 23), status: .future, recordIds: []),
            DailyStatusEntry(date: date(day: 24), status: .future, recordIds: [])
        ]

        let progress = WeeklyProgressCalculator.progress(from: entries)

        XCTAssertEqual(progress.achievedCount, 3)
        XCTAssertEqual(progress.totalDays, 7)
        XCTAssertEqual(progress.rate, 3.0 / 7.0, accuracy: 0.0001)
    }

    func testStatusesMarkTodayAchievedWhenTodayHasRecord() {
        let today = date(day: 20)
        let records = [record(day: 20)]

        let statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: records, today: today, calendar: calendar)

        XCTAssertEqual(statuses[2].status, .todayAchieved)
    }

    func testStatusesMarkFutureDays() {
        let today = date(day: 20)

        let statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: [], today: today, calendar: calendar)

        XCTAssertEqual(statuses[3].status, .future)
        XCTAssertEqual(statuses[6].status, .future)
    }

    func testWeeklyProgressIncludesRestDaysFromResolver() {
        let today = date(day: 20)
        let records = [record(day: 18), record(day: 20)]

        let statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: records, today: today, calendar: calendar)
        let progress = WeeklyProgressCalculator.progress(from: statuses)

        XCTAssertEqual(statuses[1].status, .rest)
        XCTAssertEqual(progress.achievedCount, 3)
    }

    /// 保険チケット救済日が週次進捗で達成扱いになる回帰テスト。
    /// 旧コードは rescuedDates を受け取らず、救済日を未達成のままにして
    /// 履歴タブの月次カレンダー (救済反映済み) と食い違っていた (3 LLM 監査 A-Major)。
    func testRescuedDayCountsAsAchievedInWeeklyProgress() {
        let today = date(day: 22)
        // 月曜(18)と火曜(19)に記録、水曜(20)は記録なしだが救済チケット使用。
        // restLimit:0 で自動休養日を無効化し、救済の効果を純粋に検証する
        // (restLimit>0 だと未記録日が自動 rest 扱いになり missed→achieved の差が出ない)。
        let records = [record(day: 18), record(day: 19)]
        let rescued: Set<Date> = [date(day: 20)]

        let withoutRescue = WeeklyProgressCalculator.statuses(
            forWeekContaining: today, records: records, today: today,
            restLimit: 0, calendar: calendar)
        let withRescue = WeeklyProgressCalculator.statuses(
            forWeekContaining: today, records: records, today: today,
            rescuedDates: rescued, restLimit: 0, calendar: calendar)

        // index 2 = 水曜(20)。救済なしでは missed、救済ありでは achieved。
        XCTAssertEqual(withoutRescue[2].status, .missed)
        XCTAssertEqual(withRescue[2].status, .achieved)
        XCTAssertGreaterThan(
            WeeklyProgressCalculator.progress(from: withRescue).achievedCount,
            WeeklyProgressCalculator.progress(from: withoutRescue).achievedCount)
    }

    private func record(day: Int) -> WorkoutRecord {
        WorkoutRecord(
            date: date(day: day),
            category: .strength,
            exercises: [ExerciseItem(name: "運動")],
            calendar: calendar
        )
    }

    private func date(day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 5, day: day))!
    }
}
