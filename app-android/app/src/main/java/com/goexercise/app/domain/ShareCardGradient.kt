package com.goexercise.app.domain

/**
 * 共有カードの背景グラデーション 5 種。iOS `ShareCardGradient`(sunset/ocean/twilight/forest/daybreak)パリティ。
 * 色は ARGB Int(左上→右下)。ユーザーがカードごとに選び、選択は永続化する。
 */
enum class ShareCardGradient(val displayName: String, val colors: List<Int>) {
    Sunset("サンセット", listOf(0xFFFF8A65.toInt(), 0xFFF06292.toInt())),
    Ocean("オーシャン", listOf(0xFF4FC3F7.toInt(), 0xFF5C6BC0.toInt())),
    Twilight("トワイライト", listOf(0xFF7E57C2.toInt(), 0xFF26326B.toInt())),
    Forest("フォレスト", listOf(0xFF66BB6A.toInt(), 0xFF2E7D5B.toInt())),
    Daybreak("デイブレイク", listOf(0xFFFFD54F.toInt(), 0xFFFF8A65.toInt()));

    companion object {
        val Default = Sunset
        fun fromName(name: String?): ShareCardGradient =
            entries.firstOrNull { it.name == name } ?: Default
    }
}
