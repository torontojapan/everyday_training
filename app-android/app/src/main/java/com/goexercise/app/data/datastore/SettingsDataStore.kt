package com.goexercise.app.data.datastore

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStore
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * Jetpack DataStore(Preferences)。iOS の UserDefaults 相当(計画書 §3/§4):
 * テーマ・選択猫種・通知設定・rescue 使用日・milestone 既読・onboarding 完了・
 * 友達共有 opt-in 等の小データを保存する。実キーと型付きリポジトリは各機能フェーズで追加。
 */
private val Context.settingsDataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

@Module
@InstallIn(SingletonComponent::class)
object DataStoreModule {
    @Provides
    @Singleton
    fun provideSettingsDataStore(@ApplicationContext context: Context): DataStore<Preferences> =
        context.settingsDataStore
}
