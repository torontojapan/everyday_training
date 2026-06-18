package com.goexercise.app.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.font.FontFamily

/**
 * Material3 の全テキストスタイルに丸ゴ([RoundedFontFamily])を適用する。
 * iOS が全画面 SF Rounded なのに合わせ、Android も既定フォントを丸ゴに統一する。
 * サイズ/ウェイトは Material 既定を踏襲し、family だけ差し替える(コンポーネント標準の
 * 行間・字間を壊さないため)。個別の見出し等は [AppType] トークンを参照する。
 */
private fun Typography.withRoundedFamily(family: FontFamily) = Typography(
    displayLarge = displayLarge.copy(fontFamily = family),
    displayMedium = displayMedium.copy(fontFamily = family),
    displaySmall = displaySmall.copy(fontFamily = family),
    headlineLarge = headlineLarge.copy(fontFamily = family),
    headlineMedium = headlineMedium.copy(fontFamily = family),
    headlineSmall = headlineSmall.copy(fontFamily = family),
    titleLarge = titleLarge.copy(fontFamily = family),
    titleMedium = titleMedium.copy(fontFamily = family),
    titleSmall = titleSmall.copy(fontFamily = family),
    bodyLarge = bodyLarge.copy(fontFamily = family),
    bodyMedium = bodyMedium.copy(fontFamily = family),
    bodySmall = bodySmall.copy(fontFamily = family),
    labelLarge = labelLarge.copy(fontFamily = family),
    labelMedium = labelMedium.copy(fontFamily = family),
    labelSmall = labelSmall.copy(fontFamily = family),
)

val AppTypography = Typography().withRoundedFamily(RoundedFontFamily)
