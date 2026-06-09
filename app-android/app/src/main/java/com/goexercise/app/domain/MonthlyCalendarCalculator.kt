package com.goexercise.app.domain

import java.time.LocalDate
import java.time.YearMonth

/**
 * 月カレンダーのセル列を組み立てる純粋関数。iOS `MonthlyCalendarView` のグリッド生成を移植。
 * 先頭に空白セル(月初の曜日まで)を入れ、続けて当月各日を DailyStatus 付きで並べる
 * (前後月の日付は出さず空白で詰める = iOS と同じ)。月曜始まり。
 */
object MonthlyCalendarCalculator {

    /** date=null は空白セル(月初までの詰め)。 */
    data class MonthCell(val date: LocalDate?, val status: DailyStatus?)

    fun cells(
        month: YearMonth,
        records: List<WorkoutRecord>,
        today: LocalDate,
        rescuedDates: Set<LocalDate> = emptySet(),
        restLimit: Int = 2,
    ): List<MonthCell> {
        val first = month.atDay(1)
        // 月曜始まりの先頭空白数: Mon=0 .. Sun=6。
        val leading = first.dayOfWeek.value - 1
        val blanks = List(leading) { MonthCell(null, null) }

        val days = (1..month.lengthOfMonth()).map { d ->
            val date = month.atDay(d)
            val restDays = RestDayResolver.restDaySet(date, records, today, restLimit)
            val status = AchievementEvaluator.dailyStatus(
                date = date, records = records, restDays = restDays, rescuedDates = rescuedDates, today = today,
            )
            MonthCell(date, status)
        }
        // iOS と同様、末尾も 7 列の行が埋まるまで空白で詰める(MonthlyCalendarView)。
        val cells = (blanks + days).toMutableList()
        while (cells.size % 7 != 0) cells.add(MonthCell(null, null))
        return cells
    }

    /**
     * 当月の「達成」日数。iOS の月サマリーと一致させ **休養(Rest)は含めない**
     * (Achieved/TodayAchieved のみ。MonthlyCalendarView.summaryText 参照)。
     */
    fun achievedDaysInMonth(cells: List<MonthCell>): Int =
        cells.count { it.status == DailyStatus.Achieved || it.status == DailyStatus.TodayAchieved }

    /** 当月の休養(Rest)日数。iOS は達成と分離表示する。 */
    fun restDaysInMonth(cells: List<MonthCell>): Int =
        cells.count { it.status == DailyStatus.Rest }
}
