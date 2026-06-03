package com.goexercise.app.presentation.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.WorkoutRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import java.time.Clock
import java.time.LocalDateTime
import javax.inject.Inject

/**
 * ホームの UDF ViewModel。repo の `Flow<List<WorkoutRecord>>` を [HomeStateReducer] で
 * [HomeUiState] に畳み込み StateFlow で公開する(iOS `@Observable HomeViewModel` に対応)。
 * 集計ロジックは reducer(純粋)に隔離してあるので、ここは配線のみ。
 */
@HiltViewModel
class HomeViewModel @Inject constructor(
    repository: WorkoutRepository,
    private val clock: Clock,
) : ViewModel() {

    val uiState: StateFlow<HomeUiState> = repository.observeRecords()
        .map { records -> HomeStateReducer.reduce(records, LocalDateTime.now(clock)) }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = HomeUiState(),
        )
}
