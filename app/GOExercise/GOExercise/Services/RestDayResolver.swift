import Foundation

enum RestDayResolver {
    static func restDays(
        in week: DateInterval,
        records: [WorkoutRecord],
        today: Date,
        limit: Int = 2,
        calendar: Calendar = .mondayFirst
    ) -> [Date] {
        guard limit > 0 else { return [] }

        let todayStart = calendar.startOfDay(for: today)
        let achievedDays = Set(
            records
                .filter { week.contains($0.date) && AchievementEvaluator.isAchieved(record: $0) }
                .map { calendar.startOfDay(for: $0.date) }
        )

        let candidates = calendar.days(in: week).filter { day in
            day <= todayStart && !achievedDays.contains(day)
        }

        return Array(candidates.prefix(limit))
    }

    static func restDaySet(
        for date: Date,
        records: [WorkoutRecord],
        today: Date,
        limit: Int = 2,
        calendar: Calendar = .mondayFirst
    ) -> Set<Date> {
        let week = calendar.weekInterval(containing: date)
        return Set(restDays(in: week, records: records, today: today, limit: limit, calendar: calendar))
    }
}
