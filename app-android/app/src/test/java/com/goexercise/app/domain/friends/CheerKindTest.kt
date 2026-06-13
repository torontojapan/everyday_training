package com.goexercise.app.domain.friends

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * CheerKind の rawValue は **クロスOS契約**(iOS と一致): fight/wontlose/protein/catpunch。
 * 受信フォールバック(旧 kind great/clap/fire)も検証する。
 */
class CheerKindTest {

    @Test
    fun rawValues_matchCrossOsContract() {
        assertEquals("fight", CheerKind.Fight.rawValue)
        assertEquals("wontlose", CheerKind.WontLose.rawValue)
        assertEquals("protein", CheerKind.Protein.rawValue)
        assertEquals("catpunch", CheerKind.CatPunch.rawValue)
        assertEquals(4, CheerKind.entries.size)
    }

    @Test
    fun receivedFromRaw_resolvesCurrentKinds() {
        assertEquals("負けないぞ", CheerKind.receivedFromRaw("wontlose").second)
        assertEquals("ねこぱんち", CheerKind.receivedFromRaw("catpunch").second)
    }

    @Test
    fun receivedFromRaw_resolvesLegacyKinds() {
        // 旧クライアントが送った kind も落とさずラベル化する。
        assertEquals("すごい", CheerKind.receivedFromRaw("great").second)
        assertEquals("拍手", CheerKind.receivedFromRaw("clap").second)
        assertEquals("応援", CheerKind.receivedFromRaw("fire").second)
    }

    @Test
    fun receivedFromRaw_unknownKind_fallsBack() {
        assertEquals("応援", CheerKind.receivedFromRaw("totally-unknown").second)
    }
}
