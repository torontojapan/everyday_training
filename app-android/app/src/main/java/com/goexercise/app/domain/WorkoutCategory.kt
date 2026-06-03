package com.goexercise.app.domain

/**
 * 運動カテゴリ。iOS `WorkoutCategory.swift` の 1:1 移植。
 * 並び順 = ピッカー/チップ表示順(筋トレ先頭=記録デフォルト)。`rawValue` は iOS と一致させ
 * 保存データ(Supabase/Room)で相互運用できるようにする(変更しない)。
 */
enum class WorkoutCategory(val rawValue: String, val displayName: String) {
    Strength("strength", "筋トレ"),
    Cardio("cardio", "有酸素"),
    Yoga("yoga", "ヨガ"),
    Stretch("stretch", "ストレッチ"),
    FasciaRelease("fasciaRelease", "筋膜リリース"),
    Other("other", "その他");

    companion object {
        /** 不明な rawValue は other にフォールバック(iOS の `WorkoutCategory(rawValue:) ?? .other`)。 */
        fun fromRaw(raw: String?): WorkoutCategory =
            entries.firstOrNull { it.rawValue == raw } ?: Other
    }
}
