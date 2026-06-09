package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

/** iOS `LifetimeStatsCalculatorTests.swift` の移植。 */
class LifetimeStatsCalculatorTest {

    @Test
    fun usedDaysIsAtLeastOne() {
        val today = date(5, 24)
        val stats = LifetimeStatsCalculator.calculate(records = emptyList(), firstUseDate = today, today = today)
        assertEquals(1, stats.usedDays)
        assertEquals(0, stats.achievedDays)
    }

    @Test
    fun usedDaysIsInclusive() {
        val stats = LifetimeStatsCalculator.calculate(emptyList(), firstUseDate = date(5, 1), today = date(5, 24))
        assertEquals(24, stats.usedDays) // 5/1〜5/24 inclusive
    }

    @Test
    fun achievedDaysCountsUniqueDates() {
        val records = listOf(record(5, 1), record(5, 1), record(5, 5), record(5, 10))
        val stats = LifetimeStatsCalculator.calculate(records, firstUseDate = date(5, 1), today = date(5, 24))
        assertEquals(3, stats.achievedDays) // 同日重複は1回
    }

    @Test
    fun notAchievedRecordIsExcluded() {
        val unachieved = WorkoutRecord(date = date(5, 2), category = WorkoutCategory.Strength, exercises = emptyList())
        val achieved = record(5, 3)
        val stats = LifetimeStatsCalculator.calculate(listOf(unachieved, achieved), firstUseDate = date(5, 1), today = date(5, 24))
        assertEquals(1, stats.achievedDays)
    }

    @Test
    fun ratePercentage() {
        val records = (1..4).map { record(5, it) }
        val stats = LifetimeStatsCalculator.calculate(records, firstUseDate = date(5, 1), today = date(5, 10))
        assertEquals(10, stats.usedDays)
        assertEquals(4, stats.achievedDays)
        assertEquals(0.4, stats.rate, 0.001)
    }

    private fun record(month: Int, day: Int): WorkoutRecord =
        WorkoutRecord(date = date(month, day), category = WorkoutCategory.Strength, exercises = listOf(ExerciseItem(name = "test")))

    private fun date(month: Int, day: Int): LocalDate = LocalDate.of(2026, month, day)
}
