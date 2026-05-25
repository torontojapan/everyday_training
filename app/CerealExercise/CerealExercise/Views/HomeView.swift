import SwiftUI

struct HomeView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var viewModel = HomeViewModel()
    @State private var isShowingEntry = false
    @State private var completedRecord: WorkoutRecord?
    @State private var completedStreakExtendedThisRun = false
    @State private var selectedDayEntry: DailyStatusEntry?
    @State private var isShowingStreakShare = false
    @State private var isShowingMonthlyReview = false
    @State private var monthlyReview: MonthlyReviewBuilder.Review?
    @State private var presentedMilestone: Milestone?
    private let calendar = Calendar.mondayFirst
    private let monthlyReviewTracker = MonthlyReviewTracker()

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()

                ScrollView {
                    // 階層化された spacing: 主導線 (CTA) 周りは余白を強く
                    // とり、補助カードは詰める。全体 20pt 一律から、用途別
                    // spacing で視覚的優先順位を伝える。
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        // Cat front-and-center so users greet 猫 first thing.
                        CatMessageView(
                            message: viewModel.catMessage,
                            state: viewModel.catState,
                            decoration: viewModel.catDecoration
                        )
                        .padding(.bottom, 4)   // 猫の下にひと呼吸

                        primaryActionButton

                        weeklyCalendarSection

                        // 達成済みの日は今日の達成カードだけ、未達成の日は
                        // 今週のハイライトだけ。重複を避ける。
                        if viewModel.todayStatus == .todayAchieved, viewModel.todaySummary.hasExerciseData {
                            TodayAchievementSummaryCard(summary: viewModel.todaySummary)
                        } else if viewModel.weeklySummary.hasExerciseData {
                            WeeklyHighlightCard(summary: viewModel.weeklySummary)
                        }

                        LifetimeStatsCard(
                            achievedDays: viewModel.lifetimeStats.achievedDays,
                            usedDays: viewModel.lifetimeStats.usedDays
                        )

                        weightEntry

                        monthlyReviewEntry
                    }
                    .padding(20)
                }
            }
            .navigationTitle("GOエクササイズ")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        FriendsView()
                    } label: {
                        Image(systemName: "person.2.fill")
                    }
                    .accessibilityLabel("友達")
                    .accessibilityIdentifier("friends-home-button")

                    NavigationLink {
                        HistoryView()
                            .environment(store)
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("履歴")

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("設定")
                }
            }
            .onAppear {
                store.fetchRecords()
                viewModel.refresh(records: store.records)
                handleAutoPresentations()
            }
            .sheet(isPresented: $isShowingEntry, onDismiss: {
                viewModel.refresh(records: store.records)
            }) {
                RecordEntryView { record in
                    viewModel.refresh(records: store.records, streakExtendedThisRun: true)
                    completedStreakExtendedThisRun = viewModel.streakExtendedThisRun
                    completedRecord = record
                    WidgetSnapshotPublisher.publish(from: store, today: Date(), calendar: calendar)
                    Task { @MainActor in
                        await NotificationScheduler(calendar: calendar).rescheduleAfterAchievement(
                            currentStreak: viewModel.streak.currentStreak,
                            weeklyProgressRate: viewModel.progress.rate
                        )
                    }
                    isShowingEntry = false
                }
                .environment(store)
            }
            .navigationDestination(item: $completedRecord) { record in
                RecordCompletionView(
                    record: record,
                    streakExtendedThisRun: completedStreakExtendedThisRun,
                    onRecordAnother: {
                        completedRecord = nil
                        isShowingEntry = true
                    }
                )
                .environment(store)
            }
            .sheet(item: $selectedDayEntry) { entry in
                DayDetailSheet(
                    date: entry.date,
                    records: store.records.filter { calendar.isDate($0.date, inSameDayAs: entry.date) },
                    status: entry.status
                )
            }
            .sheet(isPresented: $isShowingStreakShare) {
                StreakShareSheet(streak: viewModel.streak.currentStreak, isPresented: $isShowingStreakShare)
            }
            .sheet(isPresented: $isShowingMonthlyReview) {
                if let review = monthlyReview {
                    MonthlyReviewSheet(review: review, isPresented: $isShowingMonthlyReview)
                }
            }
            .sheet(item: $presentedMilestone) { milestone in
                MilestoneCelebrationSheet(
                    milestone: milestone,
                    isPresented: Binding(get: { presentedMilestone != nil },
                                          set: { if !$0 { presentedMilestone = nil } }),
                    onAcknowledge: {
                        viewModel.acknowledgeMilestone(milestone)
                    }
                )
            }
        }
    }

    /// 達成済みなら CTA を「もう一種目する 🔥」に変えて達成感を残しつつ
    /// 追加記録への導線も保つ。未達成なら従来通り「今日の運動を記録する」。
    /// どちらのラベルでも accessibilityIdentifier を固定にしているので
    /// UI test は識別子ベースで参照する。
    @ViewBuilder
    private var primaryActionButton: some View {
        if viewModel.todayStatus == .todayAchieved {
            PrimaryButton("もう一種目する 🔥",
                          systemImage: "plus.circle.fill",
                          accessibilityIdentifier: "primary-record-action") {
                isShowingEntry = true
            }
        } else {
            PrimaryButton("今日の運動を記録する",
                          systemImage: "plus.circle.fill",
                          accessibilityIdentifier: "primary-record-action") {
                isShowingEntry = true
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.todayStatus == .todayAchieved ? "今日も達成 ✨" : "今日も少しずつ")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textSecondary)
                StreakBadgeView(streak: viewModel.streak.currentStreak) {
                    guard viewModel.streak.currentStreak > 0 else { return }
                    isShowingStreakShare = true
                }
            }
            Spacer()
            // 達成済みなら「今日は達成済み」、未達成なら「締切まで残り X 時間」と
            // 表示を切り替える。同じ chip でも文脈で意味が変わる。
            if viewModel.todayStatus == .todayAchieved {
                Label("今日は達成済み", systemImage: "checkmark.seal.fill")
                    .font(Typography.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Palette.success.opacity(0.18), in: Capsule())
                    .foregroundStyle(Palette.success)
            } else {
                Text(remainingTimeText)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Palette.surface, in: Capsule())
            }
        }
    }

    private var weeklyCalendarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今週")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("\(viewModel.progress.achievedCount) / \(viewModel.progress.totalDays) 日達成")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
            }
            WeeklyCalendarView(statuses: viewModel.statuses, today: store.today, calendar: calendar) { entry in
                selectedDayEntry = entry
            }
        }
    }

    private var monthlyReviewEntry: some View {
        let hasPrevious = viewModel.previousMonthHasRecords
        return Button {
            buildAndPresentMonthlyReview()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.image")
                    .font(.system(size: 22))
                    .foregroundStyle(hasPrevious ? Palette.primaryDeep : Palette.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("先月のレビューを見る")
                        .font(Typography.headline)
                        .foregroundStyle(hasPrevious ? Palette.textPrimary : Palette.textSecondary)
                    Text(hasPrevious
                        ? "一ヶ月のがんばりをカードでサマリー、SNSでもシェアできます"
                        : "先月の記録はまだありません")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                if hasPrevious {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!hasPrevious)
        .accessibilityIdentifier("monthly-review-button")
    }

    private var weightEntry: some View {
        NavigationLink {
            WeightView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.primaryDeep)
                VStack(alignment: .leading, spacing: 2) {
                    Text("体重の推移をみる")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text("グラフで増減を一目で確認")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("weight-link-home")
    }

    private var remainingTimeText: String {
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: store.today) ?? Date()
        let hours = max(0, calendar.dateComponents([.hour], from: Date(), to: endOfDay).hour ?? 0)
        return "今日の締切まで あと\(hours)時間"
    }

    private func buildAndPresentMonthlyReview() {
        let today = store.today
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: today) ?? today
        monthlyReview = MonthlyReviewBuilder.build(records: store.records, month: previousMonth, calendar: calendar)
        isShowingMonthlyReview = true
        monthlyReviewTracker.markPresented(today: today)
    }

    private func handleAutoPresentations() {
        let skipAuto = ProcessInfo.processInfo.arguments.contains("--skip-milestones")
        if !skipAuto, presentedMilestone == nil, let milestone = viewModel.pendingMilestone {
            presentedMilestone = milestone
            return  // show one auto-sheet at a time
        }
        if !skipAuto, presentedMilestone == nil,
           monthlyReviewTracker.shouldAutoPresent(today: store.today) {
            // Auto-present last month's review on the first home appearance of a new month.
            buildAndPresentMonthlyReview()
        }
    }
}

extension Milestone: Identifiable {
    public var id: String {
        switch self {
        case .anniversary(let years): return "anniv-\(years)"
        case .lifetimeDays(let d): return "lifetime-\(d)"
        case .currentStreak(let d): return "streak-\(d)"
        }
    }
}
