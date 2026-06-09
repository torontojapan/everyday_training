package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** iOS `AchievementEvaluatorTests.swift` の移植。 */
class AchievementEvaluatorTest {

    @Test
    fun recordWithOneExerciseIsAchievedWithoutDuration() {
        val record = makeRecord(exercises = listOf(ExerciseItem(name = "スクワット")))
        assertTrue(AchievementEvaluator.isAchieved(record))
    }

    @Test
    fun recordWithSixtySecondsIsAchieved() {
        val record = makeRecord(exercises = listOf(ExerciseItem(name = "プランク", durationSeconds = 60)))
        assertTrue(AchievementEvaluator.isAchieved(record))
    }

    @Test
    fun recordWithMultipleDurationsCountsTotalSeconds() {
        val record = makeRecord(
            exercises = listOf(
                ExerciseItem(name = "散歩", durationSeconds = 30),
                ExerciseItem(name = "ストレッチ", durationSeconds = 30),
            ),
        )
        assertTrue(AchievementEvaluator.isAchieved(record))
    }

    @Test
    fun recordWithNoExercisesIsNotAchieved() {
        val record = makeRecord(exercises = emptyList())
        assertFalse(AchievementEvaluator.isAchieved(record))
    }

    @Test
    fun dailyStatusReturnsTodayAchievedForTodayWithRecord() {
        val today = LocalDate.of(2026, 5, 20)
        val record = makeRecord(date = today, exercises = listOf(ExerciseItem(name = "ヨガ")))

        val status = AchievementEvaluator.dailyStatus(
            date = today, records = listOf(record), restDays = emptySet(), today = today,
        )

        assertEquals(DailyStatus.TodayAchieved, status)
    }

    @Test
    fun dailyStatusReturnsFutureForFutureDate() {
        val today = LocalDate.of(2026, 5, 20)
        val future = LocalDate.of(2026, 5, 21)

        val status = AchievementEvaluator.dailyStatus(
            date = future, records = emptyList(), restDays = emptySet(), today = today,
        )

        assertEquals(DailyStatus.Future, status)
    }

    private fun makeRecord(
        date: LocalDate = LocalDate.of(2026, 5, 20),
        exercises: List<ExerciseItem>,
    ): WorkoutRecord =
        WorkoutRecord(date = date, category = WorkoutCategory.Strength, exercises = exercises)
}
