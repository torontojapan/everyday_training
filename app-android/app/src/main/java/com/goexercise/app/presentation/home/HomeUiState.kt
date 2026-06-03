package com.goexercise.app.presentation.home

import com.goexercise.app.domain.CatDecoration
import com.goexercise.app.domain.CatMessage
import com.goexercise.app.domain.CatState
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.DailyStatusEntry
import com.goexercise.app.domain.LifetimeStatsCalculator
import com.goexercise.app.domain.StreakState
import com.goexercise.app.domain.WeeklyProgress

/**
 * ホーム画面の UI 状態。iOS `HomeViewModel` の公開プロパティのうち、移植済みロジックで
 * 組める範囲(rescue チケット/マイルストーン/運動トレンド集計は後続)。
 */
data class HomeUiState(
    val streak: StreakState = StreakState(0, 0, null),
    val weekStatuses: List<DailyStatusEntry> = emptyList(),
    val weeklyProgress: WeeklyProgress = WeeklyProgress(0, 7),
    val todayStatus: DailyStatus = DailyStatus.TodayPending,
    val catState: CatState = CatState.WaitingMorning,
    val catMessage: CatMessage = CatMessage("🐱", "今日も1分だけやってみよ？"),
    val lifetimeStats: LifetimeStatsCalculator.Stats = LifetimeStatsCalculator.Stats(0, 1),
    val catDecoration: CatDecoration = CatDecoration.None,
)
