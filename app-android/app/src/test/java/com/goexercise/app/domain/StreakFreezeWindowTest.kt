package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * iOS `StreakFreezeWindow` の純判定層(Decision)移植テスト。
 * statuses[0]=昨日, [1]=一昨日… の順。
 */
class StreakFreezeWindowTest {

    private fun decide(
        statuses: List<DailyStatus>,
        remaining: Int,
        lookback: Int = 4,
    ) = StreakFreezeWindow.Decision.evaluate(statuses, remaining, lookback)

    @Test
    fun singleMissedThenAchieved_revivableWithOneFreeze() {
        val r = decide(listOf(DailyStatus.Missed, DailyStatus.Achieved), remaining = 1)
        assertTrue(r.revivable)
        assertEquals(1, r.freezesNeeded)
        assertEquals(listOf(1), r.missedOffsets)
        assertTrue(r.hasEnough)
    }

    @Test
    fun singleMissed_notEnoughFreezes() {
        val r = decide(listOf(DailyStatus.Missed, DailyStatus.Achieved), remaining = 0)
        assertTrue(r.revivable)
        assertFalse(r.hasEnough)
    }

    @Test
    fun threeMissedThenAchieved_needsThree() {
        val r = decide(
            listOf(DailyStatus.Missed, DailyStatus.Missed, DailyStatus.Missed, DailyStatus.Achieved),
            remaining = 4,
            lookback = 4,
        )
        assertTrue(r.revivable)
        assertEquals(3, r.freezesNeeded)
        assertEquals(listOf(1, 2, 3), r.missedOffsets)
    }

    @Test
    fun fourMissedThenAchieved_atLookbackBoundary_revivable() {
        // offset 1..4 が Missed、offset5(= lookback+1)に達成アンカー → ちょうど猶予枠内で復活可能。
        val r = decide(
            listOf(
                DailyStatus.Missed,
                DailyStatus.Missed,
                DailyStatus.Missed,
                DailyStatus.Missed,
                DailyStatus.Achieved,
            ),
            remaining = 4,
            lookback = 4,
        )
        assertTrue(r.revivable)
        assertEquals(4, r.freezesNeeded)
        assertEquals(listOf(1, 2, 3, 4), r.missedOffsets)
    }

    @Test
    fun fiveMissedThenAchieved_tooOld_notRevivable() {
        // offset5 の Missed が lookback(4)を超える → 猶予枠超過で復活不可。
        val r = decide(
            listOf(
                DailyStatus.Missed,
                DailyStatus.Missed,
                DailyStatus.Missed,
                DailyStatus.Missed,
                DailyStatus.Missed,
                DailyStatus.Achieved,
            ),
            remaining = 5,
            lookback = 4,
        )
        assertFalse(r.revivable)
    }

    @Test
    fun restIsSkipped() {
        val r = decide(listOf(DailyStatus.Missed, DailyStatus.Rest, DailyStatus.Achieved), remaining = 1)
        assertTrue(r.revivable)
        assertEquals(1, r.freezesNeeded)
        assertEquals(listOf(1), r.missedOffsets)
    }

    @Test
    fun noMissed_notRevivable() {
        val r = decide(listOf(DailyStatus.Achieved, DailyStatus.Achieved), remaining = 3)
        assertFalse(r.revivable)
    }

    @Test
    fun allMissedNoAchieved_notRevivable() {
        val r = decide(
            listOf(DailyStatus.Missed, DailyStatus.Missed, DailyStatus.Missed, DailyStatus.Missed),
            remaining = 4,
        )
        assertFalse(r.revivable)
    }

    @Test
    fun restBeforeMissed_offsetTwo() {
        val r = decide(listOf(DailyStatus.Rest, DailyStatus.Missed, DailyStatus.Achieved), remaining = 1)
        assertTrue(r.revivable)
        assertEquals(listOf(2), r.missedOffsets)
    }
}
