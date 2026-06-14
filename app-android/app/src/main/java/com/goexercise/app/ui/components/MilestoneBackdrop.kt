package com.goexercise.app.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import com.goexercise.app.domain.CatRank
import com.goexercise.app.domain.MetalKind
import com.goexercise.app.ui.theme.LocalAppPalette
import kotlin.math.abs

/**
 * 連続ランク駆動の進化背景。iOS の MilestoneBackdrop 相当(Spec A)。
 *
 * rank0 は無地(palette.background のみ)。rank>=1 で連続日数に応じて
 * メタル色の縦グラデ帯・上部のソフトな放射グロー・控えめなスパークルが
 * 段階的に濃くなる。あくまで背景なのでタッチは奪わない(Box の最背面に置く前提)。
 *
 * 派手になりすぎないよう不透明度は richness にスケールさせて抑制している
 * (iOS spec が高ランクの「黄色すぎ」を却下したのを踏襲)。
 */
@Composable
fun MilestoneBackdrop(streak: Int, modifier: Modifier = Modifier) {
    val palette = LocalAppPalette.current
    val rank = CatRank.of(streak)

    // rank0: 無地で塗るだけ。
    if (rank.rank == 0 || rank.metalKind == null) {
        Canvas(modifier = modifier.fillMaxSize()) {
            drawRect(color = palette.background)
        }
        return
    }

    val richness = rank.richness.toFloat()
    val band = metalBandColor(rank.metalKind!!)

    // rank>=10 の上質感: 光帯を 26 秒周期で左→右にスイープ(iOS movingBand パリティ)。
    val sweepPhase by rememberInfiniteTransition(label = "backdrop-sweep").animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(26_000, easing = LinearEasing), RepeatMode.Restart),
        label = "sweep",
    )

    Canvas(modifier = modifier.fillMaxSize().background(palette.background)) {
        val w = size.width
        val h = size.height

        // 1) メタル色の縦グラデ帯(背景の上に薄く重ねる)。
        drawRect(
            brush = Brush.verticalGradient(
                colors = listOf(
                    band.copy(alpha = 0.07f * richness),
                    band.copy(alpha = 0.30f * richness),
                ),
            ),
        )

        // 2) 上部中央のソフトな放射グロー(rank>=1)。
        val glowCenter = Offset(w * 0.5f, h * 0.18f)
        val glowRadius = (if (w < h) w else h) * 0.75f
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    band.copy(alpha = richness * 0.42f),
                    Color.Transparent,
                ),
                center = glowCenter,
                radius = glowRadius,
            ),
            radius = glowRadius,
            center = glowCenter,
        )

        // 3) スパークル(決定論的な位置・控えめなアルファ)。
        val n = minOf(4 + rank.rank * 2, 24)
        for (i in 0 until n) {
            val fx = hashUnit(i * 2 + 1)
            val fy = hashUnit(i * 2 + 7)
            val cx = fx * w
            val cy = fy * h
            // サイズも微妙に散らす(1.2..2.8dp 相当を px で簡易計算)。
            val dot = (1.2f + hashUnit(i * 3 + 2) * 1.6f) * density
            drawCircle(
                color = band.copy(alpha = 0.10f + 0.10f * richness),
                radius = dot,
                center = Offset(cx, cy),
            )
        }

        // 4) rank>=10: 薄い白みの定常帯 + 26秒周期で流れる光帯スイープ(iOS movingBand)。
        if (rank.rank >= 10) {
            drawRect(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        Color.White.copy(alpha = 0.08f),
                        Color.Transparent,
                        Color.White.copy(alpha = 0.05f),
                    ),
                ),
            )
            // 横方向に流れるソフトな光帯。画面外→画面外へ抜ける(端で消える)。
            val bandW = w * 0.35f
            val center = -bandW + sweepPhase * (w + bandW * 2f)
            drawRect(
                brush = Brush.horizontalGradient(
                    colors = listOf(Color.Transparent, Color.White.copy(alpha = 0.12f), Color.Transparent),
                    startX = center - bandW / 2f,
                    endX = center + bandW / 2f,
                ),
            )
        }
    }
}

/**
 * MetalKind → 帯のベース色。iOS spec の RGB(0..1)を転記。
 * +/- バリアントは見栄え上ベース色に丸めている(帯はベース色で十分)。
 */
private fun metalBandColor(kind: MetalKind): Color = when (kind) {
    MetalKind.Bronze, MetalKind.BronzePlus -> Color(0.74f, 0.45f, 0.20f)
    MetalKind.Silver, MetalKind.SilverPlus -> Color(0.62f, 0.66f, 0.71f)
    MetalKind.GoldMinus, MetalKind.Gold, MetalKind.GoldPlus -> Color(1.00f, 0.76f, 0.24f)
    MetalKind.Platinum -> Color(0.72f, 0.80f, 0.94f)
    MetalKind.Rainbow -> Color(1.00f, 0.80f, 0.42f) // warm gold(虹は派手すぎないよう暖色ゴールド)
}

/** index から 0f..1f の決定論的擬似乱数(スパークル位置/サイズ用)。 */
private fun hashUnit(seed: Int): Float {
    // 整数ハッシュ(splitmix 風)→ 0..1。
    var x = seed * -0x61c88647 // 黄金比定数
    x = x xor (x ushr 15)
    x *= -0x7ee3623b
    x = x xor (x ushr 13)
    val v = abs(x % 10000)
    return v / 10000f
}
