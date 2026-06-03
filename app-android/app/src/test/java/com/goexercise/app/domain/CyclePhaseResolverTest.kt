package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** iOS `CyclePhaseResolver` の純関数を移植検証(#9)。28 日サイクル / periodLength 5 / 排卵窓 13..15。 */
class CyclePhaseResolverTest {

    private val start = LocalDate.of(2026, 6, 1) // period start

    private fun periodDays(start: LocalDate, len: Int) = (0 until len).map { start.plusDays(it.toLong()) }.toSet()

    @Test
    fun markedDayIsMenstrual() {
        val marks = periodDays(start, 5)
        assertEquals(CyclePhase.Menstrual, CyclePhaseResolver.phase(start.plusDays(2), marks))
    }

    @Test
    fun phasesByDaysSinceStart() {
        val marks = periodDays(start, 5)
        // day 0..4 月経, 5..12 卵胞, 13..15 排卵, それ以降 黄体
        assertEquals(CyclePhase.Menstrual, CyclePhaseResolver.phase(start.plusDays(4), marks))
        assertEquals(CyclePhase.Follicular, CyclePhaseResolver.phase(start.plusDays(5), marks))
        assertEquals(CyclePhase.Follicular, CyclePhaseResolver.phase(start.plusDays(12), marks))
        assertEquals(CyclePhase.Ovulation, CyclePhaseResolver.phase(start.plusDays(13), marks))
        assertEquals(CyclePhase.Ovulation, CyclePhaseResolver.phase(start.plusDays(15), marks))
        assertEquals(CyclePhase.Luteal, CyclePhaseResolver.phase(start.plusDays(16), marks))
        assertEquals(CyclePhase.Luteal, CyclePhaseResolver.phase(start.plusDays(27), marks))
    }

    @Test
    fun nullBeyondCycleOrBeforeAnyStart() {
        val marks = periodDays(start, 5)
        assertNull(CyclePhaseResolver.phase(start.plusDays(28), marks)) // 1 周超過
        assertNull(CyclePhaseResolver.phase(start.minusDays(1), marks)) // start 前
    }

    @Test
    fun computePeriodStarts_groupsConsecutive() {
        val marks = (periodDays(start, 5) + periodDays(start.plusDays(28), 4))
        assertEquals(listOf(start, start.plusDays(28)), CyclePhaseResolver.computePeriodStarts(marks))
    }

    @Test
    fun spans_mergeConsecutiveAndSkipNull() {
        val marks = periodDays(start, 5)
        val spans = CyclePhaseResolver.spans(start, start.plusDays(28), marks)
        // 月経→卵胞→排卵→黄体 の 4 区間(連続同相はマージ)。
        assertEquals(listOf(CyclePhase.Menstrual, CyclePhase.Follicular, CyclePhase.Ovulation, CyclePhase.Luteal), spans.map { it.phase })
        assertEquals(start, spans.first().startDay)
        assertTrue(spans.last().endDay.isAfter(spans.first().startDay))
    }
}
