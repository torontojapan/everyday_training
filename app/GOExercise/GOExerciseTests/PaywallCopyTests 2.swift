import XCTest
@testable import GOExercise

final class PaywallCopyTests: XCTestCase {

    func test_eligible_advertisesFreeTrial() {
        let c = PaywallCopy.strings(trialEligible: true)
        XCTAssertTrue(c.subhead.contains("14日間無料"))
        XCTAssertEqual(c.cta, "14日間無料で始める")
        XCTAssertTrue(c.autoRenewDisclosure.contains("14日間の無料体験"))
        XCTAssertNotNil(c.freeTrialCancelNote)
    }

    func test_notEligible_neverMentionsFree() {
        // 適格でない(消化済み)のに「無料」を出すと審査リジェクト/誤認の元。一切出さないことを担保。
        let c = PaywallCopy.strings(trialEligible: false)
        XCTAssertEqual(c.subhead, "いつでも解約できます。")
        XCTAssertEqual(c.cta, "プレミアムを始める")
        XCTAssertEqual(c.autoRenewDisclosure, "・選択したプランで自動更新されます")
        XCTAssertNil(c.freeTrialCancelNote)
        for line in [c.subhead, c.cta, c.autoRenewDisclosure] {
            XCTAssertFalse(line.contains("無料"), "「\(line)」に無料表現が混入")
            XCTAssertFalse(line.contains("14日間"), "「\(line)」に14日間が混入")
        }
    }
}
