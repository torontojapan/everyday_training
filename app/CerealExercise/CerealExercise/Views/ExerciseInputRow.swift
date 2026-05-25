import SwiftUI

struct ExerciseInputRow: View {
    @Binding var draft: RecordEntryViewModel.ExerciseDraft
    let suggestions: [String]
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("種目名", text: $draft.name)
                    .textInputAutocapitalization(.never)

                if canRemove {
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("種目を削除")
                }
            }

            if !suggestions.isEmpty {
                // 横スクロールから 2 行ラップする FlexibleWrap に変更。
                // 候補が全部一目で見え、隠れた候補に気づかない問題を解消。
                VStack(alignment: .leading, spacing: 4) {
                    Text("よく使う種目")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                    SuggestionFlow(suggestions: suggestions) { suggestion in
                        draft.name = suggestion
                    }
                }
            }

            // Static labels above each numeric field so the meaning doesn't
            // disappear once the user types something (placeholder-only fields
            // lose context after input).
            HStack(spacing: 12) {
                labeledNumberField("時間 (分)", text: $draft.minutes, accessibility: "時間 分単位")
                labeledNumberField("回数", text: $draft.reps, accessibility: "回数")
                labeledNumberField("セット", text: $draft.sets, accessibility: "セット数")
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

    private func labeledNumberField(_ label: String, text: Binding<String>, accessibility: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
            TextField("", text: text, prompt: Text("0").foregroundStyle(Palette.textSecondary.opacity(0.5)))
                .keyboardType(.numberPad)
                .accessibilityLabel(accessibility)
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
        FlowLayout(spacing: 8, lineSpacing: 6) {
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

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let (rows, totalHeight) = layoutRows(in: width, subviews: subviews)
        let maxRowWidth = rows.map { $0.width }.max() ?? 0
        return CGSize(width: min(maxRowWidth, width), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (rows, _) = layoutRows(in: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
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
