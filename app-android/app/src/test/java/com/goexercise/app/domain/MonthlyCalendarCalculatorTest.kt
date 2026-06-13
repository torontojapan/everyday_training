package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.YearMonth

class MonthlyCalendarCalculatorTest {

    private fun record(day: Int): WorkoutRecord =
        WorkoutRecord(date = LocalDate.of(2026, 5, day), category = WorkoutCategory.Strength, exercises = listOf(ExerciseItem(name = "運動")))

    @Test
    fun leadingBlanksMatchFirstWeekday() {
        // 2026-05-01 は金曜(月曜始まりで先頭4空白: 月火水木)。
        val cells = MonthlyCalendarCalculator.cells(YearMonth.of(2026, 5), emptyList(), today = LocalDate.of(2026, 5, 31))
        assertEquals(java.time.DayOfWeek.FRIDAY, LocalDate.of(2026, 5, 1).dayOfWeek)
        val leading = cells.takeWhile { it.date == null }.size
        assertEquals(4, leading)
        // 空白 + 31日 = 35 セル
        assertEquals(4 + 31, cells.size)
    }

    @Test
    fun firstDayCellHasDateAndStatus() {
        val cells = MonthlyCalendarCalculator.cells(YearMonth.of(2026, 5), emptyList(), today = LocalDate.of(2026, 5, 31))
        val firstDay = cells.first { it.date != null }
        assertEquals(LocalDate.of(2026, 5, 1), firstDay.date)
        assertNull(cells.first().date) // 先頭は空白
    }

    @Test
    fun achievedDayShowsAchievedStatus() {
        val today = LocalDate.of(2026, 5, 31)
        val cells = MonthlyCalendarCalculator.cells(YearMonth.of(2026, 5), listOf(record(10)), today = today)
        val day10 = cells.first { it.date == LocalDate.of(2026, 5, 10) }
        assertEquals(DailyStatus.Achieved, day10.status)
        assertTrue(MonthlyCalendarCalculator.achievedDaysInMonth(cells) >= 1)
    }

    @Test
    fun cellsAlwaysFillCompleteWeeks() {
        // iOS と同様、セル数は常に 7 の倍数(先頭+末尾を空白で詰める)。
        for (m in 1..12) {
            val cells = MonthlyCalendarCalculator.cells(YearMonth.of(2026, m), emptyList(), today = LocalDate.of(2026, 12, 31))
            assertEquals("month=$m は7の倍数でない", 0, cells.size % 7)
        }
    }

    @Test
    fun trailingBlanksPadLastWeek() {
        // 2026-08-01 は土曜(leading=5)。5+31=36 → 42(6週)に詰める。
        assertEquals(java.time.DayOfWeek.SATURDAY, LocalDate.of(2026, 8, 1).dayOfWeek)
        val cells = MonthlyCalendarCalculator.cells(YearMonth.of(2026, 8), emptyList(), today = LocalDate.of(2026, 12, 31))
        assertEquals(42, cells.size)
        assertNull(cells.last().date) // 末尾は空白
    }

    @Test
    fun achievedCountExcludesRest() {
        // restLimit>0 で未記録日は Rest 扱いになるが、達成数には含めない。
        val today = LocalDate.of(2026, 5, 31)
        val cells = MonthlyCalendarCalculator.cells(YearMonth.of(2026, 5), listOf(record(10)), today = today)
        // 5/10 のみ Achieved。Rest 日(自動休養)は achievedDaysInMonth に入らない。
        assertEquals(1, MonthlyCalendarCalculator.achievedDaysInMonth(cells))
        assertTrue(MonthlyCalendarCalculator.restDaysInMonth(cells) >= 1)
    }

    @Test
    fun daysBeforeFirstRecordAreNeutralFuture() {
        // 初記録(5/10)より前の日は未達成でも休養でもなく中立「-」(Future)。iOS パリティ。
        val today = LocalDate.of(2026, 5, 31)
        val cells = MonthlyCalendarCalculator.cells(YearMonth.of(2026, 5), listOf(record(10)), today = today)
        assertEquals(DailyStatus.Future, cells.first { it.date == LocalDate.of(2026, 5, 5) }.status)
        assertEquals(DailyStatus.Achieved, cells.first { it.date == LocalDate.of(2026, 5, 10) }.status)
    }

    @Test
    fun pastDaysAreNeutralWhenNoRecordsEver() {
        // 記録が1件も無いユーザーの過去日も中立(× や 休 を出さない)。今日は除外。
        val today = LocalDate.of(2026, 5, 15)
        val cells = MonthlyCalendarCalculator.cells(YearMonth.of(2026, 5), emptyList(), today = today)
        assertEquals(DailyStatus.Future, cells.first { it.date == LocalDate.of(2026, 5, 10) }.status)
    }

    @Test
    fun futureMonthDaysAreFuture() {
        val today = LocalDate.of(2026, 5, 15)
        val cells = MonthlyCalendarCalculator.cells(YearMonth.of(2026, 5), emptyList(), today = today)
        val day20 = cells.first { it.date == LocalDate.of(2026, 5, 20) }
        assertEquals(DailyStatus.Future, day20.status)
    }
}
