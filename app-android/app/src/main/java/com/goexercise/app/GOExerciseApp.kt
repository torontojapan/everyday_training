package com.goexercise.app

import android.app.Application
import com.goexercise.app.analytics.Analytics
import com.goexercise.app.analytics.AnalyticsEvent
import com.goexercise.app.data.settings.SettingsRepository
import com.goexercise.app.notification.ReminderReceiver
import dagger.hilt.android.HiltAndroidApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Hilt の DI ルート。iOS の `@Environment` 注入 / コンポジションルートに相当(計画書 §2)。
 * Room / DataStore / Supabase リポジトリ等は今後 Hilt モジュールとしてここにぶら下げる。
 */
@HiltAndroidApp
class GOExerciseApp : Application() {

    @Inject lateinit var settings: SettingsRepository
    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onCreate() {
        super.onCreate()
        // 通知チャンネルは起動時に作る(冪等。発火時に未作成だと通知が出ないのを防ぐ)。
        ReminderReceiver.ensureChannel(this)
        // 分析: ユーザーの匿名分析オプトイン(既定 ON)を購読。許可時のみ TelemetryDeck を有効化し
        // AppOpen を1回だけ計測。オプトアウト中は consentGranted=false で track が一切送らない。
        // 実送信は release + App ID 設定時のみ(configureIfPossible 内のガード)。
        appScope.launch {
            var appOpenSent = false
            settings.analyticsEnabled.collect { enabled ->
                Analytics.consentGranted = enabled
                if (enabled && !appOpenSent) {
                    Analytics.configureIfPossible(this@GOExerciseApp)
                    Analytics.track(AnalyticsEvent.AppOpen)
                    appOpenSent = true
                }
            }
        }
    }
}
