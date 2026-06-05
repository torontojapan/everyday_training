import XCTest
@testable import GOExercise

final class CatBreedAccessTests: XCTestCase {
    func test_premium_unlocksAll() {
        XCTAssertFalse(CatBreedAccess.isLocked(.black, current: .orange, isPremium: true))
        XCTAssertFalse(CatBreedAccess.isLocked(.orange, current: .orange, isPremium: true))
    }
    func test_nonPremium_lockedExceptCurrent() {
        // 新規(current=orange): orangeのみ解放
        XCTAssertFalse(CatBreedAccess.isLocked(.orange, current: .orange, isPremium: false))
        XCTAssertTrue(CatBreedAccess.isLocked(.black,  current: .orange, isPremium: false))
        // 解約後(current=tabby): 今の猫は維持・他はロック
        XCTAssertFalse(CatBreedAccess.isLocked(.browntabby, current: .browntabby, isPremium: false))
        XCTAssertTrue(CatBreedAccess.isLocked(.orange,      current: .browntabby, isPremium: false))
    }
}
