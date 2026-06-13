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
                // Rescued(保険チケット救済)も達成同等に連続へ加算(漏らすとフリーズ日で連続が切れる)。
                DailyStatus.Achieved, DailyStatus.Rescued, DailyStatus.TodayAchieved -> streak += 1
                // Rest = カウントしないが連続も切れない。
                // TodayPending = 今日まだ未記録 → 連続を切らずスキップし「昨日までの連続」を数える
                // (今日記録すれば TodayAchieved になり加算される。iOS StreakCalculator と同一挙動)。
                DailyStatus.Rest, DailyStatus.TodayPending -> Unit // skip
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
                // Rest と TodayPending は running を保持して連続を切らない
                // (今日未記録でも昨日までの連続を維持。iOS streakState と同一挙動)。
                DailyStatus.Rest, DailyStatus.TodayPending -> Unit
                else -> running = 0
            }

            cursor = cursor.plusDays(1)
        }

        return StreakState(currentStreak = current, longestStreak = longest, lastAchievedDate = lastAchievedDate)
    }
}
