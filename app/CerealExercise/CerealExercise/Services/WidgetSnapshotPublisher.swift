import Foundation
import WidgetKit

@MainActor
enum WidgetSnapshotPublisher {
    static func publish(from store: WorkoutStore, today: Date = Date(), calendar: Calendar = .mondayFirst) {
        store.fetchRecords()

        let todayStart = calendar.startOfDay(for: today)
        let statuses = WeeklyProgressCalculator.statuses(
            forWeekContaining: todayStart,
            records: store.records,
            today: todayStart,
            calendar: calendar
        )
        let progress = WeeklyProgressCalculator.progress(from: statuses)
        let streak = StreakCalculator.currentStreak(records: store.records, today: todayStart, calendar: calendar)
        let todayStatus = statuses.first { calendar.isDate($0.date, inSameDayAs: todayStart) }?.status ?? .todayPending
        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        let yesterdayStatus = statuses.first { calendar.isDate($0.date, inSameDayAs: yesterday) }?.status
        let yesterdayAchieved = yesterdayStatus?.countsAsAchieved ?? true
        let catState = CatStateResolver.resolve(
            todayStatus: todayStatus,
            now: today,
            yesterdayAchieved: yesterdayAchieved,
            streakExtendedThisRun: false,
            calendar: calendar
        )
        let message = CatMessageProvider.message(for: catState, seedDate: todayStart, calendar: calendar).text
        let snapshot = WidgetSnapshot.make(
            generatedAt: today,
            todayAchieved: todayStatus == .todayAchieved || todayStatus == .achieved,
            isRestDay: todayStatus == .rest,
            currentStreak: streak,
            weeklyAchieved: progress.achievedCount,
            weeklyTotal: progress.totalDays,
            catState: catState,
            message: message,
            calendar: calendar
        )

        _ = SharedSnapshotStore().write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
