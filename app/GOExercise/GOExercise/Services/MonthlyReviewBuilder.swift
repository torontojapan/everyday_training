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
        today: Date,
        rescuedDates: Set<Date> = [],
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
        return buildCore(
            scoped: scoped, allRecords: records,
            rangeStart: monthStart, rangeEnd: monthEnd,
            today: today, rescuedDates: rescuedDates,
            label: label, totalDays: range.count, calendar: calendar
        )
    }

    // MARK: - 週次

    static func weekly(
        records: [WorkoutRecord],
        weekContaining date: Date,
        today: Date,
        rescuedDates: Set<Date> = [],
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
        return buildCore(
            scoped: scoped, allRecords: records,
            rangeStart: weekStart, rangeEnd: weekEnd,
            today: today, rescuedDates: rescuedDates,
            label: weekLabel(weekStart, weekEnd, calendar: calendar), totalDays: 7, calendar: calendar
        )
    }

    // MARK: - 累計

    static func lifetime(
        records: [WorkoutRecord],
        today: Date,
        rescuedDates: Set<Date> = [],
        calendar: Calendar = .mondayFirst
    ) -> Review {
        let todayStart = calendar.startOfDay(for: today)
        let firstRecordDay = records.map { calendar.startOfDay(for: $0.date) }.min()
        let totalDays: Int
        if let first = firstRecordDay {
            totalDays = (calendar.dateComponents([.day], from: first, to: todayStart).day ?? 0) + 1
        } else {
            totalDays = 0
        }
        // 最長連続の走査開始日は記録と救済の両方の最古日。救済日が最初の記録より前にある
        // 履歴も連続として正しく拾う (正本 streakState は固定窓 today-365 なのでこの穴が無い。
        // lifetime は records.min に依存していたため救済日が範囲外に落ちる edge を埋める。Codex P2)。
        let firstRescuedDay = rescuedDates.map { calendar.startOfDay(for: $0) }.min()
        let rangeStart = [firstRecordDay, firstRescuedDay].compactMap { $0 }.min() ?? todayStart
        return buildCore(
            scoped: records, allRecords: records,
            rangeStart: rangeStart, rangeEnd: todayStart,
            today: today, rescuedDates: rescuedDates,
            label: "通算 \(totalDays)日", totalDays: totalDays, calendar: calendar
        )
    }

    // MARK: - 共通コア

    private static func buildCore(
        scoped: [WorkoutRecord],
        allRecords: [WorkoutRecord],
        rangeStart: Date,
        rangeEnd: Date,
        today: Date,
        rescuedDates: Set<Date>,
        restLimit: Int = 2,
        label: String,
        totalDays: Int,
        calendar: Calendar
    ) -> Review {
        let achievedDates = Set(
            scoped.filter { AchievementEvaluator.isAchieved(record: $0) }
                .map { calendar.startOfDay(for: $0.date) }
        )
        // 最長連続は正本 (StreakCalculator.streakState) と同じ判定でカウントする:
        // 自動休養 (rest) 日とフリーズ救済日 (rescuedDates) は連続を切らず橋渡しする。
        // 期間 [rangeStart, min(rangeEnd, today)] を 1 日ずつ走査し、
        // dailyStatus が achieved/todayAchieved なら running を伸ばし、
        // rest/todayPending は据え置き (skip)、それ以外で running をリセットする。
        let longestStreak = longestConsecutiveBridged(
            records: allRecords, from: rangeStart, to: rangeEnd,
            today: today, rescuedDates: rescuedDates, restLimit: restLimit, calendar: calendar
        )

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

    /// 期間内の最長連続達成日数を、正本 (StreakCalculator.streakState) と同一の
    /// 判定で算出する。自動休養 (rest) 日とフリーズ救済日 (rescuedDates) は
    /// 連続を切らず橋渡しする。範囲は [rangeStart, min(rangeEnd, today)]。
    private static func longestConsecutiveBridged(
        records: [WorkoutRecord],
        from rangeStart: Date,
        to rangeEnd: Date,
        today: Date,
        rescuedDates: Set<Date>,
        restLimit: Int,
        calendar: Calendar
    ) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        let start = calendar.startOfDay(for: rangeStart)
        // 未来日は連続に寄与しないので today までにクランプする。
        let end = min(calendar.startOfDay(for: rangeEnd), todayStart)
        guard start <= end else { return 0 }

        var longest = 0
        var running = 0
        var cursor = start
        while cursor <= end {
            let restDays = RestDayResolver.restDaySet(
                for: cursor, records: records, today: todayStart,
                limit: restLimit, calendar: calendar
            )
            let status = AchievementEvaluator.dailyStatus(
                for: cursor, records: records, restDays: restDays,
                rescuedDates: rescuedDates, today: todayStart, calendar: calendar
            )
            switch status {
            case .achieved, .todayAchieved:
                running += 1
                longest = max(longest, running)
            case .rest, .todayPending:
                break  // skip — 連続を切らず running を保つ (rest/救済の橋渡し)
            default:
                running = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return longest
    }
}
