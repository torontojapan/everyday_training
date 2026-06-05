import XCTest
@testable import GOExercise

final class MilestoneStyleTests: XCTestCase {
    func test_item_boundaries() {
        XCTAssertEqual(MilestoneItem(totalAchievedDays: 0), .none)
        XCTAssertEqual(MilestoneItem(totalAchievedDays: 29), .none)
        XCTAssertEqual(MilestoneItem(totalAchievedDays: 30), .shaker)
        XCTAssertEqual(MilestoneItem(totalAchievedDays: 99), .shaker)
        XCTAssertEqual(MilestoneItem(totalAchievedDays: 100), .shakerCrown)
        XCTAssertEqual(MilestoneItem(totalAchievedDays: 9999), .shakerCrown)
    }

    func test_item_assetSuffix() {
        XCTAssertEqual(MilestoneItem.none.assetSuffix, "")
        XCTAssertEqual(MilestoneItem.shaker.assetSuffix, "_shaker")
        XCTAssertEqual(MilestoneItem.shakerCrown.assetSuffix, "_crown")
    }

    func test_backgroundTier_boundaries() {
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 6).tier, 0)
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 7).tier, 1)
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 29).tier, 2)
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 30).tier, 3)
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 100).tier, 6)
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 500).tier, 11)
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 99999).tier, 11)
    }

    func test_backgroundAssetName() {
        XCTAssertNil(MilestoneBackground(totalAchievedDays: 0).assetName)
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 7).assetName, "bg_milestone_01")
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 500).assetName, "bg_milestone_11")
    }
}

extension MilestoneStyleTests {
    func test_avatarAssetName_withItems() {
        XCTAssertEqual(CatBreed.orange.avatarAssetName(totalAchievedDays: 0), "cat_orange_waitingMorning")
        XCTAssertEqual(CatBreed.orange.avatarAssetName(totalAchievedDays: 30), "cat_orange_waitingMorning_shaker")
        XCTAssertEqual(CatBreed.black.avatarAssetName(totalAchievedDays: 120), "cat_black_waitingMorning_crown")
    }
}
