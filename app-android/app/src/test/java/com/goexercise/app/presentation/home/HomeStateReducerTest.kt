package com.goexercise.app.presentation.home

import com.goexercise.app.domain.CatDecoration
import com.goexercise.app.domain.CatState
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.ExerciseItem
import com.goexercise.app.domain.WorkoutCategory
import com.goexercise.app.domain.WorkoutRecord
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * HomeStateReducer(純粋関数)の検証。移植済みロジックが正しく束ねられていることを
 * coroutine 無しで確認する(VM 自体は配線のみ)。
 */
class HomeStateReducerTest {

    private fun record(day: Int): WorkoutRecord =
        WorkoutRecord(date = LocalDate.of(2026, 5, day), category = WorkoutCategory.Strength, exercises = listOf(ExerciseItem(name = "運動")))

    @Test
    fun emptyRecordsGivesPendingTodayAndZeroStreak() {
        val now = LocalDateTime.of(2026, 5, 20, 9, 0)
        val state = HomeStateReducer.reduce(records = emptyList(), now = now)

        assertEquals(0, state.streak.currentStreak)
        assertEquals(DailyStatus.TodayPending, state.todayStatus)
        assertEquals(7, state.weekStatuses.size)
        assertEquals(CatDecoration.None, state.catDecoration)
    }

    @Test
    fun todayRecordGivesTodayAchievedAndCelebratingCat() {
        val now = LocalDateTime.of(2026, 5, 20, 9, 0)
        val state = HomeStateReducer.reduce(records = listOf(record(20), record(19)), now = now)

        assertEquals(DailyStatus.TodayAchieved, state.todayStatus)
        assertEquals(CatState.Celebrating, state.catState)
        assertEquals(2, state.streak.currentStreak)
        assertTrue(state.catMessage.text.isNotBlank())
    }

    @Test
    fun morningPendingWithYesterdayAchievedShowsWaitingCat() {
        // 昨日(19)達成済み・今日(20)未記録・朝9時 → WaitingMorning
        val now = LocalDateTime.of(2026, 5, 20, 9, 0)
        val state = HomeStateReducer.reduce(records = listOf(record(19)), now = now)

        assertEquals(DailyStatus.TodayPending, state.todayStatus)
        assertEquals(CatState.WaitingMorning, state.catState)
    }

    // 2026-05-24 は日曜。週(月18..日24)で 5/18,19 が自動休養枠(先頭2日)、5/20-23 は missed に
    // なるため、昨日(土 5/23)は確実に missed。これで復帰条件を曖昧さ無く再現する。
    @Test
    fun comebackToday_whenYesterdayMissedAndStreakBrokenWith3PlusAchieved() {
        val now = LocalDateTime.of(2026, 5, 24, 9, 0)
        val records = listOf(record(1), record(2), record(3)) // 累計3日達成 → 以降ずっと欠け
        val state = HomeStateReducer.reduce(records = records, now = now, firstUseDate = LocalDate.of(2026, 5, 1))

        assertTrue(state.isComebackToday)
    }

    @Test
    fun notComeback_whenFewerThan3Achieved() {
        // 累計2日では復帰カードを出さない(三日坊主の閾値=3)。
        val now = LocalDateTime.of(2026, 5, 24, 9, 0)
        val records = listOf(record(1), record(2))
        val state = HomeStateReducer.reduce(records = records, now = now, firstUseDate = LocalDate.of(2026, 5, 1))

        assertEquals(false, state.isComebackToday)
    }

    @Test
    fun notComeback_whenTodayAchieved() {
        // 今日記録済みなら復帰カードは出さない。
        val now = LocalDateTime.of(2026, 5, 24, 9, 0)
        val records = listOf(record(1), record(2), record(3), record(24))
        val state = HomeStateReducer.reduce(records = records, now = now, firstUseDate = LocalDate.of(2026, 5, 1))

        assertEquals(false, state.isComebackToday)
    }

    @Test
    fun lifetimeAchievedDaysDriveDecoration() {
        // 7 ユニーク達成日 → Bandana(7..29)
        val now = LocalDateTime.of(2026, 5, 31, 10, 0)
        val records = (1..7).map { record(it) }
        val state = HomeStateReducer.reduce(records = records, now = now)

        assertEquals(7, state.lifetimeStats.achievedDays)
        assertEquals(CatDecoration.Bandana, state.catDecoration)
    }
}
