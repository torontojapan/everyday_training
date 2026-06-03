package com.goexercise.app.domain

import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 体重記録。iOS `WeightEntry`(@Model)の移植。同一日に複数記録できるよう `recordedAt`(壁時計)を持ち、
 * 「日内最新」は recordedAt が最大の 1 件。日付グルーピングは `date`(= recordedAt.toLocalDate())。
 */
data class WeightEntry(
    val id: String,
    val recordedAt: LocalDateTime,
    val weightKg: Double,
    val memo: String? = null,
    val createdAtMillis: Long = 0L,
) {
    val date: LocalDate get() = recordedAt.toLocalDate()
}

/** 7 日移動平均などのトレンド点。iOS `WeightTrendPoint`。 */
data class WeightTrendPoint(val date: LocalDate, val average: Double)

/** 期間統計。iOS `WeightStore.WeightStats`。change = 最新 - 最古(正=増)。 */
data class WeightStats(
    val min: Double,
    val max: Double,
    val average: Double,
    val change: Double,
    val entryCount: Int,
)

/** グラフ期間。iOS `WeightStore.ChartPeriod`。 */
enum class ChartPeriod(val shortLabel: String, val days: Int?) {
    Week("1週", 7),
    Month("1月", 30),
    ThreeMonths("3月", 90),
    SixMonths("半年", 180),
    All("全期間", null),
}

/**
 * 体重の集計・トレンド・予測(純粋)。iOS `WeightStore` の計算部を移植。入力は **date 降順ソート済み**の
 * entries(= repository が観測順で渡す)。Room/SwiftData 非依存にし unit test で全網羅する。
 */
object WeightAnalytics {

    /**
     * 期間内エントリを「日内最新」で集約(新→古)。同一日複数記録はその日の最新 recordedAt 1 件のみ。
     * 「直近 N 日」= 今日含む N 日 → 下限 = today-(N-1)。未来日は除外。iOS chartEntries と同型。
     */
    fun dailyLatest(entries: List<WeightEntry>, period: ChartPeriod, today: LocalDate): List<WeightEntry> {
        val lowerBound = period.days?.let { today.minusDays((it - 1).toLong()) }
        // 新→古に並べ(recordedAt 降順)、各日の最初(=最新時刻)だけ採用。
        val sorted = entries.sortedByDescending { it.recordedAt }
        val seenDays = mutableSetOf<LocalDate>()
        val result = mutableListOf<WeightEntry>()
        for (e in sorted) {
            val d = e.date
            if (d.isAfter(today)) continue // 未来日除外
            if (lowerBound != null && d.isBefore(lowerBound)) continue
            if (seenDays.add(d)) result.add(e)
        }
        return result
    }

    /** 期間の体重統計(日内最新ベース)。0 件なら null。iOS stats。 */
    fun stats(entries: List<WeightEntry>, period: ChartPeriod, today: LocalDate): WeightStats? {
        val daily = dailyLatest(entries, period, today) // 新→古
        val latest = daily.firstOrNull() ?: return null
        val oldest = daily.last()
        val values = daily.map { it.weightKg }
        return WeightStats(
            min = values.min(),
            max = values.max(),
            average = values.sum() / values.size,
            change = latest.weightKg - oldest.weightKg, // 最新 - 最古
            entryCount = daily.size,
        )
    }

    /**
     * 7 日移動平均トレンド(古→新)。各 anchor 日について trailing window 日の日内最新を平均。
     * 窓内 minSamples 未満はスキップ。iOS trendline と同型。
     */
    fun trendline(
        entries: List<WeightEntry>,
        period: ChartPeriod,
        today: LocalDate,
        window: Int = 7,
        minSamples: Int = 2,
    ): List<WeightTrendPoint> {
        require(window >= 1)
        require(minSamples >= 1)
        val daily = dailyLatest(entries, period, today).reversed() // 古→新
        val days = daily.map { it.date }
        val weights = daily.map { it.weightKg }
        val result = mutableListOf<WeightTrendPoint>()
        for (i in daily.indices) {
            val anchor = days[i]
            val windowStart = anchor.minusDays((window - 1).toLong())
            var sum = 0.0
            var count = 0
            var j = i
            while (j >= 0) {
                if (days[j].isBefore(windowStart)) break
                sum += weights[j]
                count++
                j--
            }
            if (count >= minSamples) result.add(WeightTrendPoint(anchor, sum / count))
        }
        return result
    }

    /**
     * 7 日移動平均トレンドから目標到達までの概算日数を線形外挿。iOS forecastDaysToTarget。
     * null: 目標/最新未設定 / trend 2 点未満 / 傾きが目標と逆 or 微小 / 365 日超。目標圏内なら 0。
     */
    fun forecastDaysToTarget(
        entries: List<WeightEntry>,
        targetKg: Double?,
        today: LocalDate,
        analysisPeriod: ChartPeriod = ChartPeriod.Month,
        minSlopeKgPerDay: Double = 0.005,
        maxDays: Int = 365,
    ): Int? {
        if (targetKg == null) return null
        val latestRaw = dailyLatest(entries, ChartPeriod.All, today).firstOrNull()?.weightKg ?: return null
        if (kotlin.math.abs(targetKg - latestRaw) < 0.05) return 0

        val trend = trendline(entries, analysisPeriod, today, window = 7, minSamples = 2)
        if (trend.size < 2) return null
        val first = trend.first()
        val last = trend.last()
        val baseline = last.average
        val delta = targetKg - baseline
        if (kotlin.math.abs(delta) < 0.05) return 0

        val dayDiff = java.time.temporal.ChronoUnit.DAYS.between(first.date, last.date).toInt()
        if (dayDiff <= 0) return null
        val slope = (last.average - first.average) / dayDiff
        if (delta > 0 && slope <= minSlopeKgPerDay) return null
        if (delta < 0 && slope >= -minSlopeKgPerDay) return null

        val days = delta / slope
        if (!days.isFinite() || days <= 0) return null
        val rounded = maxOf(1, Math.round(days).toInt())
        return if (rounded <= maxDays) rounded else null
    }

    /** BMI(身長 cm + 体重 kg)。iOS と同式。身長未設定なら null。 */
    fun bmi(weightKg: Double?, heightCm: Double?): Double? {
        if (weightKg == null || heightCm == null || heightCm <= 0) return null
        val m = heightCm / 100.0
        return weightKg / (m * m)
    }
}
