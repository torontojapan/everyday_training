package com.goexercise.app.share

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.graphics.drawable.toBitmap
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.StreakLevel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * マイルストーン(連続日数)のシェア画像を Canvas で描く。iOS `StreakShareCard` + `ImageRenderer`
 * (StreakShareSheet.swift)の移植。SwiftUI の ImageRenderer 相当を Android Canvas で再現する。
 *
 * 連続日数 × 猫種から 1080×1440 の PNG を生成し、cache/shared に書き出して FileProvider 共有する。
 */
object StreakShareImageRenderer {

    private const val W = 1080
    private const val H = 1440

    /** 連続日数 + 猫種からシェアカードの Bitmap を描く。 */
    fun render(context: Context, streak: Int, breed: CatBreed): Bitmap {
        val level = StreakLevel.of(streak)
        val bmp = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val cx = W / 2f

        // 背景グラデーション(左上→右下)。
        val colors = level.gradientColors.toIntArray()
        canvas.drawRect(
            0f, 0f, W.toFloat(), H.toFloat(),
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(0f, 0f, W.toFloat(), H.toFloat(), colors, null, Shader.TileMode.CLAMP)
            },
        )

        var top = 96f

        // バッジ(任意)。
        level.badgeText?.let { badge ->
            val tp = textPaint(40f, bold = true)
            val tw = tp.measureText(badge)
            val fm = tp.fontMetrics
            val padH = 34f
            val rect = RectF(cx - tw / 2 - padH, top, cx + tw / 2 + padH, top + (fm.descent - fm.ascent) + 16f)
            canvas.drawRoundRect(rect, rect.height() / 2, rect.height() / 2, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x73000000 })
            canvas.drawText(badge, cx, rect.centerY() - (fm.ascent + fm.descent) / 2, tp)
            top = rect.bottom + 28f
        }

        // 見出し。
        top = canvas.drawCentered(level.headline, cx, top, textPaint(60f, bold = true), gap = 24f)

        // 🔥 行。
        if (level.fireCount > 0) {
            top = canvas.drawCentered("🔥".repeat(level.fireCount), cx, top, textPaint(64f), gap = 24f)
        }

        // 大きな連続日数 + 「日連続」。
        top = canvas.drawCentered(
            streak.toString(), cx, top,
            textPaint(220f, black = true).apply { setShadowLayer(16f, 0f, 6f, 0x33000000) },
            gap = 4f,
        )
        top = canvas.drawCentered("日連続", cx, top, textPaint(52f, bold = true), gap = 32f)

        // 猫(円形クリップ + 白枠)+ きらめき。欠損時は絵文字フォールバック。
        val diameter = 360f
        val centerY = top + diameter / 2
        drawSparkles(canvas, cx, centerY, level.sparkleCount)
        drawCat(context, canvas, cx, centerY, diameter, breed, level)
        top = centerY + diameter / 2 + 40f

        // アプリ名。
        top = canvas.drawCentered("GO エクササイズ", cx, top, textPaint(34f, bold = true).apply { alpha = 235 }, gap = 8f)
        canvas.drawCentered("GO Exercise", cx, top, textPaint(22f, mono = true).apply { alpha = 180; letterSpacing = 0.15f }, gap = 0f)

        return bmp
    }

    /**
     * Bitmap を cache/shared に PNG で書き出し、FileProvider 経由で共有 chooser を開く。
     * 描画(1080×1440)と PNG 圧縮・ファイル I/O は **Default/IO** で行い、startActivity だけ Main へ戻す
     * (重い処理を UI スレッドから外す)。呼び出し側のコルーチン(VM/Compose scope)から呼ぶこと。
     */
    suspend fun share(context: Context, streak: Int, breed: CatBreed) {
        val app = context.applicationContext
        val level = StreakLevel.of(streak)
        val uri = withContext(Dispatchers.IO) {
            val dir = File(app.cacheDir, "shared").apply { mkdirs() }
            // 過去のシェア画像を溜めない(書き出し前に古い分を消す)。
            dir.listFiles { f -> f.name.startsWith("goexercise-streak-") }?.forEach { it.delete() }
            val file = File(dir, "goexercise-streak-${System.currentTimeMillis()}.png")
            file.outputStream().use { render(app, streak, breed).compress(Bitmap.CompressFormat.PNG, 100, it) }
            FileProvider.getUriForFile(app, "${app.packageName}.fileprovider", file)
        }
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, "${level.shareMessage}\nhttps://goexercise.app")
            // ClipData が無いと chooser のプレビューが URI を読めず Permission Denial になる。
            clipData = android.content.ClipData.newRawUri("streak", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        withContext(Dispatchers.Main) {
            // chooser は元の Activity context から開く(applicationContext だと NEW_TASK が要る)。
            context.startActivity(Intent.createChooser(intent, "連続記録をシェア"))
        }
    }

    // ---- 描画ヘルパ ----

    private fun textPaint(size: Float, bold: Boolean = false, black: Boolean = false, mono: Boolean = false): Paint =
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            textSize = size
            textAlign = Paint.Align.CENTER
            typeface = when {
                mono -> Typeface.MONOSPACE
                black || bold -> Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                else -> Typeface.DEFAULT
            }
        }

    /** text を cx 中央・top を上端として 1 行描き、次要素の上端 Y を返す。 */
    private fun Canvas.drawCentered(text: String, cx: Float, top: Float, paint: Paint, gap: Float): Float {
        val fm = paint.fontMetrics
        drawText(text, cx, top - fm.ascent, paint)
        return top + (fm.descent - fm.ascent) + gap
    }

    private fun drawSparkles(canvas: Canvas, cx: Float, cy: Float, count: Int) {
        for (i in 0 until count) {
            val angle = i.toDouble() / maxOf(1, count) * 360.0
            val radius = 230f + (i % 3) * 24f
            val size = 24f + (i % 4) * 8f
            val x = cx + (cos(Math.toRadians(angle)) * radius).toFloat()
            val y = cy + (sin(Math.toRadians(angle)) * radius).toFloat()
            canvas.drawText("✨", x, y, textPaint(size).apply { textAlign = Paint.Align.CENTER })
        }
    }

    private fun drawCat(context: Context, canvas: Canvas, cx: Float, cy: Float, diameter: Float, breed: CatBreed, level: StreakLevel) {
        val r = diameter / 2
        val resId = context.resources.getIdentifier(breed.assetName(level.catState), "drawable", context.packageName)
        val drawable = if (resId != 0) ContextCompat.getDrawable(context, resId) else null
        if (drawable != null) {
            val src = drawable.toBitmap(diameter.toInt(), diameter.toInt())
            val shader = android.graphics.BitmapShader(src, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply {
                setLocalMatrix(android.graphics.Matrix().apply { postTranslate(cx - r, cy - r) })
            }
            canvas.drawCircle(cx, cy, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.shader = shader })
            canvas.drawCircle(cx, cy, r, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE; strokeWidth = 6f; color = 0x73FFFFFF
            })
        } else {
            // アセット欠損時は絵文字。中央寄せのため上下中心に合わせる。
            val p = textPaint(min(diameter, 200f))
            val fm = p.fontMetrics
            canvas.drawText(level.fallbackEmoji, cx, cy - (fm.ascent + fm.descent) / 2, p)
        }
    }
}
