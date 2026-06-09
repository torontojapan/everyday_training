package com.goexercise.app.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.goexercise.app.data.settings.NotificationPrefsRepository
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * 端末再起動でアラームは消えるため、リマインダーが有効なら再予約する。Hilt の @AndroidEntryPoint で
 * 依存を注入(BroadcastReceiver でも可)。
 */
@AndroidEntryPoint
class BootReceiver : BroadcastReceiver() {

    @Inject lateinit var prefs: NotificationPrefsRepository
    @Inject lateinit var scheduler: ReminderScheduler

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val pending = goAsync()
        CoroutineScope(Dispatchers.Default).launch {
            // DataStore 読込/AlarmManager 失敗で**起動時にプロセスを落とさない**よう全例外を飲み込む。
            runCatching {
                val p = prefs.get()
                if (p.enabled) scheduler.schedule(p.hour, p.minute)
            }
            pending.finish()
        }
    }
}
