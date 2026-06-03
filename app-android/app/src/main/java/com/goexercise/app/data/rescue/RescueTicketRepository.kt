package com.goexercise.app.data.rescue

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringSetPreferencesKey
import com.goexercise.app.domain.RescueTicketLogic
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 連続記録フリーズ(保険チケット)の使用日を永続化。iOS `RescueTicketStore`(UserDefaults)の移植。
 * 使用日は epochDay 文字列の Set で DataStore に保存。月次集計は [RescueTicketLogic]。
 */
interface RescueTicketRepository {
    /** 救済(フリーズ)使用日の集合。Home/履歴の達成判定に渡す。 */
    val rescuedDates: Flow<Set<LocalDate>>

    /** 指定日にフリーズを消費。枠切れ/同日二重なら false。 */
    suspend fun useTicket(date: LocalDate, allowance: Int): Boolean
}

class RescueTicketRepositoryImpl @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : RescueTicketRepository {

    private val usedKey = stringSetPreferencesKey("rescue_used_epoch_days")

    override val rescuedDates: Flow<Set<LocalDate>> = dataStore.data.map { prefs ->
        (prefs[usedKey] ?: emptySet()).mapNotNull { it.toLongOrNull() }.map { LocalDate.ofEpochDay(it) }.toSet()
    }

    override suspend fun useTicket(date: LocalDate, allowance: Int): Boolean {
        val current = rescuedDates.first()
        if (!RescueTicketLogic.hasAvailable(current, date, allowance)) return false
        if (current.contains(date)) return false
        dataStore.edit { prefs ->
            val set = (prefs[usedKey] ?: emptySet()).toMutableSet()
            set.add(date.toEpochDay().toString())
            prefs[usedKey] = set
        }
        return true
    }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class RescueTicketModule {
    @Binds
    @Singleton
    abstract fun bindRescueTicketRepository(impl: RescueTicketRepositoryImpl): RescueTicketRepository
}
