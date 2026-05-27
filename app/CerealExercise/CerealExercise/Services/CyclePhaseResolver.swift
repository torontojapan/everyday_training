import Foundation

/// 日付 → 月経周期相 (CyclePhase) の **純関数** リゾルバ。
///
/// 入力:
/// - `periodDays`: ユーザーが marked した月経日 (startOfDay 正規化された Date の集合)
/// - 推定したい日付 + cycleLength / periodLength
///
/// アルゴリズム:
/// 1. 対象日が `periodDays` にあれば即 `.menstrual`
/// 2. 対象日 **以前** の最も近い periodStart (連続マークの先頭) を探す
/// 3. periodStart からの経過日数で相を分類:
///    - day 0 .. periodLength-1: 月経期 (フォールバック — 通常は #1 で捕捉)
///    - day periodLength .. (ovulationStart-1): 卵胞期
///    - ovulationStart .. ovulationEnd: 排卵期
///    - それ以降: 黄体期
/// 4. periodStart が見つからない or 古すぎる (= 1 cycle 以上前) なら nil
///
/// 周期長やフェーズ閾値はユーザー差があるが、まずは 28 日サイクル + 排卵窓 3 日で
/// 開始。将来は marked データから個人ごとに median 周期長を推定する余地あり。
enum CyclePhaseResolver {

    /// 1 つの相が占める区間。Chart の RectangleMark に渡しやすいよう
    /// startDay (inclusive) / endDay (exclusive) を持つ。
    struct PhaseSpan: Identifiable, Hashable, Sendable {
        var id: String { "\(phase.rawValue)-\(startDay.timeIntervalSince1970)" }
        let phase: CyclePhase
        /// 区間の先頭 (startOfDay) — inclusive
        let startDay: Date
        /// 区間の末尾の **翌日** startOfDay — exclusive (Chart で xEnd に渡しやすい)
        let endDay: Date
    }

    /// 単一日の相を判定。`periodDays` は startOfDay 正規化済みであること。
    /// 月経マーク済みの日は無条件で `.menstrual`。それ以外は直近の period start
    /// からの経過日数で推定。直近の period start が見つからない / cycleLength を
    /// 1 周以上超過していれば nil (= 推定不能)。
    static func phase(for date: Date,
                       periodDays: Set<Date>,
                       cycleLength: Int = 28,
                       periodLength: Int = 5,
                       ovulationWindow: ClosedRange<Int> = 13...15,
                       calendar: Calendar = .mondayFirst) -> CyclePhase? {
        precondition(cycleLength >= 14, "cycleLength は最小 14 (生理学的下限)")
        precondition(periodLength >= 1 && periodLength <= cycleLength / 2, "periodLength が異常")

        let day = calendar.startOfDay(for: date)
        if periodDays.contains(day) { return .menstrual }

        guard let start = mostRecentPeriodStart(onOrBefore: day,
                                                 periodDays: periodDays,
                                                 calendar: calendar) else {
            return nil
        }
        let daysSince = calendar.dateComponents([.day], from: start, to: day).day ?? 0
        // 1 周以上前の period start しか見つからない場合は次の周期予測の信頼性が
        // 落ちるので nil で扱う (= legend の "推定不可" 領域)。
        guard daysSince >= 0, daysSince < cycleLength else { return nil }

        switch daysSince {
        case 0..<periodLength:
            return .menstrual // marked 漏れの安全網 (#1 で捕捉しなかった場合)
        case periodLength..<ovulationWindow.lowerBound:
            return .follicular
        case ovulationWindow:
            return .ovulation
        default:
            return .luteal
        }
    }

    /// 指定された日付範囲 [`rangeStart`, `rangeEnd`) を相ごとに集約した
    /// `PhaseSpan` の配列を返す (古→新)。Chart で背景帯として描画しやすい。
    /// 相が連続して同じならマージ。`nil` (推定不能) な日は span に含めない。
    static func spans(in rangeStart: Date,
                       end rangeEnd: Date,
                       periodDays: Set<Date>,
                       cycleLength: Int = 28,
                       periodLength: Int = 5,
                       ovulationWindow: ClosedRange<Int> = 13...15,
                       calendar: Calendar = .mondayFirst) -> [PhaseSpan] {
        var result: [PhaseSpan] = []
        var cursor = calendar.startOfDay(for: rangeStart)
        let endDay = calendar.startOfDay(for: rangeEnd)
        guard cursor < endDay else { return [] }

        var currentPhase: CyclePhase? = nil
        var currentStart: Date = cursor

        while cursor < endDay {
            let p = phase(for: cursor, periodDays: periodDays,
                          cycleLength: cycleLength, periodLength: periodLength,
                          ovulationWindow: ovulationWindow, calendar: calendar)
            if p != currentPhase {
                // close out previous span
                if let prev = currentPhase {
                    result.append(PhaseSpan(phase: prev, startDay: currentStart, endDay: cursor))
                }
                currentPhase = p
                currentStart = cursor
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        // flush tail
        if let prev = currentPhase {
            result.append(PhaseSpan(phase: prev, startDay: currentStart, endDay: cursor))
        }
        return result
    }

    /// `target` 以前で最も近い「月経の **開始日**」を返す。開始日 = その日が
    /// marked かつ「前日が marked でない (or 存在しない)」もの。連続した
    /// 月経期間の途中日は開始日として扱わない。
    private static func mostRecentPeriodStart(onOrBefore target: Date,
                                               periodDays: Set<Date>,
                                               calendar: Calendar) -> Date? {
        // periodDays から target 以下のものだけ降順に走査
        let sorted = periodDays.filter { $0 <= target }.sorted(by: >)
        for day in sorted {
            let prev = calendar.date(byAdding: .day, value: -1, to: day) ?? day
            if !periodDays.contains(prev) {
                return day // この day は連続群の先頭 = period start
            }
        }
        return nil
    }
}
