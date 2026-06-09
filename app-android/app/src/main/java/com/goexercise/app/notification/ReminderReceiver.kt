package com.goexercise.app.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.goexercise.app.MainActivity
import com.goexercise.app.R

/**
 * リマインダー発火時の通知を出す BroadcastReceiver。チャンネル作成は冪等。POST_NOTIFICATIONS 未許可なら
 * OS 側で黙って無視される(クラッシュしない)。タップで MainActivity を開く。
 */
class ReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_FIRE) return
        ensureChannel(context)
        val contentIntent = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_paw)
            .setContentTitle("今日の運動、どう？ 🐱")
            .setContentText("1 分だけでも OK。猫が待ってるよ。")
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(contentIntent)
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(NOTIF_ID, notification) }
    }

    companion object {
        const val ACTION_FIRE = "com.goexercise.app.REMINDER_FIRE"
        const val CHANNEL_ID = "daily_reminder"
        private const val NOTIF_ID = 2001

        fun ensureChannel(context: Context) {
            val channel = NotificationChannel(CHANNEL_ID, "毎日のリマインダー", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "運動を続けるための毎日のリマインダー"
            }
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
