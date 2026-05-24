import SwiftUI

struct WeeklyCalendarView: View {
    let statuses: [DailyStatusEntry]
    let today: Date
    var calendar: Calendar = .mondayFirst
    var onDayTap: ((DailyStatusEntry) -> Void)? = nil

    private let weekdays = ["月", "火", "水", "木", "金", "土", "日"]
    private let weekdayLabels = ["月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日", "日曜日"]

    @State private var todayBreathes = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(statuses.enumerated()), id: \.element.id) { index, entry in
                Button {
                    onDayTap?(entry)
                } label: {
                    cell(index: index, entry: entry)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(weekdayLabels.indices.contains(index) ? weekdayLabels[index] : "曜日")
                .accessibilityValue(accessibilityValue(for: entry))
                .accessibilityHint("タップでこの日の記録を表示")
            }
        }
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onAppear {
            withAnimation(Motion.gentle.repeatForever(autoreverses: true)) {
                todayBreathes = true
            }
        }
    }

    private func cell(index: Int, entry: DailyStatusEntry) -> some View {
        VStack(spacing: 8) {
            Text(weekdays.indices.contains(index) ? weekdays[index] : "")
                .font(Typography.caption)
            Text(entry.status.symbol)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .frame(width: 38, height: 38)
                .background(background(for: entry), in: Circle())
        }
        .foregroundStyle(Palette.textPrimary)
        .frame(maxWidth: .infinity)
        .scaleEffect(calendar.isDate(entry.date, inSameDayAs: today) && todayBreathes ? 1.05 : 1)
        .contentShape(Rectangle())
    }

    private func background(for entry: DailyStatusEntry) -> Color {
        if calendar.isDate(entry.date, inSameDayAs: today) {
            return Palette.primary.opacity(0.95)
        }

        switch entry.status {
        case .achieved, .todayAchieved: return Palette.success.opacity(0.65)
        case .rest: return Palette.restDay.opacity(0.75)
        case .missed: return Palette.missed.opacity(0.28)
        case .future, .todayPending: return Palette.secondary.opacity(0.45)
        }
    }

    private func accessibilityValue(for entry: DailyStatusEntry) -> String {
        if calendar.isDate(entry.date, inSameDayAs: today) {
            switch entry.status {
            case .todayAchieved: return "今日、達成済み"
            case .todayPending: return "今日、未達成"
            default: break
            }
        }

        switch entry.status {
        case .achieved, .todayAchieved: return "達成済み"
        case .rest: return "休養日"
        case .missed: return "未達成"
        case .future: return "未来"
        case .todayPending: return "今日"
        }
    }
}
