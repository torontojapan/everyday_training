package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Test

class ReferralLogicTest {
    @Test fun allowance_base_unchanged() {
        assertEquals(1, RescueTicketAllowance.current(isPremium = false, referralBonus = 0))
        assertEquals(4, RescueTicketAllowance.current(isPremium = true, referralBonus = 0))
    }
    @Test fun allowance_addsBonus_clipsAt5() {
        assertEquals(4, RescueTicketAllowance.current(isPremium = false, referralBonus = 3))
        assertEquals(5, RescueTicketAllowance.current(isPremium = false, referralBonus = 10))
        assertEquals(5, RescueTicketAllowance.current(isPremium = true, referralBonus = 1))
        assertEquals(5, RescueTicketAllowance.current(isPremium = true, referralBonus = 5))
    }
    @Test fun allowance_negativeBonus_floored() {
        assertEquals(1, RescueTicketAllowance.current(isPremium = false, referralBonus = -3))
    }
    @Test fun allowance_oldApi_delegates() {
        assertEquals(1, RescueTicketAllowance.current(isPremium = false))
        assertEquals(4, RescueTicketAllowance.current(isPremium = true))
    }
}
