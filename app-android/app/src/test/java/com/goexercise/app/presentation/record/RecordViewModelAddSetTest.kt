package com.goexercise.app.presentation.record

import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.domain.WorkoutCategory
import com.goexercise.app.domain.WorkoutRecord
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import java.time.Clock
import java.time.LocalDate

/** RecordViewModel.addSet(「+ 同じ種目でセットを追加」)の検証。iOS addSet パリティ。 */
class RecordViewModelAddSetTest {

    private class FakeRepo : WorkoutRepository {
        override fun observeRecords(): Flow<List<WorkoutRecord>> = flowOf(emptyList())
        override suspend fun recordsInRange(start: LocalDate, end: LocalDate): List<WorkoutRecord> = emptyList()
        override suspend fun save(record: WorkoutRecord) {}
        override suspend fun delete(id: String) {}
    }

    private fun vm() = RecordViewModel(FakeRepo(), Clock.systemUTC())

    @Test
    fun addSet_duplicatesNameAndCategory_directlyBelow_withFreshId() {
        val vm = vm()
        val first = vm.state.value.drafts.first()
        vm.setCategory(first.id, WorkoutCategory.Cardio)
        vm.updateDraft(first.id) { it.copy(name = "スクワット", reps = "10") }

        val src = vm.state.value.drafts.first()
        vm.addSet(src.id)

        val drafts = vm.state.value.drafts
        assertEquals(2, drafts.size)
        val copy = drafts[1]
        assertEquals("スクワット", copy.name)              // 名前は引き継ぐ
        assertEquals(WorkoutCategory.Cardio, copy.category) // カテゴリも引き継ぐ
        assertEquals("", copy.reps)                          // 回数はセットごとに入れ直す=空
        assertNotEquals(src.id, copy.id)                     // id は新規
    }

    @Test
    fun addSet_carriesWeight() {
        val vm = vm()
        val first = vm.state.value.drafts.first()
        vm.updateDraft(first.id) { it.copy(name = "ベンチプレス", loadText = "60") }
        vm.addSet(vm.state.value.drafts.first().id)
        // 重さ違いの複数セットを種目選び直しなしで記録するため、重さも引き継ぐ。
        assertEquals("60", vm.state.value.drafts[1].loadText)
    }

    @Test
    fun validExercises_parsesLoadKilograms() {
        val vm = vm()
        val first = vm.state.value.drafts.first()
        vm.updateDraft(first.id) { it.copy(name = "デッドリフト", loadText = "80.5") }
        val ex = vm.state.value.validExercises().first()
        assertEquals(80.5, ex.loadKilograms!!, 0.001)
    }

    @Test
    fun addSet_unknownId_isNoOp() {
        val vm = vm()
        vm.addSet("does-not-exist")
        assertEquals(1, vm.state.value.drafts.size)
    }
}
