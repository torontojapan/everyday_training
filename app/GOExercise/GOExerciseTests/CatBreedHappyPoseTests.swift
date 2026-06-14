import XCTest
@testable import GOExercise

/// 共有カードのハッピーポーズ ランダム選択 `randomHappyPoseAsset` の挙動を固定する。
final class CatBreedHappyPoseTests: XCTestCase {
    /// 3 ポーズ全て存在するとき、seed を変えると celebrating/happy2/happy3 を巡回する。
    func test_allPosesPresent_cyclesBySeed() {
        let breed = CatBreed.orange
        let names = (0..<3).map { breed.randomHappyPoseAsset(seed: $0, exists: { _ in true }) }
        XCTAssertEqual(Set(names), [
            "cat_orange_celebrating", "cat_orange_happy2", "cat_orange_happy3",
        ], "3ポーズ全在なら seed 0/1/2 で 3 種が出る")
    }

    /// 同じ seed なら毎回同じ(再レンダリングでブレない)。
    func test_sameSeed_isDeterministic() {
        let breed = CatBreed.black
        let a = breed.randomHappyPoseAsset(seed: 42, exists: { _ in true })
        let b = breed.randomHappyPoseAsset(seed: 42, exists: { _ in true })
        XCTAssertEqual(a, b)
    }

    /// happy2/happy3 が欠けていても celebrating は必ず候補に残る。
    func test_onlyCelebratingPresent_alwaysCelebrating() {
        let breed = CatBreed.calico
        for seed in 0..<5 {
            let name = breed.randomHappyPoseAsset(
                seed: seed, exists: { $0 == "cat_calico_celebrating" })
            XCTAssertEqual(name, "cat_calico_celebrating")
        }
    }

    /// 当該猫種の画像が皆無でも orange celebrating にフォールバックして破綻しない。
    func test_nonePresent_fallsBackToOrange() {
        XCTAssertEqual(
            CatBreed.persian.randomHappyPoseAsset(seed: 7, exists: { _ in false }),
            "cat_orange_celebrating")
    }

    /// 候補は CatBreed の rawValue で命名される(全猫種で規約一致)。
    func test_naming_convention_allBreeds() {
        for breed in CatBreed.allCases {
            let name = breed.randomHappyPoseAsset(seed: 1, exists: { _ in true })
            XCTAssertTrue(name.hasPrefix("cat_\(breed.rawValue)_"), "got \(name)")
        }
    }
}
