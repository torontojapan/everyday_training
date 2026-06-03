package com.goexercise.app.presentation.rescue

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.rescue.RescueTicketRepository
import com.goexercise.app.domain.MonthlyCalendarCalculator
import com.goexercise.app.domain.MonthlyCalendarCalculator.MonthCell
import com.goexercise.app.domain.RescueTicketAllowance
import com.goexercise.app.domain.RescueTicketLogic
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.LocalDate
import java.time.YearMonth
import javax.inject.Inject

data class RescueUiState(
    val month: YearMonth,
    val cells: List<MonthCell> = emptyList(),
    val remaining: Int = 0,
    val allowance: Int = 1,
)

/**
 * 連続記録フリーズ(保険チケット)使用画面の VM。iOS RescueTicketUseView 相当。
 * 月カレンダーの「未達成(missed)」日をタップで消費する。付与枠は当面 無料=月1
 * (課金実装後に isPremium で月4へ。TODO)。
 */
@HiltViewModel
class RescueViewModel @Inject constructor(
    workoutRepository: WorkoutRepository,
    private val rescue: RescueTicketRepository,
    private val clock: Clock,
) : ViewModel() {

    // TODO(P1c 課金接続): RescueTicketAllowance.current(isPremium) に差し替え。
    private val allowance = RescueTicketAllowance.current(isPremium = false)
    private val selectedMonth = MutableStateFlow(YearMonth.now(clock))

    val uiState: StateFlow<RescueUiState> =
        combine(workoutRepository.observeRecords(), rescue.rescuedDates, selectedMonth) { records, rescued, month ->
            val today = LocalDate.now(clock)
            val cells = MonthlyCalendarCalculator.cells(month, records, today, rescued)
            RescueUiState(
                month = month,
                cells = cells,
                remaining = RescueTicketLogic.remaining(rescued, today, allowance),
                allowance = allowance,
            )
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), RescueUiState(YearMonth.now(clock)))

    /** missed 日をフリーズで救済。枠切れ/対象外は no-op(repo が判定)。 */
    fun useTicket(date: LocalDate) {
        viewModelScope.launch { rescue.useTicket(date, allowance) }
    }

    fun prevMonth() = selectedMonth.update { it.minusMonths(1) }
    fun nextMonth() = selectedMonth.update { it.plusMonths(1) }
}
