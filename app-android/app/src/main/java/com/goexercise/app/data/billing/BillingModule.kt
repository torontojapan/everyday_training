package com.goexercise.app.data.billing

import android.content.Context
import com.goexercise.app.BuildConfig
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * プレミアム課金の提供。`PLAY_BILLING_ENABLED`(既定 false)なら実 Play Billing、未設定なら Mock
 * (iOS の StoreKit ↔ デモ Premium と同型)。Play Console にサブスク商品 + 内部テスト配信が整うまで
 * dev は Mock 経路で paywall とエンタイトルメント遷移を確認する(#10 で実 Play へ)。
 */
@Module
@InstallIn(SingletonComponent::class)
object BillingModule {
    @Provides
    @Singleton
    fun providePremiumRepository(@ApplicationContext context: Context): PremiumRepository =
        if (BuildConfig.PLAY_BILLING_ENABLED) {
            PlayBillingPremiumRepository(context)
        } else {
            MockPremiumRepository()
        }
}
