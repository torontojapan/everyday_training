package com.goexercise.app.presentation.history

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.domain.MonthlyCalendarCalculator
import com.goexercise.app.domain.MonthlyCalendarCalculator.MonthCell
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import java.time.Clock
import java.time.LocalDate
import java.time.YearMonth
import javax.inject.Inject

data class HistoryUiState(
    val month: YearMonth,
    val cells: List<MonthCell> = emptyList(),
    val achievedDays: Int = 0,
)

/** 履歴(月カレンダー)の VM。記録 Flow × 選択月 → 月グリッド。 */
@HiltViewModel
class HistoryViewModel @Inject constructor(
    repository: WorkoutRepository,
    private val clock: Clock,
) : ViewModel() {

    private val selectedMonth = MutableStateFlow(YearMonth.now(clock))

    val uiState: StateFlow<HistoryUiState> =
        combine(repository.observeRecords(), selectedMonth, todayTicker()) { records, month, today ->
            val cells = MonthlyCalendarCalculator.cells(month, records, today)
            HistoryUiState(month, cells, MonthlyCalendarCalculator.achievedDaysInMonth(cells))
        }.stateIn(
            viewModelScope,
            SharingStarted.WhileSubscribed(5_000),
            HistoryUiState(YearMonth.now(clock)),
        )

    fun prevMonth() = selectedMonth.update { it.minusMonths(1) }
    fun nextMonth() = selectedMonth.update { it.plusMonths(1) }

    /** 購読中、現在日付を 1 分ごとに発火(日付が変わった時のみ下流再計算)。 */
    private fun todayTicker() = flow {
        while (true) {
            emit(LocalDate.now(clock))
            delay(60_000)
        }
    }.distinctUntilChanged()
}
