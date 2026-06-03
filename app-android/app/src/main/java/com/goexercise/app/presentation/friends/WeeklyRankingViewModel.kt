package com.goexercise.app.presentation.friends

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.friends.FriendsService
import com.goexercise.app.domain.friends.FriendProfile
import com.goexercise.app.domain.friends.RankingPeriod
import com.goexercise.app.domain.friends.WeeklyRankingCalculator
import com.goexercise.app.domain.friends.WeeklyRankingEntry
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class RankingUiState(
    val period: RankingPeriod = RankingPeriod.Weekly,
    val entries: List<WeeklyRankingEntry> = emptyList(),
    val isLoading: Boolean = true,
) {
    val myEntry: WeeklyRankingEntry? get() = entries.firstOrNull { it.isMe }
}

/**
 * 週間/月間ランキング画面の VM。iOS `WeeklyRankingView` の集計部分を移植。
 * [FriendsService] は @Singleton なので FriendsViewModel と同一バックエンドを共有する(読み取り専用)。
 */
@HiltViewModel
class WeeklyRankingViewModel @Inject constructor(
    private val service: FriendsService,
) : ViewModel() {

    private var me: FriendProfile? = null
    private var friends: List<FriendProfile> = emptyList()

    private val _uiState = MutableStateFlow(RankingUiState())
    val uiState: StateFlow<RankingUiState> = _uiState.asStateFlow()

    init { load() }

    private fun load() {
        viewModelScope.launch {
            runCatching {
                me = service.myProfile()
                friends = service.refreshFriends()
            }
            recompute()
        }
    }

    fun setPeriod(period: RankingPeriod) {
        _uiState.update { it.copy(period = period) }
        recompute()
    }

    private fun recompute() {
        val period = _uiState.value.period
        // 自分の週次が未設定なら false×7 で埋める(iOS WeeklyRankingView と同じ)。
        val meFilled = me?.let {
            if (it.weeklyAchievements == null) it.copy(weeklyAchievements = List(7) { false }) else it
        }
        _uiState.update {
            it.copy(entries = WeeklyRankingCalculator.rank(friends, meFilled, period), isLoading = false)
        }
    }
}
