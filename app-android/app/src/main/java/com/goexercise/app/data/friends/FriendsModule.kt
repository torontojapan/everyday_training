package com.goexercise.app.data.friends

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
}
