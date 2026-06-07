package com.goexercise.app.domain

import java.time.LocalDate

/**
 * フリーズ復活で「守られる連続日数」を求める純粋ロジック(iOS `HomeViewModel.restoredStreakLength` ミラー)。
 *
 * Missed を rescued 扱い(橋渡し)にした上で、起点から後方へ Achieved/TodayAchieved を数える
 * (Rest はスキップ=連続を切らないが加算もしない、それ以外で打ち切り)。
 *
 * 起点(anchor)の決め方:
 * - 今日が既に達成済み(TodayAchieved)なら **今日起点**。橋渡し後は今日が連続の先端になるため、
 *   今日 + 橋渡しした gap + 手前を全部数える。最新 Missed 起点だと今日達成分を取りこぼす(3LLM監査)。
 * - 今日未達成(TodayPending)なら最新 Missed 日起点(今日を起点にすると TodayPending で即 0 になる)。
 *
 * VM 非依存(Hilt なし)で JVM ユニットテスト可能。
 */
object RestoredStreakCalculator {

    fun restoredStreakLength(
        records: List<WorkoutRecord>,
        rescued: Set<LocalDate>,
        missedOffsets: List<Int>,
        today: LocalDate,
    ): Int {
        val missedDates = StreakFreezeWindow.missedDatesForOffsets(missedOffsets, today)
        val effectiveRescued = rescued + missedDates
        // 今日のステータスを先に確定し、達成済みなら今日を起点にする(取りこぼし防止)。
        val todayStatus = AchievementEvaluator.dailyStatus(
            date = today,
            records = records,
            restDays = RestDayResolver.restDaySet(today, records, today),
            rescuedDates = effectiveRescued,
            today = today,
        )
        val start = if (todayStatus == DailyStatus.TodayAchieved) {
            today
        } else {
            missedDates.maxOrNull() ?: return 0
        }
        var count = 0
        var date = start
        while (true) {
            val restDays = RestDayResolver.restDaySet(date, records, today)
            val status = AchievementEvaluator.dailyStatus(
                date = date,
                records = records,
                restDays = restDays,
                rescuedDates = effectiveRescued,
                today = today,
            )
            when (status) {
                DailyStatus.Achieved, DailyStatus.TodayAchieved -> count += 1
                DailyStatus.Rest -> { /* skip — 連続は切れない、カウントもしない */ }
                else -> break
            }
            date = date.minusDays(1)
        }
        return count
    }
}
