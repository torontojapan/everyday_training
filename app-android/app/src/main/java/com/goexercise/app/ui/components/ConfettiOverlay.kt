package com.goexercise.app.ui.components

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import kotlin.math.PI
import kotlin.math.sin
import kotlin.random.Random

private val confettiColors = listOf(
    Color(0xFFF5A623), Color(0xFFF8E71C), Color(0xFF4A90E2), Color(0xFFB06AB3), Color(0xFF7ED321),
)

private data class ConfettiParticle(
    val xFrac: Float,
    val color: Color,
    val rotations: Float,
    val swayFrac: Float,
    val delay: Float,
    val sizePx: Float,
)

/**
 * 達成時の全画面紙吹雪(iOS AmbientParticlesView の drawConfetti パリティ)。
 * [play] が true になった瞬間に約2.4秒間、矩形を回転・横揺れさせながら落下させ、終了で [onFinished]。
 * 記録完了→ホーム復帰の達成トランジションで 1 回だけ再生する(呼び出し側がゲート)。
 */
@Composable
fun ConfettiOverlay(play: Boolean, onFinished: () -> Unit) {
    if (!play) return
    val progress = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        progress.snapTo(0f)
        progress.animateTo(1f, tween(durationMillis = 2400, easing = LinearEasing))
        onFinished()
    }
    val particles = remember {
        List(28) {
            ConfettiParticle(
                xFrac = Random.nextFloat(),
                color = confettiColors[it % confettiColors.size],
                rotations = 2f + Random.nextFloat() * 3f,
                swayFrac = (Random.nextFloat() - 0.5f) * 0.15f,
                delay = Random.nextFloat() * 0.25f,
                sizePx = 18f + Random.nextFloat() * 16f,
            )
        }
    }
    Canvas(Modifier.fillMaxSize()) {
        particles.forEach { p ->
            val local = ((progress.value - p.delay) / (1f - p.delay)).coerceIn(0f, 1f)
            if (local <= 0f) return@forEach
            val x = (p.xFrac + p.swayFrac * sin(local * PI.toFloat() * 2f)) * size.width
            val y = local * (size.height + 80f) - 40f
            rotate(degrees = local * 360f * p.rotations, pivot = Offset(x, y)) {
                drawRect(
                    color = p.color,
                    topLeft = Offset(x - p.sizePx / 2f, y - p.sizePx / 2f),
                    size = Size(p.sizePx, p.sizePx * 0.6f),
                    alpha = (1f - local).coerceIn(0.25f, 1f),
                )
            }
        }
    }
}
