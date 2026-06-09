package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class RescueTicketLogicTest {

    @Test
    fun allowanceByPremium() {
        assertEquals(1, RescueTicketAllowance.current(isPremium = false))
        assertEquals(4, RescueTicketAllowance.current(isPremium = true))
    }

    @Test
    fun usedCountIsPerMonth() {
        val used = setOf(LocalDate.of(2026, 5, 3), LocalDate.of(2026, 5, 20), LocalDate.of(2026, 6, 1))
        assertEquals(2, RescueTicketLogic.usedCountInMonth(used, LocalDate.of(2026, 5, 15)))
        assertEquals(1, RescueTicketLogic.usedCountInMonth(used, LocalDate.of(2026, 6, 30)))
    }

    @Test
    fun availabilityAndRemainingRespectAllowance() {
        val used = setOf(LocalDate.of(2026, 5, 3)) // 5月に1枚使用
        // 無料(月1)なら 5月はもう枠なし。
        assertFalse(RescueTicketLogic.hasAvailable(used, LocalDate.of(2026, 5, 10), allowance = 1))
        assertEquals(0, RescueTicketLogic.remaining(used, LocalDate.of(2026, 5, 10), allowance = 1))
        // プレミアム(月4)なら残3。
        assertTrue(RescueTicketLogic.hasAvailable(used, LocalDate.of(2026, 5, 10), allowance = 4))
        assertEquals(3, RescueTicketLogic.remaining(used, LocalDate.of(2026, 5, 10), allowance = 4))
        // 翌月は枠回復。
        assertEquals(1, RescueTicketLogic.remaining(used, LocalDate.of(2026, 6, 1), allowance = 1))
    }
}
