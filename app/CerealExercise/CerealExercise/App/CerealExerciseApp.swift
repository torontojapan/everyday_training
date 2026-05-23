import SwiftData
import SwiftUI

@main
struct CerealExerciseApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeRootView(scenePhase: scenePhase)
        }
        .modelContainer(for: WorkoutRecord.self)
    }
}

private struct HomeRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store: WorkoutStore?
    let scenePhase: ScenePhase

    private var launchArgs: [String] { ProcessInfo.processInfo.arguments }
    private var skipNotificationPrompt: Bool { launchArgs.contains("--no-notification-prompt") }
    private var shouldSeedDemoData: Bool { launchArgs.contains("--seed-demo-data") }

    var body: some View {
        Group {
            if let store {
                HomeView()
                    .environment(store)
            } else {
                ProgressView()
                    .tint(Palette.primary)
                    .task {
                        if shouldSeedDemoData {
                            DemoDataSeeder.seed(context: modelContext, today: Date())
                        }
                        let newStore = WorkoutStore(context: modelContext)
                        store = newStore
                        publishAndSchedule(using: newStore)
                        if !skipNotificationPrompt {
                            Task { @MainActor in
                                await NotificationPermissionManager().requestAuthorizationIfNeeded()
                            }
                        }
                    }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, let store else { return }
            publishAndSchedule(using: store)
        }
    }

    private func publishAndSchedule(using store: WorkoutStore) {
        WidgetSnapshotPublisher.publish(from: store, today: Date())
        let records = store.records
        let today = store.today
        let statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: records, today: today)
        let progress = WeeklyProgressCalculator.progress(from: statuses)
        let todayStatus = statuses.first { Calendar.mondayFirst.isDate($0.date, inSameDayAs: today) }?.status ?? .todayPending
        let streak = StreakCalculator.currentStreak(records: records, today: today)

        guard !skipNotificationPrompt else { return }

        Task { @MainActor in
            await NotificationScheduler(calendar: .mondayFirst).scheduleDaily(
                todayAchieved: todayStatus == .todayAchieved || todayStatus == .achieved,
                currentStreak: streak,
                weeklyProgressRate: progress.rate
            )
        }
    }
}
