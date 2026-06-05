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
}
