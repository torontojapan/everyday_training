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
        // Public API: 都度 starts を作る (O(M log M))。spans() からの大量呼び出しには
        // pre-sorted starts を渡す internal helper を使う (Codex round1 priority 2)。
        let starts = computePeriodStarts(periodDays: periodDays, calendar: calendar)
        return phase(for: date, periodDays: periodDays, sortedPeriodStarts: starts,
                     cycleLength: cycleLength, periodLength: periodLength,
                     ovulationWindow: ovulationWindow, calendar: calendar)
    }

    /// 内部用 fast-path: sorted period starts を呼び出し側で 1 回だけ計算して
    /// 共有する形。`spans()` の day-by-day ループで毎日呼ぶ前提。
    private static func phase(for date: Date,
                               periodDays: Set<Date>,
                               sortedPeriodStarts: [Date],
                               cycleLength: Int,
                               periodLength: Int,
                               ovulationWindow: ClosedRange<Int>,
                               calendar: Calendar) -> CyclePhase? {
        precondition(cycleLength >= 14, "cycleLength は最小 14 (生理学的下限)")
        precondition(periodLength >= 1 && periodLength <= cycleLength / 2, "periodLength が異常")

        let day = calendar.startOfDay(for: date)
        if periodDays.contains(day) { return .menstrual }

        guard let start = binarySearchLatestStart(onOrBefore: day,
                                                   sortedStarts: sortedPeriodStarts) else {
            return nil
        }
        let daysSince = calendar.dateComponents([.day], from: start, to: day).day ?? 0
        guard daysSince >= 0, daysSince < cycleLength else { return nil }

        switch daysSince {
        case 0..<periodLength:
            return .menstrual
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
    ///
    /// 性能: period starts と starts の sorted ソートは **1 回だけ**事前計算。
    /// 各 day での `phase` 判定は二分探索 O(log M) となり、全体 O(N log M)
    /// (N=range 日数 / M=marked 日数)。Codex round1 priority 2 改善。
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

        // 一回だけ sorted period starts を作る。以降の per-day 判定で再利用。
        let sortedStarts = computePeriodStarts(periodDays: periodDays, calendar: calendar)

        var currentPhase: CyclePhase? = nil
        var currentStart: Date = cursor

        while cursor < endDay {
            let p = phase(for: cursor, periodDays: periodDays,
                          sortedPeriodStarts: sortedStarts,
                          cycleLength: cycleLength, periodLength: periodLength,
                          ovulationWindow: ovulationWindow, calendar: calendar)
            if p != currentPhase {
                if let prev = currentPhase {
                    result.append(PhaseSpan(phase: prev, startDay: currentStart, endDay: cursor))
                }
                currentPhase = p
                currentStart = cursor
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        if let prev = currentPhase {
            result.append(PhaseSpan(phase: prev, startDay: currentStart, endDay: cursor))
        }
        return result
    }

    /// `periodDays` から「連続群の先頭日」だけを **昇順** で抽出する。
    /// O(M log M) ソート + O(M) 走査 = O(M log M)。
    private static func computePeriodStarts(periodDays: Set<Date>,
                                             calendar: Calendar) -> [Date] {
        let sorted = periodDays.sorted()
        var starts: [Date] = []
        starts.reserveCapacity(sorted.count)
        for day in sorted {
            let prev = calendar.date(byAdding: .day, value: -1, to: day) ?? day
            if !periodDays.contains(prev) {
                starts.append(day)
            }
        }
        return starts
    }

    /// 昇順 sorted の starts から `target` 以下で最大の要素を二分探索で取得。
    /// O(log K) (K = period starts 数)。
    private static func binarySearchLatestStart(onOrBefore target: Date,
                                                 sortedStarts: [Date]) -> Date? {
        var lo = 0
        var hi = sortedStarts.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if sortedStarts[mid] <= target {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        return lo > 0 ? sortedStarts[lo - 1] : nil
    }
}
