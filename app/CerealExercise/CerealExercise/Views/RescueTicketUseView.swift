import SwiftData
import SwiftUI

struct RescueTicketUseView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var workoutStore: WorkoutStore?
    @State private var pendingDate: Date?
    @State private var resultMessage: ResultMessage?
    private let calendar = Calendar.mondayFirst
    private let store = RescueTicketStore()

    private var allowance: Int { RescueTicketAllowance.current() }
    private var hasTicketAvailable: Bool {
        store.hasTicketAvailable(today: Date(), allowance: allowance)
    }
    private var remaining: Int { store.remainingTickets(today: Date(), allowance: allowance) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summaryCard
                instructionCard

                if let workoutStore {
                    MonthlyCalendarView(
                        records: workoutStore.records,
                        today: workoutStore.today,
                        rescuedDates: store.rescuedDates(),
                        highlightStatuses: [.missed]
                    ) { date in
                        handleTap(on: date, store: workoutStore)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }

                legend

                if !store.rescuedDates().isEmpty {
                    rescuedHistory
                }
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("保険チケットを使う")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if workoutStore == nil {
                workoutStore = WorkoutStore(context: modelContext)
            }
        }
        .confirmationDialog(
            confirmTitle,
            isPresented: Binding(get: { pendingDate != nil },
                                  set: { if !$0 { pendingDate = nil } }),
            titleVisibility: .visible,
            presenting: pendingDate
        ) { date in
            Button("適用する") {
                apply(date: date)
            }
            Button("キャンセル", role: .cancel) {
                pendingDate = nil
            }
        } message: { date in
            Text("\(format(date)) に1枚使うと、今月の残り枚数が0になります。連続記録が途切れずに済みます。")
        }
        .alert(item: $resultMessage) { message in
            Alert(title: Text(message.title), message: Text(message.text), dismissButton: .default(Text("OK")))
        }
    }

    private var confirmTitle: String {
        if let pendingDate {
            return "\(format(pendingDate)) に保険チケットを適用しますか？"
        }
        return ""
    }

    // MARK: - Cards

    private var summaryCard: some View {
        HStack(spacing: 14) {
            Image(systemName: hasTicketAvailable ? "ticket.fill" : "ticket")
                .font(.system(size: 28))
                .foregroundStyle(hasTicketAvailable ? Palette.primary : Palette.textSecondary.opacity(0.5))
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(hasTicketAvailable ? Palette.primary.opacity(0.18) : Palette.chipBackground.opacity(0.5))
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("今月のチケット: \(remaining) / \(allowance)枚 残り")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text("月 \(allowance) 枚配布\(allowance > 1 ? " (体調・周期 ON で +1)" : "")。忙しい日に過去にさかのぼって適用できます。")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var instructionCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .foregroundStyle(Palette.primaryDeep)
            Text("カレンダーで × の日(未達成) をタップ → 確認 → 適用")
                .font(Typography.caption)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
        }
        .padding(12)
        .background(Palette.chipBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("マークの意味")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 14) {
                legendItem(symbol: "×", label: "未達成 (適用可)", border: true)
                legendItem(symbol: "○", label: "達成済み")
                legendItem(symbol: "休", label: "自動休養")
                Spacer()
            }
            HStack(spacing: 14) {
                legendItem(icon: "ticket.fill", label: "チケット適用済み")
                legendItem(icon: "star.fill", label: "★ 体調マーク")
                Spacer()
            }
        }
    }

    private func legendItem(symbol: String, label: String, border: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(symbol)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .frame(width: 22, height: 22)
                .background(Palette.surface, in: Circle())
                .overlay(Circle().strokeBorder(border ? Palette.primary : .clear, lineWidth: 2))
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func legendItem(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Palette.primaryDeep)
                .frame(width: 22, height: 22)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var rescuedHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("これまでに使った日")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            ForEach(Array(store.rescuedDates()).sorted(by: >), id: \.self) { date in
                HStack {
                    Image(systemName: "ticket.fill")
                        .foregroundStyle(Palette.primaryDeep)
                    Text(format(date))
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Actions

    private func handleTap(on date: Date, store: WorkoutStore) {
        let dayStart = calendar.startOfDay(for: date)

        if self.store.rescuedDates().contains(dayStart) {
            resultMessage = ResultMessage(title: "この日には既に適用済み", text: "保険チケットは同じ日に重ねて使えません。")
            return
        }
        _ = allowance  // capture in case extended later

        let restDays = RestDayResolver.restDaySet(for: date, records: store.records, today: store.today, calendar: calendar)
        let status = AchievementEvaluator.dailyStatus(
            for: date,
            records: store.records,
            restDays: restDays,
            today: store.today,
            calendar: calendar
        )

        switch status {
        case .missed, .todayPending:
            guard hasTicketAvailable else {
                resultMessage = ResultMessage(title: "今月のチケットを使い切っています", text: "翌月になると 1 枚補充されます。")
                return
            }
            pendingDate = date
        case .achieved, .todayAchieved:
            resultMessage = ResultMessage(title: "この日は達成済み", text: "保険チケットは未達成 (×) の日にだけ使えます。")
        case .rest:
            resultMessage = ResultMessage(title: "この日は自動休養日", text: "もう連続記録は維持されています。チケット不要です。")
        case .future:
            resultMessage = ResultMessage(title: "未来の日付", text: "チケットは過去または今日の日にだけ適用できます。")
        }
    }

    private func apply(date: Date) {
        let success = store.useTicket(on: date, allowance: allowance)
        pendingDate = nil
        if success {
            resultMessage = ResultMessage(title: "適用しました ✅", text: "\(format(date)) に保険チケットを使いました。連続記録が守られます。")
        } else {
            resultMessage = ResultMessage(title: "適用できませんでした", text: "今月のチケットを使い切っています。")
        }
    }

    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 (E)"
        return formatter.string(from: date)
    }
}

private struct ResultMessage: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}
