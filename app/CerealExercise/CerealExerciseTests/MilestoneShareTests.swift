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
}
