package com.goexercise.app.presentation.record

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.rescue.RescueTicketRepository
import com.goexercise.app.data.settings.SettingsRepository
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.CatState
import com.goexercise.app.presentation.home.HomeStateReducer
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import java.time.Clock
import java.time.LocalDateTime
import javax.inject.Inject

/** 記録完了画面の状態(直近の連続日数 + 猫種 + 猫の状態)。 */
data class RecordCompletionUi(
    val streak: Int = 0,
    val breed: CatBreed = CatBreed.Default,
    val catState: CatState = CatState.Celebrating,
)

/**
 * 記録完了画面の VM。保存直後の連続日数/猫種/状態を [HomeStateReducer](純粋・テスト済)で算出する。
 * iOS RecordCompletionView が記録後に表示する祝福のデータ供給に対応。
 */
@HiltViewModel
class RecordCompletionViewModel @Inject constructor(
    repository: WorkoutRepository,
    rescueTickets: RescueTicketRepository,
    settings: SettingsRepository,
    private val clock: Clock,
) : ViewModel() {

    val state: StateFlow<RecordCompletionUi> = combine(
        repository.observeRecords(),
        rescueTickets.rescuedDates,
        settings.firstUseDate,
        settings.catBreed,
    ) { records, rescued, firstUse, breed ->
        val home = HomeStateReducer.reduce(records, LocalDateTime.now(clock), rescuedDates = rescued, firstUseDate = firstUse)
        RecordCompletionUi(streak = home.streak.currentStreak, breed = breed, catState = home.catState)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), RecordCompletionUi())
}
