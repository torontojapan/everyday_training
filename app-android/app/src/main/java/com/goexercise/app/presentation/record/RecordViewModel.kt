package com.goexercise.app.presentation.record

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.domain.WorkoutCategory
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.LocalDate
import javax.inject.Inject

/**
 * 記録入力の ViewModel。iOS `RecordEntryViewModel` の移植(体重/種目サジェストは後続)。
 * フォーム状態は Compose の snapshot state(mutableStateOf)で保持し、保存で repo に書く。
 */
@HiltViewModel
class RecordViewModel @Inject constructor(
    private val repository: WorkoutRepository,
    private val clock: Clock,
) : ViewModel() {

    var state by mutableStateOf(RecordUiState())
        private set

    fun setCategory(category: WorkoutCategory) {
        state = state.copy(category = category)
    }

    fun setMemo(memo: String) {
        state = state.copy(memo = memo)
    }

    fun updateDraft(id: String, transform: (ExerciseDraft) -> ExerciseDraft) {
        state = state.copy(drafts = state.drafts.map { if (it.id == id) transform(it) else it })
    }

    fun addExercise() {
        state = state.copy(drafts = state.drafts + ExerciseDraft())
    }

    fun removeExercise(id: String) {
        if (state.drafts.size <= 1) return // 最低 1 行は残す(iOS と同じ)
        state = state.copy(drafts = state.drafts.filterNot { it.id == id })
    }

    /** 保存。成功すると state.saved=true(画面が戻る)。有効種目が無ければ何もしない。 */
    fun save() {
        val record = state.toRecord(LocalDate.now(clock)) ?: return
        viewModelScope.launch {
            repository.save(record)
            state = state.copy(saved = true)
        }
    }
}
