import SwiftData
import SwiftUI
import UIKit

@main
struct CerealExerciseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var themeStore = ThemeStore.shared
    @State private var friendsStore = FriendsStore(service: MockFriendsService())
    @State private var routeState = RouteState()
    @State private var router = DeepLinkRouter.shared

    var body: some Scene {
        WindowGroup {
            HomeRootView(scenePhase: scenePhase, routeState: routeState)
                .environment(themeStore)
                .environment(friendsStore)
                .preferredColorScheme(themeStore.theme.preferredColorScheme)
                .tint(themeStore.theme.primary)
                .task {
                    let args = ProcessInfo.processInfo.arguments
                    // For UI tests: force a clean signed-out state, regardless
                    // of what was persisted by a previous run on the same
                    // simulator. Must run before any mock-seed branch.
                    if args.contains("--mock-force-signed-out") {
                        await friendsStore.signOut()
                    }
                    if args.contains("--mock-seed-friends"),
                       friendsStore.profile == nil {
                        await friendsStore.signIn(displayName: "ジュン", username: "jun_demo")
                    }
                }
                .onOpenURL { url in
                    if let route = DeepLinkRouter.route(from: url) {
                        routeState.override = route
                    }
                }
                .onChange(of: router.pendingRoute) { _, newRoute in
                    guard let newRoute else { return }
                    routeState.override = newRoute
                    router.pendingRoute = nil
                }
        }
        .modelContainer(for: [WorkoutRecord.self, WeightEntry.self, MenstrualEntry.self])
    }
}

private struct HomeRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store: WorkoutStore?
    let scenePhase: ScenePhase
    let routeState: RouteState

    private var launchArgs: [String] { ProcessInfo.processInfo.arguments }
    private var skipNotificationPrompt: Bool { launchArgs.contains("--no-notification-prompt") }
    private var shouldSeedDemoData: Bool { launchArgs.contains("--seed-demo-data") }
    private var demoScenario: DemoScenario {
        guard let idx = launchArgs.firstIndex(of: "--seed-scenario"), idx + 1 < launchArgs.count else {
            return .basic
        }
        return DemoScenario(rawValue: launchArgs[idx + 1]) ?? .basic
    }
    private var initialRoute: AppRoute {
        guard let idx = launchArgs.firstIndex(of: "--initial-route"), idx + 1 < launchArgs.count else {
            return .home
        }
        return AppRoute(rawValue: launchArgs[idx + 1]) ?? .home
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
            let state = routeState
            NavigationStack {
                RecordEntryView { _ in state.override = .home }
                    .environment(store)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("閉じる") { state.override = .home }
                                .accessibilityIdentifier("record-deeplink-close")
                        }
                    }
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
            let state = routeState
            NavigationStack {
                NotificationSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("閉じる") { state.override = .home }
                                .accessibilityIdentifier("notif-deeplink-close")
                        }
                    }
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
            let state = routeState
            NavigationStack {
                FriendsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("閉じる") { state.override = .home }
                                .accessibilityIdentifier("friends-deeplink-close")
                        }
                    }
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
