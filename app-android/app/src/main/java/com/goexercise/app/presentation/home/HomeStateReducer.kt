package com.goexercise.app.presentation.home

import com.goexercise.app.domain.AchievementEvaluator
import com.goexercise.app.domain.CatDecoration
import com.goexercise.app.domain.CatMessageProvider
import com.goexercise.app.domain.CatStateResolver
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.ExerciseTrendSummary
import com.goexercise.app.domain.LifetimeStatsCalculator
import com.goexercise.app.domain.RestDayResolver
import com.goexercise.app.domain.StreakCalculator
import com.goexercise.app.domain.WeeklyProgressCalculator
import com.goexercise.app.domain.WorkoutRecord
import java.time.LocalDateTime

/**
 * 記録リスト + 現在時刻から [HomeUiState] を組み立てる**純粋関数**。
 * 移植済みドメインロジック(streak / 週次 / 達成 / 猫状態 / lifetime / 装飾)を 1 箇所に束ねる。
 * 純粋に保つことで coroutine 無しで単体テストでき、iOS HomeViewModel.refresh の集計と対応づく。
 *
 * 未対応(後続フェーズ): rescuedDates(保険チケット), streakExtendedThisRun, マイルストーン,
 * 運動トレンド集計(today/week summary)。現状 rescuedDates は空で計算する。
 */
object HomeStateReducer {

    fun reduce(
        records: List<WorkoutRecord>,
        now: LocalDateTime,
        rescuedDates: Set<java.time.LocalDate> = emptySet(),
    ): HomeUiState {
        val today = now.toLocalDate()

        val weekStatuses = WeeklyProgressCalculator.statuses(
            weekContaining = today, records = records, today = today, rescuedDates = rescuedDates,
        )
        val weeklyProgress = WeeklyProgressCalculator.progress(weekStatuses)
        val streak = StreakCalculator.streakState(records, today, rescuedDates)
        val todayStatus = weekStatuses.firstOrNull { it.date == today }?.status ?: DailyStatus.TodayPending

        val firstUse = records.minByOrNull { it.date }?.date ?: today
        val lifetime = LifetimeStatsCalculator.calculate(records, firstUse, today)
        val decoration = CatDecoration.of(lifetime.achievedDays)

        val yesterday = today.minusDays(1)
        val yesterdayRest = RestDayResolver.restDaySet(yesterday, records, today)
        val yesterdayAchieved = AchievementEvaluator.dailyStatus(
            date = yesterday, records = records, restDays = yesterdayRest, rescuedDates = rescuedDates, today = today,
        ).countsAsAchieved

        val catState = CatStateResolver.resolve(
            todayStatus = todayStatus,
            now = now,
            yesterdayAchieved = yesterdayAchieved,
            streakExtendedThisRun = false, // 後続: アプリ起動中に streak が伸びた瞬間の判定
        )
        val catMessage = CatMessageProvider.message(catState, today)

        val todaySummary = ExerciseTrendSummary.today(records, today)
        val weeklySummary = ExerciseTrendSummary.week(records, today)

        return HomeUiState(
            streak = streak,
            weekStatuses = weekStatuses,
            weeklyProgress = weeklyProgress,
            todayStatus = todayStatus,
            catState = catState,
            catMessage = catMessage,
            lifetimeStats = lifetime,
            catDecoration = decoration,
            todaySummary = todaySummary,
            weeklySummary = weeklySummary,
        )
    }
}
