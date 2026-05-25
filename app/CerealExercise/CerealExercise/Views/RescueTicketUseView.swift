import SwiftUI

struct RescueTicketUseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date = Date()
    @State private var isShowingConfirm = false
    @State private var resultMessage: String?
    private let calendar = Calendar.mondayFirst
    private let store = RescueTicketStore()

    private var hasTicketAvailable: Bool {
        store.hasTicketAvailable(today: selectedDate)
    }

    private var rescuedDates: [Date] {
        Array(store.rescuedDates()).sorted(by: >)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("適用する日を選ぶ")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)

                    DatePicker(
                        "",
                        selection: $selectedDate,
                        in: minDate...maxDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding(12)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .tint(Palette.primary)
                }

                applyButton

                if let resultMessage {
                    Text(resultMessage)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if !rescuedDates.isEmpty {
                    rescuedHistory
                }

                hintCard
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("保険チケットを使う")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "この日に保険チケットを適用しますか？",
            isPresented: $isShowingConfirm,
            titleVisibility: .visible
        ) {
            Button("適用する") {
                applyTicket()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(format(selectedDate)) に1枚使うと、今月の残り枚数が0になります")
        }
    }

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
                Text(hasTicketAvailable ? "今月のチケット: 1枚 残り" : "今月のチケット: 0枚 (使用済み)")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text("月 1 枚配布。忙しい日に過去にさかのぼって適用できます。")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var applyButton: some View {
        Button {
            isShowingConfirm = true
        } label: {
            Label("選んだ日に適用", systemImage: "checkmark.circle.fill")
                .font(Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(hasTicketAvailable ? Palette.primary : Palette.textSecondary.opacity(0.4),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .disabled(!hasTicketAvailable)
        .accessibilityIdentifier("apply-rescue-button")
    }

    private var rescuedHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("これまでに使った日")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            ForEach(rescuedDates, id: \.self) { date in
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Palette.success)
                    Text(format(date))
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var hintCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("使い方ヒント", systemImage: "lightbulb.fill")
                .font(Typography.headline)
                .foregroundStyle(Palette.primaryDeep)
            bullet("月に 1 枚、毎月初に新しいチケットが配られます")
            bullet("適用すると、その日が未記録でも連続記録が途切れません")
            bullet("適用済みの日は ★ などでカレンダーに表示されます")
        }
        .padding(14)
        .background(Palette.chipBackground.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("・").font(Typography.caption)
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    // MARK: - Helpers

    private var maxDate: Date {
        calendar.startOfDay(for: Date())
    }

    private var minDate: Date {
        // 過去 60 日まで遡れる
        calendar.date(byAdding: .day, value: -60, to: maxDate) ?? maxDate
    }

    private func applyTicket() {
        let success = store.useTicket(on: selectedDate)
        if success {
            resultMessage = "\(format(selectedDate)) に保険チケットを適用しました ✅"
        } else {
            resultMessage = "適用できませんでした。今月のチケットを使い切っています。"
        }
    }

    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 (E)"
        return formatter.string(from: date)
    }
}
