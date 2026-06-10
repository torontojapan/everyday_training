import XCTest
@testable import GOExercise

final class ReferralLogicTests: XCTestCase {

    // MARK: - RescueTicketAllowance (base + 紹介ボーナス, 月次上限5)
    func test_allowance_base_unchanged() {
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: false, referralBonus: 0), 1)
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: true,  referralBonus: 0), 4)
    }
    func test_allowance_addsBonus_clipsAt5() {
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: false, referralBonus: 3), 4)
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: false, referralBonus: 10), 5)
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: true, referralBonus: 1), 5)
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: true, referralBonus: 5), 5)
    }
    func test_allowance_negativeBonus_floored() {
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: false, referralBonus: -3), 1)
    }
    func test_allowance_oldAPI_delegates() {
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: false), 1)
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: true), 4)
    }

    // MARK: - ReferralClock
    func test_clock_parsesPostgresTimestamps() {
        XCTAssertNotNil(ReferralClock.parseTimestamp("2026-06-05T12:00:00+00:00"))
        XCTAssertNotNil(ReferralClock.parseTimestamp("2026-06-05T12:00:00.123456+00:00"))
        XCTAssertNil(ReferralClock.parseTimestamp("not-a-date"))
    }
    func test_clock_isInMonth() {
        // 月判定はフリーズ allowance と同じ **ローカル暦**(端末=JST)で行う(GPT-5.5 監査:
        // 旧実装は UTC 固定で、allowance(local) と月境界でずれた)。決定的にするため TZ を固定。
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let now = DateComponents(calendar: cal, year: 2026, month: 6, day: 20).date!
        // 2026-06-01 00:00Z = 06-01 09:00 JST → 6月(同月)
        XCTAssertTrue(ReferralClock.isInMonth("2026-06-01T00:00:00+00:00", of: now, calendar: cal))
        // 2026-05-31 23:00Z = 06-01 08:00 JST → ローカルでは 6月(同月)。UTC固定の旧仕様では別月だった。
        XCTAssertTrue(ReferralClock.isInMonth("2026-05-31T23:00:00+00:00", of: now, calendar: cal))
        // 2026-05-31 10:00Z = 05-31 19:00 JST → 5月(別月)
        XCTAssertFalse(ReferralClock.isInMonth("2026-05-31T10:00:00+00:00", of: now, calendar: cal))
        XCTAssertFalse(ReferralClock.isInMonth(nil, of: now, calendar: cal))
    }

    // MARK: - ReferralEntryPolicy (設定からの「後から入力」)
    func test_entryPolicy_allowsWithinGrace_whenNoReferrer() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let day3 = start.addingTimeInterval(3 * 86400)
        XCTAssertTrue(ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: start, now: day3, hasExistingReferral: false))
    }
    func test_entryPolicy_blocksAfterGrace() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let day8 = start.addingTimeInterval(8 * 86400)
        XCTAssertFalse(ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: start, now: day8, hasExistingReferral: false))
    }
    // 境界(監査): 「7日以内」= ちょうど 7×24h まで許可、それを 1 秒でも超えたら不可。
    // 旧実装は Int(interval/86400)<=7 で実質8日まで許可していた。
    func test_entryPolicy_boundaryExactly7Days_allowed() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let day7 = start.addingTimeInterval(7 * 86400)
        XCTAssertTrue(ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: start, now: day7, hasExistingReferral: false))
    }
    func test_entryPolicy_justOver7Days_blocked() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let justOver = start.addingTimeInterval(7 * 86400 + 1)
        XCTAssertFalse(ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: start, now: justOver, hasExistingReferral: false))
    }
    func test_entryPolicy_oldTruncationWindow_nowBlocked() {
        // 旧実装で許可されていた 7.5 日(切り捨てで days=7)は、新実装では不可。
        let start = Date(timeIntervalSince1970: 1_000_000)
        let day7_5 = start.addingTimeInterval(7.5 * 86400)
        XCTAssertFalse(ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: start, now: day7_5, hasExistingReferral: false))
    }

    func test_entryPolicy_blocksWhenAlreadyReferred() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let day1 = start.addingTimeInterval(86400)
        XCTAssertFalse(ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: start, now: day1, hasExistingReferral: true))
    }
    func test_entryPolicy_blocksWhenNoFirstLaunch() {
        XCTAssertFalse(ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: nil, now: Date(), hasExistingReferral: false))
    }
}
