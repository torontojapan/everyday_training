import XCTest
@testable import GOExercise

final class StreakCalculatorTests: XCTestCase {
    private let calendar = Calendar.mondayFirst

    func testCurrentStreakCountsOnlyAchievedDays() {
        let today = date(day: 20)
        let records = [record(day: 20), record(day: 19)]

        let streak = StreakCalculator.currentStreak(records: records, today: today, calendar: calendar)

        XCTAssertEqual(streak, 2, "Only actual workout days are counted")
    }

    func testCurrentStreakStopsAtThirdMissedDayInWeek() {
        let today = date(day: 22)
        let records = [record(day: 22)]

        let streak = StreakCalculator.currentStreak(records: records, today: today, calendar: calendar)

        XCTAssertEqual(streak, 1)
    }

    func testRestDaysAreSkippedButStreakIsPreserved() {
        // 5/20 achieved, 5/19 rest (auto), 5/18 achieved
        // Streak = 2 (rest days do not count, but they do not break the streak)
        let today = date(day: 20)
        let records = [record(day: 20), record(day: 18)]

        let streak = StreakCalculator.currentStreak(records: records, today: today, calendar: calendar)

        XCTAssertEqual(streak, 2)
    }

    func testPendingTodayCountsStreakThroughYesterday() {
        // 今日(5/20)未記録でも「昨日までの連続」を表示する基準に変更(2026-06-07)。
        // 5/19 達成 → 今日は todayPending でスキップ → 連続 = 1(昨日まで)。
        // これによりフリーズ復活直後や毎朝、運動前でも本当の連続日数が出る。
        let today = date(day: 20)
        let records = [record(day: 19)]

        let streak = StreakCalculator.currentStreak(records: records, today: today, calendar: calendar)

        XCTAssertEqual(streak, 1, "今日未記録でも昨日までの連続を数える")
    }

    func testPendingTodayWithMissedYesterdayIsZero() {
        // todayPending スキップが「本当に途切れた過去 missed」まで無視しないことの確認。
        // 注意: 自動休養は週2日まで付与される(RestDayResolver limit=2)。記録が直近にあると
        // 昨日付近の欠けは休養枠で橋渡しされ連続が残る。本当に途切れたケースを作るため、
        // 記録を 5/10 のみにして以降を週2日の休養枠を超える長い欠けにする → 昨日(5/19)は missed。
        let today = date(day: 20)
        let records = [record(day: 10)]

        let streak = StreakCalculator.currentStreak(records: records, today: today, calendar: calendar)

        XCTAssertEqual(streak, 0, "昨日が(休養枠を超えて)途切れていれば今日スキップしても0")
    }

    func testStreakStateTracksLongestStreakAndLastAchievedDate() {
        // 5/18, 5/20, 5/21 achieved; 5/19 rest (skipped).
        // Streak preserved across the rest day → current=3, longest=3.
        let today = date(day: 21)
        let records = [record(day: 18), record(day: 20), record(day: 21)]

        let state = StreakCalculator.streakState(records: records, today: today, lookbackDays: 7, calendar: calendar)

        XCTAssertEqual(state.currentStreak, 3)
        XCTAssertEqual(state.longestStreak, 3)
        XCTAssertEqual(state.lastAchievedDate, today)
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
