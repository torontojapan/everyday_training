package com.goexercise.app.data.friends

import com.goexercise.app.presentation.friends.AccountAuthCoordinator
import com.goexercise.app.presentation.friends.MockAccountAuthCoordinator
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
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
    fun provideFriendsService(): FriendsService =
        if (SupabaseConfig.isConfigured) {
            SupabaseFriendsService(SupabaseClientFactory.create(SupabaseConfig.url!!, SupabaseConfig.anonKey))
        } else {
            MockFriendsService()
        }

    /**
     * 連携の認証 coordinator。dev は Mock(実通信なしでフロー確認)。
     * **実 Credential Manager / Custom Tabs 実装は #10**(Web Client ID + Supabase 設定 + 実機)。
     */
    @Provides
    @Singleton
    fun provideAccountAuthCoordinator(): AccountAuthCoordinator = MockAccountAuthCoordinator()
}
