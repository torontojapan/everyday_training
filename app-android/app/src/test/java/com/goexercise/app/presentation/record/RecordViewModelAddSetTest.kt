package com.goexercise.app.presentation.record

import com.goexercise.app.data.WeightRepository
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.settings.HealthPrefs
import com.goexercise.app.data.settings.HealthRepository
import com.goexercise.app.data.settings.MenstrualEntryRecord
import com.goexercise.app.data.settings.MenstrualRepository
import com.goexercise.app.domain.WeightEntry
import com.goexercise.app.domain.WorkoutCategory
import com.goexercise.app.domain.WorkoutRecord
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import java.time.Clock
import java.time.LocalDate
import java.time.LocalDateTime

/** RecordViewModel.addSet(「+ 同じ種目でセットを追加」)の検証。iOS addSet パリティ。 */
class RecordViewModelAddSetTest {

    @get:org.junit.Rule
    val mainDispatcherRule = com.goexercise.app.MainDispatcherRule()

    private class FakeRepo : WorkoutRepository {
        override fun observeRecords(): Flow<List<WorkoutRecord>> = flowOf(emptyList())
        override suspend fun save(record: WorkoutRecord) {}
        override suspend fun delete(id: String) {}
    }

    private class FakeWeightRepo : WeightRepository {
        val added = mutableListOf<Double>()
        override fun observeEntries(): Flow<List<WeightEntry>> = MutableStateFlow(emptyList())
        override suspend fun add(recordedAt: LocalDateTime, weightKg: Double, memo: String?) { added += weightKg }
        override suspend fun delete(id: String) {}
    }

    private class FakeMenstrualRepo(initial: Set<LocalDate> = emptySet()) : MenstrualRepository {
        val days = MutableStateFlow(initial)
        override val periodDays: Flow<Set<LocalDate>> = days
        override suspend fun toggle(date: LocalDate) {
            days.value = if (days.value.contains(date)) days.value - date else days.value + date
        }
        override suspend fun clearAll() { days.value = emptySet() }
        override suspend fun entriesOnce(): List<MenstrualEntryRecord> = emptyList()
        override suspend fun applyRemoteInsert(id: String, date: LocalDate, createdAtEpochMs: Long) {}
        override suspend fun applyRemoteDelete(id: String) {}
    }

    private class FakeHealthRepo(cycleEnabled: Boolean = false) : HealthRepository {
        override val prefs: Flow<HealthPrefs> = MutableStateFlow(HealthPrefs(cycleTrackingEnabled = cycleEnabled))
        override suspend fun setStartKgIfAbsent(kg: Double) {}
        override suspend fun setTargetKg(kg: Double?) {}
        override suspend fun setHeightCm(cm: Double?) {}
        override suspend fun setIsLossGoal(isLoss: Boolean) {}
        override suspend fun setCycleTrackingEnabled(enabled: Boolean) {}
        override suspend fun clearAll() {}
    }

    private fun vm() = RecordViewModel(FakeRepo(), FakeWeightRepo(), FakeMenstrualRepo(), FakeHealthRepo(), Clock.systemUTC())

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
