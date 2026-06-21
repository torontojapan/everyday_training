package com.goexercise.app.ui.theme

import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * AppType の各トークンが **iOS build 12 の値** と厳密一致することを CI で固定する回帰テスト。
 *
 * iOS 側の正本:
 *  - `Typography.swift`(title=.largeTitle bold / screenTitle=.title2 bold / sectionTitle=.title3 bold /
 *    headline=.headline semibold / body=.body / caption=.caption medium)
 *  - iOS Dynamic Type 既定 point size: largeTitle 34 / title 28 / title2 22 / title3 20 / headline 17 /
 *    callout 16 / subheadline 15 / body 17 / footnote 13 / caption 12 / caption2 11(headline 以外は regular)。
 *
 * これが落ちる = 誰かがトークンを iOS と違う値に変えた = パリティ破壊。生 fontSize 禁止
 * (tools/parity/parity_guard.py)と合わせ、「全テキストが iOS サイズに固定される」状態を保証する。
 */
class AppTypeParityTest {

    private data class Spec(val name: String, val size: Int, val weight: FontWeight)

    // iOS build 12 の (size, weight)。ここが唯一の正本。
    private val expected = listOf(
        Spec("title", 34, FontWeight.Bold),          // Typography.title = .largeTitle bold
        Spec("largeTitleXL", 28, FontWeight.Bold),   // .title
        Spec("screenTitle", 22, FontWeight.Bold),    // .title2 bold
        Spec("sectionTitle", 20, FontWeight.Bold),   // .title3 bold
        Spec("headline", 17, FontWeight.SemiBold),   // .headline semibold
        Spec("body", 17, FontWeight.Normal),         // .body
        Spec("callout", 16, FontWeight.Normal),      // .callout
        Spec("subheadline", 15, FontWeight.Normal),  // .subheadline
        Spec("footnote", 13, FontWeight.Normal),     // .footnote
        Spec("caption", 12, FontWeight.Medium),      // Typography.caption medium
        Spec("caption2", 11, FontWeight.Normal),     // .caption2
    )

    private fun actual(name: String) = when (name) {
        "title" -> AppType.title
        "largeTitleXL" -> AppType.largeTitleXL
        "screenTitle" -> AppType.screenTitle
        "sectionTitle" -> AppType.sectionTitle
        "headline" -> AppType.headline
        "body" -> AppType.body
        "callout" -> AppType.callout
        "subheadline" -> AppType.subheadline
        "footnote" -> AppType.footnote
        "caption" -> AppType.caption
        "caption2" -> AppType.caption2
        else -> error("unknown token $name")
    }

    @Test
    fun appTypeTokensMatchIosBuild12() {
        for (s in expected) {
            val t = actual(s.name)
            assertEquals("AppType.${s.name} fontSize は iOS と不一致", s.size.sp, t.fontSize)
            assertEquals("AppType.${s.name} fontWeight は iOS と不一致", s.weight, t.fontWeight)
            assertEquals("AppType.${s.name} は丸ゴ family であるべき", RoundedFontFamily, t.fontFamily)
        }
    }

    @Test
    fun navTitleEqualsHeadline() {
        // 画面タイトルは iOS の inline nav title(17 semibold)= headline に固定。
        assertEquals(AppType.headline, AppType.navTitle)
    }
}
