package com.goexercise.app.domain

import java.time.LocalDate

/**
 * 今日/今週の運動トレンド集計。iOS `ExerciseTrendSummary.swift` の 1:1 移植。
 * 週は月曜始まり。topExerciseNames の同数 tiebreak は名前昇順(iOS は localizedStandardCompare、
 * ここでは決定的順序として自然比較を使う = ローカル表示用なので厳密一致は要件外)。
 */
object ExerciseTrendSummary {

    data class DailySummary(
        val categoryCounts: Map<WorkoutCategory, Int>,
        val exerciseCount: Int,
        val totalDurationSeconds: Int,
    ) {
        val hasExerciseData: Boolean get() = exerciseCount > 0
    }

    data class WeeklySummary(
        val usedCategories: List<WorkoutCategory>,
        val totalDurationSeconds: Int,
        val topExerciseNames: List<String>,
    ) {
        val hasExerciseData: Boolean
            get() = usedCategories.isNotEmpty() || totalDurationSeconds > 0 || topExerciseNames.isNotEmpty()

        val totalMinutes: Int get() = totalDurationSeconds / 60
    }

    fun today(records: List<WorkoutRecord>, today: LocalDate): DailySummary =
        dailySummary(records.filter { it.date == today })

    fun week(records: List<WorkoutRecord>, weekContaining: LocalDate): WeeklySummary {
        val weekStart = RestDayResolver.weekStart(weekContaining)
        val weekEnd = weekStart.plusDays(7)
        val matching = records.filter { !it.date.isBefore(weekStart) && it.date.isBefore(weekEnd) }

        val usedSet = matching.map { it.category }.toSet()
        val usedCategories = WorkoutCategory.entries.filter { it in usedSet }
        val totalDurationSeconds = matching.flatMap { it.exercises }.mapNotNull { it.durationSeconds }.sum()

        val nameCounts = matching
            .flatMap { it.exercises }
            .map { it.name.trim() }
            .filter { it.isNotEmpty() }
            .groupingBy { it }
            .eachCount()
        val topExerciseNames = nameCounts.entries
            .sortedWith(compareByDescending<Map.Entry<String, Int>> { it.value }.thenBy { it.key })
            .take(3)
            .map { it.key }

        return WeeklySummary(usedCategories, totalDurationSeconds, topExerciseNames)
    }

    private fun dailySummary(records: List<WorkoutRecord>): DailySummary {
        val categoryCounts = records.groupingBy { it.category }.eachCount()
        val exercises = records.flatMap { it.exercises }
        val totalDurationSeconds = exercises.mapNotNull { it.durationSeconds }.sum()
        return DailySummary(categoryCounts, exercises.size, totalDurationSeconds)
    }
}
