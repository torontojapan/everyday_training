package com.goexercise.app.data.milestone

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringSetPreferencesKey
import com.goexercise.app.domain.Milestone
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

/** acknowledged 集合と migration 完了フラグの**原子スナップショット**。別々の Flow を combine すると
 *  migrated=true(新)× acknowledged(旧)の混在が起こり得るため、1 つの map から両方を読む。 */
data class MilestoneState(val acknowledged: Set<String>, val migrated: Boolean)

/**
 * 達成節目の既読(acknowledged)永続化。iOS `MilestoneDetector` の UserDefaults 部分を DataStore へ。
 */
interface MilestoneRepository {
    /** acknowledged + migration 完了の一貫スナップショット。お祝い表示は migrated==true になってから。 */
    val state: Flow<MilestoneState>

    /** 節目を祝い済みにする(以後 nextPending で返らない)。 */
    suspend fun acknowledge(milestone: Milestone)

    /**
     * streak 閾値の**拡充時**に、既に通過済みの streak 節目をサイレント既読化する(版ごとに一度だけ)。
     * iOS `migrateExpandedThresholdsIfNeeded` 相当。Android v1 は新規ユーザーのみ = 起動時 streak は小さく
     * 実質 no-op だが、将来の閾値追加で既存ユーザーへ過去達成を連発しないよう機構を用意しておく。
     */
    suspend fun migrateExpandedThresholdsIfNeeded(streakKeys: List<String>)
}

class MilestoneRepositoryImpl @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) : MilestoneRepository {

    private val acknowledgedKey = stringSetPreferencesKey("milestones_acknowledged")
    // 版付きフラグ: 閾値を再拡充する時は v2/v3 と鍵を増やして再 migration する。
    private val migratedKey = booleanPreferencesKey("milestones_migrated_expanded_v1")

    // ack 集合と migration フラグを**1 つの map** から原子スナップショットで読む(migrateExpanded… は
    // 両者を同一 edit で書くので、migrated==true 観測時に silent-ack は必ず acknowledged に反映済み)。
    override val state: Flow<MilestoneState> =
        dataStore.data.map { prefs ->
            MilestoneState(
                acknowledged = prefs[acknowledgedKey] ?: emptySet(),
                migrated = prefs[migratedKey] == true,
            )
        }

    override suspend fun acknowledge(milestone: Milestone) {
        dataStore.edit { prefs ->
            prefs[acknowledgedKey] = (prefs[acknowledgedKey] ?: emptySet()) + milestone.key
        }
    }

    override suspend fun migrateExpandedThresholdsIfNeeded(streakKeys: List<String>) {
        dataStore.edit { prefs ->
            if (prefs[migratedKey] != true) {
                prefs[acknowledgedKey] = (prefs[acknowledgedKey] ?: emptySet()) + streakKeys
                prefs[migratedKey] = true
            }
        }
    }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class MilestoneModule {
    @Binds
    @Singleton
    abstract fun bindMilestoneRepository(impl: MilestoneRepositoryImpl): MilestoneRepository
}
