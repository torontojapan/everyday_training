package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime

/** iOS `WeightStore` の集計/トレンド/予測を移植検証(#9)。 */
class WeightAnalyticsTest {

    private val today = LocalDate.of(2026, 6, 3)

    private fun e(date: LocalDate, kg: Double, time: LocalTime = LocalTime.NOON, id: String = "$date-$kg"): WeightEntry =
        WeightEntry(id = id, recordedAt = LocalDateTime.of(date, time), weightKg = kg)

    @Test
    fun dailyLatest_keepsLatestPerDay_andFiltersFuture() {
        val entries = listOf(
            e(today, 64.0, LocalTime.of(8, 0)),
            e(today, 63.5, LocalTime.of(22, 0)), // 同日で最新 → これが残る
            e(today.minusDays(1), 65.0),
            e(today.plusDays(1), 99.0), // 未来 → 除外
        )
        val daily = WeightAnalytics.dailyLatest(entries, ChartPeriod.All, today)
        assertEquals(listOf(63.5, 65.0), daily.map { it.weightKg }) // 新→古, 同日は 22:00 の 63.5
    }

    @Test
    fun dailyLatest_periodWindow() {
        val entries = (0..40L).map { e(today.minusDays(it), 70.0 + it) }
        val week = WeightAnalytics.dailyLatest(entries, ChartPeriod.Week, today)
        assertEquals(7, week.size) // 今日含む 7 日
        assertEquals(today, week.first().date)
        assertEquals(today.minusDays(6), week.last().date)
    }

    @Test
    fun stats_minMaxAvgChange() {
        val entries = listOf(e(today, 64.0), e(today.minusDays(1), 66.0), e(today.minusDays(2), 65.0))
        val s = WeightAnalytics.stats(entries, ChartPeriod.Month, today)!!
        assertEquals(64.0, s.min, 1e-9)
        assertEquals(66.0, s.max, 1e-9)
        assertEquals(65.0, s.average, 1e-9)
        assertEquals(-1.0, s.change, 1e-9) // 最新64 - 最古65
        assertEquals(3, s.entryCount)
    }

    @Test
    fun stats_emptyIsNull() {
        assertNull(WeightAnalytics.stats(emptyList(), ChartPeriod.Month, today))
    }

    @Test
    fun trendline_movingAverage_skipsBelowMinSamples() {
        // 連続 5 日, window 3, minSamples 2 → 初日は 1 サンプルで skip、2 日目以降出る。
        val entries = (0..4L).map { e(today.minusDays(it), 70.0 + it) } // today=70, -1=71 ...
        val trend = WeightAnalytics.trendline(entries, ChartPeriod.All, today, window = 3, minSamples = 2)
        assertEquals(4, trend.size) // 5 日のうち初日(最古)skip
        assertTrue(trend.first().date.isBefore(trend.last().date)) // 古→新
    }

    @Test
    fun forecast_nullWhenNoTarget() {
        val entries = listOf(e(today, 70.0), e(today.minusDays(10), 72.0))
        assertNull(WeightAnalytics.forecastDaysToTarget(entries, targetKg = null, today = today))
    }

    @Test
    fun forecast_zeroWhenWithinTarget() {
        val entries = listOf(e(today, 70.0))
        assertEquals(0, WeightAnalytics.forecastDaysToTarget(entries, targetKg = 70.02, today = today))
    }

    @Test
    fun forecast_estimatesDaysWhenLosing() {
        // 0.1kg/日で減量中, 目標まで -2kg → 約 20 日。
        val entries = (0..20L).map { e(today.minusDays(it), 70.0 + it * 0.1) } // today=70, -20=72
        val days = WeightAnalytics.forecastDaysToTarget(entries, targetKg = 68.0, today = today)
        assertTrue("expected positive forecast, got $days", days != null && days in 10..40)
    }

    @Test
    fun bmi() {
        assertEquals(22.86, WeightAnalytics.bmi(70.0, 175.0)!!, 0.01)
        assertNull(WeightAnalytics.bmi(70.0, null))
    }
}
