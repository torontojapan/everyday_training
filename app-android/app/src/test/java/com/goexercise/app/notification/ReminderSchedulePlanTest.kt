package com.goexercise.app.notification

import com.goexercise.app.data.settings.ReminderPrefs
import com.goexercise.app.domain.NotificationPersonality
import com.goexercise.app.domain.NotificationSlot
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * [ReminderSchedulePlan.plan] = [ReminderScheduler.apply] の分岐の純粋テスト。
 * 朝/夕の両スロットへ必ず明示アクションを返す(漏れなく確定)ことを機械担保する。
 */
class ReminderSchedulePlanTest {

    private fun prefs(
        enabled: Boolean = true,
        personality: NotificationPersonality = NotificationPersonality.Voice,
        count: Int = 1,
        hour: Int = 8,
        minute: Int = 30,
        eveningHour: Int = 20,
        eveningMinute: Int = 0,
    ) = ReminderPrefs(
        enabled = enabled,
        hour = hour,
        minute = minute,
        eveningHour = eveningHour,
        eveningMinute = eveningMinute,
        count = count,
        personality = personality,
    )

    @Test
    fun disabled_cancelsBothSlots() {
        val plan = ReminderSchedulePlan.plan(prefs(enabled = false, count = 2))
        assertEquals(
            listOf(
                SlotAction.Cancel(NotificationSlot.Morning),
                SlotAction.Cancel(NotificationSlot.Evening),
            ),
            plan,
        )
    }

    @Test
    fun friendDriven_cancelsBothSlots_evenWhenEnabled() {
        val plan = ReminderSchedulePlan.plan(
            prefs(enabled = true, personality = NotificationPersonality.FriendDriven, count = 2),
        )
        assertEquals(
            listOf(
                SlotAction.Cancel(NotificationSlot.Morning),
                SlotAction.Cancel(NotificationSlot.Evening),
            ),
            plan,
        )
    }

    @Test
    fun quiet_cancelsMorning_schedulesEveningOnly() {
        val plan = ReminderSchedulePlan.plan(
            prefs(personality = NotificationPersonality.Quiet, count = 2, eveningHour = 21, eveningMinute = 15),
        )
        assertEquals(
            listOf(
                SlotAction.Cancel(NotificationSlot.Morning),
                SlotAction.Schedule(NotificationSlot.Evening, 21, 15),
            ),
            plan,
        )
    }

    @Test
    fun voice_count1_schedulesMorning_cancelsEvening() {
        val plan = ReminderSchedulePlan.plan(
            prefs(personality = NotificationPersonality.Voice, count = 1, hour = 7, minute = 45),
        )
        assertEquals(
            listOf(
                SlotAction.Schedule(NotificationSlot.Morning, 7, 45),
                SlotAction.Cancel(NotificationSlot.Evening),
            ),
            plan,
        )
    }

    @Test
    fun voice_count2_schedulesBothSlots() {
        val plan = ReminderSchedulePlan.plan(
            prefs(personality = NotificationPersonality.Voice, count = 2, hour = 9, minute = 0, eveningHour = 19, eveningMinute = 30),
        )
        assertEquals(
            listOf(
                SlotAction.Schedule(NotificationSlot.Morning, 9, 0),
                SlotAction.Schedule(NotificationSlot.Evening, 19, 30),
            ),
            plan,
        )
    }
}
