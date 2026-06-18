package com.goexercise.app.presentation.history

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.rescue.RescueTicketRepository
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
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.LocalDate
import java.time.YearMonth
import javax.inject.Inject

data class HistoryUiState(
    val month: YearMonth,
    val cells: List<MonthCell> = emptyList(),
    val achievedDays: Int = 0,
    /** 日セルタップ時の詳細シートで「その日の記録」を引くための全記録。 */
    val records: List<com.goexercise.app.domain.WorkoutRecord> = emptyList(),
    /** 生理日(履歴カレンダーに ★ を出す)。iOS パリティ。 */
    val periodDays: Set<LocalDate> = emptySet(),
    /** 周期トラッキング有効時のみ、日詳細から過去日を含む生理日トグルを出す。 */
    val cycleTrackingEnabled: Boolean = false,
    /** 保険チケット: 今月の残数 / 付与枠(無料1・プレミアム4 + 紹介ボーナス)/ プレミアム状態。iOS 折りたたみ subtitle・訴求用。 */
    val rescueRemaining: Int = 0,
    val rescueAllowance: Int = 1,
    val isPremium: Boolean = false,
)

/** 履歴(月カレンダー)の VM。記録 Flow × 選択月 → 月グリッド。 */
@HiltViewModel
class HistoryViewModel @Inject constructor(
    repository: WorkoutRepository,
    rescueTickets: RescueTicketRepository,
    premium: com.goexercise.app.data.billing.PremiumRepository,
    referralStore: com.goexercise.app.data.referral.ReferralStore,
    private val menstrual: com.goexercise.app.data.settings.MenstrualRepository,
    health: com.goexercise.app.data.settings.HealthRepository,
    private val clock: Clock,
) : ViewModel() {

    private val selectedMonth = MutableStateFlow(YearMonth.now(clock))

    /** 生理日/周期/プレミアム/紹介ボーナスを 1 つに束ねて top-level combine を 5 引数に収める。 */
    private data class HistoryExtras(
        val periodDays: Set<LocalDate>, val cycleEnabled: Boolean, val isPremium: Boolean, val freezeBonus: Int,
    )

    val uiState: StateFlow<HistoryUiState> =
        combine(
            repository.observeRecords(),
            selectedMonth,
            todayTicker(),
            rescueTickets.rescuedDates,
            combine(menstrual.periodDays, health.prefs, premium.isPremiumActive, referralStore.currentAccountFreezeBonus) { days, prefs, prem, bonus ->
                HistoryExtras(days, prefs.cycleTrackingEnabled, prem, bonus)
            },
        ) { records, month, today, rescued, extras ->
            val cells = MonthlyCalendarCalculator.cells(month, records, today, rescued)
            // iOS と同じ付与枠/残数(無料1・プレミアム4 + 紹介ボーナス)。
            val allowance = com.goexercise.app.domain.RescueTicketAllowance.current(extras.isPremium, extras.freezeBonus)
            val remaining = com.goexercise.app.domain.RescueTicketLogic.remaining(rescued, today, allowance)
            HistoryUiState(
                month, cells, MonthlyCalendarCalculator.achievedDaysInMonth(cells), records,
                extras.periodDays, extras.cycleEnabled,
                rescueRemaining = remaining, rescueAllowance = allowance, isPremium = extras.isPremium,
            )
        }.stateIn(
            viewModelScope,
            SharingStarted.WhileSubscribed(5_000),
            HistoryUiState(YearMonth.now(clock)),
        )

    fun prevMonth() = selectedMonth.update { it.minusMonths(1) }
    fun nextMonth() = selectedMonth.update { it.plusMonths(1) }

    /** 指定日(過去日を含む)の生理日登録/解除。iOS MenstrualEntryView パリティ。 */
    fun toggleMenstrual(date: LocalDate) {
        viewModelScope.launch { menstrual.toggle(date) }
    }

    /** 購読中、現在日付を 1 分ごとに発火(日付が変わった時のみ下流再計算)。 */
    private fun todayTicker() = flow {
        while (true) {
            emit(LocalDate.now(clock))
            delay(60_000)
        }
    }.distinctUntilChanged()
}
