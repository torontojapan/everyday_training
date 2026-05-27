import Charts
import SwiftData
import SwiftUI

struct WeightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var store: WeightStore?
    @State private var weightInput: String = ""
    @State private var memoInput: String = ""
    @State private var heightInput: String = ""
    @State private var selectedDate: Date = Date()
    @State private var chartSelectedDate: Date?
    @State private var chartPeriod: WeightStore.ChartPeriod = .month
    @State private var isShowingDeleteConfirm: WeightEntry?
    @State private var isEditingHeight: Bool = false
    @Bindable private var healthPrefs = UserHealthPreferences.shared
    var onClose: (() -> Void)? = nil

    private let calendar = Calendar.mondayFirst

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let store {
                    summarySection(store: store)
                    chartSection(store: store)
                    inputCard
                    historyList(store: store)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("体重管理")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if let onClose { onClose() } else { dismiss() }
                } label: {
                    Label("戻る", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(Typography.body)
                }
                .accessibilityLabel("戻る")
            }
        }
        .onAppear {
            if store == nil {
                store = WeightStore(context: modelContext)
            }
        }
        .confirmationDialog(
            "削除しますか？",
            isPresented: Binding(get: { isShowingDeleteConfirm != nil },
                                  set: { if !$0 { isShowingDeleteConfirm = nil } }),
            presenting: isShowingDeleteConfirm
        ) { entry in
            Button("削除", role: .destructive) {
                store?.delete(entry)
                isShowingDeleteConfirm = nil
            }
            Button("キャンセル", role: .cancel) {
                isShowingDeleteConfirm = nil
            }
        }
        .alert("身長を入力", isPresented: $isEditingHeight) {
            TextField("例: 165", text: $heightInput)
                .keyboardType(.decimalPad)
            Button("保存") {
                if let value = Double(heightInput.trimmingCharacters(in: .whitespacesAndNewlines)),
                   value >= 50, value <= 250 {
                    healthPrefs.heightCentimeters = value
                }
            }
            Button("クリア", role: .destructive) {
                healthPrefs.heightCentimeters = nil
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("身長を cm 単位で入力すると BMI が表示されます")
        }
    }

    // MARK: - Sections

    private func summarySection(store: WeightStore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最新の体重")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                    if let latest = store.latest {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", latest.weightKilograms))
                                .font(.system(size: 36, weight: .heavy, design: .rounded))
                                .foregroundStyle(Palette.primary)
                            Text("kg")
                                .font(Typography.body)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Text(format(date: latest.date))
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    } else {
                        Text("未記録")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer()
                if let change = store.change30Days {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("過去30日")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                        let sign = change == 0 ? "" : (change > 0 ? "+" : "")
                        Text("\(sign)\(String(format: "%.1f", change)) kg")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(change <= 0 ? Palette.success : Palette.primaryDeep)
                    }
                }
            }
            bmiRow(store: store)
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// BMI 表示 + 身長未設定なら入力導線。
    /// 体重 0 件のときは表示しても意味がないので隠す。
    @ViewBuilder
    private func bmiRow(store: WeightStore) -> some View {
        if let latest = store.latest {
            Divider()
            HStack {
                if let bmi = healthPrefs.bmi(weightKilograms: latest.weightKilograms) {
                    let category = BMICategory(bmi: bmi)
                    HStack(spacing: 8) {
                        Text("BMI")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                        Text(String(format: "%.1f", bmi))
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .foregroundStyle(Palette.textPrimary)
                            .monospacedDigit()
                        Text(category.displayName)
                            .font(Typography.caption)
                            .foregroundStyle(bmiCategoryColor(category))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(bmiCategoryColor(category).opacity(0.15), in: Capsule())
                    }
                    Spacer()
                    Button {
                        beginHeightEdit()
                    } label: {
                        Label("身長", systemImage: "pencil")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        beginHeightEdit()
                    } label: {
                        Label("BMI を表示するには身長を入力", systemImage: "ruler")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.primaryDeep)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
        }
    }

    private func bmiCategoryColor(_ category: BMICategory) -> Color {
        switch category {
        case .normal: return Palette.success
        case .underweight: return Palette.primaryDeep
        case .overweight, .obese: return Palette.missed
        }
    }

    private func beginHeightEdit() {
        if let h = healthPrefs.heightCentimeters {
            heightInput = String(format: "%.0f", h)
        } else {
            heightInput = ""
        }
        isEditingHeight = true
    }

    private func chartSection(store: WeightStore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("推移")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                if let selected = chartSelectedEntry(in: store) {
                    HStack(spacing: 6) {
                        Text(format(date: selected.date))
                            .foregroundStyle(Palette.textSecondary)
                        Text("·")
                            .foregroundStyle(Palette.textSecondary)
                        Text("\(String(format: "%.1f", selected.weightKilograms)) kg")
                            .foregroundStyle(Palette.primaryDeep)
                            .fontWeight(.heavy)
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Palette.primary.opacity(0.12), in: Capsule())
                }
            }

            Picker("期間", selection: $chartPeriod) {
                ForEach(WeightStore.ChartPeriod.allCases) { period in
                    Text(period.shortLabel).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: chartPeriod) { _, _ in
                // 期間切替時は選択をリセット (旧期間のドット ID が無効化されるため)
                chartSelectedDate = nil
            }

            let visible = store.chartEntries(period: chartPeriod)
            if visible.count < 2 {
                Text("\(chartPeriod.shortLabel)以内に2件以上の記録があるとグラフが表示されます")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                    .padding()
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                let chartData = Array(visible.reversed())
                let selectedEntry = chartSelectedEntry(in: store)
                Chart(chartData) { entry in
                    LineMark(
                        x: .value("日付", entry.date),
                        y: .value("kg", entry.weightKilograms)
                    )
                    .foregroundStyle(Palette.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("日付", entry.date),
                        y: .value("kg", entry.weightKilograms)
                    )
                    .foregroundStyle(Palette.primaryDeep)
                    .symbolSize(selectedEntry?.id == entry.id ? 130 : 40)

                    if let selectedEntry, selectedEntry.id == entry.id {
                        RuleMark(x: .value("選択日", selectedEntry.date))
                            .foregroundStyle(Palette.primaryDeep.opacity(0.30))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXSelection(value: $chartSelectedDate)
                .frame(height: 220)
                .padding(16)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func chartSelectedEntry(in store: WeightStore) -> WeightEntry? {
        guard let target = chartSelectedDate else { return nil }
        let visible = store.chartEntries(period: chartPeriod)
        return visible.min(by: { abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target)) })
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("記録する")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)

            DatePicker("日付", selection: $selectedDate, in: ...Date(), displayedComponents: .date)

            HStack {
                TextField("体重 (kg)", text: $weightInput)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Palette.chipBackground, in: Capsule())
                Text("kg")
                    .foregroundStyle(Palette.textSecondary)
            }

            TextField("メモ (任意)", text: $memoInput, axis: .vertical)
                .lineLimit(1...3)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Palette.chipBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            PrimaryButton("保存", systemImage: "checkmark.circle.fill") {
                save()
            }
            .disabled(parsedWeight == nil)
            .opacity(parsedWeight == nil ? 0.55 : 1)
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func historyList(store: WeightStore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("履歴")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)

            if store.entries.isEmpty {
                Text("まだ記録はありません")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                ForEach(store.entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(format(date: entry.date))
                                .font(Typography.body)
                                .foregroundStyle(Palette.textPrimary)
                            if let memo = entry.memo, !memo.isEmpty {
                                Text(memo)
                                    .font(Typography.caption)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                        Spacer()
                        Text("\(String(format: "%.1f", entry.weightKilograms)) kg")
                            .font(.system(.body, design: .rounded, weight: .heavy))
                            .foregroundStyle(Palette.primary)
                        Button(role: .destructive) {
                            isShowingDeleteConfirm = entry
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Palette.missed)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("削除")
                    }
                    .padding(12)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    // MARK: - Helpers

    private var parsedWeight: Double? {
        let trimmed = weightInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0, value < 500 else { return nil }
        return value
    }

    private func save() {
        guard let weight = parsedWeight else { return }
        let memo = memoInput.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = store?.add(date: selectedDate, weightKilograms: weight, memo: memo.isEmpty ? nil : memo)
        weightInput = ""
        memoInput = ""
    }

    private func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: date)
    }
}
