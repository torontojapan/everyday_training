package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class ExerciseHistoryProviderTest {

    private fun rec(day: Int, category: WorkoutCategory, vararg names: String) = WorkoutRecord(
        date = LocalDate.of(2026, 5, day),
        category = category,
        exercises = names.map { ExerciseItem(name = it, category = category) },
    )

    @Test
    fun ordersByLastUsedDateDescending() {
        val records = listOf(
            rec(10, WorkoutCategory.Strength, "スクワット"),
            rec(18, WorkoutCategory.Strength, "ベンチプレス"),
            rec(15, WorkoutCategory.Strength, "デッドリフト"),
        )
        val top = ExerciseHistoryProvider.topExerciseNames(records, WorkoutCategory.Strength)
        assertEquals(listOf("ベンチプレス", "デッドリフト", "スクワット"), top)
    }

    @Test
    fun filtersByCategory() {
        val records = listOf(
            rec(18, WorkoutCategory.Cardio, "ランニング"),
            rec(17, WorkoutCategory.Strength, "スクワット"),
        )
        assertEquals(listOf("スクワット"), ExerciseHistoryProvider.topExerciseNames(records, WorkoutCategory.Strength))
        assertEquals(listOf("ランニング"), ExerciseHistoryProvider.topExerciseNames(records, WorkoutCategory.Cardio))
    }

    @Test
    fun sameNameUsesLatestDate_andCountsForTiebreak() {
        val records = listOf(
            rec(10, WorkoutCategory.Strength, "スクワット"),
            rec(18, WorkoutCategory.Strength, "スクワット"), // 最終使用日=18 に更新
            rec(18, WorkoutCategory.Strength, "ベンチプレス"),
        )
        // スクワット(count2) と ベンチプレス(count1) は同日18 → count 多い方が先。
        val top = ExerciseHistoryProvider.topExerciseNames(records, WorkoutCategory.Strength)
        assertEquals(listOf("スクワット", "ベンチプレス"), top)
    }

    @Test
    fun respectsLimit() {
        val records = (1..10).map { rec(it, WorkoutCategory.Strength, "種目$it") }
        assertEquals(3, ExerciseHistoryProvider.topExerciseNames(records, WorkoutCategory.Strength, limit = 3).size)
    }
}
