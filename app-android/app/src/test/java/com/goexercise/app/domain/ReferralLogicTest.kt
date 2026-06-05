package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.assertFalse
import org.junit.Test
import com.goexercise.app.domain.friends.ReferralClock
import com.goexercise.app.domain.friends.ReferralEntryPolicy

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
    @Test fun clock_parsesTimestamps() {
        assertNotNull(ReferralClock.parseTimestamp("2026-06-05T12:00:00+00:00"))
        assertNotNull(ReferralClock.parseTimestamp("2026-06-05T12:00:00.123456+00:00"))
        assertNull(ReferralClock.parseTimestamp("nope"))
    }
    @Test fun clock_isInMonth_utc() {
        val now = java.time.OffsetDateTime.parse("2026-06-20T00:00:00+00:00").toInstant()
        assertTrue(ReferralClock.isInMonth("2026-06-01T00:00:00+00:00", now))
        assertFalse(ReferralClock.isInMonth("2026-05-31T23:00:00+00:00", now))
        assertFalse(ReferralClock.isInMonth(null, now))
    }
    @Test fun entryPolicy_allowsWithinGrace_whenNoReferrer() {
        val start = java.time.Instant.ofEpochSecond(1_000_000)
        assertTrue(ReferralEntryPolicy.canEnterCodeLater(start, start.plusSeconds(3*86400), hasExistingReferral = false))
    }
    @Test fun entryPolicy_blocksAfterGrace() {
        val start = java.time.Instant.ofEpochSecond(1_000_000)
        assertFalse(ReferralEntryPolicy.canEnterCodeLater(start, start.plusSeconds(8*86400), hasExistingReferral = false))
    }
    @Test fun entryPolicy_blocksWhenAlreadyReferred() {
        val start = java.time.Instant.ofEpochSecond(1_000_000)
        assertFalse(ReferralEntryPolicy.canEnterCodeLater(start, start.plusSeconds(86400), hasExistingReferral = true))
    }
    @Test fun entryPolicy_blocksWhenNoFirstLaunch() {
        assertFalse(ReferralEntryPolicy.canEnterCodeLater(null, java.time.Instant.now(), hasExistingReferral = false))
    }
}
