package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

/**
 * iOS `GOExerciseTests/StreakCalculatorTests.swift` の移植。
 * 同入力に対し同出力になることで iOS↔Android のストリーク仕様一致を機械検証する
 * (計画書 §14 / [[android_dev_state]])。
 */
class StreakCalculatorTest {

    @Test
    fun currentStreak_countsOnlyAchievedDays() {
        val today = date(20)
        val records = listOf(record(20), record(19))

        val streak = StreakCalculator.currentStreak(records = records, today = today)

        assertEquals(2, streak)
    }

    @Test
    fun currentStreak_stopsAtThirdMissedDayInWeek() {
        val today = date(22)
        val records = listOf(record(22))

        val streak = StreakCalculator.currentStreak(records = records, today = today)

        assertEquals(1, streak)
    }

    @Test
    fun restDays_areSkippedButStreakIsPreserved() {
        // 5/20 achieved, 5/19 rest (auto), 5/18 achieved → streak = 2
        val today = date(20)
        val records = listOf(record(20), record(18))

        val streak = StreakCalculator.currentStreak(records = records, today = today)

        assertEquals(2, streak)
    }

    @Test
    fun pendingToday_returnsZeroWhenNoRecord() {
        val today = date(20)
        val records = listOf(record(19))

        val streak = StreakCalculator.currentStreak(records = records, today = today)

        assertEquals(0, streak)
    }

    @Test
    fun streakState_tracksLongestStreakAndLastAchievedDate() {
        // 5/18, 5/20, 5/21 achieved; 5/19 rest (skipped) → current=3, longest=3
        val today = date(21)
        val records = listOf(record(18), record(20), record(21))

        val state = StreakCalculator.streakState(
            records = records,
            today = today,
            lookbackDays = 7,
        )

        assertEquals(3, state.currentStreak)
        assertEquals(3, state.longestStreak)
        assertEquals(today, state.lastAchievedDate)
    }

    private fun record(day: Int): WorkoutRecord =
        WorkoutRecord(
            date = date(day),
            category = WorkoutCategory.Strength,
            exercises = listOf(ExerciseItem(name = "運動")),
        )

    private fun date(day: Int): LocalDate = LocalDate.of(2026, 5, day)
}
