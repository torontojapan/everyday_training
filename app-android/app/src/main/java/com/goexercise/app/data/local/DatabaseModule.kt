package com.goexercise.app.data.local

import android.content.Context
import androidx.room.Room
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
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

/**
 * v1→v2: weight_entries テーブル + index を追加(WeightEntry 導入)。SQL は **schemas/2.json の
 * createSql を逐語コピー**しているため Room の identity-hash 検証に一致する(出荷データを破壊しない)。
 */
val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE IF NOT EXISTS `weight_entries` (`id` TEXT NOT NULL, `recordedAtEpochMs` INTEGER NOT NULL, " +
                "`weightKg` REAL NOT NULL, `memo` TEXT, `createdAtEpochMs` INTEGER NOT NULL, " +
                "`updatedAtEpochMs` INTEGER NOT NULL, PRIMARY KEY(`id`))",
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS `index_weight_entries_recordedAtEpochMs` ON `weight_entries` (`recordedAtEpochMs`)")
    }
}

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
            .addMigrations(MIGRATION_1_2) // v1→v2: weight_entries 追加(本番データを保持)
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
