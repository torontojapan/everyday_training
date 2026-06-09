package com.goexercise.app.domain

import java.time.LocalDate

/**
 * 達成判定。iOS `AchievementEvaluator.swift` の 1:1 移植。
 * **rescuedDates(保険チケット使用日)は achieved 同等**に扱う点が連続記録の肝
 * (渡し忘れると救済日が未達成表示になる再発バグ。必ずスレッドする)。
 */
object AchievementEvaluator {

    fun isAchieved(record: WorkoutRecord): Boolean {
        val hasExercise = record.exercises.isNotEmpty()
        val totalSeconds = record.exercises.sumOf { it.durationSeconds ?: 0 }
        return hasExercise || totalSeconds >= 60
    }

    fun dailyStatus(
        date: LocalDate,
        records: List<WorkoutRecord>,
        restDays: Set<LocalDate>,
        rescuedDates: Set<LocalDate> = emptySet(),
        today: LocalDate,
    ): DailyStatus {
        val day = date
        val dayRecords = records.filter { it.date == day }
        val achieved = dayRecords.any { isAchieved(it) }

        if (day.isAfter(today)) return DailyStatus.Future

        if (day == today) {
            return if (achieved) DailyStatus.TodayAchieved else DailyStatus.TodayPending
        }

        if (achieved) return DailyStatus.Achieved

        // 保険チケット使用日は achieved 同等(連続記録にカウント)。
        if (rescuedDates.contains(day)) return DailyStatus.Achieved

        if (restDays.contains(day)) return DailyStatus.Rest

        return DailyStatus.Missed
    }
}
