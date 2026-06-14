package com.goexercise.app.presentation.home

import com.goexercise.app.domain.AchievementEvaluator
import com.goexercise.app.domain.CatDecoration
import com.goexercise.app.domain.CatMessageProvider
import com.goexercise.app.domain.CatStateResolver
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.ExerciseTrendSummary
import com.goexercise.app.domain.LifetimeStatsCalculator
import com.goexercise.app.domain.MonthlyCalendarCalculator
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
 * 未対応(後続フェーズ): rescuedDates(保険チケット), streakExtendedThisRun, マイルストーン。
 * 現状 rescuedDates は空で計算する。運動トレンド集計(today/week)と初回利用日は実装済み。
 */
object HomeStateReducer {

    fun reduce(
        records: List<WorkoutRecord>,
        now: LocalDateTime,
        rescuedDates: Set<java.time.LocalDate> = emptySet(),
        firstUseDate: java.time.LocalDate? = null,
    ): HomeUiState {
        val today = now.toLocalDate()

        val weekStatuses = WeeklyProgressCalculator.statuses(
            weekContaining = today, records = records, today = today, rescuedDates = rescuedDates,
        )
        val weeklyProgress = WeeklyProgressCalculator.progress(weekStatuses)
        val streak = StreakCalculator.streakState(records, today, rescuedDates)
        val todayStatus = weekStatuses.firstOrNull { it.date == today }?.status ?: DailyStatus.TodayPending

        // 永続化された初回利用日を優先(記録の無い期間も利用日数に含める。iOS LifetimeUsageTracker)。
        // 未永続なら最古記録日、それも無ければ今日にフォールバック。
        val firstUse = firstUseDate ?: records.minByOrNull { it.date }?.date ?: today
        val lifetime = LifetimeStatsCalculator.calculate(records, firstUse, today)
        val decoration = CatDecoration.of(lifetime.achievedDays)

        val yesterday = today.minusDays(1)
        val yesterdayRest = RestDayResolver.restDaySet(yesterday, records, today)
        val yesterdayStatus = AchievementEvaluator.dailyStatus(
            date = yesterday, records = records, restDays = yesterdayRest, rescuedDates = rescuedDates, today = today,
        )
        val yesterdayAchieved = yesterdayStatus.countsAsAchieved

        // 復帰日の歓迎カード(iOS isComebackToday): 昨日 missed・今日未達成・累計>=3日のとき
        // 「おかえり」カードを出して再開のハードルを下げる(離脱対策)。
        val isComebackToday = yesterdayStatus == DailyStatus.Missed &&
            !todayStatus.countsAsAchieved &&
            lifetime.achievedDays >= 3

        val catState = CatStateResolver.resolve(
            todayStatus = todayStatus,
            now = now,
            yesterdayAchieved = yesterdayAchieved,
            streakExtendedThisRun = false, // 後続: アプリ起動中に streak が伸びた瞬間の判定
        )
        val catMessage = CatMessageProvider.message(catState, today)

        val todaySummary = ExerciseTrendSummary.today(records, today)
        val weeklySummary = ExerciseTrendSummary.week(records, today)

        // 当月集計(友達BEの月次ランキング用。iOS パリティ)。達成日数は Rest 除外(iOS 月サマリーと一致)。
        val monthlyAchievedDays = MonthlyCalendarCalculator.achievedDaysInMonth(
            MonthlyCalendarCalculator.cells(java.time.YearMonth.from(today), records, today, rescuedDates),
        )
        val monthlyTotalMinutes = ExerciseTrendSummary.monthTotalMinutes(records, today)

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
            monthlyTotalMinutes = monthlyTotalMinutes,
            monthlyAchievedDays = monthlyAchievedDays,
            isComebackToday = isComebackToday,
        )
    }
}
