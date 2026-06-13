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
    /// 週シェアシートの atomic payload (Codex round4 priority 2)。
    /// summary と label を 1 つのアイテムで束ねて `.sheet(item:)` に渡すこと
    /// で、両者が別ソースから drift する可能性を構造的に排除する。
    @State private var pendingWeeklyShare: WeeklySharePayload?
    /// 累計シェアシートの atomic payload。同様に achievedDays / usedDays を束ねる。
    @State private var pendingLifetimeShare: LifetimeSharePayload?
    /// 今週 / 累計 を「先月のハイライト」と同じカードで提示するための presentation。
    @State private var presentedHighlight: HighlightPresentation?

    private struct HighlightPresentation: Identifiable {
        let review: MonthlyReviewBuilder.Review
        let title: String
        let badge: String
        let streakLabel: String
        let gradient: [Color]
        var id: String { title + review.monthLabel }
    }

    private struct WeeklySharePayload: Identifiable {
        let summary: ExerciseTrendSummary.WeeklySummary
        let weekLabel: String
        let day: Date
        var id: Date { day }
    }

    private struct LifetimeSharePayload: Identifiable {
        let achievedDays: Int
        let usedDays: Int
        let snapshottedAt: Date
        var id: Date { snapshottedAt }
    }
    private let calendar = Calendar.mondayFirst
    private let cycleSettings = CycleTrackingSettings()
    @Environment(RescueTicketStore.self) private var rescueTicketStore
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(ReferralStore.self) private var referralStore
    @State private var showPremiumPaywall = false

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

                    // フリーズ (設定から移動)。折りたたみで残枚数だけ subtitle 表示。
                    CollapsibleSection(
                        persistenceKey: "stats.rescueTicket",
                        title: "保険チケット",
                        subtitle: rescueTicketSubtitle,
                        icon: rescueTicketRemaining > 0 ? "ticket.fill" : "ticket"
                    ) {
                        rescueTicketContent
                    }

                    if viewModel.weeklySummary.hasExerciseData {
                        weeklyHighlightEntry
                    }

                    monthlyReviewEntry

                    // 「これまでの記録」は一番下に。先月のレビューと同じ entry-row 形式。
                    // tap → LifetimeStatsShareSheet (= ブランドカード画面に遷移)。
                    lifetimeStatsEntry

                    // 友達タブと同じ「このアプリを友達にシェア」を最下部にも置く。
                    shareAppEntry

                    // 過去の運動履歴。デフォルト折りたたみ、タップで日別一覧を展開。
                    if !groupedRecords.isEmpty {
                        CollapsibleSection(
                            persistenceKey: "stats.workoutHistory",
                            title: "運動履歴",
                            subtitle: "合計\(groupedRecords.count)日",
                            icon: "list.bullet.rectangle.portrait.fill"
                        ) {
                            workoutHistoryContent
                        }
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
            .sheet(item: $presentedHighlight) { highlight in
                MonthlyReviewSheet(
                    review: highlight.review,
                    badge: highlight.badge,
                    title: highlight.title,
                    streakLabel: highlight.streakLabel,
                    gradient: highlight.gradient
                )
            }
            .sheet(isPresented: $showPremiumPaywall) {
                PremiumPaywallSheet(store: storeKit, context: .freeze)
            }
            .sheet(item: $selectedDay) { day in
                DayDetailSheet(date: day.date, records: day.records, status: day.status)
            }
            .sheet(item: $pendingWeeklyShare) { payload in
                WeeklyHighlightShareSheet(
                    summary: payload.summary,
                    weekLabel: payload.weekLabel,
                    isPresented: Binding(
                        get: { pendingWeeklyShare != nil },
                        set: { if !$0 { pendingWeeklyShare = nil } }
                    )
                )
            }
            .sheet(item: $pendingLifetimeShare) { payload in
                LifetimeStatsShareSheet(
                    achievedDays: payload.achievedDays,
                    usedDays: payload.usedDays,
                    isPresented: Binding(
                        get: { pendingLifetimeShare != nil },
                        set: { if !$0 { pendingLifetimeShare = nil } }
                    )
                )
            }
        }
    }

    /// 全記録を日付降順でグルーピング (新しい日が上)。運動履歴セクション用。
    private var groupedRecords: [(Date, [WorkoutRecord])] {
        let grouped = Dictionary(grouping: store.records) { calendar.startOfDay(for: $0.date) }
        return grouped
            .map { ($0.key, $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.0 > $1.0 }
    }

    private var workoutHistoryDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter
    }

    @ViewBuilder
    private var workoutHistoryContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groupedRecords.indices, id: \.self) { index in
                let date = groupedRecords[index].0
                let records = groupedRecords[index].1
                VStack(alignment: .leading, spacing: 8) {
                    Text(workoutHistoryDateFormatter.string(from: date))
                        .font(Typography.sectionTitle)
                        .foregroundStyle(Palette.textPrimary)
                    ForEach(records) { record in
                        HistoryRowView(record: record)
                    }
                }
            }
        }
    }

    /// 指定日が属する週の範囲ラベル「5/26 - 6/1」。share card の小見出し用。
    /// タップ時の date snapshot から両方 (summary, label) を作るために引数化。
    private func weekLabel(for date: Date) -> String {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d"
        let start = f.string(from: week.start)
        let endDate = calendar.date(byAdding: .day, value: -1, to: week.end) ?? week.end
        let end = f.string(from: endDate)
        return "\(start) - \(end)"
    }

    private var rescueAllowance: Int {
        RescueTicketAllowance.current(isPremium: storeKit.isPremiumActive,
                                      referralBonus: referralStore.currentAccountFreezeBonus)
    }

    /// 連続記録フリーズの今月残り枚数 (a11y / subtitle / icon の出し分けに使う)。
    private var rescueTicketRemaining: Int {
        rescueTicketStore.remainingTickets(today: Date(), allowance: rescueAllowance)
    }

    /// フリーズ折りたたみ中の subtitle。今月残を 1 行で表示。
    private var rescueTicketSubtitle: String {
        "今月 \(rescueTicketRemaining) / \(rescueAllowance) 回 残り"
    }

    /// フリーズ展開時の中身: 説明 + 「使う日を選んで適用」リンク + 非加入なら Premium 訴求。
    private var rescueTicketContent: some View {
        let allowance = rescueAllowance
        let remaining = rescueTicketStore.remainingTickets(today: Date(), allowance: allowance)
        let available = remaining > 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: available ? "ticket.fill" : "ticket")
                    .font(.system(size: 22))
                    .foregroundStyle(available ? Palette.primary : Palette.textSecondary.opacity(0.5))
                VStack(alignment: .leading, spacing: 4) {
                    Text("今月 \(remaining) / \(allowance) 回 残り")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                    Text("忙しい日に連続記録を守れます。毎月リセットされます。")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            NavigationLink {
                RescueTicketUseView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 18, weight: .heavy))
                    Text("使う日を選んで適用")
                        .font(Typography.body)
                        .fontWeight(.heavy)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .heavy))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Palette.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Palette.primary.opacity(0.30), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("rescue-use-link")
            .accessibilityLabel("保険チケットを使う日を選ぶ")

            // 非加入者には「GOプレミアムで月4回」のアップセル (¥1,000 単発購入は廃止)。
            if !storeKit.isPremiumActive {
                Divider().opacity(0.4)
                Button {
                    showPremiumPaywall = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16, weight: .heavy))
                        Text("GOプレミアムで保険チケットが月4回に")
                            .font(Typography.body)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .heavy))
                            .opacity(0.7)
                    }
                    .foregroundStyle(Palette.primary)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Palette.primary.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Palette.primary.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("rescue-premium-upsell")
                .accessibilityLabel("GOプレミアムを見る")
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

    /// 今週のハイライト entry-row。「先月のレビューを見る」と同じ tap → sheet パターン。
    /// tap → atomic snapshot を payload に詰めて `WeeklyHighlightShareSheet` を提示。
    private var weeklyHighlightEntry: some View {
        Button {
            // 1 つの `day` を refresh / summary / label の基準日として共有
            // (Codex round5/6 で確立した atomic 化を維持)。
            let day = store.today
            viewModel.refresh(records: store.records, anchorDate: day)
            guard viewModel.weeklySummary.hasExerciseData else { return }
            // 「先月のハイライト」と同じ項目・カードで今週を表示する。
            presentedHighlight = HighlightPresentation(
                review: MonthlyReviewBuilder.weekly(records: store.records, weekContaining: day, today: day, rescuedDates: rescueTicketStore.rescuedDates(), calendar: calendar),
                title: "今週のハイライト",
                badge: "WEEKLY HIGHLIGHT",
                streakLabel: "今週の最長連続",
                gradient: MonthlyReviewSheet.weeklyGradient
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.primaryDeep)
                VStack(alignment: .leading, spacing: 2) {
                    Text("今週のハイライト")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text(weeklyHighlightSubtitle)
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
        .accessibilityIdentifier("weekly-highlight-entry")
        .accessibilityLabel("今週のハイライトを共有カードで開く")
    }

    /// これまでの記録 entry-row。tap → `LifetimeStatsShareSheet`。
    private var lifetimeStatsEntry: some View {
        Button {
            // Codex round 反映: 他の StatsView 操作と同じ store.today を使い、
            // 注入クロック (テスト) と整合性を保つ。
            let day = store.today
            viewModel.refresh(records: store.records, anchorDate: day)
            // 「先月のハイライト」と同じ項目・カードで累計を表示する。
            presentedHighlight = HighlightPresentation(
                review: MonthlyReviewBuilder.lifetime(records: store.records, today: day, rescuedDates: rescueTicketStore.rescuedDates(), calendar: calendar),
                title: "これまでのハイライト",
                badge: "ALL-TIME HIGHLIGHT",
                streakLabel: "最長連続",
                gradient: MonthlyReviewSheet.lifetimeGradient
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.primaryDeep)
                VStack(alignment: .leading, spacing: 2) {
                    Text("これまでのハイライト")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text(lifetimeStatsSubtitle)
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
        .accessibilityIdentifier("lifetime-stats-entry")
        .accessibilityLabel("これまでのハイライトを共有カードで開く")
    }

    /// これまでの記録 entry-row の subtitle。
    /// `usedDays` は `LifetimeStatsCalculator` で `max(1, ...)` クランプされる
    /// ため > 0 ガードは常に true で死コード化していた (Codex 指摘)。
    /// 実際の「まだ記録がない」判定は records が空かどうかで行う。
    private var lifetimeStatsSubtitle: String {
        let stats = viewModel.lifetimeStats
        guard !store.records.isEmpty else { return "まだ記録がありません" }
        let rate = Int((Double(stats.achievedDays) / Double(stats.usedDays) * 100).rounded())
        return "累計 \(stats.achievedDays) 日達成 / 使用 \(stats.usedDays) 日 (\(rate)%)"
    }

    private var monthlyReviewEntry: some View {
        let hasPrevious = viewModel.previousMonthHasRecords
        return Button {
            let today = store.today
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: today) ?? today
            let review = MonthlyReviewBuilder.build(records: store.records, month: previousMonth, today: today, rescuedDates: rescueTicketStore.rescuedDates(), calendar: calendar)
            presentedReview = PresentedReview(review: review)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.image")
                    .font(.system(size: 22))
                    .foregroundStyle(hasPrevious ? Palette.primaryDeep : Palette.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("先月のハイライト")
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

    /// 「このアプリを友達にシェア」。友達タブの `shareAppCard` と同一構成で、
    /// 共有 URL / 文面は [[AppSharingConfig]] に集約済み。
    private var shareAppEntry: some View {
        ShareLink(
            item: AppSharingConfig.shareURL,
            subject: Text(AppSharingConfig.shareSubject),
            message: Text(AppSharingConfig.shareMessage)
        ) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Palette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("このアプリを友達にシェア")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                    Text("インストール用リンクが LINE / メッセージなどで送れます")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("share-app-button-stats")
        .accessibilityLabel("このアプリを友達にシェア")
    }
}
