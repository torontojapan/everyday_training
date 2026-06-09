package com.goexercise.app.presentation.friends

import android.graphics.Bitmap
import android.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel

/**
 * 友達招待リンクを QR 画像化する。iOS の `CIFilter.qrCodeGenerator`(FriendsView.qrImage)相当。
 * 相手が標準カメラで読むと `goexercise://friends?code=XXX` で本アプリが開き追加画面がプリフィルされる。
 */
object QrCode {
    fun generate(text: String, size: Int = 480): ImageBitmap? = runCatching {
        val hints = mapOf(
            EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.H,
            EncodeHintType.MARGIN to 1,
        )
        val matrix = QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, size, size, hints)
        val w = matrix.width
        val h = matrix.height
        val pixels = IntArray(w * h)
        for (y in 0 until h) {
            val offset = y * w
            for (x in 0 until w) {
                pixels[offset + x] = if (matrix[x, y]) Color.BLACK else Color.WHITE
            }
        }
        Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            .apply { setPixels(pixels, 0, w, 0, 0, w, h) }
            .asImageBitmap()
    }.getOrNull()
}

/** QR / 共有に使う招待ディープリンク。iOS `friendInviteURL` と同一フォーマット。 */
fun friendInviteUrl(code: String): String = "goexercise://friends?code=$code"

/** コード共有用テキスト。iOS `shareText(for:)` 相当。 */
fun friendShareText(code: String, username: String, streak: Int): String = buildString {
    append("GO エクササイズで一緒に運動しよう！\n友達コード: ")
    append(code)
    if (username.isNotBlank()) append("\n@$username")
    append(" (🔥 ${streak}日連続)")
}
