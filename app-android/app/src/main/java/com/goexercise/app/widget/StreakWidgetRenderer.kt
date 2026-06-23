package com.goexercise.app.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.toBitmap
import com.goexercise.app.domain.DailyStatus

/**
 * ホーム画面ウィジェット(systemSmall 相当)を 1 枚の Bitmap に描画する。
 *
 * 2026-06 改修: キャラ表示を廃止し、アプリアイコンと同じ**肉球マーク + 今週の達成度(X/7)+ 月〜日の
 * 達成ストリップ**にした(ユーザー要望)。iOS `WidgetWeekStrip` と同一構図。Glance は任意 Canvas 描画が
 * できないため、Android Canvas で描いた Bitmap を Image として表示する。
 */
object StreakWidgetRenderer {

    data class Data(
        /** 今週(月→日)の7日分の状態。 */
        val weeklyStatuses: List<DailyStatus>,
        val streak: Int,
        val todayAchieved: Boolean,
        val isRestDay: Boolean,
        val weeklyAchieved: Int,
        val weeklyTotal: Int,
        val hoursLeft: Int,
        /** 肉球マーク drawable(ic_stat_paw)。0 なら円で簡易描画。 */
        val pawResId: Int = 0,
    )

    private val dayLabels = listOf("月", "火", "水", "木", "金", "土", "日")
    // アプリアイコン/ライブアクティビティの肉球色 #FF8C4C。
    private fun pawColor() = rgb(1.00, 0.55, 0.30)

    private fun rgb(r: Double, g: Double, b: Double, a: Double = 1.0) =
        android.graphics.Color.argb((a * 255).toInt(), (r * 255).toInt(), (g * 255).toInt(), (b * 255).toInt())

    fun render(context: Context, widthPx: Int, heightPx: Int, data: Data): Bitmap {
        val w = widthPx.toFloat()
        val h = heightPx.toFloat()
        val density = context.resources.displayMetrics.density
        fun dp(v: Float) = v * density
        // iOS WidgetWeekStrip の compact(小)/非compact(中)に相当。幅が広い中ウィジェットでは
        // 曜日・達成ドット・件数を拡大して読みやすくする(iOS build 15 とパリティ)。
        val wide = (w / density) >= 250f

        val bmp = Bitmap.createBitmap(widthPx.coerceAtLeast(1), heightPx.coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val radius = dp(16f)
        val full = RectF(0f, 0f, w, h)

        // 背景: 温かいリニアグラデ + 右上のラジアル光彩(iOS containerBackground と同一)。
        val bg = Paint(Paint.ANTI_ALIAS_FLAG)
        bg.shader = LinearGradient(0f, 0f, w, h, rgb(1.00, 0.95, 0.86), rgb(1.00, 0.89, 0.78), Shader.TileMode.CLAMP)
        c.drawRoundRect(full, radius, radius, bg)
        val halo = Paint(Paint.ANTI_ALIAS_FLAG)
        halo.shader = RadialGradient(w, 0f, dp(120f), rgb(1.00, 0.78, 0.55, 0.55), android.graphics.Color.TRANSPARENT, Shader.TileMode.CLAMP)
        c.drawRoundRect(full, radius, radius, halo)

        val pad = dp(12f)
        val paw = pawColor()

        // --- ヘッダ: 肉球 + 「今週」 + X/7(右) ---
        val pawSize = dp(18f)
        drawPaw(c, context, pad, pad, pawSize, paw, data.pawResId)
        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = rgb(0.40, 0.34, 0.28); textSize = dp(if (wide) 15f else 12f)
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val headerBaseline = pad + pawSize / 2f - (titlePaint.fontMetrics.ascent + titlePaint.fontMetrics.descent) / 2f
        c.drawText("今週", pad + pawSize + dp(5f), headerBaseline, titlePaint)
        val total = data.weeklyTotal.coerceAtLeast(7)
        val countPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = paw; textSize = dp(if (wide) 17f else 14f); textAlign = Paint.Align.RIGHT
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        c.drawText("${data.weeklyAchieved}/$total", w - pad, headerBaseline, countPaint)

        // --- 7日ストリップ(月〜日 + ドット) ---
        val statuses = normalize(data.weeklyStatuses)
        val stripTop = pad + pawSize + dp(8f)
        val dotSize = dp(if (wide) 24f else 16f)
        val colW = (w - pad * 2f) / 7f
        val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = rgb(0.60, 0.54, 0.47); textSize = dp(if (wide) 13f else 9f); textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        for (i in 0 until 7) {
            val cxc = pad + colW * i + colW / 2f
            drawDot(c, cxc, stripTop + dotSize / 2f, dotSize, statuses[i], paw, ::dp)
            val ly = stripTop + dotSize + dp(2f) - labelPaint.fontMetrics.ascent
            c.drawText(dayLabels[i], cxc, ly, labelPaint)
        }

        // --- 見出し(達成済み/回復日/1分だけでも) ---
        var y = stripTop + dotSize + dp(if (wide) 26f else 20f)
        val headline = when {
            data.todayAchieved -> "達成済み！"
            data.isRestDay -> "回復日"
            else -> "1分だけでも"
        }
        val headlineColor = if (data.todayAchieved) rgb(0.20, 0.55, 0.28) else rgb(0.95, 0.42, 0.30)
        val hp = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = headlineColor; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textSize = dp(15f)
        }
        c.drawText(headline, pad, y - hp.fontMetrics.ascent * 0.85f, hp)
        y += dp(20f)

        // --- 未達成 & 非回復日 のみ CTA チップ ---
        if (!data.todayAchieved && !data.isRestDay && y + dp(28f) < h) {
            drawCtaChip(c, pad, y, "運動を記録", ::dp)
        }
        return bmp
    }

    private fun normalize(list: List<DailyStatus>): List<DailyStatus> =
        when {
            list.size == 7 -> list
            list.size > 7 -> list.take(7)
            else -> list + List(7 - list.size) { DailyStatus.TodayPending }
        }

    /** 状態ドット。iOS WidgetWeekStrip.dot と同方針。 */
    private fun drawDot(c: Canvas, cx: Float, cy: Float, size: Float, status: DailyStatus, paw: Int, dp: (Float) -> Float) {
        when (status) {
            DailyStatus.Achieved, DailyStatus.TodayAchieved -> {
                c.drawCircle(cx, cy, size / 2f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = paw })
            }
            DailyStatus.Rescued -> {
                c.drawCircle(cx, cy, size / 2f - dp(1f), Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    style = Paint.Style.STROKE; strokeWidth = dp(2f); color = paw
                })
            }
            DailyStatus.Rest -> {
                val blue = rgb(0.45, 0.62, 0.85)
                c.drawCircle(cx, cy, size / 2f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = rgb(0.45, 0.62, 0.85, 0.16) })
                val tp = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = blue; textSize = size * 0.58f; textAlign = Paint.Align.CENTER
                    typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                }
                c.drawText("休", cx, cy - (tp.fontMetrics.ascent + tp.fontMetrics.descent) / 2f, tp)
            }
            DailyStatus.Missed -> {
                val xp = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = rgb(0.80, 0.45, 0.40); style = Paint.Style.STROKE; strokeWidth = dp(2f); strokeCap = Paint.Cap.ROUND
                }
                val r = size * 0.28f
                c.drawLine(cx - r, cy - r, cx + r, cy + r, xp)
                c.drawLine(cx - r, cy + r, cx + r, cy - r, xp)
            }
            DailyStatus.Future, DailyStatus.TodayPending -> {
                c.drawCircle(cx, cy, size * 0.25f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = rgb(0.88, 0.83, 0.77) })
            }
        }
    }

    /** 肉球マーク。ic_stat_paw drawable を orange で tint(無ければ円で簡易)。 */
    private fun drawPaw(c: Canvas, context: Context, left: Float, top: Float, size: Float, color: Int, pawResId: Int) {
        if (pawResId != 0) {
            runCatching {
                val d = ContextCompat.getDrawable(context, pawResId)
                d?.setTint(color)
                val s = size.toInt().coerceAtLeast(1)
                val pawBmp = d?.toBitmap(s, s)
                if (pawBmp != null) {
                    c.drawBitmap(pawBmp, left, top, Paint(Paint.FILTER_BITMAP_FLAG))
                    return
                }
            }
        }
        // フォールバック: 肉球を円で簡易描画(主肉球 + 3 趾)。
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        val cx = left + size / 2f
        c.drawCircle(cx, top + size * 0.66f, size * 0.30f, p)
        c.drawCircle(cx - size * 0.28f, top + size * 0.30f, size * 0.13f, p)
        c.drawCircle(cx, top + size * 0.20f, size * 0.14f, p)
        c.drawCircle(cx + size * 0.28f, top + size * 0.30f, size * 0.13f, p)
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
        val cyy = rect.centerY()
        val icx = left + padH + iconR
        c.drawCircle(icx, cyy, iconR, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.WHITE })
        val check = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = rgb(0.99, 0.45, 0.42); style = Paint.Style.STROKE; strokeWidth = dp(1.6f); strokeCap = Paint.Cap.ROUND
        }
        val p = Path().apply {
            moveTo(icx - iconR * 0.45f, cyy)
            lineTo(icx - iconR * 0.1f, cyy + iconR * 0.4f)
            lineTo(icx + iconR * 0.5f, cyy - iconR * 0.4f)
        }
        c.drawPath(p, check)
        val ty = cyy - (tp.fontMetrics.ascent + tp.fontMetrics.descent) / 2f
        c.drawText(text, icx + iconR + dp(5f), ty, tp)
    }
}
