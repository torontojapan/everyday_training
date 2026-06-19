package com.goexercise.app.domain

/**
 * 共有カードの背景グラデーション 5 種。iOS `ShareCardGradient`(sunset/ocean/twilight/forest/daybreak)パリティ。
 * 色は ARGB Int(左上→右下)。ユーザーがカードごとに選び、選択は永続化する。
 *
 * ★ 色は iOS `ShareCardGradient.swift` の **3 ストップ カスタム RGB を厳密移植**(以前は 2 ストップの
 *   Material 近似色で iOS と別物だった=パリティ計測 2026-06-19 で検出)。各 RGB float×255 を四捨五入して ARGB 化。
 */
enum class ShareCardGradient(val displayName: String, val colors: List<Int>) {
    // iOS sunset: (1.00,0.62,0.42)/(0.90,0.45,0.55)/(0.65,0.42,0.85)
    Sunset("サンセット", listOf(0xFFFF9E6B.toInt(), 0xFFE6738C.toInt(), 0xFFA66BD9.toInt())),
    // iOS ocean: (0.36,0.76,0.82)/(0.32,0.52,0.92)/(0.44,0.36,0.84)
    Ocean("オーシャン", listOf(0xFF5CC2D1.toInt(), 0xFF5285EB.toInt(), 0xFF705CD6.toInt())),
    // iOS twilight: (0.50,0.48,0.92)/(0.62,0.42,0.88)/(0.85,0.48,0.80)
    Twilight("トワイライト", listOf(0xFF807AEB.toInt(), 0xFF9E6BE0.toInt(), 0xFFD97ACC.toInt())),
    // iOS forest: (0.30,0.70,0.46)/(0.22,0.56,0.50)/(0.16,0.42,0.48)
    Forest("フォレスト", listOf(0xFF4DB375.toInt(), 0xFF388F80.toInt(), 0xFF296B7A.toInt())),
    // iOS daybreak: (0.35,0.62,0.95)/(0.42,0.78,0.62)/(0.95,0.75,0.40)
    Daybreak("デイブレイク", listOf(0xFF599EF2.toInt(), 0xFF6BC79E.toInt(), 0xFFF2BF66.toInt()));

    companion object {
        val Default = Sunset
        fun fromName(name: String?): ShareCardGradient =
            entries.firstOrNull { it.name == name } ?: Default
    }
}
