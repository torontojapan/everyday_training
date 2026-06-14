package com.goexercise.app.data

import com.goexercise.app.data.local.WeightDao
import com.goexercise.app.data.local.WorkoutDao
import com.goexercise.app.data.rescue.RescueTicketRepository
import com.goexercise.app.data.settings.HealthRepository
import com.goexercise.app.data.settings.MenstrualRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.first
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import javax.inject.Singleton

/** エクスポート用スナップショット。iOS `DataExport` 相当。**ユーザーが記録した内容のみ**(課金状態は対象外)。 */
@Serializable
data class DataExport(
    val exportedAt: String,
    val workouts: List<WorkoutDto>,
    val weights: List<WeightDto>,
    val menstrualDays: List<String>,
) {
    @Serializable
    data class WorkoutDto(val date: String, val category: String, val exercisesJson: String, val memo: String?)

    @Serializable
    data class WeightDto(val recordedAt: String, val weightKg: Double, val memo: String?)
}

/**
 * 自分が記録したデータの「書き出し」「全削除」。iOS `DataManagementService` の移植。
 * 対象は**運動/体重/体調(生理日)のみ**。課金・サブスク状態は意図的に対象外(削除で無料体験を
 * 再取得する不正経路を防ぐ。信頼性向上が目的でアカウント破棄ではない)。
 */
interface DataManagementRepository {
    /** 全記録を整形 JSON で返す(共有/保存用)。 */
    suspend fun exportJson(now: Instant): String
    /** 運動/体重/体調の全記録を削除し、削除件数を返す。 */
    suspend fun deleteAllRecords(): Int
}

class DataManagementRepositoryImpl @Inject constructor(
    private val workoutDao: WorkoutDao,
    private val weightDao: WeightDao,
    private val menstrual: MenstrualRepository,
    private val rescue: RescueTicketRepository,
    private val health: HealthRepository,
    private val json: Json,
    private val backupStore: com.goexercise.app.data.backup.RecordBackupStore,
) : DataManagementRepository {

    override suspend fun exportJson(now: Instant): String {
        val workouts = workoutDao.getAllOnce().map {
            DataExport.WorkoutDto(
                date = LocalDate.ofEpochDay(it.dateEpochDay).toString(),
                category = it.categoryRaw,
                exercisesJson = it.exercisesJson,
                memo = it.memo,
            )
        }
        val weights = weightDao.getAllOnce().map {
            DataExport.WeightDto(
                recordedAt = java.time.LocalDateTime.ofInstant(Instant.ofEpochMilli(it.recordedAtEpochMs), ZoneOffset.UTC).toString(),
                weightKg = it.weightKg,
                memo = it.memo,
            )
        }
        val menstrualDays = menstrual.periodDays.first().sorted().map { it.toString() }
        val export = DataExport(
            exportedAt = DateTimeFormatter.ISO_INSTANT.format(now),
            workouts = workouts,
            weights = weights,
            menstrualDays = menstrualDays,
        )
        return json.encodeToString(DataExport.serializer(), export)
    }

    override suspend fun deleteAllRecords(): Int {
        val count = workoutDao.getAllOnce().size + weightDao.getAllOnce().size + menstrual.periodDays.first().size
        workoutDao.clearAll()
        weightDao.clearAll()
        menstrual.clearAll()
        // 救済使用日を残すと削除後も達成扱いの日が残る(streak/達成計算に流れる)ため必ず消す。
        rescue.clearAll()
        // 体重ゴール/身長(健康個人データ)も消す。開始体重が孤児化するのも防ぐ。
        health.clearAll()
        // クラウドバックアップも全削除予約(次回同期で user_records を物理 delete。iOS と同じ wipe フック)。
        backupStore.noteWipe()
        return count
    }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class DataManagementModule {
    @Binds
    @Singleton
    abstract fun bindDataManagementRepository(impl: DataManagementRepositoryImpl): DataManagementRepository
}
