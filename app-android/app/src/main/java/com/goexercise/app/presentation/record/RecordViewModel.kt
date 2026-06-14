package com.goexercise.app.presentation.record

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.analytics.Analytics
import com.goexercise.app.analytics.AnalyticsEvent
import com.goexercise.app.data.WeightRepository
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.settings.HealthRepository
import com.goexercise.app.data.settings.MenstrualRepository
import com.goexercise.app.domain.WorkoutCategory
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.LocalDate
import java.time.LocalDateTime
import javax.inject.Inject

/**
 * 記録入力の ViewModel。iOS `RecordEntryViewModel` の移植(体重/種目サジェストは後続)。
 * 状態は StateFlow(UDF 一貫性)。保存完了は **one-shot イベント**(Channel)で 1 回だけ発火し、
 * 構成変更で再 pop しない。保存中は isSaving でガード(二重保存防止)、失敗は errorMessage。
 */
@HiltViewModel
class RecordViewModel @Inject constructor(
    private val repository: WorkoutRepository,
    private val weightRepository: WeightRepository,
    private val menstrualRepository: MenstrualRepository,
    private val health: HealthRepository,
    private val clock: Clock,
) : ViewModel() {

    private val _state = MutableStateFlow(RecordUiState())
    val state: StateFlow<RecordUiState> = _state.asStateFlow()

    private val _saved = Channel<Unit>(Channel.BUFFERED)
    val saved = _saved.receiveAsFlow()

    /** カテゴリ別「よく使う種目」候補(最終使用日順)。記録入力の横スクロールチップ用(iOS パリティ)。 */
    val suggestionsByCategory: StateFlow<Map<WorkoutCategory, List<String>>> =
        repository.observeRecords()
            .map { records ->
                WorkoutCategory.entries.associateWith { cat ->
                    com.goexercise.app.domain.ExerciseHistoryProvider.topExerciseNames(records, cat, limit = 8)
                }
            }
            .stateIn(viewModelScope, kotlinx.coroutines.flow.SharingStarted.WhileSubscribed(5_000), emptyMap())

    init {
        // 周期トラッキング設定と直近体重を購読(生理日トグルの表示可否・体重ヒント)。
        viewModelScope.launch {
            health.prefs.map { it.cycleTrackingEnabled }.collect { enabled ->
                _state.update { it.copy(cycleTrackingEnabled = enabled) }
            }
        }
        viewModelScope.launch {
            weightRepository.observeEntries().collect { entries ->
                _state.update { it.copy(latestWeightKg = entries.maxByOrNull { e -> e.recordedAt }?.weightKg) }
            }
        }
        // 生理日トグルの初期値を今日の登録状況に合わせる(既登録なら ON 表示=保存で誤って消さない)。
        viewModelScope.launch {
            val today = LocalDate.now(clock)
            val marked = runCatching { menstrualRepository.periodDays.first().contains(today) }.getOrDefault(false)
            _state.update { it.copy(menstrualToday = marked) }
        }
    }

    fun setCategory(id: String, category: WorkoutCategory) =
        updateDraft(id) { it.copy(category = category) }

    fun setMemo(memo: String) = _state.update { it.copy(memo = memo) }

    /** 今日の体重入力(kg・小数可)。空=未入力(保存しない)。 */
    fun setWeightInput(text: String) = _state.update { it.copy(weightInput = RecordUiState.clampDecimal(text)) }

    /** 「今日は生理日」トグル。 */
    fun setMenstrualToday(on: Boolean) = _state.update { it.copy(menstrualToday = on) }

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
        val copy = ExerciseDraft(name = src.name, category = src.category, loadText = src.loadText)
        s.copy(drafts = s.drafts.toMutableList().apply { add(index + 1, copy) })
    }

    /** 保存。保存中は無視(二重実行ガード)。成功で one-shot イベント、失敗で errorMessage。 */
    fun save() {
        val current = _state.value
        if (current.isSaving) return
        val record = current.toRecord(LocalDate.now(clock)) ?: return
        _state.update { it.copy(isSaving = true, errorMessage = null) }
        viewModelScope.launch {
            runCatching {
                repository.save(record)
                // 同じ保存操作で体重・生理日も永続化(iOS RecordEntryView パリティ)。
                current.parsedWeightKg?.let { weightRepository.add(LocalDateTime.now(clock), it, null) }
                if (current.cycleTrackingEnabled) {
                    val today = LocalDate.now(clock)
                    // トグルの状態に合わせて冪等に設定(差があるときだけ toggle=iOS set(_:on:) 相当)。
                    val marked = menstrualRepository.periodDays.first().contains(today)
                    if (current.menstrualToday != marked) menstrualRepository.toggle(today)
                }
            }
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
