import Foundation

enum WeeklyProgressCalculator {
    static func statuses(
        forWeekContaining date: Date,
        records: [WorkoutRecord],
        today: Date,
        restLimit: Int = 2,
        calendar: Calendar = .mondayFirst
    ) -> [DailyStatusEntry] {
        let week = calendar.weekInterval(containing: date)
        let restDays = Set(RestDayResolver.restDays(in: week, records: records, today: today, limit: restLimit, calendar: calendar))

        return calendar.days(in: week).map { day in
            let dayRecords = records.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let status = AchievementEvaluator.dailyStatus(
                for: day,
                records: records,
                restDays: restDays,
                today: today,
                calendar: calendar
            )
            return DailyStatusEntry(date: day, status: status, recordIds: dayRecords.map(\.id))
        }
    }

    static func progress(from statuses: [DailyStatusEntry]) -> WeeklyProgress {
        WeeklyProgress(
            achievedCount: statuses.filter { $0.status.countsAsAchieved }.count,
            totalDays: 7
        )
    }
}
