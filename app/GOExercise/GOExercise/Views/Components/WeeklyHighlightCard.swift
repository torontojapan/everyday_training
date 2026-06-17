import SwiftUI

struct WeeklyHighlightCard: View {
    let summary: ExerciseTrendSummary.WeeklySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Weeklyハイライト", systemImage: "sparkles")
                .font(Typography.headline)
                .foregroundStyle(Palette.historyAccent)

            if !summary.usedCategories.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(summary.usedCategories) { category in
                        Label(category.displayName, systemImage: category.symbolName)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.categoryColor(for: category))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Palette.chipBackground, in: Capsule())
                    }
                }
            }

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("合計時間")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Text(durationText)
                        .font(Typography.sectionTitle)
                        .foregroundStyle(Palette.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !summary.topExerciseNames.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("よく使う種目")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                        Text(summary.topExerciseNames.joined(separator: " / "))
                            .font(Typography.body)
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weeklyハイライト")
        .accessibilityValue(accessibilityValue)
    }

    private var durationText: String {
        guard summary.totalDurationSeconds > 0 else { return "0分" }
        let minutes = summary.totalDurationSeconds / 60
        let remainder = summary.totalDurationSeconds % 60
        if minutes == 0 {
            return "\(remainder)秒"
        }
        return remainder == 0 ? "\(minutes)分" : "\(minutes)分\(remainder)秒"
    }

    private var accessibilityValue: String {
        var parts = ["合計\(durationText)"]
        if !summary.usedCategories.isEmpty {
            parts.append("カテゴリ \(summary.usedCategories.map(\.displayName).joined(separator: "、"))")
        }
        if !summary.topExerciseNames.isEmpty {
            parts.append("よく使う種目 \(summary.topExerciseNames.joined(separator: "、"))")
        }
        return parts.joined(separator: "、")
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if maxWidth > 0, x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
