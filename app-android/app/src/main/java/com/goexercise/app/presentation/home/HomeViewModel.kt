package com.goexercise.app.presentation.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.settings.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.LocalDate
import java.time.LocalDateTime
import javax.inject.Inject

/**
 * ホームの UDF ViewModel。repo の `Flow<List<WorkoutRecord>>` を [HomeStateReducer] で
 * [HomeUiState] に畳み込み StateFlow で公開する(iOS `@Observable HomeViewModel` に対応)。
 * 記録の変化に加え、1 分ごとの ticker で再計算し**日跨ぎ/時間帯変化**を反映する
 * (猫状態は時刻依存、today 判定は日付依存のため)。集計は reducer(純粋)に隔離。
 */
@HiltViewModel
class HomeViewModel @Inject constructor(
    repository: WorkoutRepository,
    private val settings: SettingsRepository,
    private val clock: Clock,
) : ViewModel() {

    init {
        // 初回利用日を一度だけ確定(以後不変)。iOS LifetimeUsageTracker と同じ起点。
        viewModelScope.launch { settings.setFirstUseDateIfAbsent(LocalDate.now(clock)) }
    }

    val uiState: StateFlow<HomeUiState> =
        combine(repository.observeRecords(), minuteTicker(), settings.firstUseDate) { records, _, firstUse ->
            HomeStateReducer.reduce(records, LocalDateTime.now(clock), firstUseDate = firstUse)
        }.stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = HomeUiState(),
        )

    /** 購読中だけ 1 分ごとに発火(WhileSubscribed が非表示時に停止)。日跨ぎ/時間帯変化の再計算用。 */
    private fun minuteTicker() = flow {
        while (true) {
            emit(Unit)
            delay(60_000)
        }
    }
}
