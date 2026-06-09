import XCTest
@testable import GOExercise

final class CatBreedShakerTests: XCTestCase {
    func test_shakerAssetName_convention_allBreeds() {
        for breed in CatBreed.allCases {
            XCTAssertEqual(breed.shakerAssetName, "cat_\(breed.rawValue)_waitingMorning_shaker")
        }
        XCTAssertEqual(CatBreed.orange.shakerAssetName, "cat_orange_waitingMorning_shaker")
        XCTAssertEqual(CatBreed.black.shakerAssetName, "cat_black_waitingMorning_shaker")
    }
    func test_resolvedShaker_usesBreedShaker_whenPresent() {
        XCTAssertEqual(CatBreed.black.resolvedShakerAssetName { _ in true }, "cat_black_waitingMorning_shaker")
    }
    func test_resolvedShaker_fallsBackToBreedWaiting_whenShakerMissing() {
        XCTAssertEqual(CatBreed.black.resolvedShakerAssetName { name in name == "cat_black_waitingMorning" }, "cat_black_waitingMorning")
    }
    func test_resolvedShaker_fallsBackToOrangeShaker_whenAllMissing() {
        XCTAssertEqual(CatBreed.persian.resolvedShakerAssetName { _ in false }, "cat_orange_waitingMorning_shaker")
    }
}
