import SwiftUI

struct ExerciseInputRow: View {
    @Binding var draft: RecordEntryViewModel.ExerciseDraft
    let suggestions: [String]
    let canRemove: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onRemove: () -> Void

    var body: some View {
        if isExpanded {
            expandedBody
        } else {
            collapsedRow
        }
    }

    // MARK: - 最小化表示 (入力済みの種目)

    private var collapsedRow: some View {
        Button(action: onToggleExpand) {
            HStack(spacing: 10) {
                Image(systemName: draft.category.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.primary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.name.isEmpty ? "種目名 未入力" : draft.name)
                        .font(Typography.body)
                        .foregroundStyle(draft.name.isEmpty ? Palette.textSecondary : Palette.textPrimary)
                    Text(collapsedSummary)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(draft.category.displayName) \(draft.name.isEmpty ? "未入力" : draft.name)")
        .accessibilityHint("タップして編集")
    }

    private var collapsedSummary: String {
        var parts = [draft.category.displayName]
        if draft.minutes > 0 { parts.append("\(draft.minutes)分") }
        if draft.reps > 0 { parts.append("\(draft.reps)回") }
        if draft.sets > 0 { parts.append("\(draft.sets)セット") }
        if let kg = RecordEntryViewModel.parsedLoad(draft.loadText) {
            parts.append(kg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(kg))kg" : "\(kg)kg")
        }
        return parts.joined(separator: "・")
    }

    // MARK: - 編集表示 (展開中の種目)

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            // この種目のカテゴリ選択 + 削除 + 最小化。カテゴリを種目ごとに持てる。
            HStack(spacing: 8) {
                Text("種類")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 4)
                if canRemove {
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("種目を削除")
                }
                Button(action: onToggleExpand) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.textSecondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("最小化")
            }
            // 全カテゴリを横スクロールで常時表示し、タップ選択(旧プルダウンは
            // 「押すと選べる」ことが分かりづらかった、というユーザー指摘の解消)。
            categorySelector

            // 種目名は入力の主役。ラベル + 枠線付きフィールドで埋もれないようにする。
            VStack(alignment: .leading, spacing: 4) {
                Text("種目名")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                TextField("例: スクワット", text: $draft.name)
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("種目名")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Palette.chipBackground.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Palette.primary.opacity(0.45), lineWidth: 1.5)
                    )
            }

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("よく使う種目")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                    // 種類と同じ横スクロールのチップ。前回使った種目が先頭に来る
                    // (ExerciseHistoryProvider が最終使用日の新しい順で返す)。
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button { draft.name = suggestion } label: {
                                    Text(suggestion)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .fixedSize()
                                        .foregroundStyle(Palette.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Palette.chipBackground.opacity(0.6), in: Capsule())
                                        .overlay(Capsule().strokeBorder(Palette.primary.opacity(0.25), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 1)
                    }
                }
            } else {
                Text("履歴がたまると、ここによく使う種目が出ます")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            // 時間/回数/セットはプルダウン選択。手入力 (数字キーボード) より
            // 速くタップ1つで決まり、表記ゆれ・全角入力も防げる。
            HStack(spacing: 12) {
                labeledPicker("時間 (分)", selection: $draft.minutes, options: Self.minuteOptions, unit: "分", accessibility: "時間 分単位")
                labeledPicker("回数", selection: $draft.reps, options: Self.repOptions, unit: "回", accessibility: "回数")
                labeledPicker("セット", selection: $draft.sets, options: Self.setOptions, unit: "", accessibility: "セット数")
                // 重さ(kg)はフリー入力(器具の重量は刻みが多様なためプルダウンにしない)。
                VStack(alignment: .leading, spacing: 4) {
                    Text("重さ (kg)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                    TextField("0", text: $draft.loadText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(Palette.chipBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityLabel("重さ キログラム")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            TextField("種目メモ (例: 体調メモ、回数アップ等)", text: $draft.memo)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Palette.chipBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .font(Typography.body)
        .padding(.vertical, 6)
    }

    /// 全カテゴリを横スクロールのチップで常時表示。選択中は塗り、その他は枠線。
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WorkoutCategory.allCases) { category in
                    let isSelected = draft.category == category
                    Button {
                        draft.category = category
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.symbolName)
                                .font(.system(size: 14, weight: .bold))
                            Text(category.displayName)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .fixedSize()
                        }
                        .foregroundStyle(isSelected ? .white : Palette.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            isSelected ? Palette.primary : Palette.chipBackground.opacity(0.6),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                isSelected ? Color.clear : Palette.primary.opacity(0.35),
                                lineWidth: 1.2
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(category.displayName)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 1)
        }
        .accessibilityIdentifier("exercise-category-selector")
    }

    // 0 = 未設定。時間は 5 分刻みで最大 100 分、回数は最大 50、セットは最大 10。
    private static let minuteOptions = Array(stride(from: 0, through: 100, by: 5))
    private static let repOptions = Array(0...50)
    private static let setOptions = Array(0...10)

    private func labeledPicker(
        _ label: String,
        selection: Binding<Int>,
        options: [Int],
        unit: String,
        accessibility: String
    ) -> some View {
        let value = selection.wrappedValue
        return VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
            Menu {
                Picker(label, selection: selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option == 0 ? "—" : "\(option)\(unit)").tag(option)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(value == 0 ? "—" : "\(value)\(unit)")
                        .foregroundStyle(value == 0 ? Palette.textSecondary.opacity(0.6) : Palette.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Palette.chipBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityLabel(accessibility)
            .accessibilityValue(value == 0 ? "未設定" : "\(value)\(unit)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 候補チップを自動で 2 行以上にラップするフロー。SwiftUI 標準には
/// 折り返し HStack がないため、ジオメトリ計算で組む。
private struct SuggestionFlow: View {
    let suggestions: [String]
    let onTap: (String) -> Void

    var body: some View {
        // 最大 3 行に制限。候補が多くても入力欄が縦に伸びすぎない。
        FlowLayout(spacing: 8, lineSpacing: 6, maxRows: 3) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onTap(suggestion)
                } label: {
                    Text(suggestion)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.primaryDeep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Palette.chipBackground, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(suggestion)を入力")
            }
        }
    }
}

/// Simple wrapping flow Layout (iOS 16+ Layout protocol).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 6
    /// 表示する最大行数。これを超える行のアイテムは画面外へ逃がして非表示にする。
    var maxRows: Int? = nil

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let (rows, _) = layoutRows(in: width, subviews: subviews)
        let visibleRows = maxRows.map { Array(rows.prefix($0)) } ?? rows
        let totalHeight = visibleRows.reduce(0) { $0 + $1.height }
            + CGFloat(max(0, visibleRows.count - 1)) * lineSpacing
        let maxRowWidth = visibleRows.map { $0.width }.max() ?? 0
        return CGSize(width: min(maxRowWidth, width), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (rows, _) = layoutRows(in: bounds.width, subviews: subviews)
        let visibleCount = maxRows ?? rows.count
        var y = bounds.minY
        for (rowIndex, row) in rows.enumerated() {
            guard rowIndex < visibleCount else {
                // 上限行を超えた候補は遠くへ逃がして非表示 (Layout は全 subview を
                // place する必要があるため、削除でなく画面外配置で対応)。
                for index in row.indices {
                    subviews[index].place(
                        at: CGPoint(x: bounds.minX, y: bounds.maxY + 10_000),
                        proposal: ProposedViewSize(width: 0, height: 0)
                    )
                }
                continue
            }
            var x = bounds.minX
            for index in row.indices {
                let subview = subviews[index]
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int]
        var width: CGFloat
        var height: CGFloat
    }

    private func layoutRows(in width: CGFloat, subviews: Subviews) -> (rows: [Row], totalHeight: CGFloat) {
        var rows: [Row] = []
        var current = Row(indices: [], width: 0, height: 0)
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            let needsLineBreak = current.width + size.width + (current.indices.isEmpty ? 0 : spacing) > width
            if needsLineBreak, !current.indices.isEmpty {
                rows.append(current)
                current = Row(indices: [], width: 0, height: 0)
            }
            if !current.indices.isEmpty { current.width += spacing }
            current.indices.append(i)
            current.width += size.width
            current.height = max(current.height, size.height)
        }
        if !current.indices.isEmpty { rows.append(current) }
        let totalHeight = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        return (rows, totalHeight)
    }
}
