package com.goexercise.app.presentation.record

import com.goexercise.app.domain.WorkoutCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** RecordUiState の純粋変換(validExercises / canSave / toRecord, 種目別カテゴリ)を検証。 */
class RecordUiStateTest {

    @Test
    fun blankDraftsCannotSave() {
        val state = RecordUiState()
        assertFalse(state.canSave)
        assertNull(state.toRecord(LocalDate.of(2026, 5, 20)))
    }

    @Test
    fun validExerciseEnablesSaveAndParsesNumbers() {
        val state = RecordUiState(
            drafts = listOf(ExerciseDraft(name = " ランニング ", category = WorkoutCategory.Cardio, minutes = "10", reps = "0", sets = "")),
        )
        assertTrue(state.canSave)

        val record = state.toRecord(LocalDate.of(2026, 5, 20))!!
        assertEquals(WorkoutCategory.Cardio, record.category) // 先頭種目のカテゴリが代表
        assertEquals(1, record.exercises.size)
        val ex = record.exercises.first()
        assertEquals("ランニング", ex.name)
        assertEquals(600, ex.durationSeconds)
        assertNull(ex.reps)
        assertNull(ex.sets)
        assertEquals(WorkoutCategory.Cardio, ex.category)
    }

    @Test
    fun perExerciseCategoryIsPreserved() {
        // 種目ごとに異なるカテゴリ(混在記録)。代表は先頭=Strength。
        val state = RecordUiState(
            drafts = listOf(
                ExerciseDraft(name = "スクワット", category = WorkoutCategory.Strength),
                ExerciseDraft(name = "ランニング", category = WorkoutCategory.Cardio),
            ),
        )
        val record = state.toRecord(LocalDate.of(2026, 5, 20))!!
        assertEquals(WorkoutCategory.Strength, record.category)
        assertEquals(WorkoutCategory.Strength, record.exercises[0].category)
        assertEquals(WorkoutCategory.Cardio, record.exercises[1].category)
    }

    @Test
    fun blankNamedDraftsAreDropped() {
        val state = RecordUiState(
            drafts = listOf(
                ExerciseDraft(name = "スクワット", reps = "20", sets = "3"),
                ExerciseDraft(name = "   "),
            ),
        )
        val record = state.toRecord(LocalDate.of(2026, 5, 20))!!
        assertEquals(1, record.exercises.size)
        assertEquals(20, record.exercises.first().reps)
        assertEquals(3, record.exercises.first().sets)
    }

    @Test
    fun memoTrimmedAndNullWhenBlank() {
        val withMemo = RecordUiState(drafts = listOf(ExerciseDraft(name = "x")), memo = "  頑張った  ")
            .toRecord(LocalDate.of(2026, 5, 20))!!
        assertEquals("頑張った", withMemo.memo)

        val noMemo = RecordUiState(drafts = listOf(ExerciseDraft(name = "x")), memo = "   ")
            .toRecord(LocalDate.of(2026, 5, 20))!!
        assertNull(noMemo.memo)
    }

    @Test
    fun savingBlocksCanSave() {
        val state = RecordUiState(drafts = listOf(ExerciseDraft(name = "x")), isSaving = true)
        assertFalse(state.canSave) // 保存中は再保存不可
    }

    @Test
    fun clampDigitsLimitsLength() {
        assertEquals("9999", RecordUiState.clampDigits("99999999", 4))
        assertEquals("12", RecordUiState.clampDigits("1a2b", 4)) // 数字以外除去
    }
}
