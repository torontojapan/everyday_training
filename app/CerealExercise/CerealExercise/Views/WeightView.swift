import Charts
import SwiftData
import SwiftUI

struct WeightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: WeightStore?
    @State private var menstrualStore: MenstrualStore?
    @State private var weightInput: String = ""
    @State private var memoInput: String = ""
    @State private var heightInput: String = ""
    @State private var targetInput: String = ""
    @State private var selectedDate: Date = Date()
    @State private var chartSelectedDate: Date?
    @State private var chartPeriod: WeightStore.ChartPeriod = .month
    @State private var isShowingDeleteConfirm: WeightEntry?
    private let cycleSettings = CycleTrackingSettings()
    /// 身長 / 目標体重 の編集ダイアログを単一の state machine で管理。
    /// 複数の `.alert(_, isPresented:)` を同じ view に重ねるパターンは
    /// iOS 17+ では動作するが将来の SwiftUI 仕様変更に脆く、Codex も
    /// 警告するので enum 駆動に統一。
    private enum HealthEditField: Identifiable {
        case height
        case target
        var id: Self { self }
    }
    @State private var editingField: HealthEditField?
    @Bindable private var healthPrefs = UserHealthPreferences.shared

    private let calendar = Calendar.mondayFirst

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let store {
                    summarySection(store: store)
                    targetSection(store: store)
                    statsReportSection(store: store)
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
        .onAppear {
            if store == nil {
                store = WeightStore(context: modelContext)
            }
            // 周期データ store は init / re-appear のたびに fetch を回す
            // (他画面で marked が編集された後に戻ってきたケースを反映)。
            // Codex round1 priority 1 でステイル表示が指摘されたため。
            if menstrualStore == nil {
                menstrualStore = MenstrualStore(context: modelContext)
            } else {
                menstrualStore?.fetchEntries()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // バックグラウンド復帰時 (widget AppIntent や別タブ操作で
            // 体重/周期が更新されているかもしれない) は両 store を refresh。
            // Codex round2 priority 2: onAppear だけだと WeightView が
            // mounted のまま scene 復帰した場合に stale。
            guard newPhase == .active else { return }
            store?.fetchEntries()
            menstrualStore?.fetchEntries()
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
        .alert(
            healthEditTitle,
            isPresented: Binding(
                get: { editingField != nil },
                set: { if !$0 { editingField = nil } }
            ),
            presenting: editingField
        ) { field in
            switch field {
            case .height:
                TextField("例: 165", text: $heightInput)
                    .keyboardType(.decimalPad)
                Button("保存") { saveHeight() }
                Button("クリア", role: .destructive) {
                    healthPrefs.heightCentimeters = nil
                }
                Button("キャンセル", role: .cancel) {}
            case .target:
                TextField("例: 60.0", text: $targetInput)
                    .keyboardType(.decimalPad)
                Button("保存") { saveTarget() }
                Button("クリア", role: .destructive) {
                    healthPrefs.targetKilograms = nil
                    healthPrefs.startKilograms = nil
                }
                Button("キャンセル", role: .cancel) {}
            }
        } message: { field in
            switch field {
            case .height:
                Text("身長を cm 単位で入力すると BMI が表示されます")
            case .target:
                Text("目標体重を kg で入力。新規/変更したときだけ「開始時」体重がリセットされます")
            }
        }
    }

    private var healthEditTitle: String {
        switch editingField {
        case .height: return "身長を入力"
        case .target: return "目標体重を入力"
        case .none:   return ""
        }
    }

    private func saveHeight() {
        if let value = Double(heightInput.trimmingCharacters(in: .whitespacesAndNewlines)),
           value >= 50, value <= 250 {
            healthPrefs.heightCentimeters = value
        }
    }

    private func saveTarget() {
        let trimmed = targetInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0, value < 500 else { return }
        // 目標が "実際に変わった" ときだけ start をリセット。体重の表示精度は
        // 0.1kg なので、それ未満の差分は同値扱い (prefill が %.1f で丸まる
        // 影響を吸収 / Codex round3)。
        let targetChanged: Bool = {
            guard let old = healthPrefs.targetKilograms else { return true }
            return abs(old - value) >= 0.05
        }()
        if targetChanged {
            // baseline には latest ではなく latestNonFuture を使う。
            // 未来日エントリ (時計ズレ・インポート) が baseline になると進捗
            // 計算がすべて狂うため (Codex round6)。該当なしなら nil で揃える
            // (古い start が宙に浮く問題の防止 / Codex round3)。
            healthPrefs.startKilograms = store?.latestNonFuture?.weightKilograms
        }
        healthPrefs.targetKilograms = value
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

    /// 目標体重カード。目標未設定なら CTA。設定済みなら現在 → 目標の
    /// 進捗バー + 残り kg を表示。最新の体重がないと意味がないので
    /// store.latest が nil のときは入力 CTA に絞る。
    @ViewBuilder
    private func targetSection(store: WeightStore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("目標体重")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Button {
                    beginTargetEdit()
                } label: {
                    Label(healthPrefs.targetKilograms == nil ? "設定" : "変更",
                          systemImage: "pencil")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.primaryDeep)
                }
                .buttonStyle(.plain)
            }

            if let target = healthPrefs.targetKilograms,
               let latest = store.latest {
                targetProgressBlock(target: target, current: latest.weightKilograms)
                forecastRow(store: store)
            } else {
                Text(store.latest == nil
                     ? "目標体重を設定するとモチベ表示が出ます (体重を 1 件以上記録してください)"
                     : "目標体重を設定すると残り kg と進捗バーが表示されます")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func targetProgressBlock(target: Double, current: Double) -> some View {
        let remaining = healthPrefs.remainingToTarget(currentKilograms: current) ?? 0
        let progress = healthPrefs.progressRatio(currentKilograms: current)
        let direction = healthPrefs.isLossGoal()
        // 達成判定: 減量/増量で向きが違う。start == target (direction == nil) は
        // 目標近傍 epsilon で達成扱い (target に 0.05kg = 50g 以内)。
        let achieved: Bool = {
            switch direction {
            case .some(true):  return remaining <= 0  // 減量: 目標以下になれば達成
            case .some(false): return remaining >= 0  // 増量: 目標以上になれば達成
            case .none:        return abs(remaining) < 0.05  // 開始==目標: 維持目標扱い
            }
        }()
        // 「あと」の表示は減量/増量で符号が反転 (どちらも正の "あと" を出すため)。
        // 維持目標 (direction == nil) は remaining の絶対値を表示。
        let displayRemaining: Double = {
            switch direction {
            case .some(true):  return remaining       // 減量: current - target が "あと"
            case .some(false): return -remaining      // 増量: target - current が "あと"
            case .none:        return abs(remaining)
            }
        }()

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                if achieved {
                    Label("目標達成", systemImage: "checkmark.seal.fill")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Palette.success)
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("あと")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                        Text(String(format: "%.1f", abs(displayRemaining)))
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.primary)
                            .monospacedDigit()
                        Text("kg")
                            .font(Typography.body)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer()
                Text("目標 \(String(format: "%.1f", target)) kg")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            if let progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(achieved ? Palette.success : Palette.primary)
                    .accessibilityLabel("達成率 \(Int(progress * 100)) パーセント")
                HStack {
                    if let start = healthPrefs.startKilograms {
                        Text("開始 \(String(format: "%.1f", start)) kg")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(achieved ? Palette.success : Palette.textPrimary)
                        .monospacedDigit()
                }
            }
        }
    }

    /// 7 日移動平均の傾きから「あと約 N 日で達成」を線形外挿で表示。
    /// 傾きが目標方向と逆 / トレンド不足の場合は黙って非表示にして UI を煩雑にしない。
    @ViewBuilder
    private func forecastRow(store: WeightStore) -> some View {
        if let days = store.forecastDaysToTarget() {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(Palette.primaryDeep)
                    .font(.system(.caption, design: .rounded))
                if days == 0 {
                    Text("ペースを維持できれば既に目標圏内")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.success)
                } else {
                    Text("このペースなら **約 \(days) 日** で達成")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    private func beginTargetEdit() {
        if let t = healthPrefs.targetKilograms {
            targetInput = String(format: "%.1f", t)
        } else {
            targetInput = ""
        }
        editingField = .target
    }

    private func beginHeightEdit() {
        if let h = healthPrefs.heightCentimeters {
            heightInput = String(format: "%.0f", h)
        } else {
            heightInput = ""
        }
        editingField = .height
    }

    /// 週次/月次レポートカード。週・月・3 月の最小/最大/平均/変化を一覧。
    /// 体重チャートを見ない日でも「今週はどうだった」が即わかる UX。
    @ViewBuilder
    private func statsReportSection(store: WeightStore) -> some View {
        let week = store.stats(period: .week)
        let month = store.stats(period: .month)
        if week != nil || month != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("レポート")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                if let week {
                    statsReportRow(label: "今週 (7 日)", stats: week)
                }
                if let month {
                    statsReportRow(label: "今月 (30 日)", stats: month)
                }
            }
            .padding(16)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func statsReportRow(label: String, stats: WeightStore.WeightStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                let signed = stats.change >= 0 ? "+" : ""
                Text("\(signed)\(String(format: "%.1f", stats.change)) kg")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(stats.change <= 0 ? Palette.success : Palette.primaryDeep)
                    .monospacedDigit()
            }
            HStack(spacing: 14) {
                statsValue(title: "最小", value: stats.min)
                statsValue(title: "平均", value: stats.average)
                statsValue(title: "最大", value: stats.max)
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) 平均 \(String(format: "%.1f", stats.average)) キログラム、変化 \(String(format: "%.1f", stats.change)) キログラム")
    }

    private func statsValue(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
            Text(String(format: "%.1f", value))
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
        }
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
                // 7 日移動平均トレンド。サンプル数が少ない期間は空配列が返るので
                // ForEach に渡しても安全 (薄い破線として下敷きに重ねる)。
                let trend = store.trendline(period: chartPeriod)
                // 体調周期オーバーレイ: 周期トラッキング opt-in 済みかつ
                // marked データがある場合のみ、相を色帯で背景に描画する。
                // 黄体期 (水分貯留期) を可視化することで「太った」誤解を防ぐ。
                let phaseSpans = cyclePhaseSpans(for: chartData)
                Chart {
                    ForEach(phaseSpans) { span in
                        RectangleMark(
                            xStart: .value("from", span.startDay),
                            xEnd: .value("to", span.endDay)
                        )
                        .foregroundStyle(span.phase.tint.opacity(0.13))
                        // 色覚特性に依らず相を読み上げできるよう VoiceOver ラベル付与。
                        // (Codex round1 priority 3: 色だけだと CVD で識別困難)
                        .accessibilityLabel("\(span.phase.displayName): \(span.phase.hint)")
                    }
                    if !trend.isEmpty {
                        ForEach(trend) { point in
                            LineMark(
                                x: .value("日付", point.date),
                                y: .value("kg", point.average),
                                series: .value("series", "trend")
                            )
                            .foregroundStyle(Palette.primaryDeep.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [4, 3]))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    ForEach(chartData) { entry in
                        LineMark(
                            x: .value("日付", entry.date),
                            y: .value("kg", entry.weightKilograms),
                            series: .value("series", "raw")
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
                        // 選択中の点の上に **小さく** その日の体重を float 表示。
                        // 上部の日付ピル (画面右上) は離れていて視線を動かす必要があるため、
                        // 点の近くに値を出して「いまどこを押しているか」を直感的にする。
                        // フォントは `.caption2` ベース (= Dynamic Type で拡大される)。
                        // `weight: .heavy` でアクセスフォントサイズでも視認性を保つ
                        // (Codex round1: 固定 11pt は Dynamic Type の拡大に対応しない)。
                        .annotation(position: .top, alignment: .center, spacing: 4) {
                            if selectedEntry?.id == entry.id {
                                Text("\(String(format: "%.1f", entry.weightKilograms)) kg")
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(Palette.primaryDeep)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.thinMaterial, in: Capsule())
                                    .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
                                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                                    .accessibilityLabel("選択中の体重 \(String(format: "%.1f", entry.weightKilograms)) キログラム")
                            }
                        }
                    }
                    if let selectedEntry {
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

                cyclePhaseLegend(phaseSpans)
            }
        }
    }

    private func chartSelectedEntry(in store: WeightStore) -> WeightEntry? {
        guard let target = chartSelectedDate else { return nil }
        let visible = store.chartEntries(period: chartPeriod)
        return visible.min(by: { abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target)) })
    }

    /// チャートデータ範囲に対する月経周期相の区間を返す。
    /// - 周期トラッキング opt-out / period 未マーク / chartData 空 のいずれかなら空配列
    /// - 描画範囲は chartData の最古日 〜 最新日の翌日 (Chart の RectangleMark xEnd を inclusive 扱いさせない)
    private func cyclePhaseSpans(for chartData: [WeightEntry]) -> [CyclePhaseResolver.PhaseSpan] {
        guard cycleSettings.isEnabled,
              let menstrualStore,
              !menstrualStore.entries.isEmpty,
              let oldest = chartData.first?.date,
              let newest = chartData.last?.date else { return [] }
        // chartData は古→新ソート (.reversed() 済) なので first=oldest, last=newest。
        let rangeStart = calendar.startOfDay(for: oldest)
        let rangeEnd = calendar.date(byAdding: .day, value: 1,
                                      to: calendar.startOfDay(for: newest)) ?? newest
        return CyclePhaseResolver.spans(
            in: rangeStart, end: rangeEnd,
            periodDays: menstrualStore.markedDates(),
            calendar: calendar
        )
    }

    /// 周期相の凡例。チャート下に小さく並べる。phase が 1 つでもデータに
    /// 出ているときだけ表示 (= 出ていない相は出さない)。
    @ViewBuilder
    private func cyclePhaseLegend(_ spans: [CyclePhaseResolver.PhaseSpan]) -> some View {
        let used = Array(Set(spans.map(\.phase))).sorted { $0.displayName < $1.displayName }
        if !used.isEmpty {
            HStack(spacing: 10) {
                ForEach(used, id: \.self) { phase in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(phase.tint.opacity(0.65))
                            .frame(width: 10, height: 10)
                        Text(phase.displayName)
                            .font(.caption2)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(.top, 4)
            .padding(.horizontal, 4)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("月経周期の凡例")
        }
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
                            Text(format(date: entry.date, includesTime: true))
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
        // 今日が選択されていれば現在時刻で保存し、朝/晩など同日複数記録を時刻で識別できるようにする。
        // 過去日は DatePicker から渡される 00:00 をそのまま使う (時刻入力 UI がないため)。
        let timestamp = calendar.isDateInToday(selectedDate) ? Date() : selectedDate
        _ = store?.add(date: timestamp, weightKilograms: weight, memo: memo.isEmpty ? nil : memo)
        weightInput = ""
        memoInput = ""
    }

    /// 日付フォーマット。`includesTime` が true で entry が時刻情報を持つ場合のみ HH:mm を付与。
    private func format(date: Date, includesTime: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        if includesTime && !isMidnight(date) {
            formatter.dateFormat = "yyyy/M/d HH:mm"
        } else {
            formatter.dateFormat = "yyyy/M/d"
        }
        return formatter.string(from: date)
    }

    /// entry.date が「日の頭 (00:00:00)」かどうか。過去日入力で時刻なし保存された
    /// エントリは midnight、現在時刻で記録されたエントリは非 midnight。
    private func isMidnight(_ date: Date) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return components.hour == 0 && components.minute == 0 && components.second == 0
    }
}
