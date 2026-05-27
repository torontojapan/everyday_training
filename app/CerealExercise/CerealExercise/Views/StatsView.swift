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
    private let rescueTicketStore = RescueTicketStore()

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
                VStack(alignment: .leading, spacing: 16) {
                    monthlyCalendarCard

                    if viewModel.weeklySummary.hasExerciseData {
                        // 折りたたみ (ユーザー要望): タップで展開、デフォルトは閉じる。
                        // subtitle に「使ったカテゴリ / 合計分」だけ出して中身は隠す。
                        CollapsibleSection(
                            persistenceKey: "stats.weeklyHighlight",
                            title: "今週のハイライト",
                            subtitle: weeklyHighlightSubtitle,
                            icon: "sparkles"
                        ) {
                            WeeklyHighlightCard(summary: viewModel.weeklySummary)
                        }
                    }

                    if cycleSettings.isEnabled, let menstrualStore {
                        menstrualEntry(store: menstrualStore)
                    }
                    monthlyReviewEntry

                    // 「これまでの記録」(累計達成日 / 使用日) は一番下に移動
                    // (ユーザー要望)。日次/週次の文脈とは別の長期統計なので
                    // フッター位置で「振り返り終わりの後押し」として置く。
                    LifetimeStatsCard(
                        achievedDays: viewModel.lifetimeStats.achievedDays,
                        usedDays: viewModel.lifetimeStats.usedDays
                    )
                }
                .padding(20)
            }
            .background(Palette.background)
            .navigationTitle("履歴")
            // Claude #1: .large はタイトルが画面 1/4 を占めて情報密度を下げる。
            // タブバーに「履歴」アイコンが既にあるので冗長。.inline で詰める。
            .navigationBarTitleDisplayMode(.inline)
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

    /// 「今週のハイライト」折りたたみ中の subtitle。
    /// 合計分 + 使ったカテゴリ数を要約。
    private var weeklyHighlightSubtitle: String {
        let summary = viewModel.weeklySummary
        let minutes = summary.totalDurationSeconds / 60
        if summary.usedCategories.isEmpty {
            return "記録なし"
        }
        return "合計 \(minutes) 分 / \(summary.usedCategories.count) カテゴリ"
    }

    private var monthlyCalendarCard: some View {
        // 体調・周期トラッキングが OFF のときは★を非表示。データ自体は
        // 残しておくので再 ON で復活する。
        let markedDates: Set<Date> = cycleSettings.isEnabled
            ? (menstrualStore?.markedDates() ?? [])
            : []
        return MonthlyCalendarView(
            records: store.records,
            today: store.today,
            menstrualDates: markedDates,
            rescuedDates: rescueTicketStore.rescuedDates()
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
            rescuedDates: rescueTicketStore.rescuedDates(),
            today: store.today,
            calendar: calendar
        )
        selectedDay = SelectedDay(date: date, status: status, records: dayRecords)
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
