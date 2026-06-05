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
        let cal = Calendar(identifier: .gregorian)
        let now = DateComponents(calendar: cal, year: 2026, month: 6, day: 20).date!
        XCTAssertTrue(ReferralClock.isInMonth("2026-06-01T00:00:00+00:00", of: now, calendar: cal))
        XCTAssertFalse(ReferralClock.isInMonth("2026-05-31T23:00:00+00:00", of: now, calendar: cal))
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
    func test_entryPolicy_blocksWhenAlreadyReferred() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let day1 = start.addingTimeInterval(86400)
        XCTAssertFalse(ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: start, now: day1, hasExistingReferral: true))
    }
    func test_entryPolicy_blocksWhenNoFirstLaunch() {
        XCTAssertFalse(ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: nil, now: Date(), hasExistingReferral: false))
    }
}
