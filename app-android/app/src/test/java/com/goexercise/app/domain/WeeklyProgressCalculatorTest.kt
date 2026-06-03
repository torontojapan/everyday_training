package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** iOS `WeeklyProgressCalculatorTests.swift` の移植。 */
class WeeklyProgressCalculatorTest {

    @Test
    fun statusesAlwaysReturnSevenDays() {
        val today = date(20)
        val statuses = WeeklyProgressCalculator.statuses(weekContaining = today, records = emptyList(), today = today)
        assertEquals(7, statuses.size)
    }

    @Test
    fun weekStartsOnMonday() {
        val today = date(20)
        val statuses = WeeklyProgressCalculator.statuses(weekContaining = today, records = emptyList(), today = today)
        assertEquals(date(18), statuses.first().date)
    }

    @Test
    fun progressCountsAchievedRestAndTodayAchieved() {
        val entries = listOf(
            DailyStatusEntry(date(18), DailyStatus.Achieved, emptyList()),
            DailyStatusEntry(date(19), DailyStatus.Rest, emptyList()),
            DailyStatusEntry(date(20), DailyStatus.TodayAchieved, emptyList()),
            DailyStatusEntry(date(21), DailyStatus.Missed, emptyList()),
            DailyStatusEntry(date(22), DailyStatus.Future, emptyList()),
            DailyStatusEntry(date(23), DailyStatus.Future, emptyList()),
            DailyStatusEntry(date(24), DailyStatus.Future, emptyList()),
        )

        val progress = WeeklyProgressCalculator.progress(entries)

        assertEquals(3, progress.achievedCount)
        assertEquals(7, progress.totalDays)
        assertEquals(3.0 / 7.0, progress.rate, 0.0001)
    }

    @Test
    fun statusesMarkTodayAchievedWhenTodayHasRecord() {
        val today = date(20)
        val records = listOf(record(20))
        val statuses = WeeklyProgressCalculator.statuses(weekContaining = today, records = records, today = today)
        assertEquals(DailyStatus.TodayAchieved, statuses[2].status)
    }

    @Test
    fun statusesMarkFutureDays() {
        val today = date(20)
        val statuses = WeeklyProgressCalculator.statuses(weekContaining = today, records = emptyList(), today = today)
        assertEquals(DailyStatus.Future, statuses[3].status)
        assertEquals(DailyStatus.Future, statuses[6].status)
    }

    @Test
    fun weeklyProgressIncludesRestDaysFromResolver() {
        val today = date(20)
        val records = listOf(record(18), record(20))

        val statuses = WeeklyProgressCalculator.statuses(weekContaining = today, records = records, today = today)
        val progress = WeeklyProgressCalculator.progress(statuses)

        assertEquals(DailyStatus.Rest, statuses[1].status)
        assertEquals(3, progress.achievedCount)
    }

    /** 保険チケット救済日が週次進捗で達成扱いになる回帰テスト(rescuedDates スレッド漏れ防止)。 */
    @Test
    fun rescuedDayCountsAsAchievedInWeeklyProgress() {
        val today = date(22)
        val records = listOf(record(18), record(19))
        val rescued = setOf(date(20))

        val withoutRescue = WeeklyProgressCalculator.statuses(
            weekContaining = today, records = records, today = today, restLimit = 0,
        )
        val withRescue = WeeklyProgressCalculator.statuses(
            weekContaining = today, records = records, today = today, rescuedDates = rescued, restLimit = 0,
        )

        assertEquals(DailyStatus.Missed, withoutRescue[2].status)
        assertEquals(DailyStatus.Achieved, withRescue[2].status)
        assertTrue(
            WeeklyProgressCalculator.progress(withRescue).achievedCount >
                WeeklyProgressCalculator.progress(withoutRescue).achievedCount,
        )
    }

    private fun record(day: Int): WorkoutRecord =
        WorkoutRecord(date = date(day), category = WorkoutCategory.Strength, exercises = listOf(ExerciseItem(name = "運動")))

    private fun date(day: Int): LocalDate = LocalDate.of(2026, 5, day)
}
