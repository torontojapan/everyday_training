package com.goexercise.app.domain

import com.goexercise.app.domain.friends.FriendProfile

/**
 * 称号メタル種別。iOS `MetalKind` の移植。色合い/演出の段階を表す。
 */
enum class MetalKind {
    Bronze,
    BronzePlus,
    Silver,
    SilverPlus,
    GoldMinus,
    Gold,
    GoldPlus,
    Platinum,
    Rainbow,
}

/**
 * 連続記録ベースの 11 段階ランク。iOS `CatRank` の純ロジック移植。
 *
 * rank = 連続日数 `streak` に対し `thresholds` のうち `<= max(0, streak)` を満たす個数(0..11)。
 * 称号/メタルは rank に従って決まり、rank0 は称号なし(null)。
 * iconSymbol(SF Symbol)は iOS 専用のため Android では持たない(Compose アイコンは別途)。
 *
 * 純 Kotlin のみ(Android/Compose import なし)で JVM ユニットテスト可能。
 */
class CatRank private constructor(val rank: Int) {

    /** 0.0..1.0 の充実度(rank/11)。背景進化や演出の強度に使う。 */
    val richness: Double
        get() = rank.toDouble() / 11.0

    /** 称号名。rank0 は null。 */
    val title: String?
        get() = when (rank) {
            1 -> "みならいネコ"
            2 -> "かけだしネコ"
            3 -> "がんばりネコ"
            4 -> "まいにちネコ"
            5 -> "きたえネコ"
            6 -> "つわものネコ"
            7 -> "ベテランネコ"
            8 -> "達人ネコ"
            9 -> "仙人ネコ"
            10 -> "レジェンドネコ"
            11 -> "ぬしネコ"
            else -> null
        }

    /** 称号メタル種別。rank0 は null。 */
    val metalKind: MetalKind?
        get() = when (rank) {
            1 -> MetalKind.Bronze
            2 -> MetalKind.BronzePlus
            3 -> MetalKind.Silver
            4 -> MetalKind.SilverPlus
            5 -> MetalKind.GoldMinus
            6, 7 -> MetalKind.Gold
            8, 9 -> MetalKind.GoldPlus
            10 -> MetalKind.Platinum
            11 -> MetalKind.Rainbow
            else -> null
        }

    override fun equals(other: Any?): Boolean = other is CatRank && other.rank == rank
    override fun hashCode(): Int = rank
    override fun toString(): String = "CatRank(rank=$rank, title=$title)"

    companion object {
        /** 各ランクへ昇格する連続日数の閾値(11 段階)。 */
        val thresholds = listOf(7, 14, 30, 50, 75, 100, 150, 200, 300, 365, 500)

        /** 連続日数からランクを生成。負値は 0 に丸める。 */
        fun of(currentStreak: Int): CatRank {
            val streak = maxOf(0, currentStreak)
            val rank = thresholds.count { it <= streak }
            return CatRank(rank)
        }
    }
}

/** 友達(または自分)の現在連続記録から導かれる称号ランク。 */
val FriendProfile.rank: CatRank
    get() = CatRank.of(currentStreak)
