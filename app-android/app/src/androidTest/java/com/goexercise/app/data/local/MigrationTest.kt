package com.goexercise.app.data.local

import androidx.room.testing.MigrationTestHelper
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * v1→v2 の実 Migration を計装テストで検証(#10)。`schemas/{1,2}.json`(androidTest assets)を基準に
 * MIGRATION_1_2 を実行 → スキーマ identity-hash 一致 + **v1 の workout データが生存** + 新 weight_entries
 * が使えることを確認する。逐語 SQL コピーの正しさを機械保証し、出荷時のデータ破壊を防ぐ。
 */
@RunWith(AndroidJUnit4::class)
class MigrationTest {

    private val dbName = "migration-test.db"

    @get:Rule
    val helper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        AppDatabase::class.java,
    )

    @Test
    fun migrate1To2_preservesWorkoutData_andAddsWeightTable() {
        // v1 スキーマで DB を作り、workout を 1 件入れる。
        helper.createDatabase(dbName, 1).apply {
            execSQL(
                "INSERT INTO workout_records (id, dateEpochDay, categoryRaw, exercisesJson, memo, createdAtEpochMs, updatedAtEpochMs) " +
                    "VALUES ('w1', 20000, 'strength', '[]', NULL, 1, 1)",
            )
            close()
        }

        // migration 実行 + v2 スキーマ検証(不一致なら例外)。
        val db = helper.runMigrationsAndValidate(dbName, 2, true, MIGRATION_1_2)

        // v1 の workout データが生存している。
        db.query("SELECT id, categoryRaw FROM workout_records").use { c ->
            assertTrue("workout row should survive migration", c.moveToFirst())
            assertEquals("w1", c.getString(0))
            assertEquals("strength", c.getString(1))
        }

        // 新規 weight_entries テーブルが使える。
        db.execSQL(
            "INSERT INTO weight_entries (id, recordedAtEpochMs, weightKg, memo, createdAtEpochMs, updatedAtEpochMs) " +
                "VALUES ('we1', 100, 64.5, NULL, 1, 1)",
        )
        db.query("SELECT weightKg FROM weight_entries WHERE id = 'we1'").use { c ->
            assertTrue(c.moveToFirst())
            assertEquals(64.5, c.getDouble(0), 1e-9)
        }
        db.close()
    }
}
