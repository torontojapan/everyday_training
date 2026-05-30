import Foundation

enum MonthlyReviewBuilder {
    struct Review: Equatable {
        /// 期間ラベル (月: "2026年5月" / 週: "5/26 - 6/1" / 累計: "通算 365日")。
        let monthLabel: String
        let achievedDays: Int
        let totalDays: Int
        /// 期間内の最長連続達成日数 (月/週/累計いずれもこのフィールドに入れる)。
        let longestStreakInMonth: Int
        let totalDurationMinutes: Int
        let totalExerciseCount: Int
        let topCategory: WorkoutCategory?
        let topExerciseName: String?
    }

    // MARK: - 月次

    static func build(
        records: [WorkoutRecord],
        month: Date,
        calendar: Calendar = .mondayFirst
    ) -> Review {
        let monthStart = startOfMonth(month, calendar: calendar)
        let label = monthLabel(monthStart, calendar: calendar)
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return empty(label: label)
        }
        let monthEnd = calendar.date(byAdding: .day, value: range.count - 1, to: monthStart) ?? monthStart
        let scoped = records.filter { record in
            let day = calendar.startOfDay(for: record.date)
            return day >= monthStart && day <= monthEnd
        }
        return buildCore(scoped: scoped, label: label, totalDays: range.count, calendar: calendar)
    }

    // MARK: - 週次

    static func weekly(
        records: [WorkoutRecord],
        weekContaining date: Date,
        calendar: Calendar = .mondayFirst
    ) -> Review {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return empty(label: "今週")
        }
        let weekStart = calendar.startOfDay(for: week.start)
        let lastDay = calendar.date(byAdding: .day, value: -1, to: week.end) ?? week.end
        let weekEnd = calendar.startOfDay(for: lastDay)
        let scoped = records.filter { record in
            let day = calendar.startOfDay(for: record.date)
            return day >= weekStart && day <= weekEnd
        }
        return buildCore(scoped: scoped, label: weekLabel(weekStart, weekEnd, calendar: calendar), totalDays: 7, calendar: calendar)
    }

    // MARK: - 累計

    static func lifetime(
        records: [WorkoutRecord],
        today: Date,
        calendar: Calendar = .mondayFirst
    ) -> Review {
        let todayStart = calendar.startOfDay(for: today)
        let totalDays: Int
        if let first = records.map({ calendar.startOfDay(for: $0.date) }).min() {
            totalDays = (calendar.dateComponents([.day], from: first, to: todayStart).day ?? 0) + 1
        } else {
            totalDays = 0
        }
        return buildCore(scoped: records, label: "通算 \(totalDays)日", totalDays: totalDays, calendar: calendar)
    }

    // MARK: - 共通コア

    private static func buildCore(
        scoped: [WorkoutRecord],
        label: String,
        totalDays: Int,
        calendar: Calendar
    ) -> Review {
        let achievedDates = Set(
            scoped.filter { AchievementEvaluator.isAchieved(record: $0) }
                .map { calendar.startOfDay(for: $0.date) }
        )
        let longestStreak = longestConsecutive(in: achievedDates, calendar: calendar)

        let allExercises = scoped.flatMap(\.exercises)
        let totalDurationMinutes = allExercises.compactMap(\.durationSeconds).reduce(0, +) / 60
        let totalExerciseCount = allExercises.count

        // 種目ごとのカテゴリで集計 (複数カテゴリ記録を正しく扱う。旧データは記録の category)。
        let categoryCounts = scoped.reduce(into: [WorkoutCategory: Int]()) { partial, record in
            for item in record.exercises {
                partial[item.category ?? record.category, default: 0] += 1
            }
        }
        let topCategory = categoryCounts.max(by: { $0.value < $1.value })?.key

        let exerciseNameCounts = allExercises.reduce(into: [String: Int]()) { partial, item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            partial[name, default: 0] += 1
        }
        let topExerciseName = exerciseNameCounts.max(by: { $0.value < $1.value })?.key

        return Review(
            monthLabel: label,
            achievedDays: achievedDates.count,
            totalDays: totalDays,
            longestStreakInMonth: longestStreak,
            totalDurationMinutes: totalDurationMinutes,
            totalExerciseCount: totalExerciseCount,
            topCategory: topCategory,
            topExerciseName: topExerciseName
        )
    }

    private static func empty(label: String) -> Review {
        Review(monthLabel: label, achievedDays: 0, totalDays: 0, longestStreakInMonth: 0,
               totalDurationMinutes: 0, totalExerciseCount: 0, topCategory: nil, topExerciseName: nil)
    }

    // MARK: - Helpers

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

    private static func weekLabel(_ start: Date, _ end: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
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
