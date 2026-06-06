import Foundation

/// 連続が途切れた後「4日グレース」内で、フリーズ(rescue ticket)を missed 日に
/// 適用すれば連続が復活する状況を検出する純ロジック。
/// 2層: `Decision`(status 列だけの純判定・swiftc 完全テスト可)+ records 入口。
enum StreakFreezeWindow {
    struct Result: Equatable {
        /// 復活可能(直近グレース内に missed 日があり、その手前に連続の頭がある)。
        let revivable: Bool
        /// フリーズを当てるべき「今日からの日数オフセット」(1=昨日, 2=一昨日…)。
        let missedOffsets: [Int]
        /// 必要フリーズ枚数(= missed 日数)。
        let freezesNeeded: Int
        /// 残枠が足りるか。
        let hasEnough: Bool
    }

    enum Decision {
        /// statuses[0]=昨日, [1]=一昨日… の順(古い方向)。
        static func evaluate(statuses: [DailyStatus], remainingFreezes: Int, lookback: Int) -> Result {
            var missedOffsets: [Int] = []
            var foundPrior = false
            var i = 0
            while i < lookback && i < statuses.count {
                switch statuses[i] {
                case .achieved, .todayAchieved:
                    foundPrior = true
                case .rest:
                    break // freeze 不要、連続も切らない → 次へ
                case .missed:
                    missedOffsets.append(i + 1) // offset 1=昨日
                default:
                    // .future/.todayPending は後方走査では現れない想定。安全側で停止。
                    i = lookback
                    continue
                }
                if foundPrior { break }
                i += 1
            }
            let revivable = foundPrior && !missedOffsets.isEmpty
            let need = missedOffsets.count
            return Result(
                revivable: revivable,
                missedOffsets: revivable ? missedOffsets : [],
                freezesNeeded: revivable ? need : 0,
                hasEnough: revivable && remainingFreezes >= need
            )
        }
    }

    /// records から status 列(昨日→過去)を作り `Decision` に委譲する本番入口。
    static func evaluate(
        records: [WorkoutRecord],
        today: Date,
        rescuedDates: Set<Date>,
        remainingFreezes: Int,
        lookback: Int = 4,
        calendar: Calendar = .mondayFirst
    ) -> Result {
        let todayStart = calendar.startOfDay(for: today)
        var statuses: [DailyStatus] = []
        for offset in 1...lookback {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { break }
            let restDays = RestDayResolver.restDaySet(for: day, records: records, today: todayStart, calendar: calendar)
            let s = AchievementEvaluator.dailyStatus(
                for: day, records: records, restDays: restDays,
                rescuedDates: rescuedDates, today: todayStart, calendar: calendar)
            statuses.append(s)
        }
        return Decision.evaluate(statuses: statuses, remainingFreezes: remainingFreezes, lookback: lookback)
    }

    /// offset 群(1=昨日…)を実際の Date(startOfDay)に変換。
    static func missedDates(forOffsets offsets: [Int], today: Date, calendar: Calendar = .mondayFirst) -> [Date] {
        let todayStart = calendar.startOfDay(for: today)
        return offsets.compactMap { calendar.date(byAdding: .day, value: -$0, to: todayStart) }
    }
}
