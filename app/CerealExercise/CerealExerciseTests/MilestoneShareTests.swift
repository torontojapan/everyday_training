import Foundation
import Testing
@testable import CerealExercise

/// SNS シェア用テキスト (`Milestone.shareMessage` / `shareSubject`) が空でなく、
/// 140 字以内 (Twitter プレビューや LINE 表示で切れない目安) に収まることを保証する。
struct MilestoneShareTests {
    @Test
    func shareMessage_isNonEmpty_andUnder140Chars_forAllMilestoneTypes() {
        let samples: [Milestone] = [
            .anniversary(years: 1),
            .anniversary(years: 5),
            .lifetimeDays(100),
            .lifetimeDays(365),
            .lifetimeDays(1000),
            .currentStreak(30),
            .currentStreak(100),
            .currentStreak(365),
        ]
        for m in samples {
            #expect(!m.shareMessage.isEmpty, "\(m) の shareMessage が空")
            #expect(m.shareMessage.count <= 140,
                    "\(m) の shareMessage が長すぎる: \(m.shareMessage.count) 字")
            // 「達成」が含まれていれば自慢系の語彙が拾えている保険チェック
            #expect(m.shareMessage.contains("達成"),
                    "\(m) の shareMessage に「達成」が含まれていない")
        }
    }

    @Test
    func shareSubject_matchesHeadline() {
        let m = Milestone.currentStreak(30)
        #expect(m.shareSubject == m.headline)
    }

    // MARK: - currentStreak milestone thresholds

    /// 連続記録のマイルストーン: 10/30/50 で序盤ブースト、100 以降は 100 単位。
    @Test
    func currentStreakMilestones_short_returnsExpectedSequence() {
        #expect(MilestoneDetector.currentStreakMilestones(upTo: 9) == [])
        #expect(MilestoneDetector.currentStreakMilestones(upTo: 10) == [10])
        #expect(MilestoneDetector.currentStreakMilestones(upTo: 29) == [10])
        #expect(MilestoneDetector.currentStreakMilestones(upTo: 30) == [10, 30])
        #expect(MilestoneDetector.currentStreakMilestones(upTo: 49) == [10, 30])
        #expect(MilestoneDetector.currentStreakMilestones(upTo: 50) == [10, 30, 50])
        #expect(MilestoneDetector.currentStreakMilestones(upTo: 99) == [10, 30, 50])
        #expect(MilestoneDetector.currentStreakMilestones(upTo: 100) == [10, 30, 50, 100])
    }

    /// 100 以降は厳密に 100 単位で増えること (199 で 100 のみ、200 で +200)。
    @Test
    func currentStreakMilestones_hundredsStep_returnsEveryHundred() {
        #expect(MilestoneDetector.currentStreakMilestones(upTo: 199) == [10, 30, 50, 100])
        #expect(MilestoneDetector.currentStreakMilestones(upTo: 200) == [10, 30, 50, 100, 200])
        #expect(MilestoneDetector.currentStreakMilestones(upTo: 350) == [10, 30, 50, 100, 200, 300])
        #expect(MilestoneDetector.currentStreakMilestones(upTo: 1000) ==
                [10, 30, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000])
    }

    /// 上限 (2000) を超えても無限ループせず、頭打ちすること。
    @Test
    func currentStreakMilestones_capped_doesNotOverflowAtHighInput() {
        let result = MilestoneDetector.currentStreakMilestones(upTo: 5000)
        #expect(result.last == 2000, "2000 で打ち切り (現実的範囲ガード)")
        #expect(result.count == 23, "10/30/50 + 100..2000 = 3 + 20 = 23 件")
    }
}
