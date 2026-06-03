package com.goexercise.app.domain

/**
 * 猫の状態(7 種)。iOS `CatState.swift` の移植。
 * `assetName`(breed × state = 77 画像)はアセット移植時(猫UIフェーズ)に CatBreed と共に追加。
 * rawValue は iOS と一致(将来の永続化/共有のため)。
 */
enum class CatState(val rawValue: String, val emoji: String, val displayName: String) {
    WaitingMorning("waitingMorning", "🐱", "待機中"),
    WorriedNoon("worriedNoon", "😿", "少し心配"),
    BeggingNight("beggingNight", "🙀", "お願い中"),
    Celebrating("celebrating", "😸", "達成"),
    StreakExtended("streakExtended", "😻🔥", "連続更新"),
    Resting("resting", "😽", "回復中"),
    Encouraging("encouraging", "🐱", "復帰応援"),
}
