import SwiftData
import SwiftUI
import UIKit

@main
struct GOExerciseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var themeStore = ThemeStore.shared
    /// friendsStore と referralStore で **同一** の FriendsService インスタンスを共有する。
    /// makeFriendsService() は呼ぶたびに新インスタンスを返すため、別々に作ると
    /// サインイン状態やデータが食い違う。ここで 1 度だけ生成して両者に渡す。
    private static let sharedFriendsService: any FriendsService = GOExerciseApp.makeFriendsService()
    @State private var friendsStore = FriendsStore(service: GOExerciseApp.sharedFriendsService)
    @State private var referralStore = ReferralStore(
        service: GOExerciseApp.sharedFriendsService,
        isSignedIn: { GOExerciseApp.sharedFriendsService.myProfile != nil }
    )
    /// 記録のクラウドバックアップ(オプトイン)。friends と同一サービス(=同一セッション)を共有。
    @State private var recordSync = RecordSyncCoordinator(service: GOExerciseApp.sharedFriendsService)
    @State private var routeState = RouteState()
    @State private var router = DeepLinkRouter.shared
    @State private var userCatPrefs = UserCatPreferences.shared
    @State private var storeKit = StoreKitManager()
    /// アプリ全体で共有する rescue ticket ストア。@Observable + shared でアプリ
    /// 内のあらゆる View が同一インスタンスを参照するように。
    @State private var rescueTicketStore = RescueTicketStore.shared
    @State private var isShowingOnboarding = false
    /// App Group 共有 SwiftData コンテナ。**1 回だけ** 生成する。
    /// body 内で make() をインライン呼び出しすると body 再評価毎に同一ストアへ
    /// 複数コンテナが開かれ、SwiftData が trap する (EXC_BREAKPOINT) ため。
    private let sharedModelContainer = AppModelContainer.make()

    /// 友達バックエンドの選択。
    /// - Release: 常に **Supabase** (中立BE・Apple↔Android)。Secrets.xcconfig 未設定の場合は
    ///   Mock へ無言フォールバックせず、使用時に `backendUnavailable` を投げてエラーバナーで
    ///   表面化させる (設定漏れを本番でローカル Mock 動作に化けさせない = Codexレビュー反映)。
    ///   → v1.1 アーカイブ前に Secrets.xcconfig の SUPABASE_HOST/ANON_KEY を必ず設定すること。
    /// - DEBUG: 既定は `MockFriendsService` (デモ/スクショ/UI テスト用)。
    ///   `--supabase-friends` で実 Supabase に接続して手動確認できる。
    static func makeFriendsService() -> any FriendsService {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--supabase-friends") {
            return SupabaseFriendsService()
        }
        return MockFriendsService()
        #else
        return SupabaseFriendsService()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeRootView(scenePhase: scenePhase, routeState: routeState)
                .environment(themeStore)
                .environment(friendsStore)
                .environment(storeKit)
                .environment(rescueTicketStore)
                .environment(referralStore)
                .environment(recordSync)
                .preferredColorScheme(themeStore.theme.preferredColorScheme)
                .tint(themeStore.theme.primary)
                .fullScreenCover(isPresented: $isShowingOnboarding) {
                    // fullScreenCover の中身は親の .environment(_:) を取りこぼすこと
                    // がある (SwiftUI の既知の癖)。UserCatPickerView は storeKit
                    // (猫種ロック判定) と friendsStore/referralStore (招待コード入力) を
                    // 環境から読むため、cover 上で明示的に注入し直す。
                    UserCatPickerView(isOnboarding: true)
                        .environment(themeStore)
                        .environment(friendsStore)
                        .environment(storeKit)
                        .environment(rescueTicketStore)
                        .environment(referralStore)
                        .environment(recordSync)
                }
                .onAppear {
                    // 初回起動なら自分の猫キャラ選択 onboarding を出す。
                    // UI test では --skip-onboarding で抑止可能 (DEBUG のみ。
                    // Release では本番でオンボーディングを必ず表示する = スキップ不可)。
                    var allowSkipOnboarding = false
                    #if DEBUG
                    allowSkipOnboarding = ProcessInfo.processInfo.arguments.contains("--skip-onboarding")
                    #endif
                    if !allowSkipOnboarding, !userCatPrefs.hasCompletedOnboarding {
                        isShowingOnboarding = true
                    }
                }
                .task {
                    // 計測: App ID 設定済 + Release のときだけ TelemetryDeck を有効化
                    // (未設定なら Noop = 送信なし)。その後 app_open を記録。
                    Analytics.configureIfPossible()
                    Analytics.track(.appOpen)

                    // StoreKit: 起動時に商品ロード + entitlement 評価。
                    await storeKit.loadProducts()

                    // 友達紹介: サインイン済みなら起動時に「紹介者ポップ」を取り込む。
                    // 未サインインは ReferralStore 側で no-op(匿名アカウントを作らない)。
                    if AppFeatureFlags.isReferralActive {
                        await referralStore.refresh()
                        await referralStore.pollReferrerPops()
                    }

                    // 記録のクラウドバックアップ: 共有コンテナの context を渡し、ON なら起動時同期。
                    recordSync.attach(modelContext: ModelContext(sharedModelContainer))
                    await recordSync.syncNow()

                    // 以下の mock 系起動引数は UI テスト / スクショ専用。Release では
                    // コンパイル除外し、本番で偽の友達データ生成やサインアウトが
                    // 起きないようにする (QA チェックリスト A: debug 引数は Release で無効)。
                    #if DEBUG
                    let args = ProcessInfo.processInfo.arguments
                    // For UI tests: force a clean signed-out state, regardless
                    // of what was persisted by a previous run on the same
                    // simulator. Must run before any mock-seed branch.
                    if args.contains("--mock-force-signed-out") {
                        await friendsStore.signOut()
                    }
                    if args.contains("--mock-seed-friends") {
                        if friendsStore.profile == nil {
                            // 初回のみ signIn (profile + friend code を生成 + friends シード)。
                            await friendsStore.signIn(displayName: "ジュン", username: "jun_demo")
                        } else {
                            // 既存 profile はそのまま (friend code を維持) で、in-memory
                            // friends だけ再シードする。毎回 signIn すると friend code が
                            // 再生成され profile も streak 0 にリセットされていた (3 LLM 監査 C2)。
                            await friendsStore.ensureDemoFriendsSeeded()
                        }
                    }
                    // スクショ/QA 用: 紹介スター数を直接注入(レイアウト確認、特に最大10星)。
                    if let idx = args.firstIndex(of: "--mock-referral-stars"),
                       idx + 1 < args.count, let n = Int(args[idx + 1]) {
                        // 口座ガード(currentAccountStarBadges)を通すため account code も合わせる。
                        referralStore.debugInjectStars(n)
                    }
                    #endif
                }
                .onOpenURL { url in
                    // route をパース+ゲート。friends 着地時のみ検証済み code を保持し、
                    // home へ振替(friends無効)時は code を破棄 (Codex#1)。
                    let (route, code) = DeepLinkRouter.resolve(url: url)
                    if let route { routeState.override = route }
                    DeepLinkRouter.shared.pendingFriendCode = code
                }
                .onChange(of: router.pendingRoute) { _, newRoute in
                    guard let newRoute else { return }
                    routeState.override = newRoute
                    router.pendingRoute = nil
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // 前面復帰時に購読状態(entitlement + トライアル対象)を取り直す。自主解約での
                    // 期限切れは Transaction.updates を発火させないため、これが無いと有効期限後も
                    // アプリが数日間プレミアム表示のまま固着する(iOS は長時間サスペンド)(監査 P2)。
                    // entitlement だけでなくトライアル対象も更新しないと、失効後に「14日間無料」が
                    // 残って即課金になる(Codex R1)。
                    if newPhase == .background {
                        // バックグラウンド移行時にバックアップ同期(ON のときだけ。短時間で完了する量)。
                        Task { await recordSync.syncNow() }
                    }
                    guard newPhase == .active else { return }
                    Task { await storeKit.refreshPurchaseState() }
                }
        }
        // Widget と同じ App Group 共有ストアを使う。
        // 旧 `.modelContainer(for:)` はデフォルトのローカルストアを使っており、
        // ウィジェットのクイック記録がメインアプリに反映されなかった (監査 B-Critical-1)。
        .modelContainer(sharedModelContainer)
    }
}

private struct HomeRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var store: WorkoutStore?
    let scenePhase: ScenePhase
    let routeState: RouteState

    private var launchArgs: [String] { ProcessInfo.processInfo.arguments }
    // 以下はすべて UI テスト / スクショ用の debug 起動引数。Release では本番の
    // 既定値 (通知プロンプト表示 / デモ未シード / ホーム起動) に固定し、外部から
    // 偽データ投入や画面ジャンプができないようにする (QA チェックリスト A)。
    private var skipNotificationPrompt: Bool {
        #if DEBUG
        launchArgs.contains("--no-notification-prompt")
        #else
        false
        #endif
    }
    private var shouldSeedDemoData: Bool {
        #if DEBUG
        launchArgs.contains("--seed-demo-data")
        #else
        false
        #endif
    }
    #if DEBUG
    private var demoScenario: DemoScenario {
        guard let idx = launchArgs.firstIndex(of: "--seed-scenario"), idx + 1 < launchArgs.count else {
            return .basic
        }
        return DemoScenario(rawValue: launchArgs[idx + 1]) ?? .basic
    }
    #endif
    private var initialRoute: AppRoute {
        #if DEBUG
        guard let idx = launchArgs.firstIndex(of: "--initial-route"), idx + 1 < launchArgs.count else {
            return .home
        }
        return AppRoute(rawValue: launchArgs[idx + 1]) ?? .home
        #else
        return .home
        #endif
    }

    var body: some View {
        Group {
            if let store {
                routedView(store: store)
            } else {
                ProgressView()
                    .tint(Palette.primary)
                    .task {
                        #if DEBUG
                        if shouldSeedDemoData {
                            DemoDataSeeder.seed(context: modelContext, today: Date(), scenario: demoScenario)
                        }
                        #endif
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
        // 友達機能が無効 (v1) なら friends/weeklyRanking 行きのディープリンクや
        // --initial-route はホームへ振り替える (AppFeatureFlags.resolvedRoute)。
        let activeRoute = AppFeatureFlags.resolvedRoute(routeState.override ?? initialRoute)
        switch activeRoute {
        case .home:
            if UIDevice.current.userInterfaceIdiom == .pad {
                RootSplitView()
                    .environment(store)
            } else {
                // Phase 7.0: ボトムタブを Window 直下に置く。
                MainTabView()
                    .environment(store)
            }
        case .record:
            let state = routeState
            NavigationStack {
                RecordEntryView(
                    onSaved: { _ in state.override = .home },
                    onClose: { state.override = .home }
                )
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
                rescuedDates: RescueTicketStore.shared.rescuedDates(),
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
        case .weeklyRanking:
            let state = routeState
            NavigationStack {
                WeeklyRankingView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("閉じる") { state.override = .home }
                                .accessibilityIdentifier("weekly-ranking-deeplink-close")
                        }
                    }
            }
        }
    }

    private func publishAndSchedule(using store: WorkoutStore) {
        // 保険チケットで救済した日も達成扱いにするため、全集計に rescuedDates を
        // 渡す。これが無いとウィジェット / 通知 / Live Activity の連続日数や
        // 週進捗がホーム・履歴と食い違う (3 LLM 監査: rescuedDates 未伝播)。
        let rescued = RescueTicketStore.shared.rescuedDates()
        WidgetSnapshotPublisher.publish(from: store, today: Date(), rescuedDates: rescued)
        let records = store.records
        let today = store.today
        let statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: records, today: today, rescuedDates: rescued)
        let progress = WeeklyProgressCalculator.progress(from: statuses)
        let todayStatus = statuses.first { Calendar.mondayFirst.isDate($0.date, inSameDayAs: today) }?.status ?? .todayPending
        let streak = StreakCalculator.currentStreak(records: records, today: today, rescuedDates: rescued)

        // Phase 7.0 Step 4: Live Activity を起動 or 更新。
        let liveState = CatLiveActivityController.makeState(
            records: records,
            today: today,
            catBreed: UserCatPreferences.shared.myCat,
            rescuedDates: rescued
        )
        CatLiveActivityController.shared.ensureRunning(state: liveState)

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
