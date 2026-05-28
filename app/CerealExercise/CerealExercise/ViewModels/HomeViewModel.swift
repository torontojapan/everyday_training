import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private let calendar: Calendar
    private let dateProvider: any DateProviding

    var statuses: [DailyStatusEntry] = []
    var progress = WeeklyProgress(achievedCount: 0, totalDays: 7)
    var streak = StreakState(currentStreak: 0, longestStreak: 0, lastAchievedDate: nil)
    var todayStatus: DailyStatus = .todayPending
    var todaySummary = ExerciseTrendSummary.DailySummary(categoryCounts: [:], exerciseCount: 0, totalDurationSeconds: 0)
    var weeklySummary = ExerciseTrendSummary.WeeklySummary(usedCategories: [], totalDurationSeconds: 0, topExerciseNames: [])
    var catMessage = CatMessage(emoji: "🐱", text: "今日も1分だけやってみよ？")
    var catState: CatState = .waitingMorning
    var streakExtendedThisRun = false
    var lifetimeStats = LifetimeStatsCalculator.Stats(achievedDays: 0, usedDays: 1)
    var catDecoration: CatDecoration = .none
    var rescueTicketAvailable = true
    var pendingMilestone: Milestone?
    var firstUseDate: Date = Date()
    /// 「先月のレビュー」ボタンを active / disabled で出し分けるために、
    /// 前月にいずれかの記録があるかどうかを保持する。
    var previousMonthHasRecords = false

    /// 「復帰ファーストホーム」を出すかどうか (Codex UX 提案 #2)。
    /// 判定条件 (3 つすべて true):
    /// - **昨日の status が `.missed`**: 単に streak が 0 ではなく、rest day や
    ///   rescue ticket での救済も効かなかった真の取りこぼし日
    /// - 今日まだ達成していない
    /// - 累計達成日 >= 3 (= 習慣を持っていた経験あり)
    /// 朝起きて未記録でも、昨日達成済みなら通常 UI のまま。
    var isComebackToday: Bool = false
    private let usageTracker = LifetimeUsageTracker()
    private let rescueTicketStore: RescueTicketStore
    private let milestoneDetector: MilestoneDetector

    init(dateProvider: any DateProviding = SystemDateProvider(),
         calendar: Calendar = .mondayFirst,
         rescueTicketStore: RescueTicketStore = .shared,
         milestoneDetector: MilestoneDetector? = nil) {
        self.dateProvider = dateProvider
        self.calendar = calendar
        self.rescueTicketStore = rescueTicketStore
        self.milestoneDetector = milestoneDetector ?? MilestoneDetector()
    }

    func refresh(records: [WorkoutRecord],
                  streakExtendedThisRun: Bool = false,
                  weightLoss: MilestoneDetector.WeightLossSnapshot? = nil,
                  anchorDate: Date? = nil) {
        // 呼び出し側が `anchorDate` を指定すれば、内部 dateProvider ではなく
        // その瞬間を全集計の基準日として使う。日跨ぎ atomic 化のため
        // (Codex round5: 別ソース読みによる drift を排除)。
        let now = anchorDate ?? dateProvider.currentDate()
        let today = calendar.startOfDay(for: now)
        statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: records, today: today, calendar: calendar)
        progress = WeeklyProgressCalculator.progress(from: statuses)
        streak = StreakCalculator.streakState(records: records, today: today, calendar: calendar)
        todayStatus = statuses.first { calendar.isDate($0.date, inSameDayAs: today) }?.status ?? .todayPending
        todaySummary = ExerciseTrendSummary.today(records: records, today: today, calendar: calendar)
        if let week = calendar.dateInterval(of: .weekOfYear, for: today) {
            weeklySummary = ExerciseTrendSummary.week(records: records, week: week, calendar: calendar)
        } else {
            weeklySummary = ExerciseTrendSummary.WeeklySummary(usedCategories: [], totalDurationSeconds: 0, topExerciseNames: [])
        }
        self.streakExtendedThisRun = streakExtendedThisRun && streak.currentStreak > 1
        catState = CatStateResolver.resolve(
            todayStatus: todayStatus,
            now: now,
            yesterdayAchieved: yesterdayAchieved(records: records, today: today),
            streakExtendedThisRun: self.streakExtendedThisRun,
            calendar: calendar
        )
        catMessage = CatMessageProvider.message(for: catState, seedDate: today, calendar: calendar)
        let firstUse = usageTracker.firstUseDate(records: records, fallback: today)
        firstUseDate = firstUse
        lifetimeStats = LifetimeStatsCalculator.calculate(
            records: records,
            firstUseDate: firstUse,
            today: today,
            calendar: calendar
        )
        catDecoration = CatDecoration(totalAchievedDays: lifetimeStats.achievedDays)
        rescueTicketAvailable = rescueTicketStore.hasTicketAvailable(today: today)
        pendingMilestone = milestoneDetector.nextPending(
            records: records,
            firstUseDate: firstUse,
            today: today,
            lifetimeAchieved: lifetimeStats.achievedDays,
            currentStreak: streak.currentStreak,
            weightLoss: weightLoss
        )
        previousMonthHasRecords = Self.hasPreviousMonthRecords(records: records, today: today, calendar: calendar)
        isComebackToday = yesterdayStatus(records: records, today: today) == .missed
            && !todayStatus.countsAsAchieved
            && lifetimeStats.achievedDays >= 3
    }

    /// 昨日の DailyStatus (rest day **+ rescue ticket** 自動補完を込みで評価)。
    /// 復帰モード判定で「真に missed か」を確定するため。
    /// Codex round1 priority 1: rescuedDates を渡さないと、ticket で救済済の
    /// 日も .missed 扱いになり comeback 表示が誤発火していた。
    private func yesterdayStatus(records: [WorkoutRecord], today: Date) -> DailyStatus {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return .future
        }
        let restDays = RestDayResolver.restDaySet(for: yesterday, records: records, today: today, calendar: calendar)
        let rescued = rescueTicketStore.rescuedDates()
        return AchievementEvaluator.dailyStatus(
            for: yesterday,
            records: records,
            restDays: restDays,
            rescuedDates: rescued,
            today: today,
            calendar: calendar
        )
    }

    private static func hasPreviousMonthRecords(records: [WorkoutRecord], today: Date, calendar: Calendar) -> Bool {
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: today),
              let interval = calendar.dateInterval(of: .month, for: previousMonth) else {
            return false
        }
        return records.contains { interval.contains($0.date) }
    }

    func acknowledgeMilestone(_ milestone: Milestone) {
        milestoneDetector.acknowledge(milestone)
        pendingMilestone = nil
    }

    func useRescueTicketToday() -> Bool {
        let today = calendar.startOfDay(for: dateProvider.currentDate())
        let used = rescueTicketStore.useTicket(on: today)
        rescueTicketAvailable = rescueTicketStore.hasTicketAvailable(today: today)
        return used
    }

    /// 「昨日達成済みか」を rescue ticket 補完込みで判定。
    /// `yesterdayStatus` と同じパスを使って isComebackToday と catState の
    /// 判断が一致するようにする (Codex round2 priority 1)。
    private func yesterdayAchieved(records: [WorkoutRecord], today: Date) -> Bool {
        yesterdayStatus(records: records, today: today).countsAsAchieved
    }
}
