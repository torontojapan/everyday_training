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
                    catGreetingStrip

                    monthlyCalendarCard

                    if viewModel.weeklySummary.hasExerciseData {
                        WeeklyHighlightCard(summary: viewModel.weeklySummary)
                    }

                    LifetimeStatsCard(
                        achievedDays: viewModel.lifetimeStats.achievedDays,
                        usedDays: viewModel.lifetimeStats.usedDays
                    )

                    if cycleSettings.isEnabled, let menstrualStore {
                        menstrualEntry(store: menstrualStore)
                    }
                    monthlyReviewEntry
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

    /// 履歴タブ最上段の猫アイコン + 一言ストリップ (Claude #4)。
    /// 選択中の猫キャラ avatar + 今週の達成率に応じたコメント。
    private var catGreetingStrip: some View {
        let breed = UserCatPreferences.shared.myCat
        let rate = viewModel.progress.rate
        let message: String
        switch rate {
        case 0.8...:    message = "今週、絶好調!"
        case 0.5..<0.8: message = "今週いいペース 👍"
        case 0.1..<0.5: message = "もう少しで折り返しだよ"
        default:        message = "今週は無理せず、できる時に"
        }
        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(breed.tintColor.opacity(0.25)).frame(width: 40, height: 40)
                Image(breed.avatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            }
            Text(message)
                .font(Typography.caption)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(breed.displayName)からのひとこと: \(message)")
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
