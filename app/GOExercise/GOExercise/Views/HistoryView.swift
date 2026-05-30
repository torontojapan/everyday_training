import SwiftUI

struct HistoryView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = HistoryViewModel()
    @State private var selectedDay: SelectedDay?
    @State private var menstrualStore: MenstrualStore?
    /// 過去の運動履歴一覧。デフォルトは最小化し、ヘッダをタップで展開する。
    @State private var isHistoryExpanded = false
    var onClose: (() -> Void)? = nil

    private let calendar = Calendar.mondayFirst
    private let cycleSettings = CycleTrackingSettings()
    @Environment(RescueTicketStore.self) private var rescueTicketStore
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        // 「2026/05/25」→「5月25日(月)」。曜日入りの方が
        // 「いつのことか」直感的に把握できる。
        formatter.dateFormat = "M月d日(E)"
        return formatter
    }()

    private struct SelectedDay: Identifiable {
        let date: Date
        let status: DailyStatus
        let records: [WorkoutRecord]
        var id: Date { date }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                MonthlyCalendarView(
                    records: store.records,
                    today: store.today,
                    menstrualDates: cycleSettings.isEnabled
                        ? (menstrualStore?.markedDates() ?? [])
                        : [],
                    rescuedDates: rescueTicketStore.rescuedDates()
                ) { date in
                    open(date: date)
                }

                if viewModel.groupedByDate.isEmpty {
                    EmptyStateView(message: "まだ記録がないよ。今日から始めよう")
                        .padding(.top, 20)
                } else {
                    // 過去の運動履歴は最小化して最下部に。ヘッダをタップで展開。
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isHistoryExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "list.bullet.rectangle.portrait.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Palette.primary)
                                Text("運動履歴")
                                    .font(Typography.sectionTitle)
                                    .foregroundStyle(Palette.textPrimary)
                                Text("合計\(viewModel.groupedByDate.count)日")
                                    .font(Typography.caption)
                                    .foregroundStyle(Palette.textSecondary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Palette.textSecondary)
                                    .rotationEffect(.degrees(isHistoryExpanded ? 180 : 0))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("history-toggle")
                        .accessibilityLabel("運動履歴 合計\(viewModel.groupedByDate.count)日")
                        .accessibilityValue(isHistoryExpanded ? "展開中" : "折りたたみ中")

                        if isHistoryExpanded {
                            ForEach(viewModel.groupedByDate.indices, id: \.self) { index in
                                let date = viewModel.groupedByDate[index].0
                                let records = viewModel.groupedByDate[index].1
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(dateFormatter.string(from: date))
                                        .font(Typography.sectionTitle)
                                        .foregroundStyle(Palette.textPrimary)

                                    ForEach(records) { record in
                                        HistoryRowView(record: record)
                                    }
                                }
                                .padding(.horizontal, 4)
                                .transition(.opacity)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("履歴")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if let onClose {
                        onClose()
                    } else {
                        dismiss()
                    }
                } label: {
                    Label("ホーム", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(Typography.body)
                }
                .accessibilityLabel("ホームへ戻る")
            }
        }
        .onAppear {
            store.fetchRecords()
            viewModel.refresh(records: store.records)
            if menstrualStore == nil {
                menstrualStore = MenstrualStore(context: modelContext)
            } else {
                menstrualStore?.fetchEntries()
            }
        }
        .sheet(item: $selectedDay) { day in
            DayDetailSheet(date: day.date, records: day.records, status: day.status)
        }
    }

    private func open(date: Date) {
        let records = store.records.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let restDays = RestDayResolver.restDaySet(for: date, records: store.records, today: store.today, calendar: calendar)
        let status = AchievementEvaluator.dailyStatus(
            for: date,
            records: store.records,
            restDays: restDays,
            rescuedDates: rescueTicketStore.rescuedDates(),
            today: store.today,
            calendar: calendar
        )
        selectedDay = SelectedDay(date: date, status: status, records: records)
    }
}
