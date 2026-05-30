import SwiftUI

struct HistoryRowView: View {
    let record: WorkoutRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if uniqueCategories.count <= 1 {
                // 単一カテゴリ: 従来どおりヘッダ + 種目行。
                let category = uniqueCategories.first ?? record.category
                Label(category.displayName, systemImage: category.symbolName)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.categoryColor(for: category))

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(record.exercises) { item in
                        Text(exerciseLine(for: item))
                            .font(Typography.body)
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
            } else {
                // 複数カテゴリ: 種目ごとにカテゴリアイコンを付けて区別する。
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(record.exercises) { item in
                        let category = item.category ?? record.category
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: category.symbolName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.categoryColor(for: category))
                                .frame(width: 20)
                            Text(exerciseLine(for: item))
                                .font(Typography.body)
                                .foregroundStyle(Palette.textPrimary)
                        }
                    }
                }
            }

            if totalSeconds > 0 {
                Text("合計 \(durationText(seconds: totalSeconds))")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            if let memo = record.memo, !memo.isEmpty {
                Text(memo)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var totalSeconds: Int {
        record.exercises.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
    }

    /// この記録に含まれるカテゴリを出現順で一意化 (旧データは記録の category に
    /// フォールバック)。1 つなら単一カテゴリ表示、複数なら種目ごと表示に分岐する。
    private var uniqueCategories: [WorkoutCategory] {
        var seen = Set<WorkoutCategory>()
        var result: [WorkoutCategory] = []
        for item in record.exercises {
            let category = item.category ?? record.category
            if seen.insert(category).inserted {
                result.append(category)
            }
        }
        return result
    }

    private func exerciseLine(for item: ExerciseItem) -> String {
        var parts = [item.name]
        if let reps = item.reps {
            parts.append("\(reps)回")
        }
        if let sets = item.sets {
            parts.append("\(sets)セット")
        }
        if let seconds = item.durationSeconds {
            parts.append(durationText(seconds: seconds))
        }
        return parts.joined(separator: " ")
    }

    private func durationText(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes > 0, remainder > 0 {
            return "\(minutes)分\(remainder)秒"
        }
        if minutes > 0 {
            return "\(minutes)分"
        }
        return "\(remainder)秒"
    }
}
