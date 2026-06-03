package com.goexercise.app.data.settings

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.ui.theme.AppTheme
import java.time.LocalDate
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

/**
 * アプリ設定の永続化(iOS の UserDefaults 相当)。v1 はテーマのみ。
 * 通知設定・共有 opt-in 等は順次このリポジトリに追加する。
 */
interface SettingsRepository {
    val theme: Flow<AppTheme>
    suspend fun setTheme(theme: AppTheme)

    /** 初回利用日(累計利用日数の起点)。未設定なら null。iOS LifetimeUsageTracker 相当。 */
    val firstUseDate: Flow<LocalDate?>
    suspend fun setFirstUseDateIfAbsent(date: LocalDate)

    /** ユーザーが選んだ猫種。未選択は orange。iOS UserCatPreferences.myCat 相当。 */
    val catBreed: Flow<CatBreed>
    suspend fun setCatBreed(breed: CatBreed)
}

class SettingsRepositoryImpl @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : SettingsRepository {

    private val themeKey = stringPreferencesKey("theme")
    private val firstUseKey = longPreferencesKey("first_use_epoch_day")
    private val catBreedKey = stringPreferencesKey("cat_breed")

    override val theme: Flow<AppTheme> = dataStore.data.map { prefs ->
        prefs[themeKey]?.let { name -> runCatching { AppTheme.valueOf(name) }.getOrNull() } ?: AppTheme.Peach
    }

    override suspend fun setTheme(theme: AppTheme) {
        dataStore.edit { it[themeKey] = theme.name }
    }

    override val firstUseDate: Flow<LocalDate?> = dataStore.data.map { prefs ->
        prefs[firstUseKey]?.let { LocalDate.ofEpochDay(it) }
    }

    override suspend fun setFirstUseDateIfAbsent(date: LocalDate) {
        dataStore.edit { prefs ->
            if (prefs[firstUseKey] == null) prefs[firstUseKey] = date.toEpochDay()
        }
    }

    override val catBreed: Flow<CatBreed> = dataStore.data.map { prefs ->
        CatBreed.fromRaw(prefs[catBreedKey])
    }

    override suspend fun setCatBreed(breed: CatBreed) {
        dataStore.edit { it[catBreedKey] = breed.rawValue }
    }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class SettingsModule {
    @Binds
    @Singleton
    abstract fun bindSettingsRepository(impl: SettingsRepositoryImpl): SettingsRepository
}
