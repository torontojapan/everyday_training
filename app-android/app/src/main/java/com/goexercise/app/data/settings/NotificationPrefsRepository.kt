package com.goexercise.app.data.settings

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import com.goexercise.app.domain.NotificationPersonality
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 毎日のリマインダー通知設定。iOS のローカル通知設定相当(DataStore 永続)。既定 OFF / 朝8:30 / 夕20:00 /
 * 1日2回 / 性格=voice。hour/minute は朝(1本目)、eveningHour/eveningMinute は夕(2本目・count>1 のみ)。
 */
data class ReminderPrefs(
    val enabled: Boolean = false,
    val hour: Int = 8,
    val minute: Int = 30,
    val eveningHour: Int = 20,
    val eveningMinute: Int = 0,
    /** 1日の通知回数(1=朝のみ / 2=朝+夕)。既定 1=既存ユーザー(reminder_count 未保存)の単発通知を
     *  維持し、移行で勝手に2本化・同時刻の重複配信になるのを防ぐ(Codex R3)。2本目は明示オプトイン。 */
    val count: Int = 1,
    val personality: NotificationPersonality = NotificationPersonality.Default,
)

interface NotificationPrefsRepository {
    val prefs: Flow<ReminderPrefs>
    suspend fun get(): ReminderPrefs
    /** 後方互換: 朝時刻のみ更新(既存呼び出し用)。 */
    suspend fun set(enabled: Boolean, hour: Int, minute: Int)
    /** 全設定の更新(回数/2本目/性格を含む)。 */
    suspend fun update(prefs: ReminderPrefs)
}

class NotificationPrefsRepositoryImpl @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : NotificationPrefsRepository {

    private val enabledKey = booleanPreferencesKey("reminder_enabled")
    private val hourKey = intPreferencesKey("reminder_hour")
    private val minuteKey = intPreferencesKey("reminder_minute")
    private val eveningHourKey = intPreferencesKey("reminder_evening_hour")
    private val eveningMinuteKey = intPreferencesKey("reminder_evening_minute")
    private val countKey = intPreferencesKey("reminder_count")
    private val personalityKey = stringPreferencesKey("reminder_personality")

    override val prefs: Flow<ReminderPrefs> = dataStore.data.map { p ->
        ReminderPrefs(
            enabled = p[enabledKey] ?: false,
            hour = (p[hourKey] ?: 8).coerceIn(0, 23),
            minute = (p[minuteKey] ?: 30).coerceIn(0, 59),
            eveningHour = (p[eveningHourKey] ?: 20).coerceIn(0, 23),
            eveningMinute = (p[eveningMinuteKey] ?: 0).coerceIn(0, 59),
            count = (p[countKey] ?: 1).coerceIn(1, 2), // 未保存(既存ユーザー)は単発=移行で2本化しない
            personality = NotificationPersonality.fromRaw(p[personalityKey]),
        )
    }

    override suspend fun get(): ReminderPrefs = prefs.first()

    override suspend fun set(enabled: Boolean, hour: Int, minute: Int) {
        dataStore.edit {
            it[enabledKey] = enabled
            it[hourKey] = hour.coerceIn(0, 23)
            it[minuteKey] = minute.coerceIn(0, 59)
        }
    }

    override suspend fun update(prefs: ReminderPrefs) {
        dataStore.edit {
            it[enabledKey] = prefs.enabled
            it[hourKey] = prefs.hour.coerceIn(0, 23)
            it[minuteKey] = prefs.minute.coerceIn(0, 59)
            it[eveningHourKey] = prefs.eveningHour.coerceIn(0, 23)
            it[eveningMinuteKey] = prefs.eveningMinute.coerceIn(0, 59)
            it[countKey] = prefs.count.coerceIn(1, 2)
            it[personalityKey] = prefs.personality.rawValue
        }
    }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class NotificationPrefsModule {
    @Binds
    @Singleton
    abstract fun bindNotificationPrefsRepository(impl: NotificationPrefsRepositoryImpl): NotificationPrefsRepository
}
