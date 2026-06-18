package com.goexercise.app.presentation.friends

import org.junit.Assert.assertEquals
import org.junit.Test

class CheerToastTest {

    @Test
    fun sent_reflectsTypedMessage() {
        assertEquals(
            "📣 はる に「いっしょにがんばろ」を送りました",
            CheerToast.sent("📣", "ファイト", "はる", "いっしょにがんばろ"),
        )
    }

    @Test
    fun sent_fallsBackToKindLabel_whenMessageBlankOrNull() {
        assertEquals("📣 はる に「ファイト」を送りました", CheerToast.sent("📣", "ファイト", "はる", null))
        assertEquals("📣 はる に「ファイト」を送りました", CheerToast.sent("📣", "ファイト", "はる", "   "))
    }

    @Test
    fun received_reflectsTypedMessage() {
        assertEquals(
            "けんた から「プロテインのんだ?」が届きました!",
            CheerToast.received("🥤", "けんた", "プロテイン", "プロテインのんだ?"),
        )
    }

    @Test
    fun received_fallsBackToKindLabel_whenMessageBlankOrNull() {
        assertEquals("けんた から「プロテイン」が届きました!", CheerToast.received("🥤", "けんた", "プロテイン", null))
        assertEquals("けんた から「プロテイン」が届きました!", CheerToast.received("🥤", "けんた", "プロテイン", ""))
    }

    @Test
    fun received_appendsOthersSuffix_whenMultipleUnseen() {
        assertEquals("はる から「ファイト」が届きました!(ほか2件)", CheerToast.received("📣", "はる", "ファイト", null, othersCount = 2))
        // 0件なら suffix 無し。
        assertEquals("はる から「ファイト」が届きました!", CheerToast.received("📣", "はる", "ファイト", null, othersCount = 0))
    }
}
