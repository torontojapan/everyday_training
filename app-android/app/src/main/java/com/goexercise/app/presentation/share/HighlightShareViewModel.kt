package com.goexercise.app.presentation.share

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.rescue.RescueTicketRepository
import com.goexercise.app.data.settings.SettingsRepository
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.MonthlyReviewBuilder
import com.goexercise.app.share.HighlightShareImageRenderer
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import androidx.lifecycle.viewModelScope
import java.time.Clock
import java.time.LocalDate
import javax.inject.Inject

/** ハイライト共有画面の状態(集計済み Review + 種別 + 猫種)。null=計算中。 */
data class HighlightShareUi(
    val review: MonthlyReviewBuilder.Review? = null,
    val kind: HighlightShareImageRenderer.Kind = HighlightShareImageRenderer.Kind.Weekly,
    val breed: CatBreed = CatBreed.Default,
    val streakLabel: String = "今週の最長連続",
)

/**
 * ハイライト共有画面の VM。nav 引数 `kind`(weekly/monthly/alltime)に応じて
 * [MonthlyReviewBuilder] で当該期間の Review を算出し、猫種と合わせて公開する。
 * 画像生成は [HighlightShareImageRenderer]。
 */
@HiltViewModel
class HighlightShareViewModel @Inject constructor(
    repository: WorkoutRepository,
    rescueTickets: RescueTicketRepository,
    settings: SettingsRepository,
    private val clock: Clock,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val kind: HighlightShareImageRenderer.Kind =
        when (savedStateHandle.get<String>("kind")?.lowercase()) {
            "monthly" -> HighlightShareImageRenderer.Kind.Monthly
            "alltime" -> HighlightShareImageRenderer.Kind.AllTime
            else -> HighlightShareImageRenderer.Kind.Weekly
        }

    private val streakLabel: String = when (kind) {
        HighlightShareImageRenderer.Kind.Weekly -> "今週の最長連続"
        HighlightShareImageRenderer.Kind.Monthly -> "今月の最長連続"
        HighlightShareImageRenderer.Kind.AllTime -> "最長連続"
    }

    val state: StateFlow<HighlightShareUi> = combine(
        repository.observeRecords(),
        rescueTickets.rescuedDates,
        settings.catBreed,
    ) { records, rescued, breed ->
        val today = LocalDate.now(clock)
        val review = when (kind) {
            HighlightShareImageRenderer.Kind.Weekly ->
                MonthlyReviewBuilder.weekly(records, weekContaining = today, today = today, rescuedDates = rescued)
            HighlightShareImageRenderer.Kind.Monthly ->
                MonthlyReviewBuilder.build(records, month = today, today = today, rescuedDates = rescued)
            HighlightShareImageRenderer.Kind.AllTime ->
                MonthlyReviewBuilder.lifetime(records, today = today, rescuedDates = rescued)
        }
        HighlightShareUi(review = review, kind = kind, breed = breed, streakLabel = streakLabel)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), HighlightShareUi(kind = kind, streakLabel = streakLabel))
}
