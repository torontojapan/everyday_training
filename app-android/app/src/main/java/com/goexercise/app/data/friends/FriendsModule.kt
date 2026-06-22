package com.goexercise.app.data.friends

import android.content.Context
import com.goexercise.app.presentation.friends.AccountAuthCoordinator
import com.goexercise.app.presentation.friends.MockAccountAuthCoordinator
import com.goexercise.app.presentation.friends.RealAccountAuthCoordinator
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * 友達バックエンドの提供。SupabaseConfig が設定済みなら実 Supabase、未設定なら Mock
 * (iOS の isConfigured→Mock フォールバックと同型)。実通信には local.properties に
 * SUPABASE_HOST / SUPABASE_ANON_KEY を入れる(iOS と同一プロジェクト)。
 */
@Module
@InstallIn(SingletonComponent::class)
object FriendsModule {
    @Provides
    @Singleton
    fun provideFriendsService(
        @ApplicationContext context: Context,
        watermarkStore: CheerWatermarkStore,
    ): FriendsService =
        if (SupabaseConfig.isConfigured) {
            SupabaseFriendsService(
                // Context は EncryptedSessionManager(JWT 暗号化保存)用に必要。
                SupabaseClientFactory.create(context, SupabaseConfig.url!!, SupabaseConfig.anonKey),
                watermarkStore,
            )
        } else {
            MockFriendsService()
        }

    /**
     * 連携の認証 coordinator。Supabase 設定済(#10 で anon key 投入)なら実 Credential Manager /
     * Custom Tabs、未設定の dev では Mock(実通信なしでフロー確認)。実 Google 連携には併せて
     * GOOGLE_WEB_CLIENT_ID が必要。
     */
    @Provides
    @Singleton
    fun provideAccountAuthCoordinator(): AccountAuthCoordinator =
        if (SupabaseConfig.isConfigured) RealAccountAuthCoordinator() else MockAccountAuthCoordinator()
}
