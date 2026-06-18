package com.goexercise.app.presentation.record

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.rescue.RescueTicketRepository
import com.goexercise.app.data.settings.SettingsRepository
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.CatState
import com.goexercise.app.domain.ExerciseItem
import com.goexercise.app.presentation.home.HomeStateReducer
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import java.time.Clock
import java.time.LocalDateTime
import javax.inject.Inject

/** 記録完了画面の状態(直近の連続日数 + 猫種 + 猫の状態 + 今日記録した種目)。 */
data class RecordCompletionUi(
    val streak: Int = 0,
    val breed: CatBreed = CatBreed.Default,
    val catState: CatState = CatState.Celebrating,
    /** 今日のサマリーカード用。直近(今日)の記録の種目リスト。iOS recordSummaryCard 相当。 */
    val exercises: List<ExerciseItem> = emptyList(),
    /** この保存で連続が「昨日から+1」伸びたか。streakHero に「きのうから +1 のばした！」を出す。iOS streakExtendedThisRun 相当。 */
    val streakExtendedThisRun: Boolean = false,
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
        val now = LocalDateTime.now(clock)
        val home = HomeStateReducer.reduce(records, now, rescuedDates = rescued, firstUseDate = firstUse)
        // 「今日保存した記録」のサマリー。observeRecords は日付降順なので今日の最初の1件を採る。
        val today = now.toLocalDate()
        val todaysExercises = records.firstOrNull { it.date == today }?.exercises ?: emptyList()
        // iOS streakExtendedThisRun = 「今日の最初の記録」かつ currentStreak>1。今日の記録が 1 件だけ =
        // この保存が今日の初記録 = 連続が伸びた。2 件目以降は既に今日カウント済みなので出さない。
        // currentStreak==1 は新規スタートなので出さない。
        val isFirstRecordToday = records.count { it.date == today } == 1
        val extended = isFirstRecordToday && home.streak.currentStreak > 1
        RecordCompletionUi(
            streak = home.streak.currentStreak, breed = breed, catState = home.catState,
            exercises = todaysExercises, streakExtendedThisRun = extended,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), RecordCompletionUi())
}
