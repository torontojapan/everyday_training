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
import com.goexercise.app.domain.CatRank
import com.goexercise.app.domain.MetalKind
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
 * 連続日数 × 猫種から 1080×2340 の PNG を生成し、cache/shared に書き出して FileProvider 共有する。
 */
object StreakShareImageRenderer {

    // スマホ全画面比(9:19.5)。iOS 1.3 と同じ縦長で、保存画像が端末でフルサイズ表示される
    // (上下に黒帯が出ない)。Canvas はグラデを全面に塗るので白余白は元から無い。
    private const val W = 1080
    private const val H = 2340
    /** 画面プレビュー用のコンパクトカード高さ(iOS StreakShareCard 非 fillFrame の縦横比に合わせる)。
     *  CONTENT_HEIGHT(1040)+上下マージンを確保しつつカードが間延びしない高さ。 */
    const val COMPACT_H = 1280
    // 内容ブロックのおおよその高さ(称号→日数→猫→アプリ名)。これを使って縦中央寄せにする
    // (iOS は VStack が縦長フレーム内で中央寄せ。上下対称マージンで構図を合わせる)。
    private const val CONTENT_HEIGHT = 1080f

    /**
     * 連続日数 + 猫種からシェアカードの Bitmap を描く。
     * `poseSeed` で猫のハッピーポーズ(celebrating/happy2/happy3)を決定的に選ぶ
     * (iOS の poseSeed 相当。同 seed なら再描画でブレない)。
     */
    fun render(
        context: Context,
        streak: Int,
        breed: CatBreed,
        poseSeed: Int = (0..9999).random(),
        gradient: com.goexercise.app.domain.ShareCardGradient? = null,
        // 画面プレビュー用のコンパクトカード(iOS StreakShareCard 非 fillFrame ≈ 縦横比 0.84)を描くときは
        // COMPACT_H を渡す。共有/保存(端末全画面比)は既定 H(2340)。
        heightPx: Int = H,
    ): Bitmap {
        val level = StreakLevel.of(streak)
        val h = heightPx
        val bmp = Bitmap.createBitmap(W, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val cx = W / 2f

        // 背景グラデーション(左上→右下)。ユーザー選択があればそれを、無ければ称号レベル既定色を使う。
        val colors = (gradient?.colors ?: level.gradientColors).toIntArray()
        canvas.drawRect(
            0f, 0f, W.toFloat(), h.toFloat(),
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(0f, 0f, W.toFloat(), h.toFloat(), colors, null, Shader.TileMode.CLAMP)
            },
        )

        // 内容を縦中央寄せ(上下対称マージン)。iOS の縦長カードの構図に合わせる。
        var top = ((h - CONTENT_HEIGHT) / 2f).coerceAtLeast(96f)

        // 見出しは「称号バッジ」: 連続日数で決まる CatRank 称号(みならいネコ〜ぬしネコ)を
        // メタル色カプセル+肉球で描く(iOS の RankBadge パリティ)。rank0(7日未満)は称賛文を出す。
        val rank = CatRank.of(streak)
        val rankTitle = rank.title
        if (rankTitle != null && rank.metalKind != null) {
            top = drawRankBadge(canvas, cx, top, rankTitle, rank.metalKind!!)
        } else {
            top = canvas.drawCentered(level.headline, cx, top, textPaint(56f, bold = true), gap = 24f)
        }

        // iOS StreakShareCard の並び順: 称号バッジ → 猫 → 大KPI(N 日連続)→ アプリ名。
        // 猫を数字の「前」に置く(以前は数字→猫で iOS と逆だった)。
        // iOS は猫 200pt(カード幅比 ≈0.55)。Android 1080 幅で同比率になるよう拡大(旧 360=0.33 は小さすぎ)。
        val diameter = 480f
        val centerY = top + diameter / 2
        drawConfetti(canvas, cx, centerY, diameter)
        drawCat(context, canvas, cx, centerY, diameter, breed, level, poseSeed)
        top = centerY + diameter / 2 + 44f

        // 大KPI: 「N」+「日連続」を 1 行(lastTextBaseline 揃え)で中央寄せ(iOS は HStack)。iOS 88pt≈幅0.22 に合わせ拡大。
        val numPaint = textPaint(220f, black = true).apply { setShadowLayer(16f, 0f, 6f, 0x33000000) }
        val sufPaint = textPaint(60f, bold = true)
        val numStr = streak.toString()
        val suffix = " 日連続"
        val numW = numPaint.measureText(numStr)
        val sufW = sufPaint.measureText(suffix)
        val fmNum = numPaint.fontMetrics
        val baseline = top - fmNum.ascent
        numPaint.textAlign = Paint.Align.LEFT
        sufPaint.textAlign = Paint.Align.LEFT
        val startX = cx - (numW + sufW) / 2
        canvas.drawText(numStr, startX, baseline, numPaint)
        canvas.drawText(suffix, startX + numW, baseline, sufPaint)
        top += (fmNum.descent - fmNum.ascent) + 32f

        // アプリ名(iOS StreakShareCard は "GO エクササイズ" の 1 行のみ。英字 "GO Exercise" 副題は iOS に無いため出さない)。
        canvas.drawCentered("GO エクササイズ", cx, top, textPaint(34f, bold = true).apply { alpha = 235 }, gap = 0f)

        return bmp
    }

    /**
     * Bitmap を cache/shared に PNG で書き出し、FileProvider 経由で共有 chooser を開く。
     * 描画(1080×2340)と PNG 圧縮・ファイル I/O は **Default/IO** で行い、startActivity だけ Main へ戻す
     * (重い処理を UI スレッドから外す)。呼び出し側のコルーチン(VM/Compose scope)から呼ぶこと。
     */
    suspend fun share(
        context: Context,
        streak: Int,
        breed: CatBreed,
        poseSeed: Int = (0..9999).random(),
        gradient: com.goexercise.app.domain.ShareCardGradient? = null,
    ) {
        val app = context.applicationContext
        val level = StreakLevel.of(streak)
        val uri = withContext(Dispatchers.IO) {
            val dir = File(app.cacheDir, "shared").apply { mkdirs() }
            // 過去のシェア画像を溜めない(書き出し前に古い分を消す)。
            dir.listFiles { f -> f.name.startsWith("goexercise-streak-") }?.forEach { it.delete() }
            val file = File(dir, "goexercise-streak-${System.currentTimeMillis()}.png")
            file.outputStream().use { render(app, streak, breed, poseSeed, gradient).compress(Bitmap.CompressFormat.PNG, 100, it) }
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

    /**
     * シェアカードを端末のギャラリー(Pictures/GOExercise)に PNG 保存する。iOS の「写真に保存」相当。
     * MediaStore 経由なので Android 10+ では実行時ストレージ権限が不要。成功なら true。
     */
    suspend fun saveToGallery(
        context: Context,
        streak: Int,
        breed: CatBreed,
        poseSeed: Int = (0..9999).random(),
        gradient: com.goexercise.app.domain.ShareCardGradient? = null,
    ): Boolean {
        val app = context.applicationContext
        return withContext(Dispatchers.IO) {
            runCatching {
                val bitmap = render(app, streak, breed, poseSeed, gradient)
                val name = "goexercise-streak-${System.currentTimeMillis()}.png"
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

    /** 猫の周りに紙吹雪(色付き矩形)を散らす。iOS の StaticConfettiView 相当。
     *  決定論的配置(再描画でブレない)。絵文字きらめきの置き換え。 */
    private fun drawConfetti(canvas: Canvas, cx: Float, cy: Float, diameter: Float) {
        val colors = intArrayOf(
            0xFFFFFFFF.toInt(), 0xFFFFD94D.toInt(), 0xFFFC8C73.toInt(),
            0xFF8CCCF2.toInt(), 0xFFB38CF2.toInt(),
        )
        val count = 18
        for (i in 0 until count) {
            val angle = i * 137.5 // 黄金角で偏りなく散らす
            val radius = 200f + (i % 5) * 26f
            val x = cx + (cos(Math.toRadians(angle)) * radius).toFloat()
            val y = cy + (sin(Math.toRadians(angle)) * radius).toFloat() - 30f
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = colors[i % colors.size] }
            canvas.save()
            canvas.rotate((i * 47 % 360).toFloat(), x, y)
            if (i % 4 == 0) {
                canvas.drawCircle(x, y, 9f, paint)
            } else {
                canvas.drawRoundRect(RectF(x - 7f, y - 11f, x + 7f, y + 11f), 3f, 3f, paint)
            }
            canvas.restore()
        }
    }

    /** メタル種別 → 代表色(CatRankChip と同じ RGB 値)。Rainbow はゴールド寄り。 */
    private fun metalColor(kind: MetalKind): Int {
        val (r, g, b, delta) = when (kind) {
            MetalKind.Bronze -> listOf(0.74, 0.45, 0.20, 0.0)
            MetalKind.BronzePlus -> listOf(0.74, 0.45, 0.20, 0.08)
            MetalKind.Silver -> listOf(0.62, 0.66, 0.71, 0.0)
            MetalKind.SilverPlus -> listOf(0.62, 0.66, 0.71, 0.08)
            MetalKind.GoldMinus -> listOf(1.0, 0.76, 0.24, -0.06)
            MetalKind.Gold -> listOf(1.0, 0.76, 0.24, 0.0)
            MetalKind.GoldPlus -> listOf(1.0, 0.76, 0.24, 0.08)
            MetalKind.Platinum -> listOf(0.72, 0.80, 0.94, 0.0)
            MetalKind.Rainbow -> listOf(1.0, 0.76, 0.24, 0.0)
        }
        fun ch(v: Double) = ((v + delta).coerceIn(0.0, 1.0) * 255).toInt()
        return android.graphics.Color.rgb(ch(r), ch(g), ch(b))
    }

    /** 称号バッジ(メタル色カプセル + 🐾 + 称号)を中央に描き、次要素の上端 Y を返す。 */
    private fun drawRankBadge(canvas: Canvas, cx: Float, top: Float, title: String, kind: MetalKind): Float {
        val label = "🐾 $title"
        val tp = textPaint(46f, bold = true).apply { color = 0xFF1A1A1A.toInt() } // メタル地に黒文字(コントラスト)
        val tw = tp.measureText(label)
        val fm = tp.fontMetrics
        val padH = 40f
        val rect = RectF(cx - tw / 2 - padH, top, cx + tw / 2 + padH, top + (fm.descent - fm.ascent) + 22f)
        val rad = rect.height() / 2
        // メタル地: 上→下で明→暗の簡易グラデで金属らしさを出す。
        val base = metalColor(kind)
        val lighter = android.graphics.Color.rgb(
            (android.graphics.Color.red(base) + 40).coerceAtMost(255),
            (android.graphics.Color.green(base) + 40).coerceAtMost(255),
            (android.graphics.Color.blue(base) + 40).coerceAtMost(255),
        )
        canvas.drawRoundRect(rect, rad, rad, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(0f, rect.top, 0f, rect.bottom, lighter, base, Shader.TileMode.CLAMP)
        })
        canvas.drawRoundRect(rect, rad, rad, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = 3f; color = 0x66FFFFFF
        })
        canvas.drawText(label, cx, rect.centerY() - (fm.ascent + fm.descent) / 2, tp)
        return rect.bottom + 28f
    }

    private fun drawCat(context: Context, canvas: Canvas, cx: Float, cy: Float, diameter: Float, breed: CatBreed, level: StreakLevel, poseSeed: Int) {
        val r = diameter / 2
        // ハッピーポーズ3種(celebrating/happy2/happy3)から poseSeed で決定的に選ぶ。
        // 実在チェックは drawable リソース ID の有無で行う(欠損は orange celebrating に縮退)。
        val poseAsset = breed.randomHappyPoseAsset(poseSeed) { name ->
            context.resources.getIdentifier(name, "drawable", context.packageName) != 0
        }
        val resId = context.resources.getIdentifier(poseAsset, "drawable", context.packageName)
        val drawable = if (resId != 0) ContextCompat.getDrawable(context, resId) else null
        if (drawable != null) {
            // 円クリップを廃止し全身ポーズをそのまま描く(happy2/happy3 は全身なので円だと手足が切れる)。
            // 透過 PNG をそのまま中央に配置。背面の紙吹雪が周囲に見える。
            val src = drawable.toBitmap(diameter.toInt(), diameter.toInt())
            canvas.drawBitmap(src, cx - r, cy - r, Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
        } else {
            // アセット欠損時は絵文字。中央寄せのため上下中心に合わせる。
            val p = textPaint(min(diameter, 200f))
            val fm = p.fontMetrics
            canvas.drawText(level.fallbackEmoji, cx, cy - (fm.ascent + fm.descent) / 2, p)
        }
    }
}
