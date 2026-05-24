import SwiftUI

struct HomeView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var viewModel = HomeViewModel()
    @State private var isShowingEntry = false
    @State private var completedRecord: WorkoutRecord?
    @State private var completedStreakExtendedThisRun = false
    @State private var selectedDayEntry: DailyStatusEntry?
    @State private var isShowingStreakShare = false
    @State private var isShowingAchievements = false
    @State private var isShowingMonthlyReview = false
    @State private var monthlyReview: MonthlyReviewBuilder.Review?
    @State private var presentedMilestone: Milestone?
    private let calendar = Calendar.mondayFirst

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        PrimaryButton("今日の運動を記録する", systemImage: "plus.circle.fill") {
                            isShowingEntry = true
                        }

                        rescueTicketRow

                        VStack(alignment: .leading, spacing: 12) {
                            Text("今週 \(viewModel.progress.achievedCount)/\(viewModel.progress.totalDays) 達成")
                                .font(Typography.headline)
                                .foregroundStyle(Palette.textPrimary)

                            WeeklyCalendarView(statuses: viewModel.statuses, today: store.today, calendar: calendar) { entry in
                                selectedDayEntry = entry
                            }
                        }

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

                        decorationRow

                        Button {
                            buildAndPresentMonthlyReview()
                        } label: {
                            Label("先月のレビューを見る", systemImage: "doc.text.image")
                                .font(Typography.body)
                                .foregroundStyle(Palette.primaryDeep)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("monthly-review-button")

                        CatMessageView(message: viewModel.catMessage, state: viewModel.catState, decoration: viewModel.catDecoration)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("GOエクササイズ")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isShowingAchievements = true
                    } label: {
                        Image(systemName: "rosette")
                    }
                    .accessibilityLabel("バッジ")

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
                if presentedMilestone == nil, let milestone = viewModel.pendingMilestone {
                    presentedMilestone = milestone
                }
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
                RecordCompletionView(record: record, streakExtendedThisRun: completedStreakExtendedThisRun)
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
            .sheet(isPresented: $isShowingAchievements) {
                NavigationStack {
                    AchievementsListView(achievements: viewModel.achievements, onClose: {
                        isShowingAchievements = false
                    })
                }
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
        VStack(alignment: .leading, spacing: 14) {
            Text("今日も少しずつ")
                .font(Typography.headline)
                .foregroundStyle(Palette.textSecondary)

            HStack {
                StreakBadgeView(streak: viewModel.streak.currentStreak) {
                    guard viewModel.streak.currentStreak > 0 else { return }
                    isShowingStreakShare = true
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
    }

    private var rescueTicketRow: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.rescueTicketAvailable ? "ticket.fill" : "ticket")
                .foregroundStyle(viewModel.rescueTicketAvailable ? Palette.primary : Palette.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.rescueTicketAvailable ? "今月の保険チケット 1枚" : "今月のチケットは使用済み")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                Text("忙しい日も連続記録を 1日だけ守れます")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            if viewModel.rescueTicketAvailable, viewModel.todayStatus == .todayPending {
                Button("今日に使う") {
                    _ = viewModel.useRescueTicketToday()
                    viewModel.refresh(records: store.records)
                }
                .font(Typography.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Palette.primary, in: Capsule())
                .foregroundStyle(.white)
                .accessibilityIdentifier("rescue-use-button")
            }
        }
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var decorationRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(viewModel.catDecoration.accentColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                if !viewModel.catDecoration.symbolName.isEmpty {
                    Image(systemName: viewModel.catDecoration.symbolName)
                        .foregroundStyle(viewModel.catDecoration.accentColor)
                } else {
                    Text("🐱").font(.system(size: 22))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("現在の装飾: \(viewModel.catDecoration.displayName)")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                Text(viewModel.catDecoration.unlockHint)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
