package com.goexercise.app.domain

import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.Locale

/**
 * ハイライト共有カード(Weekly / Monthly / All-time)の集計。iOS `MonthlyReviewBuilder.swift` の移植。
 * 期間内の達成日数・最長連続・合計時間・種目数・イチオシのカテゴリ/推し種目を算出する。
 * 最長連続は正本 [StreakCalculator]/[AchievementEvaluator] と同じ判定(rest 日・rescued 日は連続を橋渡し)。
 */
object MonthlyReviewBuilder {

    /** 期間ラベル(月: "2026年5月" / 週: "5/26 - 6/1" / 累計: "通算 365日")。 */
    data class Review(
        val periodLabel: String,
        val achievedDays: Int,
        val totalDays: Int,
        /** 期間内の最長連続達成日数(月/週/累計いずれもこのフィールド)。 */
        val longestStreak: Int,
        val totalDurationMinutes: Int,
        val totalExerciseCount: Int,
        val topCategory: WorkoutCategory?,
        val topExerciseName: String?,
    )

    // MARK: - 月次

    fun build(
        records: List<WorkoutRecord>,
        month: LocalDate,
        today: LocalDate,
        rescuedDates: Set<LocalDate> = emptySet(),
    ): Review {
        val ym = YearMonth.from(month)
        val monthStart = ym.atDay(1)
        val monthEnd = ym.atEndOfMonth()
        val label = monthLabel(monthStart)
        val scoped = records.filter { !it.date.isBefore(monthStart) && !it.date.isAfter(monthEnd) }
        return buildCore(
            scoped = scoped, allRecords = records,
            rangeStart = monthStart, rangeEnd = monthEnd,
            today = today, rescuedDates = rescuedDates,
            label = label, totalDays = ym.lengthOfMonth(),
        )
    }

    // MARK: - 週次

    fun weekly(
        records: List<WorkoutRecord>,
        weekContaining: LocalDate,
        today: LocalDate,
        rescuedDates: Set<LocalDate> = emptySet(),
    ): Review {
        val weekStart = RestDayResolver.weekStart(weekContaining)
        val weekEnd = weekStart.plusDays(6)
        val scoped = records.filter { !it.date.isBefore(weekStart) && !it.date.isAfter(weekEnd) }
        return buildCore(
            scoped = scoped, allRecords = records,
            rangeStart = weekStart, rangeEnd = weekEnd,
            today = today, rescuedDates = rescuedDates,
            label = weekLabel(weekStart, weekEnd), totalDays = 7,
        )
    }

    // MARK: - 累計

    fun lifetime(
        records: List<WorkoutRecord>,
        today: LocalDate,
        rescuedDates: Set<LocalDate> = emptySet(),
    ): Review {
        val firstRecordDay = records.minByOrNull { it.date }?.date
        // 走査開始は記録と救済の両最古日(救済日が初記録より前にある履歴も連続として拾う)。iOS F4/P2 と同じ。
        val firstRescuedDay = rescuedDates.minOrNull()
        val rangeStart = listOfNotNull(firstRecordDay, firstRescuedDay).minOrNull() ?: today
        val totalDays = if (firstRecordDay == null && firstRescuedDay == null) {
            0
        } else {
            ChronoUnit.DAYS.between(rangeStart, today).toInt() + 1
        }
        return buildCore(
            scoped = records, allRecords = records,
            rangeStart = rangeStart, rangeEnd = today,
            today = today, rescuedDates = rescuedDates,
            label = "通算 ${totalDays}日", totalDays = totalDays,
        )
    }

    // MARK: - 共通コア

    private fun buildCore(
        scoped: List<WorkoutRecord>,
        allRecords: List<WorkoutRecord>,
        rangeStart: LocalDate,
        rangeEnd: LocalDate,
        today: LocalDate,
        rescuedDates: Set<LocalDate>,
        restLimit: Int = 2,
        label: String,
        totalDays: Int,
    ): Review {
        // 集計対象は [rangeStart, min(rangeEnd, today)]。未来日付の記録は数えない
        // (通常フローでは未来日の記録は作られないので iOS と実データ同一。防御的にクランプ)。
        val clampEnd = minOf(rangeEnd, today)
        val effectiveScoped = scoped.filter { !it.date.isAfter(clampEnd) }
        val achievedDates = effectiveScoped.filter { AchievementEvaluator.isAchieved(it) }.map { it.date }.toMutableSet()
        // フリーズ救済日も達成として数える(同じ範囲内)。iOS F4。
        rescuedDates.filter { !it.isBefore(rangeStart) && !it.isAfter(clampEnd) }.forEach { achievedDates.add(it) }

        val longestStreak = longestConsecutiveBridged(
            records = allRecords, from = rangeStart, to = rangeEnd,
            today = today, rescuedDates = rescuedDates, restLimit = restLimit,
        )

        val allExercises = effectiveScoped.flatMap { it.exercises }
        val totalDurationMinutes = allExercises.mapNotNull { it.durationSeconds }.sum() / 60
        val totalExerciseCount = allExercises.size

        // 種目ごとのカテゴリで集計(複数カテゴリ記録を正しく扱う。旧データは記録の category)。
        val categoryCounts = mutableMapOf<WorkoutCategory, Int>()
        for (record in effectiveScoped) {
            for (item in record.exercises) {
                val cat = item.category ?: record.category
                categoryCounts[cat] = (categoryCounts[cat] ?: 0) + 1
            }
        }
        val topCategory = categoryCounts.maxByOrNull { it.value }?.key

        val exerciseNameCounts = mutableMapOf<String, Int>()
        for (item in allExercises) {
            val name = item.name.trim()
            if (name.isEmpty()) continue
            exerciseNameCounts[name] = (exerciseNameCounts[name] ?: 0) + 1
        }
        val topExerciseName = exerciseNameCounts.maxByOrNull { it.value }?.key

        return Review(
            periodLabel = label,
            achievedDays = achievedDates.size,
            totalDays = totalDays,
            longestStreak = longestStreak,
            totalDurationMinutes = totalDurationMinutes,
            totalExerciseCount = totalExerciseCount,
            topCategory = topCategory,
            topExerciseName = topExerciseName,
        )
    }

    // MARK: - Helpers

    private fun monthLabel(date: LocalDate): String =
        date.format(DateTimeFormatter.ofPattern("yyyy年M月", Locale.JAPAN))

    private fun weekLabel(start: LocalDate, end: LocalDate): String {
        val f = DateTimeFormatter.ofPattern("M/d", Locale.JAPAN)
        return "${start.format(f)} - ${end.format(f)}"
    }

    /**
     * 期間内の最長連続達成日数。正本 [StreakCalculator] と同じ判定で、自動休養(rest)日と
     * フリーズ救済日は連続を切らず橋渡しする。範囲は [rangeStart, min(rangeEnd, today)]。
     */
    private fun longestConsecutiveBridged(
        records: List<WorkoutRecord>,
        from: LocalDate,
        to: LocalDate,
        today: LocalDate,
        rescuedDates: Set<LocalDate>,
        restLimit: Int,
    ): Int {
        val start = from
        val end = minOf(to, today) // 未来日は連続に寄与しない
        if (start.isAfter(end)) return 0

        var longest = 0
        var running = 0
        var cursor = start
        while (!cursor.isAfter(end)) {
            val restDays = RestDayResolver.restDaySet(cursor, records, today, restLimit)
            val status = AchievementEvaluator.dailyStatus(
                date = cursor, records = records, restDays = restDays,
                rescuedDates = rescuedDates, today = today,
            )
            when (status) {
                DailyStatus.Achieved, DailyStatus.TodayAchieved, DailyStatus.Rescued -> {
                    running += 1
                    longest = maxOf(longest, running)
                }
                DailyStatus.Rest, DailyStatus.TodayPending -> {
                    // skip — 連続を切らず running を保つ(rest の橋渡し)
                }
                else -> running = 0
            }
            cursor = cursor.plusDays(1)
        }
        return longest
    }
}
