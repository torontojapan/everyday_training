package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDateTime

/** iOS `CatStateResolverTests.swift` の移植。 */
class CatStateResolverTest {

    @Test
    fun streakExtendedHasHighestPriority() {
        val state = CatStateResolver.resolve(
            todayStatus = DailyStatus.TodayAchieved,
            now = at(20),
            yesterdayAchieved = false,
            streakExtendedThisRun = true,
        )
        assertEquals(CatState.StreakExtended, state)
    }

    @Test
    fun todayAchievedBecomesCelebrating() {
        val state = CatStateResolver.resolve(DailyStatus.TodayAchieved, at(9), yesterdayAchieved = false, streakExtendedThisRun = false)
        assertEquals(CatState.Celebrating, state)
    }

    @Test
    fun restDayBecomesResting() {
        val state = CatStateResolver.resolve(DailyStatus.Rest, at(13), yesterdayAchieved = false, streakExtendedThisRun = false)
        assertEquals(CatState.Resting, state)
    }

    @Test
    fun yesterdayMissedBecomesEncouraging() {
        val state = CatStateResolver.resolve(DailyStatus.TodayPending, at(9), yesterdayAchieved = false, streakExtendedThisRun = false)
        assertEquals(CatState.Encouraging, state)
    }

    @Test
    fun morningPendingBecomesWaitingMorning() {
        val state = CatStateResolver.resolve(DailyStatus.TodayPending, at(11, 59), yesterdayAchieved = true, streakExtendedThisRun = false)
        assertEquals(CatState.WaitingMorning, state)
    }

    @Test
    fun noonPendingBecomesWorriedNoon() {
        val state = CatStateResolver.resolve(DailyStatus.TodayPending, at(12), yesterdayAchieved = true, streakExtendedThisRun = false)
        assertEquals(CatState.WorriedNoon, state)
    }

    @Test
    fun nightPendingBecomesBeggingNight() {
        val state = CatStateResolver.resolve(DailyStatus.TodayPending, at(18), yesterdayAchieved = true, streakExtendedThisRun = false)
        assertEquals(CatState.BeggingNight, state)
    }

    private fun at(hour: Int, minute: Int = 0): LocalDateTime =
        LocalDateTime.of(2026, 5, 20, hour, minute)
}
