package com.goexercise.app.domain

/**
 * カテゴリ別のよく使う種目のデフォルト候補(履歴が無い時のサジェスト)。
 * iOS `DefaultExerciseSuggestions.swift` の 1:1 移植(文言・順序を一致)。
 */
object DefaultExerciseSuggestions {
    fun suggestions(category: WorkoutCategory): List<String> = when (category) {
        WorkoutCategory.Strength -> listOf(
            "スクワット", "腕立て伏せ", "プランク", "腹筋", "背筋", "バーピー", "ランジ",
            "ジャンピングジャック", "マウンテンクライマー", "ヒップリフト", "サイドプランク", "デッドバグ",
        )
        WorkoutCategory.Cardio -> listOf(
            "ウォーキング", "ジョギング", "ランニング", "サイクリング", "縄跳び", "階段昇降", "ダンス", "エアロビクス",
        )
        WorkoutCategory.Yoga -> listOf(
            "太陽礼拝", "ダウンドッグ", "コブラのポーズ", "戦士のポーズ", "子供のポーズ", "橋のポーズ", "三日月のポーズ", "猫のポーズ",
        )
        WorkoutCategory.Stretch -> listOf(
            "前屈ストレッチ", "開脚ストレッチ", "肩回し", "首回し", "ふくらはぎ伸ばし", "太もも前ストレッチ", "股関節ストレッチ", "背中ストレッチ",
        )
        WorkoutCategory.FasciaRelease -> listOf(
            "フォームローラー (背中)", "フォームローラー (太もも)", "フォームローラー (ふくらはぎ)",
            "テニスボール (肩甲骨)", "テニスボール (足裏)", "ボール (お尻)", "首・肩ほぐし", "腰回り",
        )
        WorkoutCategory.Other -> emptyList()
    }

    /** 履歴(最終使用順)とデフォルトを重複排除して結合。iOS merged() と同仕様。 */
    fun merged(history: List<String>, category: WorkoutCategory, limit: Int = 12): List<String> {
        val result = mutableListOf<String>()
        val seen = mutableSetOf<String>()
        for (name in history) {
            val t = name.trim()
            if (t.isEmpty() || t in seen) continue
            result += t; seen += t
            if (result.size >= limit) return result
        }
        for (name in suggestions(category)) {
            if (name in seen) continue
            result += name; seen += name
            if (result.size >= limit) return result
        }
        return result
    }
}
