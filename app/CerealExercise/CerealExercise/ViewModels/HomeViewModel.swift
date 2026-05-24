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
    var achievements: [Achievement] = []
    var rescueTicketAvailable = true
    var pendingMilestone: Milestone?
    var firstUseDate: Date = Date()
    private let usageTracker = LifetimeUsageTracker()
    private let rescueTicketStore = RescueTicketStore()
    private let milestoneDetector = MilestoneDetector()

    init(dateProvider: any DateProviding = SystemDateProvider(), calendar: Calendar = .mondayFirst) {
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    func refresh(records: [WorkoutRecord], streakExtendedThisRun: Bool = false) {
        let now = dateProvider.currentDate()
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
        achievements = AchievementCatalog.evaluate(
            records: records,
            streak: streak,
            lifetime: lifetimeStats,
            calendar: calendar
        )
        rescueTicketAvailable = rescueTicketStore.hasTicketAvailable(today: today)
        pendingMilestone = milestoneDetector.nextPending(
            records: records,
            firstUseDate: firstUse,
            today: today,
            lifetimeAchieved: lifetimeStats.achievedDays,
            currentStreak: streak.currentStreak
        )
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

    private func yesterdayAchieved(records: [WorkoutRecord], today: Date) -> Bool {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return true }
        let restDays = RestDayResolver.restDaySet(for: yesterday, records: records, today: today, calendar: calendar)
        let status = AchievementEvaluator.dailyStatus(
            for: yesterday,
            records: records,
            restDays: restDays,
            today: today,
            calendar: calendar
        )
        return status.countsAsAchieved
    }
}
