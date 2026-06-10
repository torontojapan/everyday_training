import XCTest
@testable import GOExercise

/// MonthlyReviewBuilder の「最長連続」寛容化 (2026-06-09) の回帰テスト。
///
/// 寛容化前は達成日の暦上の隣接のみで連続を数えていたため、自動休養 (rest) 日や
/// フリーズ救済日 (rescuedDates) を挟むと連続が切れていた。寛容化後は正本
/// StreakCalculator.streakState と同じ判定 (rest/救済は連続を橋渡し) に統一した。
///
/// 日付メモ: 2026-05-18 は月曜 (mondayFirst の週頭)。週 = 5/18〜5/24。
/// RestDayResolver は週内の未記録日 (today以下) を早い順に 2 日まで rest にする。
final class MonthlyReviewBuilderTests: XCTestCase {
    private let calendar = Calendar.mondayFirst

    // MARK: - 月次: rest 日の橋渡し

    func testMonthlyLongestStreakBridgesRestDays() {
        // 5/18, 5/20, 5/21 達成 / 5/19 は未記録 → 週2日休養枠で rest。
        // 旧ロジック: 達成日 18・20・21 の隣接のみ → longest = 2 (20-21)。
        // 新ロジック: 5/19 rest を橋渡し → 18,19,20,21 で longest = 3。
        let records = [record(day: 18), record(day: 20), record(day: 21)]

        let review = MonthlyReviewBuilder.build(
            records: records, month: date(day: 1), today: date(month: 6, day: 1), calendar: calendar
        )

        XCTAssertEqual(review.longestStreakInMonth, 3, "rest 日が連続を橋渡しする")
    }

    // MARK: - 月次: フリーズ救済日の橋渡し

    func testMonthlyLongestStreakBridgesRescuedDays() {
        // 5/21〜5/24 達成 / 5/18・5/19・5/20 は未記録。
        // rest = 早い順 2 日 = 5/18, 5/19。5/20 は休養枠を超えるので素では missed。
        // 5/20 を救済すると 5/20〜5/24 が達成扱いになり、rest の 5/18・5/19 も橋渡しされ
        // longest = 5 (18,19,20,21,22... 実際は 18 rest,19 rest,20 救済,21,22,23,24 = 5 連続)。
        let records = [record(day: 21), record(day: 22), record(day: 23), record(day: 24)]
        let rescued: Set<Date> = [date(day: 20)]

        let review = MonthlyReviewBuilder.build(
            records: records, month: date(day: 1), today: date(month: 6, day: 1),
            rescuedDates: rescued, calendar: calendar
        )

        XCTAssertEqual(review.longestStreakInMonth, 5, "救済日が連続を橋渡しする")
    }

    func testMonthlyLongestStreakWithoutRescueBreaksAtMissedDay() {
        // 上と同じ records だが救済なし → 5/20 は missed で連続が切れる。
        // longest = 4 (5/21〜5/24)。救済の寄与 (+1) が明確に出る対比ケース。
        let records = [record(day: 21), record(day: 22), record(day: 23), record(day: 24)]

        let review = MonthlyReviewBuilder.build(
            records: records, month: date(day: 1), today: date(month: 6, day: 1), calendar: calendar
        )

        XCTAssertEqual(review.longestStreakInMonth, 4, "救済が無ければ missed で切れる")
    }

    // MARK: - 週次・累計も同じ意味論で橋渡しする (回帰)

    func testWeeklyLongestStreakBridgesRescuedDays() {
        let records = [record(day: 21), record(day: 22), record(day: 23), record(day: 24)]
        let rescued: Set<Date> = [date(day: 20)]

        let review = MonthlyReviewBuilder.weekly(
            records: records, weekContaining: date(day: 21), today: date(month: 6, day: 1),
            rescuedDates: rescued, calendar: calendar
        )

        XCTAssertEqual(review.longestStreakInMonth, 5, "週次も救済/休養を橋渡しする")
    }

    func testLifetimeLongestStreakBridgesRestDays() {
        let records = [record(day: 18), record(day: 20), record(day: 21)]

        let review = MonthlyReviewBuilder.lifetime(
            records: records, today: date(month: 6, day: 1), calendar: calendar
        )

        XCTAssertEqual(review.longestStreakInMonth, 3, "累計も rest を橋渡しする")
    }

    func testLifetimeIncludesRescuedDayBeforeFirstRecord() {
        // Codex P2 (2026-06-09): lifetime の走査開始日が記録の最古日だと、それより前の
        // 救済日が範囲外に落ちて連続に寄与しない (正本 streakState の固定窓には無い穴)。
        // 5/17 救済 (記録なし) → 5/18・5/19 達成。救済日を範囲に含めれば 5/17〜5/19 で longest=3。
        let records = [record(day: 18), record(day: 19)]
        let rescued: Set<Date> = [date(day: 17)]

        let review = MonthlyReviewBuilder.lifetime(
            records: records, today: date(month: 6, day: 1), rescuedDates: rescued, calendar: calendar
        )

        XCTAssertEqual(review.longestStreakInMonth, 3, "記録より前の救済日も走査範囲に含める")
    }

    // MARK: - 未来日は today までクランプ

    func testWeeklyClampsToTodayForOngoingWeek() {
        // 今週進行中 (today = 5/20 水)。5/18・5/19・5/20 達成、5/21〜5/24 は未来。
        // 範囲は today=5/20 までにクランプ → longest = 3 (未来日で誤って切らない/伸ばさない)。
        let records = [record(day: 18), record(day: 19), record(day: 20)]

        let review = MonthlyReviewBuilder.weekly(
            records: records, weekContaining: date(day: 20), today: date(day: 20), calendar: calendar
        )

        XCTAssertEqual(review.longestStreakInMonth, 3)
    }

    // MARK: - 記録なし

    func testEmptyRecordsHaveZeroLongestStreak() {
        let review = MonthlyReviewBuilder.build(
            records: [], month: date(day: 1), today: date(month: 6, day: 1), calendar: calendar
        )

        XCTAssertEqual(review.longestStreakInMonth, 0)
    }

    // MARK: - achievedDays に救済日を含める(監査 F4: カレンダー footer / longest との整合)

    func testAchievedDaysIncludesRescuedDay() {
        // 5/21〜5/24 記録達成(4日)+ 5/20 を救済。救済日も「達成」と数え達成5日。
        // longestStreakInMonth(5)と矛盾しない(旧実装は achievedDays=4 で自己矛盾)。
        let records = [record(day: 21), record(day: 22), record(day: 23), record(day: 24)]
        let rescued: Set<Date> = [date(day: 20)]

        let review = MonthlyReviewBuilder.build(
            records: records, month: date(day: 1), today: date(month: 6, day: 1),
            rescuedDates: rescued, calendar: calendar
        )

        XCTAssertEqual(review.achievedDays, 5, "救済日も達成日数に含める")
        XCTAssertLessThanOrEqual(review.longestStreakInMonth, review.achievedDays, "最長連続 ≤ 達成日数")
    }

    func testAchievedDaysDoesNotDoubleCountRescuedOnRecordedDay() {
        // 記録済みの日を救済しても二重カウントしない(Set union)。
        let records = [record(day: 21), record(day: 22)]
        let rescued: Set<Date> = [date(day: 21)] // 記録日と同じ

        let review = MonthlyReviewBuilder.build(
            records: records, month: date(day: 1), today: date(month: 6, day: 1),
            rescuedDates: rescued, calendar: calendar
        )

        XCTAssertEqual(review.achievedDays, 2, "記録日と重なる救済日は二重計上しない")
    }

    func testLifetimeTotalDaysSpansRescueBeforeFirstRecord() {
        // 記録より前の救済日を範囲に含めるなら、totalDays もその起点から数え、
        // longestStreakInMonth > totalDays の矛盾を起こさない(監査 F4)。
        let records = [record(day: 18), record(day: 19)]
        let rescued: Set<Date> = [date(day: 17)]

        let review = MonthlyReviewBuilder.lifetime(
            records: records, today: date(month: 6, day: 1), rescuedDates: rescued, calendar: calendar
        )

        XCTAssertLessThanOrEqual(review.longestStreakInMonth, review.totalDays, "最長連続 ≤ 通算日数")
    }

    // MARK: - Helpers

    private func record(day: Int) -> WorkoutRecord {
        WorkoutRecord(
            date: date(day: day),
            category: .strength,
            exercises: [ExerciseItem(name: "運動")],
            calendar: calendar
        )
    }

    private func date(month: Int = 5, day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }
}
