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
    fun futureMonthDaysAreFuture() {
        val today = LocalDate.of(2026, 5, 15)
        val cells = MonthlyCalendarCalculator.cells(YearMonth.of(2026, 5), emptyList(), today = today)
        val day20 = cells.first { it.date == LocalDate.of(2026, 5, 20) }
        assertEquals(DailyStatus.Future, day20.status)
    }
}
