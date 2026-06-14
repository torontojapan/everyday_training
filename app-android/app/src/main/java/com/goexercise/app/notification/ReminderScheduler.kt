package com.goexercise.app.notification

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.goexercise.app.data.settings.ReminderPrefs
import com.goexercise.app.domain.NotificationPersonality
import com.goexercise.app.domain.NotificationSlot
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.Calendar
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 毎日のリマインダーを AlarmManager で予約/解除する。**inexact 繰り返し**(`setInexactRepeating`)を使い、
 * SCHEDULE_EXACT_ALARM 権限(Android 12+ の審査摩擦)を避ける。習慣リマインダーには十分な精度。
 * 再起動でアラームは消えるため [BootReceiver] が再予約する。
 *
 * 朝(1本目)と夕(2本目・count>1 のとき)の 2 本を別々の PendingIntent(REQUEST_CODE 違い + slot extra)で
 * 予約する。達成日の当日抑制やメッセージのパーソナライズは発火時に [ReminderReceiver] が行う
 * (iOS は事前 cancelToday だが、Android の repeating は発火時評価で同等の挙動にする)。
 */
@Singleton
class ReminderScheduler @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val alarmManager get() = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    /** 後方互換: 朝1本だけ予約(夕は解除)。 */
    fun schedule(hour: Int, minute: Int) {
        scheduleSlot(NotificationSlot.Morning, hour, minute)
        cancelSlot(NotificationSlot.Evening)
    }

    /**
     * prefs と**性格**に従って予約(iOS scheduleDaily の性格分岐パリティ。Codex R3 是正)。
     * - friendDriven: 日常 push 抑制 → 全解除。
     * - quiet: 静かに → **夕のみ**(朝は出さない)。発火時に「連続が危うい時だけ」へさらに絞る。
     * - voice: 朝(常時)+ 夕(count>1)。
     */
    fun apply(prefs: ReminderPrefs) {
        if (!prefs.enabled || prefs.personality == NotificationPersonality.FriendDriven) { cancel(); return }
        if (prefs.personality == NotificationPersonality.Quiet) {
            cancelSlot(NotificationSlot.Morning)
            scheduleSlot(NotificationSlot.Evening, prefs.eveningHour, prefs.eveningMinute)
            return
        }
        scheduleSlot(NotificationSlot.Morning, prefs.hour, prefs.minute)
        if (prefs.count > 1) scheduleSlot(NotificationSlot.Evening, prefs.eveningHour, prefs.eveningMinute)
        else cancelSlot(NotificationSlot.Evening)
    }

    fun cancel() {
        cancelSlot(NotificationSlot.Morning)
        cancelSlot(NotificationSlot.Evening)
    }

    private fun scheduleSlot(slot: NotificationSlot, hour: Int, minute: Int) {
        alarmManager.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            nextTrigger(hour, minute),
            AlarmManager.INTERVAL_DAY,
            pendingIntent(slot),
        )
    }

    private fun cancelSlot(slot: NotificationSlot) = alarmManager.cancel(pendingIntent(slot))

    /** 今日の指定時刻が未来ならそれ、過ぎていれば翌日。 */
    private fun nextTrigger(hour: Int, minute: Int): Long {
        val now = Calendar.getInstance()
        val target = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (!target.after(now)) target.add(Calendar.DAY_OF_YEAR, 1)
        return target.timeInMillis
    }

    private fun pendingIntent(slot: NotificationSlot): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java)
            .setAction(ReminderReceiver.ACTION_FIRE)
            .putExtra(ReminderReceiver.EXTRA_SLOT, slot.name)
        val requestCode = if (slot == NotificationSlot.Morning) REQUEST_CODE_MORNING else REQUEST_CODE_EVENING
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private companion object {
        const val REQUEST_CODE_MORNING = 1001
        const val REQUEST_CODE_EVENING = 1002
    }
}
