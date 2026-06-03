package com.goexercise.app.domain

/**
 * 猫の種類。iOS `CatBreed` の移植(11 種 = orange + 10)。自分用(設定)と将来の友達表示で使う。
 * tint は domain を Compose 非依存に保つため **ARGB Long** で持ち、UI 側で `Color(tintArgb)` に包む。
 * drawable リソース名は全 lowercase(`cat_<breed>_<state>`。例: cat_orange_waitingmorning)。
 */
enum class CatBreed(val rawValue: String, val displayName: String, val tintArgb: Long) {
    Orange("orange", "オレンジトラ", 0xFFFFA659),
    Black("black", "黒猫", 0xFF4D4D52),
    White("white", "白猫", 0xFFF2F2F7),
    Gray("gray", "グレー猫", 0xFFA6B3BF),
    Calico("calico", "三毛猫", 0xFFFFCC8C),
    SilverTabby("silvertabby", "サバトラ", 0xFFBFC7D1),
    BrownTabby("browntabby", "茶トラ", 0xFFBF8C61),
    Siamese("siamese", "シャム", 0xFFEBDBBF),
    Tuxedo("tuxedo", "ハチワレ", 0xFF595961),
    Persian("persian", "ペルシャ", 0xFFEDE0C7),
    Scottish("scottish", "スコティッシュ", 0xFFB3BFCC);

    /** breed × state の drawable 名。例: cat_orange_celebrating。iOS assetName(for:) 相当。 */
    fun assetName(state: CatState): String = "cat_${rawValue}_${state.rawValue.lowercase()}"

    /** 一覧/プロフィール用の単一アバター(waitingMorning を中性ポーズとして使う)。 */
    val avatarAssetName: String get() = "cat_${rawValue}_waitingmorning"

    companion object {
        val Default = Orange

        fun fromRaw(raw: String?): CatBreed = entries.firstOrNull { it.rawValue == raw } ?: Default

        /** 生成漏れ時のフォールバック(orange の同 state)。iOS fallbackAssetName 相当。 */
        fun fallbackAssetName(state: CatState): String = "cat_orange_${state.rawValue.lowercase()}"
        const val FALLBACK_AVATAR: String = "cat_orange_waitingmorning"
    }
}
