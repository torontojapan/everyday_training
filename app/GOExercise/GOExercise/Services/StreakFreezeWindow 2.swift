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
                case .achieved, .todayAchieved, .rescued:
                    // rescued(過去のフリーズ救済日)も達成と同じ「連続の頭」(.rescued は表示分離用)。
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
    ///
    /// rest 日は lookback 枠を消費しない(連続を切らない)ため、anchor(連続の頭=achieved)に
    /// 到達するまで rest を読み飛ばして走査を**動的に延長**する。固定 lookback+1 件だと、
    /// missed と anchor の間に自動休養(週2日)が挟まったとき anchor が窓の外へ押し出され、
    /// foundPrior=false → 復活可能なのにポップが出ない不具合になる(監査 P1)。
    /// 打ち切り条件: anchor 到達 / lookback 超の missed 到達 / 安全上限(lookback + 1週間)。
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
        // 自動休養は最大週2日。grace(lookback)+ 連続した休養の最大幅を吸収できる安全上限。
        let hardCap = lookback + 7
        scan: for offset in 1...hardCap {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { break }
            let restDays = RestDayResolver.restDaySet(for: day, records: records, today: todayStart, calendar: calendar)
            let s = AchievementEvaluator.dailyStatus(
                for: day, records: records, restDays: restDays,
                rescuedDates: rescuedDates, today: todayStart, calendar: calendar)
            statuses.append(s)
            switch s {
            case .achieved, .todayAchieved, .rescued:
                break scan                       // anchor 到達 → これ以上不要(rescued も達成扱い)
            case .rest:
                continue                          // 休養は枠を消費せず連続も切らない → 延長
            case .missed:
                if offset > lookback { break scan }  // グレース超 → 復活不可確定、打ち切り
                continue
            default:
                break scan                        // .future/.todayPending は後方に現れない想定、安全側で停止
            }
        }
        return Decision.evaluate(statuses: statuses, remainingFreezes: remainingFreezes, lookback: lookback)
    }

    /// offset 群(1=昨日…)を実際の Date(startOfDay)に変換。
    static func missedDates(forOffsets offsets: [Int], today: Date, calendar: Calendar = .mondayFirst) -> [Date] {
        let todayStart = calendar.startOfDay(for: today)
        return offsets.compactMap { calendar.date(byAdding: .day, value: -$0, to: todayStart) }
    }
}
