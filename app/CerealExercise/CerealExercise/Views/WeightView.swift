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
    /// 月経周期オーバーレイの凡例を展開しているか (Claude #3)。デフォルト閉。
    @State private var isCycleLegendExpanded: Bool = false
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
            VStack(alignment: .leading, spacing: 16) {
                if let store {
                    // ヒーロー (最新 + 目標 + リング + 猫) は常時展開。
                    heroDashboard(store: store)

                    // BMI / 身長 は独立したストリップに移動。
                    bmiInfoStrip(store: store)

                    // 「記録する」をヒーロー直下に移動 (ユーザー要望)。
                    // 主アクションへ到達するまでのスクロールを削る。
                    CollapsibleSection(
                        persistenceKey: "weight.input",
                        title: "記録する",
                        subtitle: "新しい体重を追加",
                        icon: "plus.circle.fill"
                    ) {
                        inputCard
                    }

                    CollapsibleSection(
                        persistenceKey: "weight.report",
                        title: "レポート",
                        subtitle: reportSubtitle(store: store),
                        icon: "chart.bar.fill"
                    ) {
                        statsReportSection(store: store)
                    }

                    CollapsibleSection(
                        persistenceKey: "weight.chart",
                        title: "推移",
                        subtitle: chartSubtitle(store: store),
                        icon: "waveform.path.ecg",
                        defaultExpanded: true   // 推移はデフォルト展開 (チャートが本体)
                    ) {
                        chartSection(store: store)
                    }

                    CollapsibleSection(
                        persistenceKey: "weight.history",
                        title: "履歴",
                        subtitle: historySubtitle(store: store),
                        icon: "list.bullet"
                    ) {
                        historyList(store: store)
                    }
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

    // MARK: - Hero / Strip (新設計)

    /// ヒーローダッシュボード (B)。最新 + 目標 + 進捗リング + 選択中の猫 +
    /// KPI チップ を 1 枚に集約。
    @ViewBuilder
    private func heroDashboard(store: WeightStore) -> some View {
        let latest = store.latestNonFuture
        let progress = latest.flatMap { healthPrefs.progressRatio(currentKilograms: $0.weightKilograms) }
        let isLoss = healthPrefs.isLossGoal()
        let weekStats = store.stats(period: .week)
        WeightHeroDashboard(
            latest: latest,
            startKg: healthPrefs.startKilograms,
            targetKg: healthPrefs.targetKilograms,
            progress: progress,
            isLossGoal: isLoss,
            weeklyChange: weekStats?.change,
            onEditTarget: { beginTargetEdit() }
        )
    }

    /// BMI + 身長 編集の独立ストリップ (Claude #2)。ヒーロー直下に薄く敷く。
    /// 体重 0 件 OR 身長未設定 で表示内容を出し分ける。
    @ViewBuilder
    private func bmiInfoStrip(store: WeightStore) -> some View {
        if let latest = store.latestNonFuture {
            HStack(spacing: 10) {
                Image(systemName: "ruler")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                if let bmi = healthPrefs.bmi(weightKilograms: latest.weightKilograms) {
                    // BMI カテゴリ badge (「普通」/「肥満」など) はユーザー要望で
                    // 非表示。数値のみ表示してニュートラルなトーンに。
                    Text("BMI")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                    Text(String(format: "%.1f", bmi))
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                    if let h = healthPrefs.heightCentimeters {
                        Text("身長 \(String(format: "%.0f", h))cm")
                            .font(.caption2)
                            .foregroundStyle(Palette.textSecondary)
                    }
                } else {
                    Text("身長を設定すると BMI が表示されます")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Button {
                    beginHeightEdit()
                } label: {
                    Label("身長", systemImage: "pencil")
                        .font(.caption2)
                        .foregroundStyle(Palette.primaryDeep)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Palette.surface.opacity(0.6), in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(bmiAccessibilityLabel(latestKg: latest.weightKilograms))
            .accessibilityIdentifier("bmi-info-strip")
        }
    }

    /// VoiceOver 用の BMI 説明ラベル。視覚的には数値のみだが、読み上げでは
    /// 「BMI 23.0 普通」のようにカテゴリも含めて文脈を保つ (Codex round2 priority 2)。
    private func bmiAccessibilityLabel(latestKg: Double) -> String {
        guard let bmi = healthPrefs.bmi(weightKilograms: latestKg) else {
            return "身長未設定、BMI 表示なし"
        }
        let category = BMICategory(bmi: bmi)
        let bmiStr = String(format: "%.1f", bmi)
        if let h = healthPrefs.heightCentimeters {
            // 視覚側と同じ `%.0f` で丸めて a11y 表記との不整合を防ぐ
            // (Codex round3 priority 2: Int() は truncation で 165.9 → 165、
            //  視覚側 %.0f は四捨五入で 166cm になり読み上げとズレる)。
            let heightStr = String(format: "%.0f", h)
            return "BMI \(bmiStr) \(category.displayName)、身長 \(heightStr) センチ"
        }
        return "BMI \(bmiStr) \(category.displayName)"
    }

    /// CollapsibleSection の subtitle 生成 (折りたたみ中の要約)。
    /// week が取れなければ month にフォールバック (Codex round1: 月だけでもデータ
    /// が有るのに「データなし」と表示する regression を防ぐ)。
    private func reportSubtitle(store: WeightStore) -> String {
        if let week = store.stats(period: .week) {
            let sign = week.change >= 0 ? "+" : ""
            return "今週 \(sign)\(String(format: "%.1f", week.change))kg / 平均 \(String(format: "%.1f", week.average))kg"
        }
        if let month = store.stats(period: .month) {
            let sign = month.change >= 0 ? "+" : ""
            return "今月 \(sign)\(String(format: "%.1f", month.change))kg / 平均 \(String(format: "%.1f", month.average))kg"
        }
        return "データなし"
    }

    private func chartSubtitle(store: WeightStore) -> String {
        let count = store.chartEntries(period: .month).count
        return count > 0 ? "30 日で \(count) 件記録" : "記録がありません"
    }

    private func historySubtitle(store: WeightStore) -> String {
        let total = store.entries.count
        return total > 0 ? "全 \(total) 件" : "履歴なし"
    }

    // MARK: - Sections

    /// 旧 forecastRow 互換 (CollapsibleSection 内で他から呼び出される可能性に備えて残す)。
    /// ヒーローダッシュボード化により今は未使用だが、subtle な達成圏内訴求を
    /// 別箇所で再活用する余地がある。
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
            VStack(alignment: .leading, spacing: 6) {
                // Claude #3: 周期色帯の意味をユーザーが見落とすのを防ぐため、
                // 凡例自体をタップで展開して「黄体期は水分で増えがち」等の説明
                // を出せる toggle 形に。デフォルト閉、必要な時だけ展開。
                Button {
                    withAnimation { isCycleLegendExpanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.dashed")
                            .font(.caption2)
                            .foregroundStyle(Palette.textSecondary)
                        Text("月経周期オーバーレイ")
                            .font(.caption2)
                            .foregroundStyle(Palette.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Palette.textSecondary)
                            .rotationEffect(.degrees(isCycleLegendExpanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(isCycleLegendExpanded ? "閉じる" : "色帯の意味を見る")

                if isCycleLegendExpanded {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(used, id: \.self) { phase in
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(phase.tint.opacity(0.65))
                                    .frame(width: 12, height: 12)
                                Text(phase.displayName)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Palette.textPrimary)
                                Text("· \(phase.hint)")
                                    .font(.caption2)
                                    .foregroundStyle(Palette.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 4)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("月経周期の凡例")
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 日付セグメント (Claude #5): 最頻ケースの「今日」を 1 タップで完了。
            // 古い DatePicker を毎回展開する手間を削り、稀な「過去日」は
            // セグメント「その他」で従来 DatePicker を出す。
            dateSegment

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
    }

    /// 日付セグメント. 「今日 / 昨日 / その他」を 1 タップで切替。
    /// 「その他」選択時のみ従来 DatePicker を展開。
    @ViewBuilder
    private var dateSegment: some View {
        let cal = self.calendar
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        let isToday = cal.isDate(selectedDate, inSameDayAs: today)
        let isYesterday = cal.isDate(selectedDate, inSameDayAs: yesterday)
        let isOther = !isToday && !isYesterday

        HStack(spacing: 8) {
            dateChip("今日", isSelected: isToday) { selectedDate = today }
            dateChip("昨日", isSelected: isYesterday) { selectedDate = yesterday }
            dateChip("その他", isSelected: isOther) {
                // 「その他」が押されたら、まだ today/yesterday のままなら 2 日前にする。
                if !isOther {
                    selectedDate = cal.date(byAdding: .day, value: -2, to: today) ?? selectedDate
                }
            }
            Spacer()
        }
        if isOther {
            DatePicker("日付", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
                .accessibilityIdentifier("weight-date-picker-other")
        }
    }

    private func dateChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(isSelected ? .white : Palette.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(
                    isSelected ? Palette.primary : Palette.chipBackground,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("日付を \(label) にする")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
