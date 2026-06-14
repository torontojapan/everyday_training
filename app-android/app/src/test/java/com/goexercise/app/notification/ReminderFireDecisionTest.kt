package com.goexercise.app.notification

import com.goexercise.app.domain.NotificationPersonality
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * [ReminderFireDecision.suppressReason] = [ReminderReceiver.onReceive] の発火時抑制判定の純粋テスト。
 * null=通知を出す / 非null=抑制理由。優先順(disabled → friendDriven → 当日達成 → quiet で連続なし)も担保。
 */
class ReminderFireDecisionTest {

    private fun reason(
        enabled: Boolean = true,
        personality: NotificationPersonality = NotificationPersonality.Voice,
        todayAchieved: Boolean = false,
        streak: Int = 0,
        weeklyRate: Double = 0.0,
    ) = ReminderFireDecision.suppressReason(enabled, personality, todayAchieved, streak, weeklyRate)

    @Test
    fun disabled_suppresses() {
        assertEquals(ReminderSuppressReason.DISABLED, reason(enabled = false))
    }

    @Test
    fun friendDriven_suppresses() {
        assertEquals(
            ReminderSuppressReason.FRIEND_DRIVEN,
            reason(personality = NotificationPersonality.FriendDriven),
        )
    }

    @Test
    fun todayAchieved_suppresses_evenForVoiceWithStreak() {
        assertEquals(
            ReminderSuppressReason.TODAY_ACHIEVED,
            reason(personality = NotificationPersonality.Voice, todayAchieved = true, streak = 5, weeklyRate = 0.8),
        )
    }

    @Test
    fun quiet_noStreakNoProgress_suppresses() {
        assertEquals(
            ReminderSuppressReason.QUIET_NO_STREAK,
            reason(personality = NotificationPersonality.Quiet, streak = 0, weeklyRate = 0.0),
        )
    }

    @Test
    fun quiet_withStreak_fires() {
        assertNull(reason(personality = NotificationPersonality.Quiet, streak = 3, weeklyRate = 0.0))
    }

    @Test
    fun quiet_withWeeklyProgress_fires() {
        assertNull(reason(personality = NotificationPersonality.Quiet, streak = 0, weeklyRate = 0.5))
    }

    @Test
    fun voice_noStreakNoProgress_fires() {
        // Voice は連続0・週進捗0 でも(当日未達成なら)鳴らす。quiet とは異なる。
        assertNull(reason(personality = NotificationPersonality.Voice, streak = 0, weeklyRate = 0.0))
    }

    @Test
    fun disabled_takesPriorityOverAchieved() {
        // 優先順: disabled が最上位。
        assertEquals(
            ReminderSuppressReason.DISABLED,
            reason(enabled = false, todayAchieved = true),
        )
    }

    @Test
    fun friendDriven_takesPriorityOverAchieved() {
        assertEquals(
            ReminderSuppressReason.FRIEND_DRIVEN,
            reason(personality = NotificationPersonality.FriendDriven, todayAchieved = true),
        )
    }
}
