package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class ExerciseTrendSummaryTest {

    private fun rec(day: Int, category: WorkoutCategory, vararg ex: ExerciseItem): WorkoutRecord =
        WorkoutRecord(date = LocalDate.of(2026, 5, day), category = category, exercises = ex.toList())

    @Test
    fun todaySummaryCountsCategoriesAndDuration() {
        val today = LocalDate.of(2026, 5, 20)
        val records = listOf(
            rec(20, WorkoutCategory.Strength, ExerciseItem(name = "スクワット"), ExerciseItem(name = "腕立て", durationSeconds = 120)),
            rec(20, WorkoutCategory.Cardio, ExerciseItem(name = "走る", durationSeconds = 300)),
            rec(19, WorkoutCategory.Yoga, ExerciseItem(name = "ヨガ")), // 別日=除外
        )
        val s = ExerciseTrendSummary.today(records, today)
        assertEquals(3, s.exerciseCount)
        assertEquals(420, s.totalDurationSeconds)
        assertEquals(1, s.categoryCounts[WorkoutCategory.Strength])
        assertEquals(1, s.categoryCounts[WorkoutCategory.Cardio])
        assertTrue(s.hasExerciseData)
    }

    @Test
    fun weekSummaryUsedCategoriesInEnumOrderAndMinutes() {
        // 週(2026-05-18 Mon〜24 Sun)。Cardio と Strength を使用 → enum 順は Strength,Cardio。
        val records = listOf(
            rec(18, WorkoutCategory.Cardio, ExerciseItem(name = "走る", durationSeconds = 600)),
            rec(20, WorkoutCategory.Strength, ExerciseItem(name = "スクワット", durationSeconds = 600)),
        )
        val s = ExerciseTrendSummary.week(records, LocalDate.of(2026, 5, 20))
        assertEquals(listOf(WorkoutCategory.Strength, WorkoutCategory.Cardio), s.usedCategories)
        assertEquals(1200, s.totalDurationSeconds)
        assertEquals(20, s.totalMinutes)
    }

    @Test
    fun weekTopExerciseNamesByCountThenName() {
        val records = listOf(
            rec(18, WorkoutCategory.Strength, ExerciseItem(name = "スクワット"), ExerciseItem(name = "スクワット")),
            rec(19, WorkoutCategory.Strength, ExerciseItem(name = "腕立て")),
        )
        val s = ExerciseTrendSummary.week(records, LocalDate.of(2026, 5, 20))
        assertEquals("スクワット", s.topExerciseNames.first()) // 出現2回で先頭
        assertTrue(s.topExerciseNames.size <= 3)
    }

    @Test
    fun emptyWeekHasNoData() {
        val s = ExerciseTrendSummary.week(emptyList(), LocalDate.of(2026, 5, 20))
        assertEquals(0, s.totalMinutes)
        assertTrue(s.usedCategories.isEmpty())
        assertTrue(!s.hasExerciseData)
    }
}
