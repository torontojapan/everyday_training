package com.goexercise.app.notification

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.Calendar
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 毎日のリマインダーを AlarmManager で予約/解除する。**inexact 繰り返し**(`setInexactRepeating`)を使い、
 * SCHEDULE_EXACT_ALARM 権限(Android 12+ の審査摩擦)を避ける。習慣リマインダーには十分な精度。
 * 再起動でアラームは消えるため [BootReceiver] が再予約する。
 */
@Singleton
class ReminderScheduler @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val alarmManager get() = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    fun schedule(hour: Int, minute: Int) {
        val next = nextTrigger(hour, minute)
        alarmManager.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            next,
            AlarmManager.INTERVAL_DAY,
            pendingIntent(),
        )
    }

    fun cancel() {
        alarmManager.cancel(pendingIntent())
    }

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

    private fun pendingIntent(): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).setAction(ReminderReceiver.ACTION_FIRE)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private companion object {
        const val REQUEST_CODE = 1001
    }
}
