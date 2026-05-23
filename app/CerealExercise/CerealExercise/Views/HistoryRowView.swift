import SwiftUI

struct HistoryRowView: View {
    let record: WorkoutRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(record.category.displayName, systemImage: record.category.symbolName)
                .font(Typography.headline)
                .foregroundStyle(Palette.categoryColor(for: record.category))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(record.exercises) { item in
                    Text(exerciseLine(for: item))
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
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
