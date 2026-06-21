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
 * iOS `Typography.swift` + iOS Dynamic Type の全スタイルを移植した**唯一の真実**。
 * iOS `Font.system(.STYLE)` の既定 point size に厳密一致させる(下表)。**画面側で生 `fontSize` を
 * 書くことは禁止**(`tools/parity/parity_guard.py` が CI/pre-commit で fail させる)。iOS が要素ごとに
 * `.weight(.heavy)` 等を足すのと同様、ウェイト変種は `AppType.X.copy(fontWeight = …)` で表現する。
 *
 * iOS Dynamic Type 既定サイズ/ウェイト(default content size):
 *   largeTitle 34 / title 28 / title2 22 / title3 20 / headline 17(semibold) / body 17 /
 *   callout 16 / subheadline 15 / footnote 13 / caption 12 / caption2 11 — headline 以外は regular。
 *
 * iOS↔Android のサイズ/ウェイト一致は `AppTypeParityTest`(iOS 値を正本に突合)で CI 保証する。
 */
object AppType {
    // 既存トークン(iOS Typography enum 名を踏襲)
    val title = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Bold, fontSize = 34.sp)       // .largeTitle
    val screenTitle = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Bold, fontSize = 22.sp) // .title2
    val sectionTitle = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Bold, fontSize = 20.sp) // .title3
    val headline = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.SemiBold, fontSize = 17.sp) // .headline(semibold)
    val body = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Normal, fontSize = 17.sp)       // .body
    val caption = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Medium, fontSize = 12.sp)    // Typography.caption(medium)

    // iOS Dynamic Type の残りサイズ(従来 caption/body で近似されズレていた帯を正確に持つ)
    val largeTitleXL = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Bold, fontSize = 28.sp) // .title
    val callout = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Normal, fontSize = 16.sp)    // .callout
    val subheadline = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Normal, fontSize = 15.sp) // .subheadline
    val footnote = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Normal, fontSize = 13.sp)   // .footnote
    val caption2 = TextStyle(fontFamily = RoundedFontFamily, fontWeight = FontWeight.Normal, fontSize = 11.sp)   // .caption2

    /** iOS の `.navigationTitle(...).inline` 相当(17pt semibold)。画面タイトルはこれを使う。 */
    val navTitle = headline
}
