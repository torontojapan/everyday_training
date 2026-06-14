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

    /** 称賛の見出し。具体的な日数には言及しない(実日数は KPI が担う)。
     *  旧「1年達成」(Legend=365+ 全部で固定)は 500 日でも「1年達成」と出て過小だったため廃止。
     *  絵文字 🎉✨ もブランド方針で除去。iOS StreakLevel.headline と一致。 */
    val headline: String
        get() = when (this) {
            Zero -> "今日から始めよう"
            Sprout -> "いい調子！"
            Week -> "1週間つづいた！"
            TwoWeeks -> "2週間つづいた！"
            Month -> "習慣になってきた！"
            Century -> "偉業の領域！"
            Legend -> "継続のレジェンド！"
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

    /** asset 欠損時のフォールバック文字(猫)。炎(🔥)は廃止。iOS と一致。 */
    val fallbackEmoji: String
        get() = "😻"

    val shareMessage: String
        get() = when (this) {
            Zero -> "GO エクササイズで運動を始めました"
            Sprout -> "GO エクササイズで運動継続中"
            Week, TwoWeeks -> "GO エクササイズで運動続けてます"
            Month, Century -> "GO エクササイズで運動の習慣化に成功"
            Legend -> "GO エクササイズで運動を継続中 #LEGEND"
        }

    /** シェアカードに出す猫の状態。炎を背負う StreakExtended は廃止し全レベル Celebrating に統一
     *  (シェアカードのポーズは randomHappyPoseAsset 側でランダム化)。iOS と一致。 */
    val catState: CatState
        get() = CatState.Celebrating

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
