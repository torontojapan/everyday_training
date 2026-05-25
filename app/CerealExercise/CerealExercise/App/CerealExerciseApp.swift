import SwiftData
import SwiftUI
import UIKit

@main
struct CerealExerciseApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var themeStore = ThemeStore.shared
    @State private var friendsStore = FriendsStore(service: MockFriendsService())

    var body: some Scene {
        WindowGroup {
            HomeRootView(scenePhase: scenePhase)
                .environment(themeStore)
                .environment(friendsStore)
                .preferredColorScheme(themeStore.theme.preferredColorScheme)
                .tint(themeStore.theme.primary)
                .task {
                    if ProcessInfo.processInfo.arguments.contains("--mock-seed-friends"),
                       friendsStore.profile == nil {
                        await friendsStore.signIn(displayName: "ジュン", username: "jun_demo")
                    }
                }
        }
        .modelContainer(for: [WorkoutRecord.self, WeightEntry.self, MenstrualEntry.self])
    }
}

private enum InitialRoute: String {
    case home
    case record
    case history
    case settings
    case notificationSettings = "notification-settings"
    case streakShare = "streak-share"
    case friends
}

@MainActor
@Observable
private final class RouteState {
    var override: InitialRoute? = nil
}

private struct HomeRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store: WorkoutStore?
    @State private var routeState = RouteState()
    let scenePhase: ScenePhase

    private var launchArgs: [String] { ProcessInfo.processInfo.arguments }
    private var skipNotificationPrompt: Bool { launchArgs.contains("--no-notification-prompt") }
    private var shouldSeedDemoData: Bool { launchArgs.contains("--seed-demo-data") }
    private var demoScenario: DemoScenario {
        guard let idx = launchArgs.firstIndex(of: "--seed-scenario"), idx + 1 < launchArgs.count else {
            return .basic
        }
        return DemoScenario(rawValue: launchArgs[idx + 1]) ?? .basic
    }
    private var initialRoute: InitialRoute {
        guard let idx = launchArgs.firstIndex(of: "--initial-route"), idx + 1 < launchArgs.count else {
            return .home
        }
        return InitialRoute(rawValue: launchArgs[idx + 1]) ?? .home
    }

    var body: some View {
        Group {
            if let store {
                routedView(store: store)
            } else {
                ProgressView()
                    .tint(Palette.primary)
                    .task {
                        if shouldSeedDemoData {
                            DemoDataSeeder.seed(context: modelContext, today: Date(), scenario: demoScenario)
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

    @ViewBuilder
    private func routedView(store: WorkoutStore) -> some View {
        let activeRoute = routeState.override ?? initialRoute
        switch activeRoute {
        case .home:
            if UIDevice.current.userInterfaceIdiom == .pad {
                RootSplitView()
                    .environment(store)
            } else {
                HomeView()
                    .environment(store)
            }
        case .record:
            NavigationStack {
                RecordEntryView { _ in }
                    .environment(store)
            }
        case .history:
            let state = routeState
            NavigationStack {
                HistoryView(onClose: { state.override = .home })
                    .environment(store)
            }
        case .settings:
            let state = routeState
            NavigationStack {
                SettingsView(onClose: { state.override = .home })
            }
        case .notificationSettings:
            NavigationStack {
                NotificationSettingsView()
            }
        case .streakShare:
            let streak = StreakCalculator.currentStreak(
                records: store.records,
                today: Date(),
                calendar: .mondayFirst
            )
            let state = routeState
            StreakShareSheet(
                streak: max(1, streak),
                isPresented: Binding(
                    get: { (state.override ?? initialRoute) == .streakShare },
                    set: { isPresented in
                        if !isPresented {
                            state.override = .home
                        }
                    }
                )
            )
        case .friends:
            NavigationStack {
                FriendsView()
            }
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
