package com.goexercise.app.ui.components

import androidx.compose.ui.graphics.Color
import com.goexercise.app.domain.MetalKind

/** MetalKind → 単色(リング/アイコン用)。spec RGB 基準。rainbow は暖色ゴールド寄せ。*/
fun metalColor(kind: MetalKind): Color = when (kind) {
    MetalKind.Bronze, MetalKind.BronzePlus -> Color(0.74f, 0.45f, 0.20f)
    MetalKind.Silver, MetalKind.SilverPlus -> Color(0.62f, 0.66f, 0.71f)
    MetalKind.GoldMinus, MetalKind.Gold, MetalKind.GoldPlus -> Color(1.0f, 0.76f, 0.24f)
    MetalKind.Platinum -> Color(0.72f, 0.80f, 0.94f)
    MetalKind.Rainbow -> Color(1.0f, 0.80f, 0.42f)
}
