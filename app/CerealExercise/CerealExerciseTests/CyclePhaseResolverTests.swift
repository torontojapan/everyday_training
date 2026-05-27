import Foundation
import Testing
@testable import CerealExercise

@MainActor
struct CyclePhaseResolverTests {
    private let cal: Calendar = .mondayFirst

    /// テスト用に「period start を day0 として N 日分 marked」を作る helper。
    private func marks(startingAt day0: Date, lengthDays: Int) -> Set<Date> {
        var result: Set<Date> = []
        for i in 0..<lengthDays {
            if let d = cal.date(byAdding: .day, value: i, to: cal.startOfDay(for: day0)) {
                result.insert(d)
            }
        }
        return result
    }

    private func day(_ offset: Int, from base: Date) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: base))!
    }

    // MARK: - phase(for:)

    /// 月経マーク済みの日は無条件で .menstrual。
    @Test
    func phase_markedDay_isMenstrual() {
        let base = Date()
        let periods = marks(startingAt: base, lengthDays: 5)
        for i in 0..<5 {
            #expect(CyclePhaseResolver.phase(for: day(i, from: base),
                                              periodDays: periods, calendar: cal) == .menstrual)
        }
    }

    /// 28 日周期、5 日経血のとき、day 6 (= period 終了直後) は卵胞期。
    @Test
    func phase_postPeriod_isFollicular() {
        let base = Date()
        let periods = marks(startingAt: base, lengthDays: 5)
        // day 5 = period 6 日目だが marked されていない (= period 終了済)
        // periodLength=5 で day 5 (daysSince=5) は follicular に入る
        let p = CyclePhaseResolver.phase(for: day(5, from: base),
                                          periodDays: periods, calendar: cal)
        #expect(p == .follicular)

        let p10 = CyclePhaseResolver.phase(for: day(10, from: base),
                                            periodDays: periods, calendar: cal)
        #expect(p10 == .follicular)
    }

    /// day 13/14/15 が排卵期 (デフォルト window 13...15)。
    @Test
    func phase_midCycle_isOvulation() {
        let base = Date()
        let periods = marks(startingAt: base, lengthDays: 5)
        for i in 13...15 {
            #expect(CyclePhaseResolver.phase(for: day(i, from: base),
                                              periodDays: periods, calendar: cal) == .ovulation,
                    "day \(i) は排卵期のはず")
        }
    }

    /// day 16〜27 が黄体期 (水分貯留が増えやすい期間)。
    @Test
    func phase_postOvulation_isLuteal() {
        let base = Date()
        let periods = marks(startingAt: base, lengthDays: 5)
        for i in [16, 20, 27] {
            #expect(CyclePhaseResolver.phase(for: day(i, from: base),
                                              periodDays: periods, calendar: cal) == .luteal,
                    "day \(i) は黄体期のはず")
        }
    }

    /// 1 周以上前の period start しか見つからないとき (= 次の周期予測の信頼性
    /// が落ちる) は nil を返す。
    @Test
    func phase_overOneFullCycle_returnsNil() {
        let base = Date()
        let periods = marks(startingAt: base, lengthDays: 5)
        // day 28 = ちょうど 1 周期後 (信頼境界)
        #expect(CyclePhaseResolver.phase(for: day(28, from: base),
                                          periodDays: periods, calendar: cal) == nil)
        #expect(CyclePhaseResolver.phase(for: day(50, from: base),
                                          periodDays: periods, calendar: cal) == nil)
    }

    /// period start が未来日 (= 対象日より後) しか無いと nil。
    @Test
    func phase_onlyFuturePeriods_returnsNil() {
        let base = Date()
        let futurePeriods = marks(startingAt: day(10, from: base), lengthDays: 5)
        #expect(CyclePhaseResolver.phase(for: base, periodDays: futurePeriods, calendar: cal) == nil)
    }

    /// 連続したマーク群の中央の day は「開始日」ではなく、その群の先頭が
    /// `mostRecentPeriodStart` として使われる (= 経過日数の起点が正しい)。
    @Test
    func phase_takesFirstDayOfStreak_asPeriodStart() {
        let base = Date()
        let periods = marks(startingAt: base, lengthDays: 5) // day 0..4
        // day 3 は marked で .menstrual 即返り。day 14 は base から 14 日 →
        // 排卵期 (group の先頭 = base が period start として正しく使われる)
        #expect(CyclePhaseResolver.phase(for: day(14, from: base),
                                          periodDays: periods, calendar: cal) == .ovulation)
    }

    // MARK: - spans(in:end:)

    /// 60 日範囲を spans に展開して、月経期 / 卵胞期 / 排卵期 / 黄体期 / nil
    /// の隣接同相がマージされていることを確認。
    @Test
    func spans_mergesConsecutiveSamePhases() {
        let base = cal.startOfDay(for: Date())
        let periods = marks(startingAt: base, lengthDays: 5)
        let spans = CyclePhaseResolver.spans(
            in: base,
            end: day(28, from: base),
            periodDays: periods,
            calendar: cal
        )

        // 期待: [月経 0..5), [卵胞 5..13), [排卵 13..16), [黄体 16..28)
        #expect(spans.count == 4)
        #expect(spans[0].phase == .menstrual)
        #expect(spans[0].startDay == base)
        #expect(spans[0].endDay == day(5, from: base))
        #expect(spans[1].phase == .follicular)
        #expect(spans[1].endDay == day(13, from: base))
        #expect(spans[2].phase == .ovulation)
        #expect(spans[2].endDay == day(16, from: base))
        #expect(spans[3].phase == .luteal)
        #expect(spans[3].endDay == day(28, from: base))
    }

    /// 大きな範囲 (1000 日) で構造的破綻が起きないこと。
    /// wall-clock の閾値は CI 環境差で flaky になるため使わない (Codex round2)。
    /// 「無限ループしていない」「span が時間順」「過剰な数の span が出ない」
    /// の structural 不変条件のみを検証する。
    @Test
    func spans_largeRange_structurallyConsistent() {
        let base = cal.startOfDay(for: Date())
        var periods: Set<Date> = []
        for cycle in 0..<36 {
            for d in 0..<5 {
                if let day = cal.date(byAdding: .day, value: -(cycle * 28 + d), to: base) {
                    periods.insert(day)
                }
            }
        }
        let rangeStart = cal.date(byAdding: .day, value: -999, to: base)!
        let rangeEnd = cal.date(byAdding: .day, value: 1, to: base)!
        let spans = CyclePhaseResolver.spans(
            in: rangeStart, end: rangeEnd, periodDays: periods, calendar: cal
        )

        #expect(!spans.isEmpty)
        // 時間順 (前 span の終端 ≤ 次 span の始端)
        for i in 1..<spans.count {
            #expect(spans[i - 1].endDay <= spans[i].startDay,
                    "span \(i-1) と \(i) が時間順でない")
        }
        // 1 周期 4 相 × 36 周期 = 144 が上限。1000 日 / 7 = 143。
        // 200 を超えたら明らかにマージ漏れか無限ループ気味。
        #expect(spans.count <= 200, "span 数 \(spans.count) が想定上限 200 を超えた (マージ漏れの兆候)")
    }

    /// period 未マークの期間 (1 周以上前) は span から欠落する (nil でスキップ)。
    @Test
    func spans_skipsUnresolvableRegion() {
        let base = Date()
        let periods = marks(startingAt: base, lengthDays: 5)
        // 周期 28 を超えた day 28〜35 は nil で span から消える
        let spans = CyclePhaseResolver.spans(
            in: base,
            end: day(35, from: base),
            periodDays: periods,
            calendar: cal
        )
        // 期待: 4 つの相の span が day 0..28 まで → day 28..35 は span 無し
        let coveredEnd = spans.last?.endDay ?? base
        #expect(coveredEnd <= day(28, from: base),
                "1 周期超過は span に含まれない (got endDay=\(coveredEnd))")
    }
}
