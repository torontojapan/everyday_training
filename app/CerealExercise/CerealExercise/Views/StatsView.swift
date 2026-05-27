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
    @State private var isShowingWeeklyShare = false
    @State private var isShowingLifetimeShare = false
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
                    // ユーザー指定の並び順:
                    // 1. カレンダー → 2. 生理日入力 → 3. 保険チケット →
                    // 4. 今週のハイライト → 5. 先月のレビュー → 6. これまでの記録
                    monthlyCalendarCard

                    if cycleSettings.isEnabled, let menstrualStore {
                        menstrualEntry(store: menstrualStore)
                    }

                    // 保険チケット (設定から移動)。折りたたみで残枚数だけ subtitle 表示。
                    CollapsibleSection(
                        persistenceKey: "stats.rescueTicket",
                        title: "保険チケット",
                        subtitle: rescueTicketSubtitle,
                        icon: rescueTicketRemaining > 0 ? "ticket.fill" : "ticket"
                    ) {
                        rescueTicketContent
                    }

                    if viewModel.weeklySummary.hasExerciseData {
                        CollapsibleSection(
                            persistenceKey: "stats.weeklyHighlight",
                            title: "今週のハイライト",
                            subtitle: weeklyHighlightSubtitle,
                            icon: "sparkles"
                        ) {
                            VStack(spacing: 12) {
                                WeeklyHighlightCard(summary: viewModel.weeklySummary)
                                Button {
                                    // 共有直前に refresh して、週またぎでも
                                    // summary と label がズレないようにする
                                    // (Codex round1 priority 1)。
                                    viewModel.refresh(records: store.records)
                                    isShowingWeeklyShare = true
                                } label: {
                                    Label("SNSで共有", systemImage: "square.and.arrow.up")
                                        .font(Typography.caption)
                                        .foregroundStyle(Palette.primaryDeep)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Palette.primary.opacity(0.12), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("weekly-highlight-share")
                                .accessibilityLabel("今週のハイライトを SNS で共有")
                            }
                        }
                    }

                    monthlyReviewEntry

                    // 「これまでの記録」(累計達成日 / 使用日) は一番下に。
                    // 長期統計を「振り返り終わりの後押し」として置く。
                    VStack(spacing: 12) {
                        LifetimeStatsCard(
                            achievedDays: viewModel.lifetimeStats.achievedDays,
                            usedDays: viewModel.lifetimeStats.usedDays
                        )
                        Button {
                            viewModel.refresh(records: store.records)
                            isShowingLifetimeShare = true
                        } label: {
                            Label("SNSで共有", systemImage: "square.and.arrow.up")
                                .font(Typography.caption)
                                .foregroundStyle(Palette.primaryDeep)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(Palette.primary.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("lifetime-stats-share")
                        .accessibilityLabel("これまでの記録を SNS で共有")
                    }
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
            .sheet(isPresented: $isShowingWeeklyShare) {
                WeeklyHighlightShareSheet(
                    summary: viewModel.weeklySummary,
                    weekLabel: currentWeekLabel,
                    isPresented: $isShowingWeeklyShare
                )
            }
            .sheet(isPresented: $isShowingLifetimeShare) {
                LifetimeStatsShareSheet(
                    achievedDays: viewModel.lifetimeStats.achievedDays,
                    usedDays: viewModel.lifetimeStats.usedDays,
                    isPresented: $isShowingLifetimeShare
                )
            }
        }
    }

    /// 「5/26 - 6/1」のような今週の範囲ラベル。share card の小見出しに使う。
    private var currentWeekLabel: String {
        let today = store.today
        guard let week = calendar.dateInterval(of: .weekOfYear, for: today) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d"
        let start = f.string(from: week.start)
        // dateInterval.end は exclusive なので 1 日前を週末として表示
        let endDate = calendar.date(byAdding: .day, value: -1, to: week.end) ?? week.end
        let end = f.string(from: endDate)
        return "\(start) - \(end)"
    }

    /// 保険チケットの今月残り枚数 (a11y / subtitle / icon の出し分けに使う)。
    private var rescueTicketRemaining: Int {
        let allowance = RescueTicketAllowance.current(cycleSettings: cycleSettings)
        return rescueTicketStore.remainingTickets(today: Date(), allowance: allowance)
    }

    /// 保険チケット折りたたみ中の subtitle。残り枚数を 1 行で表示。
    private var rescueTicketSubtitle: String {
        let allowance = RescueTicketAllowance.current(cycleSettings: cycleSettings)
        let remaining = rescueTicketStore.remainingTickets(today: Date(), allowance: allowance)
        return "今月 \(remaining) / \(allowance) 枚 残り"
    }

    /// 保険チケット展開時の中身: 説明 + 「使う日を選んで適用」リンク。
    private var rescueTicketContent: some View {
        let allowance = RescueTicketAllowance.current(cycleSettings: cycleSettings)
        let remaining = rescueTicketStore.remainingTickets(today: Date(), allowance: allowance)
        let available = remaining > 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: available ? "ticket.fill" : "ticket")
                    .font(.system(size: 22))
                    .foregroundStyle(available ? Palette.primary : Palette.textSecondary.opacity(0.5))
                VStack(alignment: .leading, spacing: 4) {
                    Text("今月 \(remaining) / \(allowance) 枚 残り")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                    Text(allowance > 1
                         ? "忙しい日に連続記録を守れます (体調・周期 ON で +1 枚)"
                         : "忙しい日に1日だけ連続記録を守れます")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            NavigationLink {
                RescueTicketUseView()
            } label: {
                Label("使う日を選んで適用", systemImage: "calendar.badge.checkmark")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.primaryDeep)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Palette.primary.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("rescue-use-link")
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
