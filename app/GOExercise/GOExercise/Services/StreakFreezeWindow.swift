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
        /// 直近 `lookback` 日ぶんの missed を集めつつ、**その手前(最大 lookback+1 日目)に連続の頭**
        /// (achieved/rest 経由)があるかで復活可否を決める。lookback 丁度(例: 4日)の連続欠けでも、
        /// 1つ先(offset lookback+1)の achieved を anchor に拾えるよう statuses は lookback+1 件渡す。
        static func evaluate(statuses: [DailyStatus], remainingFreezes: Int, lookback: Int) -> Result {
            var missedOffsets: [Int] = []
            var foundPrior = false
            var tooOld = false // missed が lookback を超えて続く = 4日グレース外で復活不可
            loop: for (idx, status) in statuses.enumerated() {
                let offset = idx + 1
                switch status {
                case .achieved, .todayAchieved:
                    foundPrior = true // 連続の頭に到達
                    break loop
                case .rest:
                    continue // freeze 不要、連続も切らない → 次へ
                case .missed:
                    if offset <= lookback {
                        missedOffsets.append(offset) // offset 1=昨日
                    } else {
                        tooOld = true // lookback+1 日目以降も missed = グレース超過
                        break loop
                    }
                default:
                    break loop // .future/.todayPending は後方走査では現れない想定。安全側で停止。
                }
            }
            let revivable = foundPrior && !tooOld && !missedOffsets.isEmpty
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
    /// anchor 検出のため lookback+1 日ぶん作る(missed 収集は Decision 側で lookback に制限)。
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
        for offset in 1...(lookback + 1) {
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
