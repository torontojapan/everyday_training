package com.goexercise.app.presentation.premium

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PaywallCopyTest {

    @Test
    fun eligible_advertisesFreeTrial() {
        val c = PaywallCopy.strings(trialEligible = true)
        assertTrue(c.subhead.contains("14日間無料"))
        assertEquals("14日間無料で始める", c.cta)
        assertTrue(c.autoRenewDisclosure.contains("14日間の無料体験"))
        assertNotNull(c.freeTrialCancelNote)
    }

    @Test
    fun notEligible_neverMentionsFree() {
        // 適格でない(消化済み)のに「無料」を出すと審査リジェクト/誤認の元。一切出さないことを担保。
        val c = PaywallCopy.strings(trialEligible = false)
        assertEquals("いつでも解約できます。", c.subhead)
        assertEquals("プレミアムを始める", c.cta)
        assertEquals("・選択したプランで自動更新されます", c.autoRenewDisclosure)
        assertNull(c.freeTrialCancelNote)
        // 出し分け対象の全文言に「無料」「14日間」が混入しないこと。
        val all = listOf(c.subhead, c.cta, c.autoRenewDisclosure)
        for (line in all) {
            assertFalse("「$line」に無料表現が混入", line.contains("無料"))
            assertFalse("「$line」に14日間が混入", line.contains("14日間"))
        }
    }
}
