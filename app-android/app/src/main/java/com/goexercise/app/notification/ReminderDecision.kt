package com.goexercise.app.notification

import com.goexercise.app.data.settings.ReminderPrefs
import com.goexercise.app.domain.NotificationPersonality
import com.goexercise.app.domain.NotificationSlot

/**
 * 通知スケジューラ/レシーバの**純粋な意思決定**を AlarmManager / NotificationManager / DB の副作用から
 * 切り離したもの。[ReminderScheduler.apply] と [ReminderReceiver.onReceive] の分岐を 1:1 で表し、JVM
 * ユニットテスト可能にする(リポジトリの「ロジックを純粋関数へ抽出→機械テスト」パターン)。
 */

/** 1 スロット(朝/夕)に対する予約 or 解除の指示。 */
sealed interface SlotAction {
    val slot: NotificationSlot
    data class Schedule(override val slot: NotificationSlot, val hour: Int, val minute: Int) : SlotAction
    data class Cancel(override val slot: NotificationSlot) : SlotAction
}

/**
 * [ReminderScheduler.apply] の分岐。常に朝・夕の両スロットへ明示的なアクションを返す(漏れなく確定)。
 * - enabled=false / FriendDriven: 日常 push 抑制 → 両方解除。
 * - Quiet: 静かに → 夕のみ(朝は解除)。発火時にさらに「連続が危うい時だけ」へ絞る。
 * - Voice(既定): 朝(常時)+ 夕(count>1 のときのみ)。
 */
object ReminderSchedulePlan {
    fun plan(prefs: ReminderPrefs): List<SlotAction> {
        if (!prefs.enabled || prefs.personality == NotificationPersonality.FriendDriven) {
            return listOf(SlotAction.Cancel(NotificationSlot.Morning), SlotAction.Cancel(NotificationSlot.Evening))
        }
        if (prefs.personality == NotificationPersonality.Quiet) {
            return listOf(
                SlotAction.Cancel(NotificationSlot.Morning),
                SlotAction.Schedule(NotificationSlot.Evening, prefs.eveningHour, prefs.eveningMinute),
            )
        }
        val evening = if (prefs.count > 1) {
            SlotAction.Schedule(NotificationSlot.Evening, prefs.eveningHour, prefs.eveningMinute)
        } else {
            SlotAction.Cancel(NotificationSlot.Evening)
        }
        return listOf(SlotAction.Schedule(NotificationSlot.Morning, prefs.hour, prefs.minute), evening)
    }
}

/** 発火時に通知を抑制する理由。null(fire)= 通知を出す。 */
enum class ReminderSuppressReason { DISABLED, FRIEND_DRIVEN, TODAY_ACHIEVED, QUIET_NO_STREAK }

/**
 * [ReminderReceiver.onReceive] の発火時抑制判定を 1:1 で表す。優先順は onReceive と同一
 * (disabled → friendDriven → 当日達成 → quiet で連続なし)。
 * @param weeklyRate 今週の達成率(0.0..1.0)。Quiet モードで「連続0 かつ 週進捗0」のときだけ静かにする。
 */
object ReminderFireDecision {
    fun suppressReason(
        enabled: Boolean,
        personality: NotificationPersonality,
        todayAchieved: Boolean,
        streak: Int,
        weeklyRate: Double,
    ): ReminderSuppressReason? = when {
        !enabled -> ReminderSuppressReason.DISABLED
        personality == NotificationPersonality.FriendDriven -> ReminderSuppressReason.FRIEND_DRIVEN
        todayAchieved -> ReminderSuppressReason.TODAY_ACHIEVED
        personality == NotificationPersonality.Quiet && streak == 0 && weeklyRate == 0.0 ->
            ReminderSuppressReason.QUIET_NO_STREAK
        else -> null
    }
}
