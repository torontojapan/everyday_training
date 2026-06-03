package com.goexercise.app.domain

import java.time.LocalDate

/**
 * 連続記録の計算。iOS `StreakCalculator.swift` の 1:1 移植。
 * 休息日(Rest)は連続記録を**途切れさせずスキップ**する(カウントもしない)。
 * rescuedDates は AchievementEvaluator 経由で achieved 扱いになる。
 */
object StreakCalculator {

    fun currentStreak(
        records: List<WorkoutRecord>,
        today: LocalDate,
        rescuedDates: Set<LocalDate> = emptySet(),
        restLimit: Int = 2,
    ): Int {
        var streak = 0
        var cursor = today

        while (true) {
            val restDays = RestDayResolver.restDaySet(cursor, records, today, restLimit)
            val status = AchievementEvaluator.dailyStatus(
                date = cursor,
                records = records,
                restDays = restDays,
                rescuedDates = rescuedDates,
                today = today,
            )

            when (status) {
                DailyStatus.Achieved, DailyStatus.TodayAchieved -> streak += 1
                DailyStatus.Rest -> Unit // skip — カウントしないが連続も切れない
                else -> return streak
            }

            cursor = cursor.minusDays(1)
        }
    }

    fun streakState(
        records: List<WorkoutRecord>,
        today: LocalDate,
        rescuedDates: Set<LocalDate> = emptySet(),
        lookbackDays: Long = 365,
        restLimit: Int = 2,
    ): StreakState {
        val current = currentStreak(records, today, rescuedDates, restLimit)
        var longest = 0
        var running = 0
        var lastAchievedDate: LocalDate? = null

        var cursor = today.minusDays(lookbackDays)
        while (!cursor.isAfter(today)) {
            val restDays = RestDayResolver.restDaySet(cursor, records, today, restLimit)
            val status = AchievementEvaluator.dailyStatus(
                date = cursor,
                records = records,
                restDays = restDays,
                rescuedDates = rescuedDates,
                today = today,
            )

            when (status) {
                DailyStatus.Achieved, DailyStatus.TodayAchieved -> {
                    running += 1
                    longest = maxOf(longest, running)
                    lastAchievedDate = cursor
                }
                DailyStatus.Rest -> Unit // running 保持
                else -> running = 0
            }

            cursor = cursor.plusDays(1)
        }

        return StreakState(currentStreak = current, longestStreak = longest, lastAchievedDate = lastAchievedDate)
    }
}
