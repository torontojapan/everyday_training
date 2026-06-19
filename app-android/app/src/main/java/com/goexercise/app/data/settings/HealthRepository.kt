package com.goexercise.app.data.settings

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

/** 体重ゴール/身長などの健康設定。iOS `UserHealthPreferences` の移植(DataStore 永続)。 */
data class HealthPrefs(
    val startKg: Double? = null,
    val targetKg: Double? = null,
    val heightCm: Double? = null,
    /** true=減量目標 / false=増量目標。weightLoss マイルストーンの発火条件。 */
    val isLossGoal: Boolean = true,
    /** 生理周期トラッキングのオプトイン。既定 false(プライバシー優先=明示 ON まで生理日UIを出さない)。iOS CycleTrackingSettings.isEnabled 相当。 */
    val cycleTrackingEnabled: Boolean = false,
) {
    /** 開始→目標の達成率(0..1、超過は1で頭打ち)。増量/減量両対応。開始=目標は null。
     *  iOS `UserHealthPreferences.progressRatio(currentKilograms:)` 完全移植(体重 HeroCard の達成リング用)。 */
    fun progressRatio(currentKg: Double): Double? {
        val t = targetKg ?: return null
        val s = startKg ?: return null
        val totalDelta = t - s
        if (kotlin.math.abs(totalDelta) <= 0.001) return null
        val raw = (currentKg - s) / totalDelta
        return raw.coerceIn(0.0, 1.0)
    }
}

interface HealthRepository {
    val prefs: Flow<HealthPrefs>
    suspend fun setStartKgIfAbsent(kg: Double)
    suspend fun setTargetKg(kg: Double?)
    suspend fun setHeightCm(cm: Double?)
    suspend fun setIsLossGoal(isLoss: Boolean)
    suspend fun setCycleTrackingEnabled(enabled: Boolean)
    /** 体重ゴール/身長を全消去(データ全削除導線。体重記録と一緒に消す=開始体重の孤児化も防ぐ)。 */
    suspend fun clearAll()
}

class HealthRepositoryImpl @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : HealthRepository {

    private val startKey = doublePreferencesKey("health_start_kg")
    private val targetKey = doublePreferencesKey("health_target_kg")
    private val heightKey = doublePreferencesKey("health_height_cm")
    private val lossGoalKey = booleanPreferencesKey("health_is_loss_goal")
    private val cycleKey = booleanPreferencesKey("health_cycle_tracking_enabled")

    override val prefs: Flow<HealthPrefs> = dataStore.data.map { p ->
        HealthPrefs(
            startKg = p[startKey],
            targetKg = p[targetKey],
            heightCm = p[heightKey],
            isLossGoal = p[lossGoalKey] ?: true,
            cycleTrackingEnabled = p[cycleKey] ?: false,
        )
    }

    /** 最初の記録時に「開始時体重」を一度だけ自動キャプチャ(iOS captureStartWeightIfNeeded)。 */
    override suspend fun setStartKgIfAbsent(kg: Double) {
        dataStore.edit { if (it[startKey] == null) it[startKey] = kg }
    }

    override suspend fun setTargetKg(kg: Double?) {
        dataStore.edit { if (kg == null) it.remove(targetKey) else it[targetKey] = kg }
    }

    override suspend fun setHeightCm(cm: Double?) {
        dataStore.edit { if (cm == null) it.remove(heightKey) else it[heightKey] = cm }
    }

    override suspend fun setIsLossGoal(isLoss: Boolean) {
        dataStore.edit { it[lossGoalKey] = isLoss }
    }

    override suspend fun setCycleTrackingEnabled(enabled: Boolean) {
        dataStore.edit { it[cycleKey] = enabled }
    }

    override suspend fun clearAll() {
        dataStore.edit { prefs ->
            listOf(startKey, targetKey, heightKey, lossGoalKey, cycleKey).forEach { prefs.remove(it) }
        }
    }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class HealthModule {
    @Binds
    @Singleton
    abstract fun bindHealthRepository(impl: HealthRepositoryImpl): HealthRepository
}
