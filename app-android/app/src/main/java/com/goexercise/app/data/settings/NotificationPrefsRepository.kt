package com.goexercise.app.data.settings

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

/** 毎日のリマインダー通知設定。iOS のローカル通知設定相当(DataStore 永続)。既定 OFF / 20:00。 */
data class ReminderPrefs(val enabled: Boolean = false, val hour: Int = 20, val minute: Int = 0)

interface NotificationPrefsRepository {
    val prefs: Flow<ReminderPrefs>
    suspend fun get(): ReminderPrefs
    suspend fun set(enabled: Boolean, hour: Int, minute: Int)
}

class NotificationPrefsRepositoryImpl @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : NotificationPrefsRepository {

    private val enabledKey = booleanPreferencesKey("reminder_enabled")
    private val hourKey = intPreferencesKey("reminder_hour")
    private val minuteKey = intPreferencesKey("reminder_minute")

    override val prefs: Flow<ReminderPrefs> = dataStore.data.map { p ->
        ReminderPrefs(
            enabled = p[enabledKey] ?: false,
            hour = (p[hourKey] ?: 20).coerceIn(0, 23),
            minute = (p[minuteKey] ?: 0).coerceIn(0, 59),
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
}

@Module
@InstallIn(SingletonComponent::class)
abstract class NotificationPrefsModule {
    @Binds
    @Singleton
    abstract fun bindNotificationPrefsRepository(impl: NotificationPrefsRepositoryImpl): NotificationPrefsRepository
}
