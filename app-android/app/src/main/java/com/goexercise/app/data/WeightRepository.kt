package com.goexercise.app.data

import com.goexercise.app.data.local.WeightDao
import com.goexercise.app.data.local.toDomain
import com.goexercise.app.data.local.toEntity
import com.goexercise.app.domain.WeightEntry
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.Clock
import java.time.LocalDateTime
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/** 体重記録の永続層。ドメイン型のみ公開(Room を上に漏らさない)。iOS WeightStore の CRUD 部相当。 */
interface WeightRepository {
    fun observeEntries(): Flow<List<WeightEntry>>
    /** 同一日に複数記録できるよう常に新規 insert(iOS 仕様)。 */
    suspend fun add(recordedAt: LocalDateTime, weightKg: Double, memo: String?)
    suspend fun delete(id: String)
}

class WeightRepositoryImpl @Inject constructor(
    private val dao: WeightDao,
    private val clock: Clock,
) : WeightRepository {

    override fun observeEntries(): Flow<List<WeightEntry>> =
        dao.observeAll().map { rows -> rows.map { it.toDomain() } }

    override suspend fun add(recordedAt: LocalDateTime, weightKg: Double, memo: String?) {
        val now = clock.millis()
        val entry = WeightEntry(id = UUID.randomUUID().toString(), recordedAt = recordedAt, weightKg = weightKg, memo = memo?.trim()?.ifBlank { null })
        dao.insert(entry.toEntity(createdAt = now, updatedAt = now))
    }

    override suspend fun delete(id: String) = dao.deleteById(id)
}

@Module
@InstallIn(SingletonComponent::class)
abstract class WeightRepositoryModule {
    @Binds
    @Singleton
    abstract fun bindWeightRepository(impl: WeightRepositoryImpl): WeightRepository
}
