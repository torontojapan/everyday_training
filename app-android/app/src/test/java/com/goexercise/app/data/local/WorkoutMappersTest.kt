package com.goexercise.app.data.local

import com.goexercise.app.domain.ExerciseItem
import com.goexercise.app.domain.WorkoutCategory
import com.goexercise.app.domain.WorkoutRecord
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlinx.serialization.json.Json
import java.time.LocalDate

/**
 * entity ↔ domain の往復(exercises JSON 含む)を DB 無しで検証する。
 * Room DAO 自体の検証は emulator/Robolectric が要るため別途(androidTest)。
 */
class WorkoutMappersTest {
    // 本番 DI(DatabaseModule.provideJson)と同設定。coerceInputValues で未知 enum を既定値へ寄せる。
    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true; encodeDefaults = true }

    @Test
    fun roundTripPreservesAllFields() {
        val original = WorkoutRecord(
            id = "rec-1",
            date = LocalDate.of(2026, 5, 20),
            category = WorkoutCategory.Cardio,
            exercises = listOf(
                ExerciseItem(id = "e1", name = "スクワット", reps = 20, sets = 3, category = WorkoutCategory.Strength),
                ExerciseItem(id = "e2", name = "ランニング", durationSeconds = 600),
            ),
            memo = "今日は調子よい",
        )

        val entity = original.toEntity(json, createdAtEpochMs = 1000L, updatedAtEpochMs = 2000L)
        val restored = entity.toDomain(json)

        assertEquals(original, restored)
        // epochDay で日付がTZ非依存に保存される
        assertEquals(LocalDate.of(2026, 5, 20).toEpochDay(), entity.dateEpochDay)
        // category は rawValue で保存(iOS 互換)
        assertEquals("cardio", entity.categoryRaw)
    }

    @Test
    fun categorySerializesWithRawValue() {
        val record = WorkoutRecord(
            date = LocalDate.of(2026, 5, 1),
            category = WorkoutCategory.FasciaRelease,
            exercises = listOf(ExerciseItem(name = "ほぐし", category = WorkoutCategory.FasciaRelease)),
        )
        val entity = record.toEntity(json, 0L, 0L)
        // JSON 内の category は rawValue "fasciaRelease"(@SerialName)
        assertTrue(entity.exercisesJson.contains("\"category\":\"fasciaRelease\""))
    }

    @Test
    fun corruptJsonFallsBackToEmpty() {
        // 壊れた JSON の行は空配列にフォールバックし、一覧を落とさない(iOS と同じ)。
        val entity = WorkoutRecordEntity(
            id = "bad", dateEpochDay = LocalDate.of(2026, 5, 1).toEpochDay(),
            categoryRaw = "strength", exercisesJson = "{not valid json", memo = null,
            createdAtEpochMs = 0L, updatedAtEpochMs = 0L,
        )
        assertTrue(entity.toDomain(json).exercises.isEmpty())
    }

    @Test
    fun unknownExerciseCategoryCoercesToNull() {
        // 未知カテゴリ(将来の値)は coerceInputValues で nullable 既定値(null)へ。decode は落ちない。
        val entity = WorkoutRecordEntity(
            id = "u", dateEpochDay = LocalDate.of(2026, 5, 1).toEpochDay(),
            categoryRaw = "strength",
            exercisesJson = """[{"id":"e","name":"未来種目","category":"spaceflight"}]""",
            memo = null, createdAtEpochMs = 0L, updatedAtEpochMs = 0L,
        )
        val domain = entity.toDomain(json)
        assertEquals(1, domain.exercises.size)
        assertEquals("未来種目", domain.exercises.first().name)
        assertNull(domain.exercises.first().category) // 未知 enum → null に coerce
    }

    @Test
    fun emptyExercisesRoundTrips() {
        val record = WorkoutRecord(
            date = LocalDate.of(2026, 5, 2),
            category = WorkoutCategory.Other,
            exercises = emptyList(),
        )
        val restored = record.toEntity(json, 0L, 0L).toDomain(json)
        assertEquals(record, restored)
        assertTrue(restored.exercises.isEmpty())
    }
}
