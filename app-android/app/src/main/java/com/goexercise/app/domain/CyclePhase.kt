package com.goexercise.app.domain

import java.time.LocalDate

/**
 * 月経周期の 4 相モデル。iOS `CyclePhase` の移植。体重変動の生理的背景を可視化する(黄体期=水分増)。
 * tint は domain を Compose 非依存に保つため ARGB Long(UI 側で Color(tintArgb))。
 */
enum class CyclePhase(val displayName: String, val hint: String, val tintArgb: Long) {
    Menstrual("月経期", "出血のある期間", 0xFFEB7380),
    Follicular("卵胞期", "心身が安定しやすい時期", 0xFF8CC79E),
    Ovulation("排卵期", "中央付近の数日", 0xFFF2C74D),
    Luteal("黄体期", "水分貯留で体重が一時増えやすい", 0xFFC794D9),
}

/**
 * 日付 → 月経周期相の純関数リゾルバ。iOS `CyclePhaseResolver` の移植。LocalDate なので startOfDay 不要。
 * 入力 periodDays = ユーザーが marked した月経日(LocalDate 集合)。28 日サイクル + 排卵窓 13..15 で開始。
 */
object CyclePhaseResolver {

    /** 1 相の区間。endDay は末尾翌日(exclusive)。iOS PhaseSpan。 */
    data class PhaseSpan(val phase: CyclePhase, val startDay: LocalDate, val endDay: LocalDate)

    /**
     * 単一日の相。月経マーク日は無条件で Menstrual。それ以外は直近の period start からの経過日数で推定。
     * 直近 start が無い / cycleLength を 1 周超過なら null(推定不能)。
     */
    fun phase(
        date: LocalDate,
        periodDays: Set<LocalDate>,
        cycleLength: Int = 28,
        periodLength: Int = 5,
        ovulationWindow: IntRange = 13..15,
        sortedStarts: List<LocalDate> = computePeriodStarts(periodDays),
    ): CyclePhase? {
        require(cycleLength >= 14) { "cycleLength は最小 14(生理学的下限)" }
        require(periodLength in 1..(cycleLength / 2)) { "periodLength が異常" }

        if (date in periodDays) return CyclePhase.Menstrual
        val start = binarySearchLatestStart(date, sortedStarts) ?: return null
        val daysSince = java.time.temporal.ChronoUnit.DAYS.between(start, date).toInt()
        if (daysSince < 0 || daysSince >= cycleLength) return null

        return when {
            daysSince < periodLength -> CyclePhase.Menstrual
            daysSince < ovulationWindow.first -> CyclePhase.Follicular
            daysSince in ovulationWindow -> CyclePhase.Ovulation
            else -> CyclePhase.Luteal
        }
    }

    /**
     * [rangeStart, rangeEnd) を相ごとに集約した PhaseSpan(古→新)。連続同相はマージ。null 日は含めない。
     * period starts を 1 回だけ事前計算 → 各日の判定は二分探索 O(N log M)。iOS spans と同型。
     */
    fun spans(
        rangeStart: LocalDate,
        rangeEnd: LocalDate,
        periodDays: Set<LocalDate>,
        cycleLength: Int = 28,
        periodLength: Int = 5,
        ovulationWindow: IntRange = 13..15,
    ): List<PhaseSpan> {
        if (!rangeStart.isBefore(rangeEnd)) return emptyList()
        val sortedStarts = computePeriodStarts(periodDays)
        val result = mutableListOf<PhaseSpan>()
        var cursor = rangeStart
        var currentPhase: CyclePhase? = null
        var currentStart = cursor
        while (cursor.isBefore(rangeEnd)) {
            val p = phase(cursor, periodDays, cycleLength, periodLength, ovulationWindow, sortedStarts)
            if (p != currentPhase) {
                currentPhase?.let { result.add(PhaseSpan(it, currentStart, cursor)) }
                currentPhase = p
                currentStart = cursor
            }
            cursor = cursor.plusDays(1)
        }
        currentPhase?.let { result.add(PhaseSpan(it, currentStart, cursor)) }
        return result
    }

    /** periodDays から連続群の先頭日だけを昇順抽出。iOS computePeriodStarts。 */
    fun computePeriodStarts(periodDays: Set<LocalDate>): List<LocalDate> =
        periodDays.sorted().filter { it.minusDays(1) !in periodDays }

    /** 昇順 starts から target 以下で最大の要素を二分探索。iOS binarySearchLatestStart。 */
    private fun binarySearchLatestStart(target: LocalDate, sortedStarts: List<LocalDate>): LocalDate? {
        var lo = 0
        var hi = sortedStarts.size
        while (lo < hi) {
            val mid = (lo + hi) / 2
            if (!sortedStarts[mid].isAfter(target)) lo = mid + 1 else hi = mid
        }
        return if (lo > 0) sortedStarts[lo - 1] else null
    }
}
