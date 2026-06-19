package com.goexercise.app.presentation.share

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.rescue.RescueTicketRepository
import com.goexercise.app.data.settings.SettingsRepository
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.presentation.home.HomeStateReducer
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.LocalDateTime
import javax.inject.Inject

/** シェア画面の状態(現在の連続日数 + 猫種 + 背景グラデ選択)。 */
data class StreakShareUi(
    val streak: Int = 0,
    val breed: CatBreed = CatBreed.Default,
    // 連続カード既定は Ocean(iOS shareCard.gradient.streak=.ocean パリティ)。flow 確定までの初期値も合わせる。
    val gradient: com.goexercise.app.domain.ShareCardGradient = com.goexercise.app.domain.ShareCardGradient.Ocean,
)

/**
 * マイルストーン シェア画面の VM。現在の連続日数を [HomeStateReducer](純粋・テスト済)で算出し、
 * 猫種と合わせて公開する。シェア画像の生成自体は [com.goexercise.app.share.StreakShareImageRenderer]。
 */
@HiltViewModel
class StreakShareViewModel @Inject constructor(
    repository: WorkoutRepository,
    rescueTickets: RescueTicketRepository,
    private val settings: SettingsRepository,
    private val clock: Clock,
) : ViewModel() {

    val state: StateFlow<StreakShareUi> = combine(
        repository.observeRecords(),
        rescueTickets.rescuedDates,
        settings.firstUseDate,
        settings.catBreed,
        settings.shareGradient,
    ) { records, rescued, firstUse, breed, gradient ->
        val home = HomeStateReducer.reduce(records, LocalDateTime.now(clock), rescuedDates = rescued, firstUseDate = firstUse)
        StreakShareUi(streak = home.streak.currentStreak, breed = breed, gradient = gradient)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), StreakShareUi())

    fun setGradient(gradient: com.goexercise.app.domain.ShareCardGradient) {
        viewModelScope.launch { settings.setShareGradient(gradient) }
    }
}
