package com.goexercise.app.domain

import java.time.DayOfWeek
import java.time.LocalDate

/**
 * 週ごとの自動休息日の解決。iOS `RestDayResolver.swift` の移植。
 * iOS の `Calendar.mondayFirst`(firstWeekday=2, minimumDaysInFirstWeek=4)は
 * ISO-8601 週(月曜始まり)と一致するため、週の起点は月曜に丸める。
 *
 * ルール: 週内で「today 以前 かつ 未達成」の日を先頭から最大 `limit`(既定2)日まで休息扱い。
 */
object RestDayResolver {

    /** その日付を含む週の月曜。 */
    fun weekStart(date: LocalDate): LocalDate =
        date.minusDays((date.dayOfWeek.value - DayOfWeek.MONDAY.value).toLong())

    private fun daysInWeek(weekStart: LocalDate): List<LocalDate> =
        (0L until 7L).map { weekStart.plusDays(it) }

    fun restDays(
        weekStart: LocalDate,
        records: List<WorkoutRecord>,
        today: LocalDate,
        limit: Int = 2,
    ): List<LocalDate> {
        if (limit <= 0) return emptyList()

        val weekEnd = weekStart.plusDays(7) // exclusive (iOS DateInterval [start, end))
        val achievedDays = records
            .filter { !it.date.isBefore(weekStart) && it.date.isBefore(weekEnd) && AchievementEvaluator.isAchieved(it) }
            .map { it.date }
            .toSet()

        val candidates = daysInWeek(weekStart).filter { day ->
            !day.isAfter(today) && !achievedDays.contains(day)
        }

        return candidates.take(limit)
    }

    fun restDaySet(
        date: LocalDate,
        records: List<WorkoutRecord>,
        today: LocalDate,
        limit: Int = 2,
    ): Set<LocalDate> =
        restDays(weekStart(date), records, today, limit).toSet()
}
