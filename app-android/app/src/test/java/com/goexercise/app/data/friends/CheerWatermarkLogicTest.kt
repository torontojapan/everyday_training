package com.goexercise.app.data.friends

import com.goexercise.app.domain.friends.ReceivedCheer
import org.junit.Assert.assertEquals
import org.junit.Test

class CheerWatermarkLogicTest {

    private fun cheer(id: String, at: Long) =
        ReceivedCheer(id = id, fromDisplayName = "ともだち", kindRaw = "fight", message = null, createdAtEpochMs = at)

    @Test
    fun firstTime_surfacesNothing_andAnchorsToNow() {
        // 初回(watermark 未設定)は過去の蓄積を一切出さず、起点を「今」に置く。
        val out = CheerWatermarkLogic.evaluate(lastSeen = null, now = 1_000L, candidates = emptyList())
        assertEquals(emptyList<ReceivedCheer>(), out.unseen)
        assertEquals(1_000L, out.newWatermark)
    }

    @Test
    fun firstTime_ignoresBacklog() {
        // 初回は既存の受信応援(過去分)があっても surface しない。
        val out = CheerWatermarkLogic.evaluate(
            lastSeen = null,
            now = 1_000L,
            candidates = listOf(cheer("a", 500L), cheer("b", 900L)),
        )
        assertEquals(emptyList<ReceivedCheer>(), out.unseen)
        assertEquals(1_000L, out.newWatermark)
    }

    @Test
    fun surfacesOnlyStrictlyNewer_boundaryExcluded() {
        // watermark と同時刻(==)は既読扱いで除外。より後(>)だけ出す。
        val out = CheerWatermarkLogic.evaluate(
            lastSeen = 100L,
            now = 9_999L,
            candidates = listOf(cheer("eq", 100L), cheer("new", 150L)),
        )
        assertEquals(listOf("new"), out.unseen.map { it.id })
        assertEquals(150L, out.newWatermark)
    }

    @Test
    fun advancesToNewest_andSortsAscending() {
        // 複数新着は昇順で返し、watermark は最新 createdAt まで前進する。
        val out = CheerWatermarkLogic.evaluate(
            lastSeen = 0L,
            now = 9_999L,
            candidates = listOf(cheer("c", 30L), cheer("a", 10L), cheer("b", 20L)),
        )
        assertEquals(listOf("a", "b", "c"), out.unseen.map { it.id })
        assertEquals(30L, out.newWatermark)
    }

    @Test
    fun noNewCheers_keepsWatermark() {
        // 既読より後が無ければ何も出さず watermark を据え置く(前進も後退もしない)。
        val out = CheerWatermarkLogic.evaluate(
            lastSeen = 200L,
            now = 9_999L,
            candidates = listOf(cheer("a", 100L), cheer("b", 200L)),
        )
        assertEquals(emptyList<ReceivedCheer>(), out.unseen)
        assertEquals(200L, out.newWatermark)
    }

    @Test
    fun reEvaluatingWithAdvancedWatermark_surfacesNothing() {
        // 一度 surface した応援は、前進後の watermark で再評価しても二度と出ない。
        val first = CheerWatermarkLogic.evaluate(
            lastSeen = 0L, now = 9_999L,
            candidates = listOf(cheer("a", 10L), cheer("b", 20L)),
        )
        assertEquals(listOf("a", "b"), first.unseen.map { it.id })
        val second = CheerWatermarkLogic.evaluate(
            lastSeen = first.newWatermark, now = 9_999L,
            candidates = listOf(cheer("a", 10L), cheer("b", 20L)),
        )
        assertEquals(emptyList<ReceivedCheer>(), second.unseen)
        assertEquals(20L, second.newWatermark)
    }
}
