package com.goexercise.app.data.local

import android.content.Context
import androidx.room.Room
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.WorkoutRepositoryImpl
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.serialization.json.Json
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideJson(): Json = Json {
        ignoreUnknownKeys = true // 後方互換: 旧/新フィールド差異を許容
        coerceInputValues = true // 未知 enum 値や null を既定値へ寄せる(壊れた行で落とさない)
        encodeDefaults = true
    }

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, "goexercise.db")
            // dev: v1→v2 は破壊的再生成(未リリース=本番データ無し)。**#10 で実 Migration に差し替え**。
            .fallbackToDestructiveMigration(dropAllTables = true)
            .build()

    @Provides
    @Singleton
    fun provideWorkoutDao(db: AppDatabase): WorkoutDao = db.workoutDao()

    @Provides
    @Singleton
    fun provideWeightDao(db: AppDatabase): WeightDao = db.weightDao()
}

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {
    @Binds
    @Singleton
    abstract fun bindWorkoutRepository(impl: WorkoutRepositoryImpl): WorkoutRepository
}
