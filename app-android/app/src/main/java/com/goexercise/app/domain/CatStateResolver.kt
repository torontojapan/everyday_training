package com.goexercise.app.domain

import java.time.LocalDateTime

/**
 * 今日の状態・時刻から猫の表示状態を決める。iOS `CatStateResolver.swift` の 1:1 移植。
 * 優先順位: streakExtended > 達成(celebrating) > 休息(resting) > 昨日未達成の復帰応援(encouraging)
 * > 時間帯(朝待機/昼心配/夜おねだり)。`now` は時刻判定にだけ使うので LocalDateTime で受ける。
 */
object CatStateResolver {
    fun resolve(
        todayStatus: DailyStatus,
        now: LocalDateTime,
        yesterdayAchieved: Boolean,
        streakExtendedThisRun: Boolean,
    ): CatState {
        if (streakExtendedThisRun) return CatState.StreakExtended

        if (todayStatus == DailyStatus.TodayAchieved || todayStatus == DailyStatus.Achieved) {
            return CatState.Celebrating
        }

        if (todayStatus == DailyStatus.Rest) return CatState.Resting

        if (todayStatus == DailyStatus.TodayPending && !yesterdayAchieved) {
            return CatState.Encouraging
        }

        return when (now.hour) {
            in 0 until 12 -> CatState.WaitingMorning
            in 12 until 18 -> CatState.WorriedNoon
            else -> CatState.BeggingNight
        }
    }
}
