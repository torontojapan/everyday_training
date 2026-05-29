import Foundation

enum LifetimeStatsCalculator {
    struct Stats: Equatable {
        let achievedDays: Int
        let usedDays: Int

        var rate: Double {
            guard usedDays > 0 else { return 0 }
            return Double(achievedDays) / Double(usedDays)
        }
    }

    static func calculate(
        records: [WorkoutRecord],
        firstUseDate: Date,
        today: Date,
        calendar: Calendar = .mondayFirst
    ) -> Stats {
        let firstUseStart = calendar.startOfDay(for: firstUseDate)
        let todayStart = calendar.startOfDay(for: today)

        // Used days = inclusive day count from first use to today (min 1).
        let daysBetween = calendar.dateComponents([.day], from: firstUseStart, to: todayStart).day ?? 0
        let usedDays = max(1, daysBetween + 1)

        // Achieved days = unique days where at least one workout record was achieved.
        let achievedDates = records
            .filter { AchievementEvaluator.isAchieved(record: $0) }
            .map { calendar.startOfDay(for: $0.date) }
        let uniqueAchieved = Set(achievedDates).count

        return Stats(achievedDays: uniqueAchieved, usedDays: usedDays)
    }
}
