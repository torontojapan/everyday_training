package com.goexercise.app.data.settings

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.ShareCardGradient
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

    /** 共有カードの背景グラデーション選択(既定 Sunset)。永続化。 */
    val shareGradient: Flow<ShareCardGradient>
    suspend fun setShareGradient(gradient: ShareCardGradient)

    /** オンボーディング(初回の猫選択)を完了したか。iOS UserCatPreferences.hasCompletedOnboarding 相当。 */
    val onboardingComplete: Flow<Boolean>
    suspend fun setOnboardingComplete()

    /**
     * 匿名の利用状況分析(TelemetryDeck)を共有するか。**既定 true(匿名 ON)**・設定でオプトアウト可。
     * 個人を特定しない匿名計測で、OFF にすると一切送信しない(Analytics.consentGranted を制御)。
     */
    val analyticsEnabled: Flow<Boolean>
    suspend fun setAnalyticsEnabled(enabled: Boolean)

    /** 達成時の振動(haptic)を有効にするか。既定 true。iOS CelebrationPreferences.hapticEnabled 相当。 */
    val hapticEnabled: Flow<Boolean>
    suspend fun setHapticEnabled(enabled: Boolean)

    /** バックアップ促し(BackupCard)を「あとで」で閉じた日。30日間は再表示しない(iOS の沈黙期間)。未設定は null。 */
    val backupPromptDismissedAt: Flow<LocalDate?>
    suspend fun dismissBackupPrompt(date: LocalDate)

    /** 友達の初回「表示名を決める」カードを閉じたか。iOS `friends.didDismissNamePrompt`(@AppStorage)相当。 */
    val namePromptDismissed: Flow<Boolean>
    suspend fun setNamePromptDismissed(dismissed: Boolean)

    /** 友達に種目の回数/時間/セット数も共有するか(opt-in・既定 OFF)。iOS `FriendSharingPreferences.includeExerciseDetail`。 */
    val shareExerciseDetail: Flow<Boolean>
    suspend fun setShareExerciseDetail(enabled: Boolean)
}

class SettingsRepositoryImpl @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : SettingsRepository {

    private val themeKey = stringPreferencesKey("theme")
    private val firstUseKey = longPreferencesKey("first_use_epoch_day")
    private val catBreedKey = stringPreferencesKey("cat_breed")
    private val onboardingKey = androidx.datastore.preferences.core.booleanPreferencesKey("onboarding_complete")
    private val analyticsKey = androidx.datastore.preferences.core.booleanPreferencesKey("analytics_enabled")
    private val hapticKey = androidx.datastore.preferences.core.booleanPreferencesKey("haptic_enabled")
    private val backupDismissedKey = longPreferencesKey("backup_prompt_dismissed_epoch_day")
    private val namePromptDismissedKey = androidx.datastore.preferences.core.booleanPreferencesKey("friends_name_prompt_dismissed")
    private val shareDetailKey = androidx.datastore.preferences.core.booleanPreferencesKey("friend_share_exercise_detail")

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

    private val shareGradientKey = stringPreferencesKey("share_gradient")
    override val shareGradient: Flow<ShareCardGradient> = dataStore.data.map { prefs ->
        ShareCardGradient.fromName(prefs[shareGradientKey])
    }

    override suspend fun setShareGradient(gradient: ShareCardGradient) {
        dataStore.edit { it[shareGradientKey] = gradient.name }
    }

    // 明示フラグが無い既存インストール(アップグレード)は、初回利用日が既にあれば「オンボ済」とみなす
    // (新規キーの欠如で既存ユーザーを猫選択に押し戻さない)。新規インストールは両方とも無く false。
    override val onboardingComplete: Flow<Boolean> = dataStore.data.map { prefs ->
        prefs[onboardingKey] ?: (prefs[firstUseKey] != null)
    }

    override suspend fun setOnboardingComplete() {
        dataStore.edit { it[onboardingKey] = true }
    }

    // 既定 true(匿名 ON)。明示的に false を入れた時だけオプトアウト。
    override val analyticsEnabled: Flow<Boolean> = dataStore.data.map { prefs ->
        prefs[analyticsKey] ?: true
    }

    override suspend fun setAnalyticsEnabled(enabled: Boolean) {
        dataStore.edit { it[analyticsKey] = enabled }
    }

    // 既定 true(達成時に振動)。OFF で celebration haptic を抑止。
    override val hapticEnabled: Flow<Boolean> = dataStore.data.map { prefs -> prefs[hapticKey] ?: true }

    override suspend fun setHapticEnabled(enabled: Boolean) {
        dataStore.edit { it[hapticKey] = enabled }
    }

    override val backupPromptDismissedAt: Flow<LocalDate?> = dataStore.data.map { prefs ->
        prefs[backupDismissedKey]?.let { LocalDate.ofEpochDay(it) }
    }

    override suspend fun dismissBackupPrompt(date: LocalDate) {
        dataStore.edit { it[backupDismissedKey] = date.toEpochDay() }
    }

    override val shareExerciseDetail: Flow<Boolean> = dataStore.data.map { it[shareDetailKey] ?: false }
    override suspend fun setShareExerciseDetail(enabled: Boolean) {
        dataStore.edit { it[shareDetailKey] = enabled }
    }

    override val namePromptDismissed: Flow<Boolean> = dataStore.data.map { it[namePromptDismissedKey] ?: false }

    override suspend fun setNamePromptDismissed(dismissed: Boolean) {
        dataStore.edit { it[namePromptDismissedKey] = dismissed }
    }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class SettingsModule {
    @Binds
    @Singleton
    abstract fun bindSettingsRepository(impl: SettingsRepositoryImpl): SettingsRepository
}
