package com.goexercise.app.domain

/**
 * 累計達成日数で決まる猫の装飾ランク。iOS `CatDecoration.swift` の移植。
 * tier(0..4)は FriendProfile.decorationTier と相互変換。accentColor/SF Symbol は UI 実装時に追加。
 */
enum class CatDecoration(val tier: Int, val displayName: String, val unlockHint: String, val emoji: String) {
    None(0, "なし", "7日達成でバンダナがもらえます", ""),
    Bandana(1, "バンダナ", "30日達成でヘッドバンドにレベルアップ", "🧣"),
    Headband(2, "ヘッドバンド", "100日達成で金色のメダル", "🎀"),
    Medal(3, "メダル", "365日達成で王冠に!!", "🥉"),
    Crown(4, "王冠", "最高ランク達成 ✨", "👑");

    companion object {
        fun of(totalAchievedDays: Int): CatDecoration = when {
            totalAchievedDays < 7 -> None
            totalAchievedDays < 30 -> Bandana
            totalAchievedDays < 100 -> Headband
            totalAchievedDays < 365 -> Medal
            else -> Crown
        }

        fun fromTier(tier: Int): CatDecoration = entries.firstOrNull { it.tier == tier } ?: None
    }
}
