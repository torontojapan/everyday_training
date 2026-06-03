package com.goexercise.app.presentation.record

import com.goexercise.app.domain.WorkoutCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** RecordUiState の純粋変換(validExercises / canSave / toRecord)を検証。 */
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
            category = WorkoutCategory.Cardio,
            drafts = listOf(ExerciseDraft(name = " ランニング ", minutes = "10", reps = "0", sets = "")),
        )
        assertTrue(state.canSave)

        val record = state.toRecord(LocalDate.of(2026, 5, 20))!!
        assertEquals(WorkoutCategory.Cardio, record.category)
        assertEquals(1, record.exercises.size)
        val ex = record.exercises.first()
        assertEquals("ランニング", ex.name) // trim される
        assertEquals(600, ex.durationSeconds) // 10分=600秒
        assertNull(ex.reps) // "0" は未設定
        assertNull(ex.sets) // 空は未設定
        assertEquals(WorkoutCategory.Cardio, ex.category)
    }

    @Test
    fun blankNamedDraftsAreDropped() {
        val state = RecordUiState(
            drafts = listOf(
                ExerciseDraft(name = "スクワット", reps = "20", sets = "3"),
                ExerciseDraft(name = "   "), // 名前空白 → 除外
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
}
