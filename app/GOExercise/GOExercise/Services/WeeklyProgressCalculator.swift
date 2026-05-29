import Foundation

enum WeeklyProgressCalculator {
    static func statuses(
        forWeekContaining date: Date,
        records: [WorkoutRecord],
        today: Date,
        rescuedDates: Set<Date> = [],
        restLimit: Int = 2,
        calendar: Calendar = .mondayFirst
    ) -> [DailyStatusEntry] {
        let week = calendar.weekInterval(containing: date)
        let restDays = Set(RestDayResolver.restDays(in: week, records: records, today: today, limit: restLimit, calendar: calendar))

        return calendar.days(in: week).map { day in
            let dayRecords = records.filter { calendar.isDate($0.date, inSameDayAs: day) }
            // 保険チケット救済日も達成扱いにするため rescuedDates を渡す。
            // これが無いと週カレンダー/週次進捗だけが救済を無視し、
            // 履歴タブの月次カレンダーや streak と食い違う (3 LLM 監査 A-Major)。
            let status = AchievementEvaluator.dailyStatus(
                for: day,
                records: records,
                restDays: restDays,
                rescuedDates: rescuedDates,
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
