package com.goexercise.app.domain

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 累計達成日数で決まる猫の装飾ランク。iOS `CatDecoration`(String, Codable)の移植。
 * tier(0..4)は FriendProfile.decorationTier と相互変換。rawValue/@SerialName で iOS と JSON 一致。
 * accentColor/SF Symbol は UI 実装時に追加。
 */
@Serializable
enum class CatDecoration(val rawValue: String, val tier: Int, val displayName: String, val unlockHint: String, val emoji: String) {
    @SerialName("none") None("none", 0, "なし", "7日達成でバンダナがもらえます", ""),
    @SerialName("bandana") Bandana("bandana", 1, "バンダナ", "30日達成でヘッドバンドにレベルアップ", "🧣"),
    @SerialName("headband") Headband("headband", 2, "ヘッドバンド", "100日達成で金色のメダル", "🎀"),
    @SerialName("medal") Medal("medal", 3, "メダル", "365日達成で王冠に!!", "🥉"),
    @SerialName("crown") Crown("crown", 4, "王冠", "最高ランク達成 ✨", "👑");

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
