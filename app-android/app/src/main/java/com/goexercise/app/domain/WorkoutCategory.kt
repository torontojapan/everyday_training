package com.goexercise.app.domain

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 運動カテゴリ。iOS `WorkoutCategory.swift` の 1:1 移植。
 * 並び順 = ピッカー/チップ表示順(筋トレ先頭=記録デフォルト)。`rawValue` は iOS と一致させ
 * 保存データ(Supabase/Room)で相互運用できるようにする(変更しない)。
 * JSON シリアライズも rawValue を使う(@SerialName)ことで iOS と同じ表現にする。
 */
@Serializable
enum class WorkoutCategory(val rawValue: String, val displayName: String) {
    @SerialName("strength") Strength("strength", "筋トレ"),
    @SerialName("cardio") Cardio("cardio", "有酸素"),
    @SerialName("yoga") Yoga("yoga", "ヨガ"),
    @SerialName("stretch") Stretch("stretch", "ストレッチ"),
    @SerialName("fasciaRelease") FasciaRelease("fasciaRelease", "筋膜リリース"),
    @SerialName("other") Other("other", "その他");

    companion object {
        /** 不明な rawValue は other にフォールバック(iOS の `WorkoutCategory(rawValue:) ?? .other`)。 */
        fun fromRaw(raw: String?): WorkoutCategory =
            entries.firstOrNull { it.rawValue == raw } ?: Other
    }
}
