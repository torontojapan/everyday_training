package com.goexercise.app.domain

/**
 * 連続記録のレベル(シェアカードの演出量・バッジ・文言)。iOS `StreakLevel.swift` の移植。
 * UI 依存(gradientColors / catStateAssetName)は除き、純粋な閾値・カウント・文言のみ移植する
 * (グラデーション/猫アセットはシェア UI 実装時に Compose で追加)。
 */
enum class StreakLevel {
    Zero,       // 0 days — シェア不可
    Sprout,     // 1-6
    Week,       // 7-13
    TwoWeeks,   // 14-29
    Month,      // 30-99
    Century,    // 100-364
    Legend;     // 365+

    val fireCount: Int
        get() = when (this) {
            Zero -> 0; Sprout -> 1; Week -> 2; TwoWeeks -> 3; Month -> 4; Century -> 5; Legend -> 6
        }

    val sparkleCount: Int
        get() = when (this) {
            Zero -> 0; Sprout -> 3; Week -> 6; TwoWeeks -> 10; Month -> 14; Century -> 20; Legend -> 28
        }

    val headline: String
        get() = when (this) {
            Zero -> "今日から始めよう"
            Sprout -> "いい調子！"
            Week -> "1週間達成 🎉"
            TwoWeeks -> "2週間達成、すごい！"
            Month -> "1ヶ月達成、本物！"
            Century -> "100日達成!! 偉業!"
            Legend -> "1年達成 ✨ LEGEND ✨"
        }

    val badgeText: String?
        get() = when (this) {
            Legend -> "LEGEND"
            Century -> "CENTURY"
            Month -> "MONTH"
            TwoWeeks -> "2 WEEKS"
            Week -> "1 WEEK"
            Sprout, Zero -> null
        }

    val fallbackEmoji: String
        get() = when (this) {
            Zero, Sprout, Week, TwoWeeks -> "😻"
            Month, Century, Legend -> "🐱🔥"
        }

    val shareMessage: String
        get() = when (this) {
            Zero -> "GO エクササイズで運動を始めました🐱"
            Sprout -> "GO エクササイズで運動継続中🐱"
            Week, TwoWeeks -> "GO エクササイズで運動続けてます🔥"
            Month, Century -> "GO エクササイズで運動の習慣化に成功🔥🔥"
            Legend -> "GO エクササイズで1年連続達成しました✨ #LEGEND"
        }

    /** シェアカードに出す猫の状態(低レベル=達成 / 高レベル=連続更新)。breed と組み合わせ画像解決。 */
    val catState: CatState
        get() = when (this) {
            Zero, Sprout, Week, TwoWeeks -> CatState.Celebrating
            Month, Century, Legend -> CatState.StreakExtended
        }

    /** 背景グラデーション色(ARGB Int, 左上→右下)。iOS `gradientColors` の RGB と一致させる。 */
    val gradientColors: List<Int>
        get() = when (this) {
            Zero, Sprout -> listOf(0xFFFFC9A8.toInt(), 0xFFE8895C.toInt())
            Week -> listOf(0xFFFF8A5C.toInt(), 0xFF8FD9A8.toInt())
            TwoWeeks -> listOf(0xFFFF8C80.toInt(), 0xFFF2C74D.toInt())
            Month -> listOf(0xFFFF6E4F.toInt(), 0xFFF59E33.toInt())
            Century -> listOf(0xFF8C4DF2.toInt(), 0xFFFF8C80.toInt(), 0xFFFFD94D.toInt())
            Legend -> listOf(0xFFFFD94D.toInt(), 0xFFF273BF.toInt(), 0xFF8C4DF2.toInt(), 0xFF4DBFF2.toInt())
        }

    companion object {
        fun of(streak: Int): StreakLevel = when {
            streak < 1 -> Zero
            streak <= 6 -> Sprout
            streak <= 13 -> Week
            streak <= 29 -> TwoWeeks
            streak <= 99 -> Month
            streak <= 364 -> Century
            else -> Legend
        }
    }
}
