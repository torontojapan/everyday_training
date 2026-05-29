import Foundation
import OSLog
import WidgetKit

private let widgetPublishLogger = Logger(subsystem: "com.serial.cerealexercise", category: "WidgetSnapshotPublisher")

@MainActor
enum WidgetSnapshotPublisher {
    static func publish(from store: WorkoutStore, today: Date = Date(), rescuedDates: Set<Date> = [], calendar: Calendar = .mondayFirst) {
        store.fetchRecords()

        let todayStart = calendar.startOfDay(for: today)
        // 保険チケット救済日も達成扱いにするため rescuedDates を渡す。これが無いと
        // ウィジェットの連続日数 / 週進捗がアプリ本体と食い違う (3 LLM 監査)。
        let statuses = WeeklyProgressCalculator.statuses(
            forWeekContaining: todayStart,
            records: store.records,
            today: todayStart,
            rescuedDates: rescuedDates,
            calendar: calendar
        )
        let progress = WeeklyProgressCalculator.progress(from: statuses)
        let streak = StreakCalculator.currentStreak(records: store.records, today: todayStart, rescuedDates: rescuedDates, calendar: calendar)
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

        // App Group への書き込み失敗を握り潰さない。失敗時はウィジェットが古い
        // ままになるため、検知できるようログを残す (Codex 指摘)。
        if !SharedSnapshotStore().write(snapshot) {
            widgetPublishLogger.error("ウィジェットスナップショットの書き込みに失敗 (App Group suite 不可 or エンコード失敗)。ウィジェットが stale になる可能性。")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
