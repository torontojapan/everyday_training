package com.goexercise.app.ui.theme

import androidx.compose.ui.graphics.Color
import com.goexercise.app.domain.WorkoutCategory

/**
 * アプリのカラーテーマ。iOS `AppTheme.swift` の 1:1 移植(5テーマ × 全カラートークン)。
 * 色値は iOS の `Color(red:green:blue:)`(0..1)をそのまま Float で転記している。
 * 仕様一致が要件なので**値は iOS を正本**とし、勝手に変えない。
 */
enum class AppTheme(val displayName: String, val hint: String) {
    Peach("ピーチ", "やわらかピーチ&コーラル"),         // デフォルト (女性向け)
    Sky("スカイ", "クールなブルー系"),                  // 男性向け
    Midnight("ミッドナイト", "目に優しい暗め配色"),       // ダーク
    Sunshine("サンシャイン", "明るく元気な黄色系"),       // 黄色系
    Forest("フォレスト", "落ち着きのある自然系");         // 自然系

    val background: Color
        get() = when (this) {
            Peach -> Color(1.00f, 0.97f, 0.93f)
            Sky -> Color(0.94f, 0.97f, 1.00f)
            Midnight -> Color(0.10f, 0.11f, 0.14f)
            Sunshine -> Color(1.00f, 0.98f, 0.90f)
            Forest -> Color(0.95f, 0.97f, 0.93f)
        }

    val surface: Color
        get() = when (this) {
            Peach -> Color(1.00f, 0.99f, 0.96f)
            Sky -> Color(1.00f, 1.00f, 1.00f)
            Midnight -> Color(0.17f, 0.18f, 0.22f)
            Sunshine -> Color(1.00f, 1.00f, 0.96f)
            Forest -> Color(1.00f, 1.00f, 0.98f)
        }

    val primary: Color
        get() = when (this) {
            Peach -> Color(1.00f, 0.62f, 0.55f)
            Sky -> Color(0.36f, 0.62f, 0.92f)
            Midnight -> Color(0.65f, 0.78f, 1.00f)
            Sunshine -> Color(1.00f, 0.78f, 0.30f)
            Forest -> Color(0.42f, 0.66f, 0.52f)
        }

    val primaryDeep: Color
        get() = when (this) {
            Peach -> Color(0.84f, 0.33f, 0.30f)
            Sky -> Color(0.18f, 0.40f, 0.78f)
            Midnight -> Color(0.45f, 0.62f, 0.95f)
            Sunshine -> Color(0.85f, 0.58f, 0.12f)
            Forest -> Color(0.22f, 0.50f, 0.32f)
        }

    val secondary: Color
        get() = when (this) {
            Peach -> Color(0.96f, 0.85f, 0.74f)
            Sky -> Color(0.78f, 0.88f, 0.98f)
            Midnight -> Color(0.30f, 0.34f, 0.42f)
            Sunshine -> Color(0.98f, 0.90f, 0.70f)
            Forest -> Color(0.82f, 0.92f, 0.84f)
        }

    val textPrimary: Color
        get() = when (this) {
            Peach -> Color(0.30f, 0.25f, 0.20f)
            Sky -> Color(0.16f, 0.20f, 0.30f)
            Midnight -> Color(0.95f, 0.95f, 0.97f)
            Sunshine -> Color(0.35f, 0.28f, 0.12f)
            Forest -> Color(0.18f, 0.26f, 0.20f)
        }

    val textSecondary: Color
        get() = when (this) {
            Peach -> Color(0.54f, 0.47f, 0.39f)
            Sky -> Color(0.40f, 0.46f, 0.55f)
            Midnight -> Color(0.70f, 0.72f, 0.78f)
            Sunshine -> Color(0.55f, 0.48f, 0.32f)
            Forest -> Color(0.42f, 0.50f, 0.42f)
        }

    val success: Color
        get() = when (this) {
            Peach -> Color(0.55f, 0.78f, 0.55f)
            Sky -> Color(0.36f, 0.78f, 0.66f)
            Midnight -> Color(0.40f, 0.85f, 0.65f)
            Sunshine -> Color(0.60f, 0.80f, 0.40f)
            Forest -> Color(0.45f, 0.74f, 0.48f)
        }

    val restDay: Color
        get() = when (this) {
            Peach -> Color(0.70f, 0.80f, 0.95f)
            Sky -> Color(0.60f, 0.78f, 0.95f)
            Midnight -> Color(0.45f, 0.55f, 0.78f)
            Sunshine -> Color(0.78f, 0.84f, 0.95f)
            Forest -> Color(0.70f, 0.85f, 0.90f)
        }

    val missed: Color
        get() = when (this) {
            Peach -> Color(0.86f, 0.47f, 0.45f)
            Sky -> Color(0.85f, 0.55f, 0.55f)
            Midnight -> Color(0.95f, 0.45f, 0.55f)
            Sunshine -> Color(0.88f, 0.50f, 0.30f)
            Forest -> Color(0.78f, 0.50f, 0.45f)
        }

    val historyAccent: Color
        get() = when (this) {
            Peach -> Color(0.62f, 0.49f, 0.86f)
            Sky -> Color(0.45f, 0.58f, 0.85f)
            Midnight -> Color(0.75f, 0.60f, 0.92f)
            Sunshine -> Color(0.85f, 0.55f, 0.45f)
            Forest -> Color(0.55f, 0.65f, 0.45f)
        }

    val settingsAccent: Color
        get() = when (this) {
            Peach -> Color(0.36f, 0.62f, 0.72f)
            Sky -> Color(0.30f, 0.55f, 0.78f)
            Midnight -> Color(0.55f, 0.70f, 0.85f)
            Sunshine -> Color(0.65f, 0.55f, 0.40f)
            Forest -> Color(0.45f, 0.62f, 0.55f)
        }

    val chipBackground: Color
        get() = when (this) {
            Peach -> Color(1.00f, 0.91f, 0.86f)
            Sky -> Color(0.88f, 0.94f, 1.00f)
            Midnight -> Color(0.22f, 0.25f, 0.32f)
            Sunshine -> Color(1.00f, 0.94f, 0.78f)
            Forest -> Color(0.92f, 0.96f, 0.88f)
        }

    fun categoryColor(category: WorkoutCategory): Color = when (category) {
        WorkoutCategory.Cardio -> Color(0.36f, 0.62f, 0.72f)
        WorkoutCategory.Strength -> primaryDeep
        WorkoutCategory.Yoga -> Color(0.58f, 0.55f, 0.82f)
        WorkoutCategory.Stretch -> Color(0.42f, 0.66f, 0.52f)
        WorkoutCategory.FasciaRelease -> Color(0.85f, 0.55f, 0.40f)
        WorkoutCategory.Other -> historyAccent
    }

    /** midnight のみダーク扱い(iOS preferredColorScheme と一致)。 */
    val isDark: Boolean get() = this == Midnight
}
