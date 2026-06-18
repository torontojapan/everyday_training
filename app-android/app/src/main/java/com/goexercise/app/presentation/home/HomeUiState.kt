package com.goexercise.app.presentation.home

import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.CatDecoration
import com.goexercise.app.domain.CatMessage
import com.goexercise.app.domain.CatState
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.DailyStatusEntry
import com.goexercise.app.domain.ExerciseTrendSummary
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
    val catBreed: CatBreed = CatBreed.Default,
    val catMessage: CatMessage = CatMessage("🐱", "今日も1分だけやってみよ？"),
    val lifetimeStats: LifetimeStatsCalculator.Stats = LifetimeStatsCalculator.Stats(0, 1),
    val catDecoration: CatDecoration = CatDecoration.None,
    val todaySummary: ExerciseTrendSummary.DailySummary = ExerciseTrendSummary.DailySummary(emptyMap(), 0, 0),
    val weeklySummary: ExerciseTrendSummary.WeeklySummary = ExerciseTrendSummary.WeeklySummary(emptyList(), 0, emptyList()),
    /** 当月の運動時間合計(分)と達成日数。友達バックエンドの月次ランキング用(iOS パリティ)。 */
    val monthlyTotalMinutes: Int = 0,
    val monthlyAchievedDays: Int = 0,
    /** 復帰日の歓迎カード表示フラグ(昨日 missed・今日未達成・累計>=3日)。iOS isComebackToday パリティ。 */
    val isComebackToday: Boolean = false,
)

/** ホーム上段3行目の紹介スター行の表示データ。iOS `ReferralStarsRow(count:friendCode:)` 引数に対応。 */
data class ReferralRowUi(
    val stars: Int,
    val friendCode: String,
)
