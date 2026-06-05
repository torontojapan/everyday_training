// CatBreedAccess.swift
import Foundation

/// 猫種選択のロック判定(課金解放)。
/// 無料(非プレミアム)は「今の猫」以外ロック=新規はオレンジ限定、解約後は今の猫維持・変更不可。
enum CatBreedAccess {
    static func isLocked(_ breed: CatBreed, current: CatBreed, isPremium: Bool) -> Bool {
        !isPremium && breed != current
    }
}
