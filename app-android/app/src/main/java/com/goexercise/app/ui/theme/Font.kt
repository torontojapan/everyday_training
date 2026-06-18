package com.goexercise.app.ui.theme

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.goexercise.app.R

/**
 * iOS は全画面 `Font.system(design: .rounded)`(SF Rounded)。Android に SF Rounded は無いので
 * 日本語対応の丸ゴ **M PLUS Rounded 1c**(Google Fonts, SIL OFL)を同梱して代替する。
 * res/font に 4 ウェイト(regular/medium/bold/black)を配置済み。
 */
val RoundedFontFamily = FontFamily(
    Font(R.font.mplus_rounded1c_regular, FontWeight.Normal),
    Font(R.font.mplus_rounded1c_medium, FontWeight.Medium),
    Font(R.font.mplus_rounded1c_bold, FontWeight.Bold),
    Font(R.font.mplus_rounded1c_black, FontWeight.Black),
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
