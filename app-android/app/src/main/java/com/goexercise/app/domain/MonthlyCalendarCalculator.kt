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
        return blanks + days
    }

    /** 当月の達成日数(達成扱い = countsAsAchieved)。 */
    fun achievedDaysInMonth(cells: List<MonthCell>): Int =
        cells.count { it.date != null && it.status?.countsAsAchieved == true }
}
