package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationPersonalityTest {

    @Test
    fun rawValues_matchCrossOsContract() {
        assertEquals("quiet", NotificationPersonality.Quiet.rawValue)
        assertEquals("voice", NotificationPersonality.Voice.rawValue)
        assertEquals("cheer", NotificationPersonality.Cheer.rawValue)
        assertEquals("spartan", NotificationPersonality.Spartan.rawValue)
        assertEquals("cool", NotificationPersonality.Cool.rawValue)
        assertEquals("tsundere", NotificationPersonality.Tsundere.rawValue)
        assertEquals("friendDriven", NotificationPersonality.FriendDriven.rawValue)
        // 声掛けトーン4種を追加し、全7種(うち friendDriven は friends ゲート)。
        assertEquals(7, NotificationPersonality.entries.size)
    }

    @Test
    fun fromRaw_defaultsToVoice() {
        assertEquals(NotificationPersonality.Voice, NotificationPersonality.fromRaw(null))
        assertEquals(NotificationPersonality.Voice, NotificationPersonality.fromRaw("unknown"))
        assertEquals(NotificationPersonality.Quiet, NotificationPersonality.fromRaw("quiet"))
    }

    @Test
    fun visibleCases_hidesFriendDrivenWhenFriendsDisabled() {
        assertFalse(NotificationPersonality.visibleCases(friendsEnabled = false).contains(NotificationPersonality.FriendDriven))
        assertTrue(NotificationPersonality.visibleCases(friendsEnabled = true).contains(NotificationPersonality.FriendDriven))
    }
}
