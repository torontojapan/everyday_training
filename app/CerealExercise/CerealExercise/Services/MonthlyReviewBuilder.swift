import Foundation

enum MonthlyReviewBuilder {
    struct Review: Equatable {
        let monthLabel: String
        let achievedDays: Int
        let totalDays: Int
        let longestStreakInMonth: Int
        let totalDurationMinutes: Int
        let totalExerciseCount: Int
        let topCategory: WorkoutCategory?
        let topExerciseName: String?
    }

    static func build(
        records: [WorkoutRecord],
        month: Date,
        calendar: Calendar = .mondayFirst
    ) -> Review {
        let monthStart = startOfMonth(month, calendar: calendar)
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return Review(monthLabel: monthLabel(monthStart, calendar: calendar), achievedDays: 0, totalDays: 0,
                          longestStreakInMonth: 0, totalDurationMinutes: 0, totalExerciseCount: 0,
                          topCategory: nil, topExerciseName: nil)
        }
        let monthEnd = calendar.date(byAdding: .day, value: range.count - 1, to: monthStart) ?? monthStart

        let monthRecords = records.filter { record in
            let day = calendar.startOfDay(for: record.date)
            return day >= monthStart && day <= monthEnd
        }

        let achievedDates = Set(
            monthRecords.filter { AchievementEvaluator.isAchieved(record: $0) }
                .map { calendar.startOfDay(for: $0.date) }
        )
        let achievedDays = achievedDates.count
        let totalDays = range.count

        let longestStreakInMonth = longestConsecutive(in: achievedDates, calendar: calendar)

        let allExercises = monthRecords.flatMap(\.exercises)
        let totalDurationSeconds = allExercises.compactMap(\.durationSeconds).reduce(0, +)
        let totalDurationMinutes = totalDurationSeconds / 60
        let totalExerciseCount = allExercises.count

        let categoryCounts = monthRecords.reduce(into: [WorkoutCategory: Int]()) { partial, record in
            partial[record.category, default: 0] += 1
        }
        let topCategory = categoryCounts.max(by: { $0.value < $1.value })?.key

        let exerciseNameCounts = allExercises.reduce(into: [String: Int]()) { partial, item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            partial[name, default: 0] += 1
        }
        let topExerciseName = exerciseNameCounts.max(by: { $0.value < $1.value })?.key

        return Review(
            monthLabel: monthLabel(monthStart, calendar: calendar),
            achievedDays: achievedDays,
            totalDays: totalDays,
            longestStreakInMonth: longestStreakInMonth,
            totalDurationMinutes: totalDurationMinutes,
            totalExerciseCount: totalExerciseCount,
            topCategory: topCategory,
            topExerciseName: topExerciseName
        )
    }

    private static func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private static func monthLabel(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    private static func longestConsecutive(in achievedDates: Set<Date>, calendar: Calendar) -> Int {
        guard !achievedDates.isEmpty else { return 0 }
        let sorted = achievedDates.sorted()
        var longest = 1
        var current = 1
        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let curr = sorted[i]
            let days = calendar.dateComponents([.day], from: prev, to: curr).day ?? 0
            if days == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }
}
