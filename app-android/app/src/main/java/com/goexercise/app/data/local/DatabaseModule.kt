package com.goexercise.app.data.local

import android.content.Context
import androidx.room.Room
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.WorkoutRepositoryImpl
import com.goexercise.app.data.security.DatabasePassphraseProvider
import com.goexercise.app.data.security.PlaintextDbMigrator
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.serialization.json.Json
import net.zetetic.database.sqlcipher.SupportOpenHelperFactory
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

    private const val DB_NAME = "goexercise.db"

    /** DB パスフレーズの提供元(Keystore 連動の EncryptedSharedPreferences に保管)。 */
    @Provides
    @Singleton
    fun provideDatabasePassphraseProvider(@ApplicationContext context: Context): DatabasePassphraseProvider =
        DatabasePassphraseProvider(context)

    /**
     * Room DB を **SQLCipher で暗号化**して開く(2026-06-22 セキュリティ強化)。
     *
     * 手順:
     *   1. 既存の **平文** goexercise.db があれば、開く前に暗号化へ一度だけ移行(PlaintextDbMigrator)。
     *      移行に失敗した場合は平文のまま残し(データ損失回避)、保存パスフレーズも巻き戻して次回再試行。
     *   2. SupportOpenHelperFactory(passphrase) を openHelperFactory に渡し、以後の読み書きを暗号化。
     *
     * 異常系(データ保全 > 暗号化): 平文移行が失敗した端末では、その平文 DB を SQLCipher で開くと
     * "file is not a database" で **起動不能ループ** になる。これを避けるため、移行失敗時 (PLAINTEXT_FALLBACK)
     * は **今回は平文のまま** 開いて起動とデータを守り、次回起動で再移行を試みる(クラッシュより安全側)。
     * fallback の destructive migration は設定しない(健康データを黙って捨てない)。MIGRATION_1_2 は保持。
     */
    @Provides
    @Singleton
    fun provideDatabase(
        @ApplicationContext context: Context,
        passphraseProvider: DatabasePassphraseProvider,
    ): AppDatabase {
        // 既存平文 DB の一度きりの暗号化移行(冪等。SQLCipher ネイティブのロードも兼ねる)。
        val result = PlaintextDbMigrator.migrateIfNeeded(context, DB_NAME, passphraseProvider)

        val builder = Room.databaseBuilder(context, AppDatabase::class.java, DB_NAME)
            .addMigrations(MIGRATION_1_2) // v1→v2: weight_entries 追加(本番データを保持)

        when (result) {
            PlaintextDbMigrator.Result.ENCRYPTED_READY -> {
                // SupportOpenHelperFactory は渡された ByteArray を内部で消費(使用後 zeroize)するため
                // ここで都度新しい配列を取得して渡す。
                val passphrase = passphraseProvider.getOrCreatePassphrase()
                builder.openHelperFactory(SupportOpenHelperFactory(passphrase)) // SQLCipher で暗号化
            }
            PlaintextDbMigrator.Result.PLAINTEXT_FALLBACK -> {
                // 移行失敗で平文 DB が残存。SQLCipher で開くと起動不能ループになるため、今回は
                // 既定(平文)ファクトリで開く(openHelperFactory 未設定)。パスフレーズは保存しない
                // (= 次回起動の migrateIfNeeded が再移行を試みる)。
            }
        }
        return builder.build()
    }

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
