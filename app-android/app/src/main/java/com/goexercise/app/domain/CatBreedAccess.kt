package com.goexercise.app.domain

/**
 * 猫種選択のロック判定(課金解放)。iOS `CatBreedAccess` の移植。
 * 無料(非プレミアム)は「今の猫」以外ロック=新規はオレンジ限定、解約後は今の猫維持・変更不可。
 * ただし紹介⭐10個達成(referralUnlocked)なら無料でも全種解放。
 * オンボーディングはこの判定を無視して全種選択可(確定後=設定でのみロック)。
 */
object CatBreedAccess {
    /** 紹介⭐がこの数に達すると無料でも全猫種解放(iOS `ReferralReward.breedUnlockThreshold` と一致)。 */
    const val BREED_UNLOCK_STARS = 10

    fun isLocked(
        breed: CatBreed,
        current: CatBreed,
        isPremium: Boolean,
        referralUnlocked: Boolean,
    ): Boolean = !isPremium && !referralUnlocked && breed != current

    fun referralUnlocked(starBadges: Int): Boolean = starBadges >= BREED_UNLOCK_STARS
}
