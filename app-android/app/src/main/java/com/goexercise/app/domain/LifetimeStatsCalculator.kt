package com.goexercise.app.domain

import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * 累計の達成日数・利用日数・達成率。iOS `LifetimeStatsCalculator.swift` の 1:1 移植。
 */
object LifetimeStatsCalculator {

    data class Stats(
        val achievedDays: Int,
        val usedDays: Int,
    ) {
        val rate: Double
            get() = if (usedDays > 0) achievedDays.toDouble() / usedDays.toDouble() else 0.0
    }

    fun calculate(
        records: List<WorkoutRecord>,
        firstUseDate: LocalDate,
        today: LocalDate,
    ): Stats {
        // 利用日数 = 初回利用日〜今日の inclusive(最低 1)。
        val daysBetween = ChronoUnit.DAYS.between(firstUseDate, today).toInt()
        val usedDays = maxOf(1, daysBetween + 1)

        // 達成日数 = 達成した記録のあるユニーク日数。
        val uniqueAchieved = records
            .filter { AchievementEvaluator.isAchieved(it) }
            .map { it.date }
            .toSet()
            .size

        return Stats(achievedDays = uniqueAchieved, usedDays = usedDays)
    }
}
