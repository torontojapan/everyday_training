package com.goexercise.app.domain

import java.time.LocalDate

/**
 * 週次進捗の計算。iOS `WeeklyProgressCalculator.swift` の 1:1 移植。
 * 週は月曜起点で常に 7 日。rescuedDates を必ず渡す(渡し忘れると週カレンダー/週次進捗
 * だけが救済を無視し、月次カレンダーや streak と食い違う再発バグ [[gotcha_rescued_dates_threading]])。
 */
object WeeklyProgressCalculator {

    fun statuses(
        weekContaining: LocalDate,
        records: List<WorkoutRecord>,
        today: LocalDate,
        rescuedDates: Set<LocalDate> = emptySet(),
        restLimit: Int = 2,
    ): List<DailyStatusEntry> {
        val weekStart = RestDayResolver.weekStart(weekContaining)
        val restDays = RestDayResolver.restDays(weekStart, records, today, restLimit).toSet()

        return RestDayResolver.weekDays(weekStart).map { day ->
            val dayRecords = records.filter { it.date == day }
            val status = AchievementEvaluator.dailyStatus(
                date = day,
                records = records,
                restDays = restDays,
                rescuedDates = rescuedDates,
                today = today,
            )
            DailyStatusEntry(date = day, status = status, recordIds = dayRecords.map { it.id })
        }
    }

    fun progress(statuses: List<DailyStatusEntry>): WeeklyProgress =
        WeeklyProgress(
            achievedCount = statuses.count { it.status.countsAsAchieved },
            totalDays = 7,
        )
}
