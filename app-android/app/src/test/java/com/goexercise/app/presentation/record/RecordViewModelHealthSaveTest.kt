package com.goexercise.app.presentation.record

import com.goexercise.app.MainDispatcherRule
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
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import java.time.Clock
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneOffset

/** 記録保存と同時に体重・生理日も永続化する(iOS RecordEntryView パリティ)検証。 */
class RecordViewModelHealthSaveTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private val fixedClock = Clock.fixed(LocalDate.of(2026, 6, 14).atStartOfDay().toInstant(ZoneOffset.UTC), ZoneOffset.UTC)
    private val today = LocalDate.of(2026, 6, 14)

    private class FakeWorkoutRepo : WorkoutRepository {
        val saved = mutableListOf<WorkoutRecord>()
        override fun observeRecords(): Flow<List<WorkoutRecord>> = flowOf(emptyList())
        override suspend fun recordsInRange(start: LocalDate, end: LocalDate): List<WorkoutRecord> = emptyList()
        override suspend fun save(record: WorkoutRecord) { saved += record }
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
        var toggleCount = 0
        override val periodDays: Flow<Set<LocalDate>> = days
        override suspend fun toggle(date: LocalDate) {
            toggleCount++
            days.value = if (days.value.contains(date)) days.value - date else days.value + date
        }
        override suspend fun clearAll() { days.value = emptySet() }
        override suspend fun entriesOnce(): List<MenstrualEntryRecord> = emptyList()
        override suspend fun applyRemoteInsert(id: String, date: LocalDate, createdAtEpochMs: Long) {}
        override suspend fun applyRemoteDelete(id: String) {}
    }

    private class FakeHealthRepo(cycleEnabled: Boolean) : HealthRepository {
        override val prefs: Flow<HealthPrefs> = MutableStateFlow(HealthPrefs(cycleTrackingEnabled = cycleEnabled))
        override suspend fun setStartKgIfAbsent(kg: Double) {}
        override suspend fun setTargetKg(kg: Double?) {}
        override suspend fun setHeightCm(cm: Double?) {}
        override suspend fun setIsLossGoal(isLoss: Boolean) {}
        override suspend fun setCycleTrackingEnabled(enabled: Boolean) {}
        override suspend fun clearAll() {}
    }

    private fun vm(
        weight: FakeWeightRepo = FakeWeightRepo(),
        menstrual: FakeMenstrualRepo = FakeMenstrualRepo(),
        cycleEnabled: Boolean = true,
        workout: FakeWorkoutRepo = FakeWorkoutRepo(),
    ) = RecordViewModel(workout, weight, menstrual, FakeHealthRepo(cycleEnabled), fixedClock)

    private fun RecordViewModel.fillExercise() {
        val id = state.value.drafts.first().id
        updateDraft(id) { it.copy(name = "スクワット", reps = "10") }
    }

    @Test
    fun save_persistsWeight_whenEntered() = runTest {
        val weight = FakeWeightRepo()
        val vm = vm(weight = weight)
        vm.fillExercise()
        vm.setWeightInput("62.5")
        vm.save()
        assertEquals(listOf(62.5), weight.added)
    }

    @Test
    fun save_skipsWeight_whenBlank() = runTest {
        val weight = FakeWeightRepo()
        val vm = vm(weight = weight)
        vm.fillExercise()
        vm.save()
        assertTrue(weight.added.isEmpty())
    }

    @Test
    fun save_marksMenstrual_whenToggledOnAndNotYetMarked() = runTest {
        val menstrual = FakeMenstrualRepo(initial = emptySet())
        val vm = vm(menstrual = menstrual)
        vm.fillExercise()
        vm.setMenstrualToday(true)
        vm.save()
        assertTrue(menstrual.days.value.contains(today))
        assertEquals(1, menstrual.toggleCount)
    }

    @Test
    fun save_idempotent_whenAlreadyMarkedAndStillOn() = runTest {
        // 既に登録済みで ON のまま保存 → toggle しない(冪等 set。誤って解除しない)。
        val menstrual = FakeMenstrualRepo(initial = setOf(today))
        val vm = vm(menstrual = menstrual)
        vm.fillExercise()
        // init で menstrualToday は今日の登録状況(=true)に揃う。
        assertTrue(vm.state.value.menstrualToday)
        vm.save()
        assertTrue(menstrual.days.value.contains(today))
        assertEquals(0, menstrual.toggleCount)
    }

    @Test
    fun save_doesNotTouchMenstrual_whenCycleTrackingDisabled() = runTest {
        val menstrual = FakeMenstrualRepo(initial = emptySet())
        val vm = vm(menstrual = menstrual, cycleEnabled = false)
        vm.fillExercise()
        vm.setMenstrualToday(true) // UI 上は出ないが、保存ロジックが gate していることを確認
        vm.save()
        assertEquals(0, menstrual.toggleCount)
        assertFalse(menstrual.days.value.contains(today))
    }
}
