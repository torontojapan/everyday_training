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
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.rescue.RescueTicketRepository
import com.goexercise.app.data.settings.NotificationPrefsRepository
import com.goexercise.app.domain.AchievementEvaluator
import com.goexercise.app.domain.NotificationMessageProvider
import com.goexercise.app.domain.NotificationSlot
import com.goexercise.app.domain.RestDayResolver
import com.goexercise.app.domain.StreakCalculator
import com.goexercise.app.domain.WeeklyProgressCalculator
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.time.LocalDate
import javax.inject.Inject

/**
 * リマインダー発火時の通知を出す BroadcastReceiver。発火時に記録を読んで
 * - **当日達成済みなら通知を抑制**(iOS rescheduleAfterAchievement/cancelToday 相当を発火時評価で実現)、
 * - 性格(personality)・連続・週達成率・スロットで**パーソナライズした文言**([NotificationMessageProvider])、
 * - タップで route=home を渡す deep-link
 * を行う。POST_NOTIFICATIONS 未許可なら OS 側で黙って無視される(クラッシュしない)。
 */
@AndroidEntryPoint
class ReminderReceiver : BroadcastReceiver() {

    @Inject lateinit var prefs: NotificationPrefsRepository
    @Inject lateinit var workoutRepository: WorkoutRepository
    @Inject lateinit var rescueTickets: RescueTicketRepository

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_FIRE) return
        val slot = runCatching { NotificationSlot.valueOf(intent.getStringExtra(EXTRA_SLOT) ?: "Morning") }
            .getOrDefault(NotificationSlot.Morning)
        val pending = goAsync()
        CoroutineScope(Dispatchers.Default).launch {
            runCatching {
                val p = prefs.get()
                if (!p.enabled) return@runCatching
                if (p.personality == com.goexercise.app.domain.NotificationPersonality.FriendDriven) return@runCatching // v1 は日常 push 抑制
                val today = LocalDate.now()
                val records = workoutRepository.observeRecords().first()
                val rescued = rescueTickets.rescuedDates.first()

                // 当日達成済みなら鳴らさない(達成日に追い立てない。iOS の当日 cancel と同じ体験)。
                val restDays = RestDayResolver.restDaySet(today, records, today)
                val todayAchieved = AchievementEvaluator.dailyStatus(today, records, restDays, rescued, today).countsAsAchieved
                if (todayAchieved) return@runCatching

                val streak = StreakCalculator.currentStreak(records, today, rescued)
                val weekStatuses = WeeklyProgressCalculator.statuses(today, records, today, rescued)
                val progress = WeeklyProgressCalculator.progress(weekStatuses)
                val rate = if (progress.totalDays > 0) progress.achievedCount.toDouble() / progress.totalDays else 0.0
                // quiet は連続が危ういとき(連続中 or 週進捗あり)だけ鳴らす。
                if (p.personality == com.goexercise.app.domain.NotificationPersonality.Quiet && streak == 0 && rate == 0.0) return@runCatching

                val body = NotificationMessageProvider.message(slot, p.personality, streak, rate, today)
                ensureChannel(context)
                runCatching { NotificationManagerCompat.from(context).notify(NOTIF_ID, buildNotification(context, body)) }
            }
            pending.finish()
        }
    }

    private fun buildNotification(context: Context, body: String): android.app.Notification {
        // タップで home へ。MainActivity は intent.dataString(goexercise://)のみ deep link 消費するため、
        // extra ではなく **data URI** で渡す(singleTop で別画面表示中でも onNewIntent→home 遷移する。Codex R3)。
        val tapIntent = Intent(context, MainActivity::class.java)
            .setAction(Intent.ACTION_VIEW)
            .setData(android.net.Uri.parse("goexercise://home"))
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val contentIntent = PendingIntent.getActivity(
            context, 0, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_paw)
            .setContentTitle("GOエクササイズ")
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(contentIntent)
            .build()
    }

    companion object {
        const val ACTION_FIRE = "com.goexercise.app.REMINDER_FIRE"
        const val CHANNEL_ID = "daily_reminder"
        const val EXTRA_SLOT = "slot"
        private const val NOTIF_ID = 2001

        fun ensureChannel(context: Context) {
            val channel = NotificationChannel(CHANNEL_ID, "毎日のリマインダー", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "運動を続けるための毎日のリマインダー"
            }
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
