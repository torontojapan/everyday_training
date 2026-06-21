import XCTest
@testable import GOExercise

/// 犬追加に伴う猫犬統合型 PetBreed の解決ロジックを検証する。
/// asset 名・フォールバック・永続化文字列・ロック判定は描画/選択の正しさを左右する。
final class PetBreedTests: XCTestCase {

    // MARK: - asset 名(prefix が species で切り替わる)

    func test_assetName_cat_and_dog_prefix() {
        XCTAssertEqual(PetBreed.cat(.orange).assetName(for: .celebrating), "cat_orange_celebrating")
        XCTAssertEqual(PetBreed.dog(.shiba).assetName(for: .celebrating), "dog_shiba_celebrating")
        XCTAssertEqual(PetBreed.dog(.golden).avatarAssetName, "dog_golden_waitingMorning")
        XCTAssertEqual(PetBreed.dog(.bulldog).shakerAssetName, "dog_bulldog_waitingMorning_shaker")
    }

    func test_allDogBreeds_assetConvention() {
        for b in DogBreed.allCases {
            XCTAssertEqual(PetBreed.dog(b).assetName(for: .resting), "dog_\(b.rawValue)_resting")
        }
    }

    // MARK: - フォールバック(同種の既定 → 最終 orange 猫 / shiba 犬)

    func test_fallback_staysWithinSpecies() {
        XCTAssertEqual(PetBreed.cat(.persian).fallbackAssetName(for: .worriedNoon), "cat_orange_worriedNoon")
        XCTAssertEqual(PetBreed.dog(.toypoodle).fallbackAssetName(for: .worriedNoon), "dog_shiba_worriedNoon")
    }

    func test_resolvedShaker_dog_fallbackChain() {
        XCTAssertEqual(PetBreed.dog(.golden).resolvedShakerAssetName { _ in true }, "dog_golden_waitingMorning_shaker")
        XCTAssertEqual(PetBreed.dog(.golden).resolvedShakerAssetName { $0 == "dog_golden_waitingMorning" }, "dog_golden_waitingMorning")
        XCTAssertEqual(PetBreed.dog(.golden).resolvedShakerAssetName { _ in false }, "dog_shiba_waitingMorning_shaker")
    }

    func test_randomHappyPose_dog_filtersToExisting_elseShibaCelebrating() {
        // 候補が皆無 → dog_shiba_celebrating
        XCTAssertEqual(PetBreed.dog(.chihuahua).randomHappyPoseAsset(seed: 3) { _ in false }, "dog_shiba_celebrating")
        // happy2 のみ存在 → それを選ぶ(決定的)
        let only = PetBreed.dog(.chihuahua).randomHappyPoseAsset(seed: 0) { $0 == "dog_chihuahua_happy2" }
        XCTAssertEqual(only, "dog_chihuahua_happy2")
    }

    // MARK: - 永続化文字列(round-trip + 旧形式救済)

    func test_storageValue_roundTrip() {
        for pet in CatBreed.allCases.map(PetBreed.cat) + DogBreed.allCases.map(PetBreed.dog) {
            XCTAssertEqual(PetBreed(storageValue: pet.storageValue), pet)
        }
        XCTAssertEqual(PetBreed.dog(.shiba).storageValue, "dog:shiba")
        XCTAssertEqual(PetBreed.cat(.orange).storageValue, "cat:orange")
    }

    func test_storageValue_legacyBareCatRaw_migrates() {
        // prefix 無し旧データ(= 猫 rawValue のみ)を .cat として救済。
        XCTAssertEqual(PetBreed(storageValue: "black"), .cat(.black))
        XCTAssertNil(PetBreed(storageValue: "totally-unknown"))
    }

    // MARK: - species / ロック判定

    func test_species() {
        XCTAssertEqual(PetBreed.cat(.gray).species, .cat)
        XCTAssertEqual(PetBreed.dog(.bulldog).species, .dog)
    }

    func test_access_lockedUnlessPremiumOrReferralOrCurrent() {
        let current = PetBreed.dog(.shiba)
        // 別キャラは無料だとロック
        XCTAssertTrue(PetBreedAccess.isLocked(.cat(.orange), current: current, isPremium: false, referralUnlocked: false))
        // 現在のキャラは常に可
        XCTAssertFalse(PetBreedAccess.isLocked(current, current: current, isPremium: false, referralUnlocked: false))
        // プレミアム / 紹介解放なら別キャラも可
        XCTAssertFalse(PetBreedAccess.isLocked(.cat(.orange), current: current, isPremium: true, referralUnlocked: false))
        XCTAssertFalse(PetBreedAccess.isLocked(.dog(.golden), current: current, isPremium: false, referralUnlocked: true))
    }
}
