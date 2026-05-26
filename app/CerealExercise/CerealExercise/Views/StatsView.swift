import SwiftUI

/// Phase 7.0 で新設した「記録」タブ。
/// 旧ホームに散らばっていた数字 (累計 / 週間ハイライト / 月次レビュー /
/// 体重) をすべてこのタブに集約し、ホームを猫劇場として浄化する。
/// Step 2 で Positive-Only な月間カレンダーや友達公園と並んで強化予定。
struct StatsView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()
    @State private var menstrualStore: MenstrualStore?
    @State private var presentedReview: PresentedReview?
    @State private var selectedDay: SelectedDay?
    private let calendar = Calendar.mondayFirst
    private let cycleSettings = CycleTrackingSettings()

    // `.sheet(item:)` で使うため Identifiable 化したラッパー。
    // `.sheet(isPresented:)` だと state 更新と content closure の評価順序の
    // 都合で「flag は true なのに review が nil → 空 sheet」になる事故が起きる。
    private struct PresentedReview: Identifiable {
        let review: MonthlyReviewBuilder.Review
        var id: String { review.monthLabel }
    }

    private struct SelectedDay: Identifiable {
        let date: Date
        let status: DailyStatus
        let records: [WorkoutRecord]
        var id: Date { date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    monthlyCalendarCard

                    if viewModel.weeklySummary.hasExerciseData {
                        WeeklyHighlightCard(summary: viewModel.weeklySummary)
                    }

                    LifetimeStatsCard(
                        achievedDays: viewModel.lifetimeStats.achievedDays,
                        usedDays: viewModel.lifetimeStats.usedDays
                    )

                    weightEntry
                    if cycleSettings.isEnabled, let menstrualStore {
                        menstrualEntry(store: menstrualStore)
                    }
                    monthlyReviewEntry
                }
                .padding(20)
            }
            .background(Palette.background)
            .navigationTitle("履歴")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                store.fetchRecords()
                viewModel.refresh(records: store.records)
                if menstrualStore == nil {
                    menstrualStore = MenstrualStore(context: modelContext)
                } else {
                    menstrualStore?.fetchEntries()
                }
            }
            .sheet(item: $presentedReview) { wrapper in
                MonthlyReviewSheet(review: wrapper.review)
            }
            .sheet(item: $selectedDay) { day in
                DayDetailSheet(date: day.date, records: day.records, status: day.status)
            }
        }
    }

    private var monthlyCalendarCard: some View {
        MonthlyCalendarView(
            records: store.records,
            today: store.today,
            menstrualDates: menstrualStore?.markedDates() ?? []
        ) { date in
            openDay(date)
        }
    }

    private func openDay(_ date: Date) {
        let dayRecords = store.records.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let restDays = RestDayResolver.restDaySet(
            for: date, records: store.records, today: store.today, calendar: calendar
        )
        let status = AchievementEvaluator.dailyStatus(
            for: date,
            records: store.records,
            restDays: restDays,
            today: store.today,
            calendar: calendar
        )
        selectedDay = SelectedDay(date: date, status: status, records: dayRecords)
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
        .accessibilityIdentifier("weight-link-stats")
    }

    /// 設定で「体調・周期を記録する」ON のときだけ表示。
    /// 同じ menstrualStore インスタンスを渡すので、入力した★は履歴カレンダーに
    /// 即時反映される (@Observable の同一インスタンス共有)。
    private func menstrualEntry(store: MenstrualStore) -> some View {
        NavigationLink {
            MenstrualEntryView(store: store)
        } label: {
            HStack(spacing: 12) {
                Text("★")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Color(red: 0.86, green: 0.36, blue: 0.45))
                VStack(alignment: .leading, spacing: 2) {
                    Text("生理日を記録する")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text("過去の日付もまとめて入力できます")
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
        .accessibilityIdentifier("menstrual-link-stats")
    }

    private var monthlyReviewEntry: some View {
        let hasPrevious = viewModel.previousMonthHasRecords
        return Button {
            let today = store.today
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: today) ?? today
            let review = MonthlyReviewBuilder.build(records: store.records, month: previousMonth, calendar: calendar)
            presentedReview = PresentedReview(review: review)
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
                        ? "一ヶ月のがんばりをカードでサマリー"
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
        .accessibilityIdentifier("monthly-review-stats-button")
    }
}
