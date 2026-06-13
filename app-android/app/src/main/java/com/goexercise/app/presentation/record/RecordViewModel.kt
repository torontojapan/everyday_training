package com.goexercise.app.presentation.record

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.analytics.Analytics
import com.goexercise.app.analytics.AnalyticsEvent
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.domain.WorkoutCategory
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.LocalDate
import javax.inject.Inject

/**
 * 記録入力の ViewModel。iOS `RecordEntryViewModel` の移植(体重/種目サジェストは後続)。
 * 状態は StateFlow(UDF 一貫性)。保存完了は **one-shot イベント**(Channel)で 1 回だけ発火し、
 * 構成変更で再 pop しない。保存中は isSaving でガード(二重保存防止)、失敗は errorMessage。
 */
@HiltViewModel
class RecordViewModel @Inject constructor(
    private val repository: WorkoutRepository,
    private val clock: Clock,
) : ViewModel() {

    private val _state = MutableStateFlow(RecordUiState())
    val state: StateFlow<RecordUiState> = _state.asStateFlow()

    private val _saved = Channel<Unit>(Channel.BUFFERED)
    val saved = _saved.receiveAsFlow()

    fun setCategory(id: String, category: WorkoutCategory) =
        updateDraft(id) { it.copy(category = category) }

    fun setMemo(memo: String) = _state.update { it.copy(memo = memo) }

    fun updateDraft(id: String, transform: (ExerciseDraft) -> ExerciseDraft) =
        _state.update { s -> s.copy(drafts = s.drafts.map { if (it.id == id) transform(it) else it }) }

    fun addExercise() = _state.update { s ->
        // 直前種目のカテゴリを引き継ぐ(同カテゴリ連続入力が多いため。iOS と同じ)。
        s.copy(drafts = s.drafts + ExerciseDraft(category = s.drafts.lastOrNull()?.category ?: WorkoutCategory.Strength))
    }

    fun removeExercise(id: String) = _state.update { s ->
        if (s.drafts.size <= 1) s else s.copy(drafts = s.drafts.filterNot { it.id == id })
    }

    /**
     * 「+ 同じ種目でセットを追加」: 指定行の名前・カテゴリ・重さ(reps/sets/minutes は引き継がず
     * セットごとに入れ直す前提で空)を引き継いだ新しい行を直下に複製する。iOS addSet(after:) 相当。
     * 重さ違いの複数セットを種目選び直しなしで記録できる。
     */
    fun addSet(id: String) = _state.update { s ->
        val index = s.drafts.indexOfFirst { it.id == id }
        if (index < 0) return@update s
        val src = s.drafts[index]
        val copy = ExerciseDraft(name = src.name, category = src.category)
        s.copy(drafts = s.drafts.toMutableList().apply { add(index + 1, copy) })
    }

    /** 保存。保存中は無視(二重実行ガード)。成功で one-shot イベント、失敗で errorMessage。 */
    fun save() {
        val current = _state.value
        if (current.isSaving) return
        val record = current.toRecord(LocalDate.now(clock)) ?: return
        _state.update { it.copy(isSaving = true, errorMessage = null) }
        viewModelScope.launch {
            runCatching { repository.save(record) }
                .onSuccess {
                    _state.update { it.copy(isSaving = false) }
                    val category = current.drafts.firstOrNull()?.category?.name ?: "unknown"
                    Analytics.track(AnalyticsEvent.RecordCreated(category))
                    _saved.send(Unit)
                }
                .onFailure { e ->
                    _state.update { it.copy(isSaving = false, errorMessage = "保存に失敗しました。もう一度お試しください。") }
                }
        }
    }
}
