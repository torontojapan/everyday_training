package com.goexercise.app.data

import com.goexercise.app.data.friends.MockFriendsService
import com.goexercise.app.domain.friends.ReferralConfirmation
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class ReferralServiceTest {
    @Test fun submit_autoFriends_andHasReferrer() = runBlocking {
        val svc = MockFriendsService()
        svc.signIn("新規", "newbie")
        svc.submitInviteCode("ABC234")
        assertTrue(svc.hasReferrer())
        assertTrue(svc.refreshFriends().any { it.friendCode == "ABC234" })
    }
    @Test fun submit_rejectsDuplicate() = runBlocking {
        val svc = MockFriendsService(); svc.signIn("新規", "newbie")
        svc.submitInviteCode("ABC234")
        try { svc.submitInviteCode("XYZ789"); fail("should throw") } catch (e: Exception) { }
    }
    @Test fun confirm_returnsRefereePop_thenNull() = runBlocking {
        val svc = MockFriendsService(); svc.signIn("新規", "newbie")
        svc.submitInviteCode("ABC234")
        assertEquals(ReferralConfirmation.Role.REFEREE, svc.confirmReferralIfEligible(true)?.role)
        assertNull(svc.confirmReferralIfEligible(true))
    }
    @Test fun confirm_noFirstRecord_null() = runBlocking {
        val svc = MockFriendsService(); svc.signIn("新規", "newbie")
        svc.submitInviteCode("ABC234")
        assertNull(svc.confirmReferralIfEligible(false))
    }
    @Test fun unseen_markSeen() = runBlocking {
        val svc = MockFriendsService(); svc.signIn("紹介者", "host")
        svc.seedInboundConfirmation("ともだちA")
        assertEquals(1, svc.unseenReferrerConfirmations().size)
        assertTrue(svc.unseenReferrerConfirmations().isEmpty())
    }
    @Test fun summary_starsAndBonus() = runBlocking {
        val svc = MockFriendsService(); svc.signIn("紹介者", "host")
        svc.seedInboundConfirmation("A"); svc.seedInboundConfirmation("B")
        val s = svc.referralSummary()
        assertEquals(2, s.starBadges)
        assertEquals(2, s.freezeBonusThisMonth)
    }
}
