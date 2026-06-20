package com.goexercise.app.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import androidx.core.graphics.drawable.toBitmap
import com.goexercise.app.domain.CatState

/**
 * ホーム画面ウィジェット(systemSmall 相当)を 1 枚の Bitmap に描画する。
 *
 * Glance は任意 Canvas 描画ができず、iOS `SmallWidgetView`(猫 halo + 週達成リング + 見出し/サブ +
 * 未達成 CTA・左寄せ)を忠実に再現できない。そこで Android Canvas で iOS と同じ構図を描き、Glance では
 * その Bitmap を Image として表示する。同じ関数を instrumented test で render → PNG 化し iOS golden と照合する。
 *
 * 配色・寸法は iOS の各 View(SmallWidgetView / WidgetCatView / RecordPromptChipView /
 * GOExerciseWidget.containerBackground)に一致させている。
 */
object StreakWidgetRenderer {

    data class Data(
        val catResId: Int,
        val catState: CatState,
        val streak: Int,
        val todayAchieved: Boolean,
        val isRestDay: Boolean,
        val weeklyAchieved: Int,
        val weeklyTotal: Int,
        val hoursLeft: Int,
    )

    private fun rgb(r: Double, g: Double, b: Double, a: Double = 1.0) =
        android.graphics.Color.argb((a * 255).toInt(), (r * 255).toInt(), (g * 255).toInt(), (b * 255).toInt())

    fun render(context: Context, widthPx: Int, heightPx: Int, data: Data): Bitmap {
        val w = widthPx.toFloat()
        val h = heightPx.toFloat()
        val density = context.resources.displayMetrics.density
        fun dp(v: Float) = v * density

        val bmp = Bitmap.createBitmap(widthPx.coerceAtLeast(1), heightPx.coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val radius = dp(16f)
        val full = RectF(0f, 0f, w, h)

        // 背景: 温かいリニアグラデ + 右上のラジアル光彩(iOS containerBackground)。
        val bg = Paint(Paint.ANTI_ALIAS_FLAG)
        bg.shader = LinearGradient(0f, 0f, w, h, rgb(1.00, 0.95, 0.86), rgb(1.00, 0.89, 0.78), Shader.TileMode.CLAMP)
        c.drawRoundRect(full, radius, radius, bg)
        val halo = Paint(Paint.ANTI_ALIAS_FLAG)
        halo.shader = RadialGradient(w, 0f, dp(120f), rgb(1.00, 0.78, 0.55, 0.55), android.graphics.Color.TRANSPARENT, Shader.TileMode.CLAMP)
        c.drawRoundRect(full, radius, radius, halo)

        val pad = dp(10f)
        val catSize = dp(58f)
        // 猫(halo 円 + 白枠 + キャラ画像)。iOS WidgetCatView。
        drawHaloCat(c, context, pad, pad, catSize, data, ::dp)
        // 週達成リング(右上)。iOS progressRing。
        val ringSize = dp(44f)
        drawRing(c, w - pad - ringSize, pad + dp(7f), ringSize, data, ::dp)

        // 見出し + サブ(左寄せ)。
        var y = pad + catSize + dp(10f)
        val headline = when {
            data.todayAchieved -> "達成済み！"
            data.isRestDay -> "回復日"
            else -> "1分だけでも"
        }
        val headlineColor = if (data.todayAchieved) rgb(0.20, 0.55, 0.28) else rgb(0.95, 0.42, 0.30)
        val hp = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = headlineColor; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textSize = dp(16f)
        }
        c.drawText(headline, pad, y - hp.fontMetrics.ascent * 0.85f, hp)
        y += dp(20f)
        val sub = when {
            data.todayAchieved -> "また明日も続けよう"
            data.isRestDay -> "むりせず整えよう"
            else -> "23:59まであと${data.hoursLeft}時間"
        }
        val sp = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = rgb(0.54, 0.47, 0.39); textSize = dp(11f)
        }
        c.drawText(sub, pad, y - sp.fontMetrics.ascent * 0.85f, sp)
        y += dp(16f)

        // 未達成 & 非回復日 のみ CTA チップ(iOS RecordPromptChipView)。
        if (!data.todayAchieved && !data.isRestDay) {
            drawCtaChip(c, pad, y, "運動を記録", ::dp)
        }
        return bmp
    }

    private fun haloColor(state: CatState): Int = when (state) {
        CatState.Celebrating, CatState.StreakExtended -> rgb(0.58, 0.85, 0.55)
        CatState.Resting -> rgb(0.72, 0.83, 0.98)
        CatState.BeggingNight -> rgb(0.70, 0.80, 0.95)
        CatState.WorriedNoon -> rgb(1.00, 0.80, 0.62)
        else -> rgb(1.00, 0.86, 0.66)
    }

    private fun drawHaloCat(c: Canvas, context: Context, left: Float, top: Float, size: Float, data: Data, dp: (Float) -> Float) {
        val cx = left + size / 2f
        val cy = top + size / 2f
        val base = haloColor(data.catState)
        // halo: 中心濃→外薄のラジアル。
        val haloPaint = Paint(Paint.ANTI_ALIAS_FLAG)
        val withA = { col: Int, a: Double -> android.graphics.Color.argb((a * 255).toInt(), android.graphics.Color.red(col), android.graphics.Color.green(col), android.graphics.Color.blue(col)) }
        haloPaint.shader = RadialGradient(cx, cy, size * 0.6f, withA(base, 0.9), withA(base, 0.35), Shader.TileMode.CLAMP)
        c.drawCircle(cx, cy, size / 2f, haloPaint)
        // 白枠。
        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = dp(1.5f); color = withA(android.graphics.Color.WHITE, 0.7)
        }
        c.drawCircle(cx, cy, size / 2f - dp(0.75f), border)
        // キャラ画像(0.78 倍・中央)。
        if (data.catResId != 0) {
            runCatching {
                val drawable = androidx.core.content.ContextCompat.getDrawable(context, data.catResId)
                val target = (size * 0.78f).toInt().coerceAtLeast(1)
                val catBmp = drawable?.toBitmap(target, target)
                if (catBmp != null) {
                    c.drawBitmap(catBmp, cx - target / 2f, cy - target / 2f, Paint(Paint.FILTER_BITMAP_FLAG))
                }
            }
        }
    }

    private fun drawRing(c: Canvas, left: Float, top: Float, size: Float, data: Data, dp: (Float) -> Float) {
        val stroke = dp(5f)
        val rect = RectF(left + stroke / 2f, top + stroke / 2f, left + size - stroke / 2f, top + size - stroke / 2f)
        val bgRing = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = stroke; color = rgb(0.96, 0.85, 0.74)
        }
        c.drawArc(rect, 0f, 360f, false, bgRing)
        val total = data.weeklyTotal.coerceAtLeast(1)
        val progress = (data.weeklyAchieved.toFloat() / total).coerceIn(0f, 1f)
        val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = stroke; strokeCap = Paint.Cap.ROUND; color = rgb(1.00, 0.62, 0.55)
        }
        c.drawArc(rect, -90f, 360f * progress, false, arc)
        val label = "${data.weeklyAchieved}/$total"
        val lp = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = rgb(0.30, 0.25, 0.20); textSize = dp(11f); textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val midY = top + size / 2f - (lp.fontMetrics.ascent + lp.fontMetrics.descent) / 2f
        c.drawText(label, left + size / 2f, midY, lp)
    }

    private fun drawCtaChip(c: Canvas, left: Float, top: Float, text: String, dp: (Float) -> Float) {
        val tp = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.WHITE; textSize = dp(13f); typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val iconR = dp(6f)
        val tw = tp.measureText(text)
        val ph = dp(8f)
        val padH = dp(14f)
        val chipH = dp(13f) + ph * 2
        val chipW = padH * 2 + iconR * 2 + dp(5f) + tw
        val rect = RectF(left, top, left + chipW, top + chipH)
        val grad = Paint(Paint.ANTI_ALIAS_FLAG)
        grad.shader = LinearGradient(rect.left, rect.top, rect.right, rect.bottom, rgb(1.00, 0.58, 0.38), rgb(0.99, 0.45, 0.42), Shader.TileMode.CLAMP)
        c.drawRoundRect(rect, chipH / 2f, chipH / 2f, grad)
        // チェック丸アイコン。
        val cyy = rect.centerY()
        val icx = left + padH + iconR
        c.drawCircle(icx, cyy, iconR, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.WHITE })
        val check = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = rgb(0.99, 0.45, 0.42); style = Paint.Style.STROKE; strokeWidth = dp(1.6f); strokeCap = Paint.Cap.ROUND
        }
        val p = android.graphics.Path().apply {
            moveTo(icx - iconR * 0.45f, cyy)
            lineTo(icx - iconR * 0.1f, cyy + iconR * 0.4f)
            lineTo(icx + iconR * 0.5f, cyy - iconR * 0.4f)
        }
        c.drawPath(p, check)
        // テキスト。
        val ty = cyy - (tp.fontMetrics.ascent + tp.fontMetrics.descent) / 2f
        c.drawText(text, icx + iconR + dp(5f), ty, tp)
    }
}
