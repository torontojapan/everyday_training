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
    var catMessage = CatMessage(emoji: "🐱", text: "今日も1分だけやってみよ？")
    var catState: CatState = .waitingMorning
    var streakExtendedThisRun = false

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
        self.streakExtendedThisRun = streakExtendedThisRun && streak.currentStreak > 1
        catState = CatStateResolver.resolve(
            todayStatus: todayStatus,
            now: now,
            yesterdayAchieved: yesterdayAchieved(records: records, today: today),
            streakExtendedThisRun: self.streakExtendedThisRun,
            calendar: calendar
        )
        catMessage = CatMessageProvider.message(for: catState, seedDate: today, calendar: calendar)
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
