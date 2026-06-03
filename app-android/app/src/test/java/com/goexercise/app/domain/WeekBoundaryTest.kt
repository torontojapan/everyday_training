package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate

/**
 * 週起点(月曜)の年跨ぎ/ISO week-year 境界の回帰テスト(Codexレビュー指摘)。
 * iOS Calendar.mondayFirst(firstWeekday=2, minimumDaysInFirstWeek=4)= ISO週と一致することを担保。
 */
class WeekBoundaryTest {

    @Test
    fun weekStartIsMondayAcrossYearBoundary() {
        // 2021-01-01(金)を含む週は 2020-12-28(月)始まり。
        assertEquals(LocalDate.of(2020, 12, 28), RestDayResolver.weekStart(LocalDate.of(2021, 1, 1)))
        assertEquals(DayOfWeek.MONDAY, RestDayResolver.weekStart(LocalDate.of(2021, 1, 1)).dayOfWeek)
        // 2021-01-04(月)はその週の起点そのもの。
        assertEquals(LocalDate.of(2021, 1, 4), RestDayResolver.weekStart(LocalDate.of(2021, 1, 4)))
    }

    @Test
    fun weekStartForSundayIsPreviousMonday() {
        // 日曜は同じ週の月曜(6日前)に丸める。
        assertEquals(DayOfWeek.SUNDAY, LocalDate.of(2026, 5, 31).dayOfWeek)
        assertEquals(LocalDate.of(2026, 5, 25), RestDayResolver.weekStart(LocalDate.of(2026, 5, 31)))
    }

    @Test
    fun streakCountsAcrossYearBoundary() {
        // 2020-12-31, 2021-01-01 連続達成 → 年跨ぎでも streak=2。
        val records = listOf(
            WorkoutRecord(date = LocalDate.of(2020, 12, 31), category = WorkoutCategory.Strength, exercises = listOf(ExerciseItem(name = "x"))),
            WorkoutRecord(date = LocalDate.of(2021, 1, 1), category = WorkoutCategory.Strength, exercises = listOf(ExerciseItem(name = "x"))),
        )
        val streak = StreakCalculator.currentStreak(records, today = LocalDate.of(2021, 1, 1))
        assertEquals(2, streak)
    }
}
