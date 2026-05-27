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

    // MARK: - Expanded thresholds migration

    /// 旧定義時代から streak=350 のユーザーが拡充版に上がった瞬間、
    /// 過去達成済みの 10/30/50/100/200/300 (streak 系) を **連発しない** こと。
    /// firstUseDate は 364 日前 (anniversary 未到達) + lifetimeAchieved=0 にして
    /// 「streak 以外の候補は無い」状態を作り、純粋に migration scope を検証。
    @MainActor
    @Test
    func migratesExistingLongStreak_silentlyAcknowledgesPriorMilestones() {
        let suite = "milestone-migrate-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let detector = MilestoneDetector(defaults: defaults, calendar: .mondayFirst)

        let today = Date()
        // 364 日前 = 1 周年未満 → anniversary milestone は出ない
        let firstUse = Calendar.mondayFirst.date(byAdding: .day, value: -364, to: today)!

        let first = detector.nextPending(records: [], firstUseDate: firstUse, today: today,
                                          lifetimeAchieved: 0, currentStreak: 350)
        #expect(first == nil,
                "アップグレード直後の最初の呼び出しでは streak の連発が起きない")

        // 翌日 streak=400 に到達 → これは新しい節目なので celebration が出るべき
        let after = detector.nextPending(records: [], firstUseDate: firstUse, today: today,
                                          lifetimeAchieved: 0, currentStreak: 400)
        #expect(after == .currentStreak(400), "400 (= 新しい節目) は通常通り通知される")
    }

    // MARK: - Weight loss milestones

    /// 開始 70kg → 現在 64.8kg + 減量目標 → -3, -5 の閾値が達成済として返る。
    @Test
    func weightLossDetector_returnsReachedThresholds() {
        let reached = WeightLossMilestoneDetector.reachedThresholds(
            startKg: 70.0, currentKg: 64.8, isLossGoal: true
        )
        #expect(reached == [3, 5])
    }

    /// 増量目標 (isLossGoal=false) なら weightLoss は発火しない。
    @Test
    func weightLossDetector_skipsWhenNotLossGoal() {
        let reached = WeightLossMilestoneDetector.reachedThresholds(
            startKg: 55.0, currentKg: 60.0, isLossGoal: false
        )
        #expect(reached.isEmpty)
    }

    /// 必須情報が nil なら空。
    @Test
    func weightLossDetector_emptyOnMissingInputs() {
        #expect(WeightLossMilestoneDetector.reachedThresholds(
            startKg: nil, currentKg: 64.0, isLossGoal: true).isEmpty)
        #expect(WeightLossMilestoneDetector.reachedThresholds(
            startKg: 70.0, currentKg: nil, isLossGoal: true).isEmpty)
        #expect(WeightLossMilestoneDetector.reachedThresholds(
            startKg: 70.0, currentKg: 65.0, isLossGoal: nil).isEmpty)
    }

    /// weightLoss milestone の shareSubject / shareMessage / emoji / headline 整合性。
    @Test
    func weightLoss_milestone_consistentDisplayFields() {
        let m = Milestone.weightLoss(kg: 5)
        #expect(m.headline.contains("5"))
        #expect(m.shareMessage.contains("達成"))
        #expect(m.shareSubject == m.headline)
        #expect(!m.detail.isEmpty)
    }

    /// migration scope は streak のみで、未受け取りの anniversary / lifetimeDays は
    /// アップグレード後も通常通り通知される (Codex round2 priority 1)。
    @MainActor
    @Test
    func migrationDoesNotSwallow_anniversaryOrLifetimeMilestones() {
        let suite = "milestone-migrate-scope-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let detector = MilestoneDetector(defaults: defaults, calendar: .mondayFirst)

        let today = Date()
        // 2 周年 + 累計 100 日 + streak=350 のユーザー (旧定義時代から長期使用)。
        let firstUse = Calendar.mondayFirst.date(byAdding: .day, value: -800, to: today)!

        let first = detector.nextPending(records: [], firstUseDate: firstUse, today: today,
                                          lifetimeAchieved: 100, currentStreak: 350)
        // 一発目は migration で streak が消されるが、anniversary か lifetime のうち
        // 最初に出てくるものが返るべき。candidates の順序は anniversary → lifetime → streak。
        #expect(first == .anniversary(years: 2),
                "anniversary は migration 対象外、通常通り通知される (got \(String(describing: first)))")

        // anniversary を ack して再呼び出し → lifetime が次に来る
        if case .some(let m) = first { detector.acknowledge(m) }
        let second = detector.nextPending(records: [], firstUseDate: firstUse, today: today,
                                           lifetimeAchieved: 100, currentStreak: 350)
        #expect(second == .lifetimeDays(100),
                "lifetimeDays も migration 対象外で通知される (got \(String(describing: second)))")
    }
}
