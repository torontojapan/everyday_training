import Foundation

enum AchievementEvaluator {
    static func isAchieved(record: WorkoutRecord) -> Bool {
        let hasExercise = !record.exercises.isEmpty
        let totalSeconds = record.exercises.reduce(0) { total, exercise in
            total + (exercise.durationSeconds ?? 0)
        }
        return hasExercise || totalSeconds >= 60
    }

    static func dailyStatus(
        for date: Date,
        records: [WorkoutRecord],
        restDays: Set<Date>,
        rescuedDates: Set<Date> = [],
        today: Date,
        calendar: Calendar = .mondayFirst
    ) -> DailyStatus {
        let day = calendar.startOfDay(for: date)
        let currentDay = calendar.startOfDay(for: today)
        let dayRecords = records.filter { calendar.isDate($0.date, inSameDayAs: day) }
        let achieved = dayRecords.contains { isAchieved(record: $0) }

        if day > currentDay {
            return .future
        }

        if calendar.isDate(day, inSameDayAs: currentDay) {
            return achieved ? .todayAchieved : .todayPending
        }

        if achieved {
            return .achieved
        }

        // 保険チケット使用日は achieved と同等に扱う。連続記録にカウントされ、
        // カレンダー上は ○ + チケットアイコンで表示される。
        if rescuedDates.contains(day) {
            return .achieved
        }

        if restDays.contains(day) {
            return .rest
        }

        return .missed
    }
}
