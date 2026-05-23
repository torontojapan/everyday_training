import SwiftUI

struct HomeView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var viewModel = HomeViewModel()
    @State private var isShowingEntry = false
    @State private var completedRecord: WorkoutRecord?
    @State private var completedStreakExtendedThisRun = false
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

                        VStack(alignment: .leading, spacing: 12) {
                            Text("今週 \(viewModel.progress.achievedCount)/\(viewModel.progress.totalDays) 達成")
                                .font(Typography.headline)
                                .foregroundStyle(Palette.textPrimary)

                            WeeklyCalendarView(statuses: viewModel.statuses, today: store.today, calendar: calendar)
                        }

                        CatMessageView(message: viewModel.catMessage, state: viewModel.catState)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("シリアルエクササイズ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
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
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("今日も少しずつ")
                .font(Typography.title)
                .foregroundStyle(Palette.textPrimary)
                .minimumScaleFactor(0.8)

            HStack {
                StreakBadgeView(streak: viewModel.streak.currentStreak)
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

    private var remainingTimeText: String {
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: store.today) ?? Date()
        let hours = max(0, calendar.dateComponents([.hour], from: Date(), to: endOfDay).hour ?? 0)
        return "あと\(hours)時間"
    }
}
