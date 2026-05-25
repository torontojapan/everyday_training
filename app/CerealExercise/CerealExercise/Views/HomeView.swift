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
                    VStack(alignment: .leading, spacing: 20) {
                        header

                        // Cat front-and-center so users greet 猫 first thing.
                        CatMessageView(
                            message: viewModel.catMessage,
                            state: viewModel.catState,
                            decoration: viewModel.catDecoration
                        )

                        PrimaryButton("今日の運動を記録する", systemImage: "plus.circle.fill") {
                            isShowingEntry = true
                        }

                        weeklyCalendarSection

                        if viewModel.todayStatus == .todayAchieved, viewModel.todaySummary.hasExerciseData {
                            TodayAchievementSummaryCard(summary: viewModel.todaySummary)
                        }

                        if viewModel.weeklySummary.hasExerciseData {
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

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("今日も少しずつ")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textSecondary)
                StreakBadgeView(streak: viewModel.streak.currentStreak) {
                    guard viewModel.streak.currentStreak > 0 else { return }
                    isShowingStreakShare = true
                }
            }
            Spacer()
            Text(remainingTimeText)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Palette.surface, in: Capsule())
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
        Button {
            buildAndPresentMonthlyReview()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.image")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.primaryDeep)
                VStack(alignment: .leading, spacing: 2) {
                    Text("先月のレビューを見る")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text("一ヶ月のがんばりをカードでサマリー、SNSでもシェアできます")
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
        return "あと\(hours)時間"
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
