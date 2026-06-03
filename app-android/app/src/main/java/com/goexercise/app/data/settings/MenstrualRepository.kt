package com.goexercise.app.data.settings

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringSetPreferencesKey
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

/** 月経日マーキングの永続化(premium 周期オーバーレイ用)。iOS `MenstrualStore` 相当。epochDay の集合。 */
interface MenstrualRepository {
    val periodDays: Flow<Set<LocalDate>>
    suspend fun toggle(date: LocalDate)
}

class MenstrualRepositoryImpl @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : MenstrualRepository {

    private val key = stringSetPreferencesKey("menstrual_period_epoch_days")

    override val periodDays: Flow<Set<LocalDate>> = dataStore.data.map { prefs ->
        (prefs[key] ?: emptySet()).mapNotNull { it.toLongOrNull()?.let(LocalDate::ofEpochDay) }.toSet()
    }

    override suspend fun toggle(date: LocalDate) {
        val day = date.toEpochDay().toString()
        dataStore.edit { prefs ->
            val cur = prefs[key] ?: emptySet()
            prefs[key] = if (day in cur) cur - day else cur + day
        }
    }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class MenstrualModule {
    @Binds
    @Singleton
    abstract fun bindMenstrualRepository(impl: MenstrualRepositoryImpl): MenstrualRepository
}
