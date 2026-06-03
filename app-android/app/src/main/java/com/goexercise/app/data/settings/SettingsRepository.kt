package com.goexercise.app.data.settings

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import com.goexercise.app.ui.theme.AppTheme
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject

/**
 * アプリ設定の永続化(iOS の UserDefaults 相当)。v1 はテーマのみ。
 * 通知設定・共有 opt-in 等は順次このリポジトリに追加する。
 */
interface SettingsRepository {
    val theme: Flow<AppTheme>
    suspend fun setTheme(theme: AppTheme)
}

class SettingsRepositoryImpl @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : SettingsRepository {

    private val themeKey = stringPreferencesKey("theme")

    override val theme: Flow<AppTheme> = dataStore.data.map { prefs ->
        prefs[themeKey]?.let { name -> runCatching { AppTheme.valueOf(name) }.getOrNull() } ?: AppTheme.Peach
    }

    override suspend fun setTheme(theme: AppTheme) {
        dataStore.edit { it[themeKey] = theme.name }
    }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class SettingsModule {
    @Binds
    abstract fun bindSettingsRepository(impl: SettingsRepositoryImpl): SettingsRepository
}
