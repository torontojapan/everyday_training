import XCTest
@testable import GOExercise

final class ReferralRewardsTests: XCTestCase {
    func test_stars_zero_isGhost() {
        XCTAssertEqual(ReferralStarsDisplay.style(count: 0), .ghost)
    }
    func test_stars_oneToNine_isProgressToTen() {
        XCTAssertEqual(ReferralStarsDisplay.style(count: 1), .progress(filled: 1, total: 10))
        XCTAssertEqual(ReferralStarsDisplay.style(count: 9), .progress(filled: 9, total: 10))
    }
    func test_stars_ten_isComplete() {
        XCTAssertEqual(ReferralStarsDisplay.style(count: 10), .complete)
    }
    func test_stars_elevenPlus_isCollapsed() {
        XCTAssertEqual(ReferralStarsDisplay.style(count: 11), .collapsed(11))
        XCTAssertEqual(ReferralStarsDisplay.style(count: 25), .collapsed(25))
    }
    func test_breedUnlock_threshold() {
        XCTAssertEqual(ReferralReward.breedUnlockThreshold, 10)
        XCTAssertFalse(ReferralReward.isBreedUnlocked(starBadges: 9))
        XCTAssertTrue(ReferralReward.isBreedUnlocked(starBadges: 10))
        XCTAssertTrue(ReferralReward.isBreedUnlocked(starBadges: 11))
    }
    func test_catBreed_referralUnlock_unlocksAll() {
        XCTAssertFalse(CatBreedAccess.isLocked(.black, current: .orange, isPremium: false, referralUnlocked: true))
        XCTAssertTrue(CatBreedAccess.isLocked(.black, current: .orange, isPremium: false, referralUnlocked: false))
        XCTAssertFalse(CatBreedAccess.isLocked(.black, current: .orange, isPremium: true, referralUnlocked: false))
        XCTAssertTrue(CatBreedAccess.isLocked(.black, current: .orange, isPremium: false))
    }
}
