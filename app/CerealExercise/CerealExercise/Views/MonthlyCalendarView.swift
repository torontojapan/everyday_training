import SwiftUI

struct MonthlyCalendarView: View {
    let records: [WorkoutRecord]
    let today: Date
    var onDayTap: ((Date) -> Void)? = nil

    @State private var currentMonth: Date
    private let calendar = Calendar.mondayFirst
    private let weekdays = ["月", "火", "水", "木", "金", "土", "日"]

    init(records: [WorkoutRecord], today: Date, onDayTap: ((Date) -> Void)? = nil) {
        self.records = records
        self.today = today
        self.onDayTap = onDayTap
        self._currentMonth = State(initialValue: today)
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            weekdayRow
            calendarGrid
            footerSummary
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var header: some View {
        HStack {
            Button { shiftMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Palette.primaryDeep)
                    .frame(width: 36, height: 36)
                    .background(Palette.chipBackground, in: Circle())
            }
            .accessibilityLabel("前の月")
            Spacer()
            Text(monthTitle)
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Button { shiftMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(canShiftForward ? Palette.primaryDeep : Palette.textSecondary.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .background(Palette.chipBackground, in: Circle())
            }
            .disabled(!canShiftForward)
            .accessibilityLabel("次の月")
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let cells = monthCells
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(cells.indices, id: \.self) { idx in
                cellView(cells[idx])
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: MonthCell) -> some View {
        switch cell {
        case .blank:
            Color.clear.frame(height: 38)
        case .day(let date, let status, let isToday):
            Button {
                onDayTap?(date)
            } label: {
                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 13, weight: isToday ? .heavy : .semibold, design: .rounded))
                        .foregroundStyle(textColor(for: status, isToday: isToday))
                    Text(status.symbol)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(textColor(for: status, isToday: isToday).opacity(0.85))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(background(for: status, isToday: isToday), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(calendar.component(.month, from: date))月\(calendar.component(.day, from: date))日 \(accessibilityValue(for: status))")
        }
    }

    private var footerSummary: some View {
        HStack {
            Text(summaryText)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
        }
    }

    // MARK: - Computed

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: currentMonth)
    }

    private var canShiftForward: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { return false }
        let nextStart = startOfMonth(next)
        let todayMonthStart = startOfMonth(today)
        return nextStart <= todayMonthStart
    }

    private enum MonthCell {
        case blank
        case day(date: Date, status: DailyStatus, isToday: Bool)
    }

    private var monthCells: [MonthCell] {
        let monthStart = startOfMonth(currentMonth)
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let daysInMonth = range.count

        // Monday-first: weekday(1=Sun..7=Sat). Calendar.mondayFirst has firstWeekday = 2.
        let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
        // Map to Mon=0..Sun=6
        let leading = (weekdayOfFirst + 5) % 7

        var cells: [MonthCell] = Array(repeating: .blank, count: leading)
        let todayStart = calendar.startOfDay(for: today)

        for day in 0..<daysInMonth {
            guard let date = calendar.date(byAdding: .day, value: day, to: monthStart) else { continue }
            let restDays = RestDayResolver.restDaySet(for: date, records: records, today: today, calendar: calendar)
            let status = AchievementEvaluator.dailyStatus(
                for: date,
                records: records,
                restDays: restDays,
                today: today,
                calendar: calendar
            )
            let isToday = calendar.isDate(date, inSameDayAs: todayStart)
            cells.append(.day(date: date, status: status, isToday: isToday))
        }

        // Pad trailing blanks to fill complete rows (multiples of 7).
        while cells.count % 7 != 0 {
            cells.append(.blank)
        }
        return cells
    }

    private var summaryText: String {
        let monthStart = startOfMonth(currentMonth)
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return "" }
        let achievedCount = monthCells.reduce(0) { acc, cell in
            if case let .day(_, status, _) = cell, status.countsAsAchieved {
                return acc + 1
            }
            return acc
        }
        return "\(calendar.component(.month, from: currentMonth))月: \(achievedCount) / \(range.count) 日達成"
    }

    // MARK: - Helpers

    private func shiftMonth(by months: Int) {
        if months > 0, !canShiftForward { return }
        guard let new = calendar.date(byAdding: .month, value: months, to: currentMonth) else { return }
        currentMonth = new
    }

    private func startOfMonth(_ date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private func background(for status: DailyStatus, isToday: Bool) -> Color {
        if isToday {
            return Palette.primary.opacity(0.85)
        }
        switch status {
        case .achieved, .todayAchieved: return Palette.success.opacity(0.55)
        case .rest: return Palette.restDay.opacity(0.6)
        case .missed: return Palette.missed.opacity(0.18)
        case .future: return Palette.surface
        case .todayPending: return Palette.secondary.opacity(0.4)
        }
    }

    private func textColor(for status: DailyStatus, isToday: Bool) -> Color {
        if isToday { return .white }
        switch status {
        case .future: return Palette.textSecondary.opacity(0.6)
        default: return Palette.textPrimary
        }
    }

    private func accessibilityValue(for status: DailyStatus) -> String {
        switch status {
        case .achieved, .todayAchieved: return "達成"
        case .rest: return "休養日"
        case .missed: return "未達成"
        case .future: return "未来"
        case .todayPending: return "今日 未達成"
        }
    }
}
