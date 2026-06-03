package com.goexercise.app.analytics

import android.content.Context
import android.util.Log
import com.goexercise.app.BuildConfig
import com.telemetrydeck.sdk.TelemetryDeck

/**
 * 計測する行動イベント。離脱・課金ファネルを後から分析できるよう、主要ステップに対応させる。
 * iOS `AnalyticsEvent`(Analytics.swift)と signal 名・パラメータを揃える。
 */
sealed interface AnalyticsEvent {
    /** TelemetryDeck の signal 名(英小文字スネーク)。iOS と一致させること。 */
    val name: String

    /** 個人を特定しない補助パラメータのみ。 */
    val parameters: Map<String, String> get() = emptyMap()

    data object AppOpen : AnalyticsEvent {
        override val name = "app_open"
    }

    data object OnboardingCompleted : AnalyticsEvent {
        override val name = "onboarding_complete"
    }

    data class RecordCreated(val category: String) : AnalyticsEvent {
        override val name = "record_created"
        override val parameters = mapOf("category" to category)
    }

    data class PaywallViewed(val product: String) : AnalyticsEvent {
        override val name = "view_paywall"
        override val parameters = mapOf("product" to product)
    }

    data class PurchaseStarted(val product: String) : AnalyticsEvent {
        override val name = "start_purchase"
        override val parameters = mapOf("product" to product)
    }

    data class PurchaseCompleted(val product: String) : AnalyticsEvent {
        override val name = "purchase_complete"
        override val parameters = mapOf("product" to product)
    }

    data object DataExported : AnalyticsEvent {
        override val name = "data_exported"
    }

    data object DataDeleted : AnalyticsEvent {
        override val name = "data_deleted"
    }
}

/**
 * 計測の抽象。アプリ本体はこの interface 越しに track するだけで、実体
 * (TelemetryDeck / Noop)を意識しない。iOS `AnalyticsService` protocol に対応。
 */
interface AnalyticsService {
    fun track(event: AnalyticsEvent)
}

/** 何も送らない実装。テスト・DEBUG・App ID 未設定時のデフォルト。 */
object NoopAnalytics : AnalyticsService {
    override fun track(event: AnalyticsEvent) {}
}

/** TelemetryDeck(プライバシー配慮型・匿名)への送信実装。 */
internal class TelemetryDeckAnalytics : AnalyticsService {
    override fun track(event: AnalyticsEvent) {
        TelemetryDeck.signal(event.name, params = event.parameters)
    }
}

/**
 * アプリ全体から呼ぶ計測ファサード。iOS `enum Analytics` に対応(グローバルな差し替え可能ファサード)。
 *
 * 既定は [NoopAnalytics] なので **App ID を設定するまで一切データを送らない**。これにより
 * 「TelemetryDeck App ID 設定」までは現状のゼロ収集(プライバシーラベル「データ収集なし」)を維持する。
 */
object Analytics {
    private const val TAG = "Analytics"

    /** 差し替え可能な実体(テストでは Noop のまま)。 */
    @Volatile
    var service: AnalyticsService = NoopAnalytics

    fun track(event: AnalyticsEvent) {
        service.track(event)
    }

    /**
     * 起動時に一度だけ呼ぶ。App ID が設定済み かつ Release ビルドのときだけ TelemetryDeck を有効化する。
     * iOS の `configureIfPossible()`(`#if !DEBUG` + App ID guard)と対称。
     * App ID が不正でも(`UUID.fromString` 例外)アプリは落とさない。
     */
    fun configureIfPossible(context: Context) {
        if (BuildConfig.DEBUG) return
        val appId = BuildConfig.TELEMETRYDECK_APP_ID
        if (appId.isBlank()) return
        runCatching {
            TelemetryDeck.start(context.applicationContext, TelemetryDeck.Builder().appID(appId))
            service = TelemetryDeckAnalytics()
        }.onFailure { Log.w(TAG, "TelemetryDeck init skipped: ${it.message}") }
    }
}
