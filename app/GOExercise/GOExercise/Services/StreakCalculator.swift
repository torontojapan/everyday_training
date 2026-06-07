import Foundation

enum StreakCalculator {
    static func currentStreak(
        records: [WorkoutRecord],
        today: Date,
        rescuedDates: Set<Date> = [],
        restLimit: Int = 2,
        calendar: Calendar = .mondayFirst
    ) -> Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: today)

        while true {
            let restDays = RestDayResolver.restDaySet(
                for: cursor,
                records: records,
                today: today,
                limit: restLimit,
                calendar: calendar
            )
            let status = AchievementEvaluator.dailyStatus(
                for: cursor,
                records: records,
                restDays: restDays,
                rescuedDates: rescuedDates,
                today: today,
                calendar: calendar
            )

            switch status {
            case .achieved, .todayAchieved:
                streak += 1
            case .rest, .todayPending:
                // rest = 連続を切らずスキップ。
                // todayPending = 今日まだ未記録 → 連続を切らずスキップし「昨日までの連続」を数える。
                // (今日記録すれば .todayAchieved になり今日分も加算される。フリーズ復活直後も
                //  昨日までの連続が即表示されるようにするための基準。todayPending は今日のみ発生。)
                break  // skip — does not count, but does not break the streak
            default:
                return streak
            }

            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return streak
            }
            cursor = previous
        }
    }

    static func streakState(
        records: [WorkoutRecord],
        today: Date,
        rescuedDates: Set<Date> = [],
        lookbackDays: Int = 365,
        restLimit: Int = 2,
        calendar: Calendar = .mondayFirst
    ) -> StreakState {
        let todayStart = calendar.startOfDay(for: today)
        let current = currentStreak(
            records: records, today: todayStart,
            rescuedDates: rescuedDates, restLimit: restLimit, calendar: calendar
        )
        var longest = 0
        var running = 0
        var lastAchievedDate: Date?

        let start = calendar.date(byAdding: .day, value: -lookbackDays, to: todayStart) ?? todayStart
        var cursor = start

        while cursor <= todayStart {
            let restDays = RestDayResolver.restDaySet(
                for: cursor,
                records: records,
                today: todayStart,
                limit: restLimit,
                calendar: calendar
            )
            let status = AchievementEvaluator.dailyStatus(
                for: cursor,
                records: records,
                restDays: restDays,
                rescuedDates: rescuedDates,
                today: todayStart,
                calendar: calendar
            )

            switch status {
            case .achieved, .todayAchieved:
                running += 1
                longest = max(longest, running)
                lastAchievedDate = cursor
            case .rest:
                break  // skip — running is preserved
            default:
                running = 0
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        return StreakState(currentStreak: current, longestStreak: longest, lastAchievedDate: lastAchievedDate)
    }
}
