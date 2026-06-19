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
import com.goexercise.app.domain.MonthlyReviewBuilder
import com.goexercise.app.domain.WorkoutCategory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.math.min

/**
 * ハイライト共有カード(Weekly / Monthly / All-time)を Canvas で描く。
 * iOS `MonthlyReviewCard`(MonthlyReviewSheet.swift)+ ImageRenderer の移植。
 * 構成: アイコン付き日本語バッジ → 期間ラベル → 猫 → 大 KPI「N / M 日達成」→ stat 行 → アプリ名。
 * 1080×2340(スマホ全画面比)・グラデ全面塗り(白余白なし)・内容は縦中央寄せ(iOS 1.3 パリティ)。
 */
object HighlightShareImageRenderer {

    private const val W = 1080
    private const val H = 2340
    /** 画面プレビュー用のコンパクトカード高さ(iOS MonthlyReviewCard 非 fillFrame の縦横比)。 */
    const val COMPACT_H = 1480

    /** ハイライト種別。バッジ絵文字・タイトル・グラデ色を持つ(iOS の icon/title/gradient 対応)。 */
    enum class Kind(val badgeEmoji: String, val title: String, val gradient: List<Int>) {
        // iOS weeklyGradient(青緑)/ monthlyGradient(紫)/ lifetimeGradient(金)を ARGB 化。
        Weekly("✨", "Weeklyハイライト", listOf(0xFF29A0BD.toInt(), 0xFF38B3A8.toInt(), 0xFF6BCC99.toInt())),
        Monthly("📄", "Monthlyハイライト", listOf(0xFF807AEB.toInt(), 0xFF9E6BE0.toInt(), 0xFFD97ACC.toInt())),
        AllTime("🏆", "All-timeハイライト", listOf(0xFFF5A338.toInt(), 0xFFF08547.toInt(), 0xFFE6666B.toInt())),
    }

    fun render(
        context: Context,
        review: MonthlyReviewBuilder.Review,
        kind: Kind,
        breed: CatBreed,
        streakLabel: String,
        poseSeed: Int = (0..9999).random(),
        gradient: com.goexercise.app.domain.ShareCardGradient? = null,
        // プレビュー用コンパクトカードは COMPACT_H を渡す。共有/保存は既定 H(全画面比)。
        heightPx: Int = H,
    ): Bitmap {
        val h = heightPx
        val bmp = Bitmap.createBitmap(W, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val cx = W / 2f

        // 背景グラデーション(左上→右下)を全面に(白余白なし)。ユーザー選択があればそれを、無ければ種別既定色。
        val colors = (gradient?.colors ?: kind.gradient).toIntArray()
        canvas.drawRect(
            0f, 0f, W.toFloat(), h.toFloat(),
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(0f, 0f, W.toFloat(), h.toFloat(), colors, null, Shader.TileMode.CLAMP)
            },
        )

        // 内容を縦中央寄せ(stat 行数で高さが変わるので概算で上端を決める)。
        val statRows = buildStatRows(review, streakLabel)
        val contentHeight = 1180f + statRows.size * 64f
        var top = ((h - contentHeight) / 2f).coerceAtLeast(120f)

        // アイコン付き日本語バッジ(英字バッジ + 和タイトルの重複を解消、iOS 1.3)。
        top = drawBadgePill(canvas, cx, top, "${kind.badgeEmoji} ${kind.title}")

        // 期間ラベル(2026年6月 / 5/26 - 6/1 / 通算 365日)。
        top = canvas.drawCentered(review.periodLabel, cx, top, textPaint(40f, bold = true).apply { alpha = 220 }, gap = 36f)

        // 猫。iOS MonthlyReviewCard は猫(影付き)のみで**プログラム紙吹雪を持たない**(粒は猫スプライトに焼込み)。
        // よって連続カードと違いハイライトでは drawConfetti を呼ばない(iOS パリティ・2LLM監査)。
        val diameter = 340f
        val centerY = top + diameter / 2
        drawCat(context, canvas, cx, centerY, diameter, breed, poseSeed)
        top = centerY + diameter / 2 + 48f

        // 大 KPI: 達成日数 / 総日数。
        val numPaint = textPaint(170f, black = true).apply { setShadowLayer(14f, 0f, 5f, 0x33000000) }
        val numStr = review.achievedDays.toString()
        val suffix = " / ${review.totalDays} 日達成"
        val suffixPaint = textPaint(40f, bold = true).apply { alpha = 235 }
        // 数字 + 接尾を 1 行に中央寄せで並べる。
        val numW = numPaint.measureText(numStr)
        val sufW = suffixPaint.measureText(suffix)
        val totalW = numW + sufW
        val fmNum = numPaint.fontMetrics
        val baseline = top - fmNum.ascent
        numPaint.textAlign = Paint.Align.LEFT
        suffixPaint.textAlign = Paint.Align.LEFT
        val startX = cx - totalW / 2
        canvas.drawText(numStr, startX, baseline, numPaint)
        canvas.drawText(suffix, startX + numW, baseline, suffixPaint)
        top += (fmNum.descent - fmNum.ascent) + 36f

        // stat 行(半透明角丸ボックス)。
        top = drawStatBox(canvas, cx, top, statRows)
        top += 32f

        // アプリ名(iOS MonthlyReviewCard は "GO エクササイズ" 1 行のみ。英字 "GO Exercise" 副題は iOS に無い)。
        canvas.drawCentered("GO エクササイズ", cx, top, textPaint(34f, bold = true).apply { alpha = 235 }, gap = 0f)

        return bmp
    }

    /** 端末ギャラリー(Pictures/GOExercise)に PNG 保存。iOS「写真に保存」相当。成功なら true。 */
    suspend fun saveToGallery(
        context: Context,
        review: MonthlyReviewBuilder.Review,
        kind: Kind,
        breed: CatBreed,
        streakLabel: String,
        poseSeed: Int = (0..9999).random(),
        gradient: com.goexercise.app.domain.ShareCardGradient? = null,
    ): Boolean {
        val app = context.applicationContext
        return withContext(Dispatchers.IO) {
            runCatching {
                val bitmap = render(app, review, kind, breed, streakLabel, poseSeed, gradient)
                val name = "goexercise-highlight-${System.currentTimeMillis()}.png"
                val values = android.content.ContentValues().apply {
                    put(android.provider.MediaStore.Images.Media.DISPLAY_NAME, name)
                    put(android.provider.MediaStore.Images.Media.MIME_TYPE, "image/png")
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                        put(android.provider.MediaStore.Images.Media.RELATIVE_PATH, "Pictures/GOExercise")
                    }
                }
                val resolver = app.contentResolver
                val uri = resolver.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                    ?: return@runCatching false
                resolver.openOutputStream(uri)?.use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                    ?: return@runCatching false
                true
            }.getOrDefault(false)
        }
    }

    /** 共有 chooser を開く(PNG を cache に書き出して FileProvider 共有)。iOS「SNSで共有」相当。 */
    suspend fun share(
        context: Context,
        review: MonthlyReviewBuilder.Review,
        kind: Kind,
        breed: CatBreed,
        streakLabel: String,
        poseSeed: Int = (0..9999).random(),
        gradient: com.goexercise.app.domain.ShareCardGradient? = null,
    ) {
        val app = context.applicationContext
        val uri = withContext(Dispatchers.IO) {
            val dir = File(app.cacheDir, "shared").apply { mkdirs() }
            dir.listFiles { f -> f.name.startsWith("goexercise-highlight-") }?.forEach { it.delete() }
            val file = File(dir, "goexercise-highlight-${System.currentTimeMillis()}.png")
            file.outputStream().use { render(app, review, kind, breed, streakLabel, poseSeed, gradient).compress(Bitmap.CompressFormat.PNG, 100, it) }
            FileProvider.getUriForFile(app, "${app.packageName}.fileprovider", file)
        }
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, "${kind.title} · GO エクササイズ\nhttps://goexercise.app")
            clipData = android.content.ClipData.newRawUri("highlight", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        withContext(Dispatchers.Main) {
            context.startActivity(Intent.createChooser(intent, "ハイライトをシェア"))
        }
    }

    // ---- stat 行の組み立て ----

    private data class StatRow(val icon: String, val label: String, val value: String)

    // iOS MonthlyReviewCard.statRow の SF Symbol を共有画像用の emoji に対応付け
    // (pawprint.fill/clock.fill/list.bullet.rectangle/star.fill/heart.fill)。バッジと同じ emoji 方式。
    private fun buildStatRows(review: MonthlyReviewBuilder.Review, streakLabel: String): List<StatRow> = buildList {
        add(StatRow("🐾", streakLabel, "${review.longestStreak} 日"))
        add(StatRow("🕐", "合計時間", "${review.totalDurationMinutes} 分"))
        add(StatRow("📋", "種目数", "${review.totalExerciseCount} 件"))
        review.topCategory?.let { add(StatRow("⭐", "イチオシのカテゴリ", it.displayName)) }
        review.topExerciseName?.let { add(StatRow("❤️", "推し種目", it)) }
    }

    // ---- 描画ヘルパ(自己完結。StreakShareImageRenderer を壊さないため独立)----

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

    /** text が maxWidth に収まらなければ末尾を「…」で省略する(共有カードのレイアウト崩れ防止)。 */
    private fun ellipsize(text: String, paint: Paint, maxWidth: Float): String {
        if (paint.measureText(text) <= maxWidth) return text
        val ell = "…"
        var end = text.length
        while (end > 0 && paint.measureText(text.substring(0, end) + ell) > maxWidth) end--
        return if (end <= 0) ell else text.substring(0, end) + ell
    }

    private fun Canvas.drawCentered(text: String, cx: Float, top: Float, paint: Paint, gap: Float): Float {
        val fm = paint.fontMetrics
        drawText(text, cx, top - fm.ascent, paint)
        return top + (fm.descent - fm.ascent) + gap
    }

    /** アイコン付き日本語バッジ(黒半透明カプセル)。次要素の上端 Y を返す。 */
    private fun drawBadgePill(canvas: Canvas, cx: Float, top: Float, text: String): Float {
        val tp = textPaint(40f, bold = true)
        val tw = tp.measureText(text)
        val fm = tp.fontMetrics
        val padH = 36f
        val rect = RectF(cx - tw / 2 - padH, top, cx + tw / 2 + padH, top + (fm.descent - fm.ascent) + 24f)
        val rad = rect.height() / 2
        canvas.drawRoundRect(rect, rad, rad, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x73000000 })
        canvas.drawText(text, cx, rect.centerY() - (fm.ascent + fm.descent) / 2, tp)
        return rect.bottom + 28f
    }

    /** stat 行を半透明角丸ボックスにまとめて描く。次要素の上端 Y を返す。 */
    private fun drawStatBox(canvas: Canvas, cx: Float, top: Float, rows: List<StatRow>): Float {
        if (rows.isEmpty()) return top
        val boxW = 760f
        val rowH = 64f
        val padV = 28f
        val left = cx - boxW / 2
        val right = cx + boxW / 2
        val boxH = padV * 2 + rows.size * rowH
        val rect = RectF(left, top, right, top + boxH)
        canvas.drawRoundRect(rect, 28f, 28f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x2EFFFFFF })

        val iconPaint = textPaint(30f).apply { textAlign = Paint.Align.LEFT }
        val labelPaint = textPaint(32f).apply { textAlign = Paint.Align.LEFT; alpha = 220 }
        val valuePaint = textPaint(32f, bold = true).apply { textAlign = Paint.Align.RIGHT }
        val padH = 36f
        val iconW = 48f // 先頭アイコン + 余白の幅(iOS Label のアイコン列に相当)。
        // ラベルと値が重ならないよう、値が使える最大幅(右カラム)。
        // 推し種目名はユーザー入力で長くなり得るので、はみ出す前に「…」で省略する。
        val valueMaxW = boxW - padH * 2 - iconW - 260f // ラベル側に最低 260px 確保
        rows.forEachIndexed { i, row ->
            val rowTop = top + padV + i * rowH
            val fm = labelPaint.fontMetrics
            val baseline = rowTop + rowH / 2 - (fm.ascent + fm.descent) / 2
            canvas.drawText(row.icon, left + padH, baseline, iconPaint)
            canvas.drawText(row.label, left + padH + iconW, baseline, labelPaint)
            canvas.drawText(ellipsize(row.value, valuePaint, valueMaxW), right - padH, baseline, valuePaint)
        }
        return rect.bottom + 28f
    }

    private fun drawCat(context: Context, canvas: Canvas, cx: Float, cy: Float, diameter: Float, breed: CatBreed, poseSeed: Int) {
        val r = diameter / 2
        val poseAsset = breed.randomHappyPoseAsset(poseSeed) { name ->
            context.resources.getIdentifier(name, "drawable", context.packageName) != 0
        }
        val resId = context.resources.getIdentifier(poseAsset, "drawable", context.packageName)
        val drawable = if (resId != 0) ContextCompat.getDrawable(context, resId) else null
        if (drawable != null) {
            val src = drawable.toBitmap(diameter.toInt(), diameter.toInt())
            canvas.drawBitmap(src, cx - r, cy - r, Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
        } else {
            val p = textPaint(min(diameter, 200f))
            val fm = p.fontMetrics
            canvas.drawText("😺", cx, cy - (fm.ascent + fm.descent) / 2, p)
        }
    }
}
