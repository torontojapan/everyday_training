package com.goexercise.app.ui.theme

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.goexercise.app.R

/**
 * iOS build 12 パリティ: iOS は `Font.system(design: .rounded)` だが **SF Rounded は欧文/数字のみ**で、
 * **日本語はシステムのゴシック(Hiragino)**で描画される(丸ゴにならない)。
 * これに合わせ Android も「欧文/数字=丸ゴ・和文=ゴシック」のハイブリッドにする:
 *  - 欧文/数字: M PLUS Rounded 1c を **Latin サブセット**(ASCII+Latin-1)にして同梱(丸ゴ)。
 *  - 和文(かな/漢字/和文約物): このフォントに字形が無いため **端末標準の和文ゴシック**
 *    (Noto Sans CJK JP 等)へ自動フォールバック=iOS が Hiragino を使うのと同じ発想。
 * これにより、以前「和文まで丸ゴ」で iOS と字形が違っていた問題を解消する(ユーザー指摘 2026-06-19)。
 */
val RoundedFontFamily = FontFamily(
    Font(R.font.mplus_latin_regular, FontWeight.Normal),
    Font(R.font.mplus_latin_medium, FontWeight.Medium),
    Font(R.font.mplus_latin_bold, FontWeight.Bold),
    Font(R.font.mplus_latin_black, FontWeight.Black),
)

/**
 * iOS `Typography.swift` のセマンティックトークンの移植。Dynamic Type の既定サイズに合わせる
 * (largeTitle≈34 / title2≈22 / title3≈20 / headline≈17 semibold / body≈17 / caption≈12)。
 * 画面側は inline の sp 指定でなく、できるだけこのトークンを参照して iOS と粒度を揃える。
 */
object AppType {
    val title = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Bold, fontSize = 34.sp)
    val screenTitle = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Bold, fontSize = 22.sp)
    val sectionTitle = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Bold, fontSize = 20.sp)
    val headline = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
    val body = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Normal, fontSize = 17.sp)
    val caption = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Medium, fontSize = 12.sp)
}
