package com.goexercise.app.domain

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 猫の状態(7 種)。iOS `CatState`(String, Codable)の移植。
 * `assetName`(breed × state = 77 画像)はアセット移植時(猫UIフェーズ)に CatBreed と共に追加。
 * @SerialName で iOS rawValue と JSON 表現を一致させる(将来の永続化/共有のため)。
 */
@Serializable
enum class CatState(val rawValue: String, val emoji: String, val displayName: String) {
    @SerialName("waitingMorning") WaitingMorning("waitingMorning", "🐱", "待機中"),
    @SerialName("worriedNoon") WorriedNoon("worriedNoon", "😿", "少し心配"),
    @SerialName("beggingNight") BeggingNight("beggingNight", "🙀", "お願い中"),
    @SerialName("celebrating") Celebrating("celebrating", "😸", "達成"),
    @SerialName("streakExtended") StreakExtended("streakExtended", "😻🔥", "連続更新"),
    @SerialName("resting") Resting("resting", "😽", "回復中"),
    @SerialName("encouraging") Encouraging("encouraging", "🐱", "復帰応援"),
}
