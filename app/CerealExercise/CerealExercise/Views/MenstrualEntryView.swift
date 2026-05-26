import SwiftUI

/// Phase 7.0 拡張: 過去・当日の生理日を後付けで記録するための専用カレンダー。
/// 設定で「体調・周期を記録する」を ON にしているときだけ履歴タブからリンクされる。
/// 受け取った `MenstrualStore` を共有するので、ここでトグルすれば
/// 履歴カレンダーの ★ マークが即時に反映される。
struct MenstrualEntryView: View {
    let store: MenstrualStore
    @State private var currentMonth: Date = Date()
    private let calendar = Calendar.mondayFirst
    private let weekdays = ["月", "火", "水", "木", "金", "土", "日"]
    /// 生理日マークの基準色 (履歴カレンダーの ★ と揃える)。
    private let markColor = Color(red: 0.86, green: 0.36, blue: 0.45)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                calendarCard
                explainer
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("生理日")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.fetchEntries()
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 14) {
            header
            weekdayRow
            grid
            summaryLine
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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
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

    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(cells.indices, id: \.self) { idx in
                cellView(cells[idx])
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: Cell) -> some View {
        switch cell {
        case .blank:
            Color.clear.frame(height: 44)
        case .day(let date):
            let dayStart = calendar.startOfDay(for: date)
            let today = calendar.startOfDay(for: Date())
            let isFuture = dayStart > today
            let isToday = calendar.isDate(dayStart, inSameDayAs: today)
            let isMarked = store.isMarked(date)
            Button {
                toggle(date: date)
            } label: {
                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 14, weight: isMarked || isToday ? .heavy : .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(textColor(isFuture: isFuture, isToday: isToday, isMarked: isMarked))
                    if isMarked {
                        Text("★")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(markColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    background(isMarked: isMarked, isToday: isToday),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(isMarked ? markColor : .clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .disabled(isFuture)
            .accessibilityLabel("\(calendar.component(.month, from: date))月\(calendar.component(.day, from: date))日 \(isMarked ? "生理日" : "未マーク")")
            .accessibilityHint(isFuture ? "未来日のため選択できません" : "タップで★を切り替えます")
        }
    }

    private var summaryLine: some View {
        let markedInMonth = monthMarkedCount
        return HStack {
            Text("\(calendar.component(.month, from: currentMonth))月の記録: \(markedInMonth) 日")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
        }
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("日付をタップで★トグル", systemImage: "hand.tap.fill")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            Label("入力した日は履歴カレンダーにも★で表示されます", systemImage: "calendar.badge.checkmark")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            Label("未来の日付は選択できません", systemImage: "lock.fill")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Palette.chipBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Logic

    private enum Cell {
        case blank
        case day(date: Date)
    }

    private var cells: [Cell] {
        let monthStart = startOfMonth(currentMonth)
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
        let leading = (weekdayOfFirst + 5) % 7
        var arr: [Cell] = Array(repeating: .blank, count: leading)
        for d in 0..<range.count {
            guard let date = calendar.date(byAdding: .day, value: d, to: monthStart) else { continue }
            arr.append(.day(date: date))
        }
        while arr.count % 7 != 0 { arr.append(.blank) }
        return arr
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: currentMonth)
    }

    private var canShiftForward: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { return false }
        return startOfMonth(next) <= startOfMonth(Date())
    }

    private var monthMarkedCount: Int {
        cells.reduce(0) { acc, cell in
            if case let .day(date) = cell, store.isMarked(date) { return acc + 1 }
            return acc
        }
    }

    private func shiftMonth(by months: Int) {
        if months > 0, !canShiftForward { return }
        guard let new = calendar.date(byAdding: .month, value: months, to: currentMonth) else { return }
        currentMonth = new
    }

    private func startOfMonth(_ date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private func toggle(date: Date) {
        store.set(!store.isMarked(date), on: date)
    }

    private func background(isMarked: Bool, isToday: Bool) -> Color {
        if isMarked { return markColor.opacity(0.18) }
        if isToday { return Palette.primary.opacity(0.18) }
        return Palette.surface
    }

    private func textColor(isFuture: Bool, isToday: Bool, isMarked: Bool) -> Color {
        if isFuture { return Palette.textSecondary.opacity(0.5) }
        if isMarked { return markColor }
        return Palette.textPrimary
    }
}
