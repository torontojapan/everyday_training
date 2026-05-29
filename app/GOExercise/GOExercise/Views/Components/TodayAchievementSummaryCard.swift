import SwiftUI

struct TodayAchievementSummaryCard: View {
    let summary: ExerciseTrendSummary.DailySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("今日の達成", systemImage: "checkmark.seal.fill")
                .font(Typography.headline)
                .foregroundStyle(Palette.primaryDeep)

            HStack(spacing: 12) {
                ForEach(displayCategories, id: \.category) { item in
                    Label("\(item.count)", systemImage: item.category.symbolName)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.categoryColor(for: item.category))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Palette.chipBackground, in: Capsule())
                }
            }

            HStack(spacing: 10) {
                metric(title: "種目", value: "\(summary.exerciseCount)")
                metric(title: "合計", value: durationText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日の達成")
        .accessibilityValue("\(summary.exerciseCount)種目、合計\(durationText)")
    }

    private var displayCategories: [(category: WorkoutCategory, count: Int)] {
        WorkoutCategory.allCases.compactMap { category in
            guard let count = summary.categoryCounts[category], count > 0 else { return nil }
            return (category, count)
        }
    }

    private var durationText: String {
        Self.durationText(seconds: summary.totalDurationSeconds)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(Typography.sectionTitle)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func durationText(seconds: Int) -> String {
        guard seconds > 0 else { return "0分" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes == 0 {
            return "\(remainder)秒"
        }
        return remainder == 0 ? "\(minutes)分" : "\(minutes)分\(remainder)秒"
    }
}
