package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

/**
 * ハイライト集計の検証(iOS MonthlyReviewBuilder パリティ)。
 * 達成日数(rescued 含む)・最長連続(rest/rescued 橋渡し)・合計時間/種目・期間ラベルを確認。
 */
class MonthlyReviewBuilderTest {

    private fun rec(date: LocalDate, cat: WorkoutCategory = WorkoutCategory.Strength, name: String = "スクワット", sec: Int = 600) =
        WorkoutRecord(date = date, category = cat, exercises = listOf(ExerciseItem(name = name, durationSeconds = sec)))

    @Test
    fun `monthly aggregates achieved days and label`() {
        val today = LocalDate.of(2026, 6, 17)
        val records = listOf(
            rec(LocalDate.of(2026, 6, 1)),
            rec(LocalDate.of(2026, 6, 2)),
            rec(LocalDate.of(2026, 6, 10), WorkoutCategory.Cardio, "ジョギング", 1800),
        )
        val r = MonthlyReviewBuilder.build(records, month = today, today = today)
        assertEquals("2026年6月", r.periodLabel)
        assertEquals(3, r.achievedDays)
        assertEquals(30, r.totalDays) // 6月は30日
        assertEquals((600 + 600 + 1800) / 60, r.totalDurationMinutes)
        assertEquals(3, r.totalExerciseCount)
        assertEquals(WorkoutCategory.Strength, r.topCategory) // 2 vs 1
        assertEquals("スクワット", r.topExerciseName)
    }

    @Test
    fun `rescued days count as achieved`() {
        val today = LocalDate.of(2026, 6, 17)
        val records = listOf(rec(LocalDate.of(2026, 6, 1)))
        val rescued = setOf(LocalDate.of(2026, 6, 2), LocalDate.of(2026, 6, 3))
        val r = MonthlyReviewBuilder.build(records, month = today, today = today, rescuedDates = rescued)
        assertEquals(3, r.achievedDays) // 実運動1 + 救済2
    }

    @Test
    fun `weekly label and 7 day total`() {
        val today = LocalDate.of(2026, 6, 17) // 水曜
        val weekStart = RestDayResolver.weekStart(today) // 2026-06-15(月)
        val r = MonthlyReviewBuilder.weekly(listOf(rec(weekStart)), weekContaining = today, today = today)
        assertEquals(7, r.totalDays)
        assertEquals(1, r.achievedDays)
        val expected = "${weekStart.monthValue}/${weekStart.dayOfMonth} - ${weekStart.plusDays(6).monthValue}/${weekStart.plusDays(6).dayOfMonth}"
        assertEquals(expected, r.periodLabel)
    }

    @Test
    fun `lifetime totalDays spans first record to today`() {
        val today = LocalDate.of(2026, 6, 17)
        val first = LocalDate.of(2026, 6, 8) // 10 日前
        val r = MonthlyReviewBuilder.lifetime(listOf(rec(first), rec(today)), today = today)
        assertEquals(10, r.totalDays) // 8..17 inclusive = 10
        assertEquals("通算 10日", r.periodLabel)
        assertEquals(2, r.achievedDays)
    }

    @Test
    fun `lifetime empty yields zero`() {
        val today = LocalDate.of(2026, 6, 17)
        val r = MonthlyReviewBuilder.lifetime(emptyList(), today = today)
        assertEquals(0, r.totalDays)
        assertEquals(0, r.achievedDays)
        assertEquals(0, r.longestStreak)
    }

    @Test
    fun `longest streak bridges a rescued gap`() {
        // today を週末に置き、月-木をすべて過去日にする(未来日は連続にカウントされないため)。
        val today = LocalDate.of(2026, 6, 20) // 土曜
        // 月-火 運動, 水 救済, 木 運動 → 連続4(救済が橋渡し)。
        val mon = LocalDate.of(2026, 6, 15)
        val records = listOf(rec(mon), rec(mon.plusDays(1)), rec(mon.plusDays(3)))
        val rescued = setOf(mon.plusDays(2)) // 水曜(過去日なので Rescued 判定になる)
        val r = MonthlyReviewBuilder.build(records, month = today, today = today, rescuedDates = rescued)
        assertEquals(4, r.longestStreak)
    }
}
