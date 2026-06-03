package com.goexercise.app

import android.app.Application
import com.goexercise.app.analytics.Analytics
import com.goexercise.app.analytics.AnalyticsEvent
import com.goexercise.app.notification.ReminderReceiver
import dagger.hilt.android.HiltAndroidApp

/**
 * Hilt の DI ルート。iOS の `@Environment` 注入 / コンポジションルートに相当(計画書 §2)。
 * Room / DataStore / Supabase リポジトリ等は今後 Hilt モジュールとしてここにぶら下げる。
 */
@HiltAndroidApp
class GOExerciseApp : Application() {
    override fun onCreate() {
        super.onCreate()
        // 通知チャンネルは起動時に作る(冪等。発火時に未作成だと通知が出ないのを防ぐ)。
        ReminderReceiver.ensureChannel(this)
        // 分析を有効化(release + App ID 設定時のみ。未設定なら no-op)してから起動を計測。
        Analytics.configureIfPossible(this)
        Analytics.track(AnalyticsEvent.AppOpen)
    }
}
