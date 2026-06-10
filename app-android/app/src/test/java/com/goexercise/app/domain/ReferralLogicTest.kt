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
    @Test fun clock_isInMonth_usesLocalCalendar() {
        // 月判定は**ローカル暦**(allowance の月境界 RescueTicketLogic と一致)。マシン TZ に
        // 依存しないよう、判定対象もローカルゾーンで構築して決定的に検証する。
        val zone = java.time.ZoneId.systemDefault()
        val fmt = java.time.format.DateTimeFormatter.ISO_OFFSET_DATE_TIME
        fun iso(d: java.time.ZonedDateTime) = d.format(fmt)
        val now = java.time.LocalDate.of(2026, 6, 20).atStartOfDay(zone).toInstant()
        // ローカルで6月頭 → 今月
        assertTrue(ReferralClock.isInMonth(iso(java.time.LocalDate.of(2026, 6, 1).atStartOfDay(zone)), now))
        // ローカルで5月末 → 先月
        assertFalse(ReferralClock.isInMonth(iso(java.time.LocalDate.of(2026, 5, 31).atTime(23, 0).atZone(zone)), now))
        assertFalse(ReferralClock.isInMonth(null, now))
    }

    @Test fun clock_isInMonth_jstBoundary_countsLocalMonth() {
        // 月境界 UTC-local 型の回帰: JST(UTC+9)で 6/30 23:00 JST(= 6/30 14:00 UTC)は
        // **ローカルでは6月**。UTC で割ると同じく6月だが、7/1 早朝 JST(= 6/30 夜 UTC)を
        // ローカル7月として扱えることを、ローカルゾーン構築で決定的に確認する。
        val zone = java.time.ZoneId.systemDefault()
        val fmt = java.time.format.DateTimeFormatter.ISO_OFFSET_DATE_TIME
        fun iso(d: java.time.ZonedDateTime) = d.format(fmt)
        val julyNow = java.time.LocalDate.of(2026, 7, 2).atStartOfDay(zone).toInstant()
        // ローカル 7/1 0:30 は7月(allowance も7月扱い)→ 今月ボーナス
        assertTrue(ReferralClock.isInMonth(iso(java.time.LocalDate.of(2026, 7, 1).atTime(0, 30).atZone(zone)), julyNow))
        // ローカル 6/30 23:30 は6月 → 7月の now とは別月
        assertFalse(ReferralClock.isInMonth(iso(java.time.LocalDate.of(2026, 6, 30).atTime(23, 30).atZone(zone)), julyNow))
    }
    @Test fun entryPolicy_allowsWithinGrace_whenNoReferrer() {
        val start = java.time.Instant.ofEpochSecond(1_000_000)
        assertTrue(ReferralEntryPolicy.canEnterCodeLater(start, start.plusSeconds(3*86400), hasExistingReferral = false))
    }
    @Test fun entryPolicy_blocksAfterGrace() {
        val start = java.time.Instant.ofEpochSecond(1_000_000)
        assertFalse(ReferralEntryPolicy.canEnterCodeLater(start, start.plusSeconds(8*86400), hasExistingReferral = false))
    }
    @Test fun entryPolicy_boundaryExactly7Days_allowed() {
        val start = java.time.Instant.ofEpochSecond(1_000_000)
        assertTrue(ReferralEntryPolicy.canEnterCodeLater(start, start.plusSeconds(7*86400), hasExistingReferral = false))
    }
    @Test fun entryPolicy_justOver7Days_blocked() {
        val start = java.time.Instant.ofEpochSecond(1_000_000)
        assertFalse(ReferralEntryPolicy.canEnterCodeLater(start, start.plusSeconds(7*86400 + 1), hasExistingReferral = false))
    }
    @Test fun entryPolicy_oldTruncationWindow_nowBlocked() {
        // 旧実装で許可されていた 7.5 日(切り捨てで days=7)は新実装では不可。
        val start = java.time.Instant.ofEpochSecond(1_000_000)
        assertFalse(ReferralEntryPolicy.canEnterCodeLater(start, start.plusSeconds((7.5 * 86400).toLong()), hasExistingReferral = false))
    }
    @Test fun entryPolicy_blocksWhenAlreadyReferred() {
        val start = java.time.Instant.ofEpochSecond(1_000_000)
        assertFalse(ReferralEntryPolicy.canEnterCodeLater(start, start.plusSeconds(86400), hasExistingReferral = true))
    }
    @Test fun entryPolicy_blocksWhenNoFirstLaunch() {
        assertFalse(ReferralEntryPolicy.canEnterCodeLater(null, java.time.Instant.now(), hasExistingReferral = false))
    }
}
