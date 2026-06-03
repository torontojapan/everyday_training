package com.goexercise.app.presentation.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.billing.PremiumRepository
import com.goexercise.app.data.settings.SettingsRepository
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.ui.theme.AppTheme
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/** 設定の VM。テーマの購読/更新 + プレミアム加入状態。ルートの App() とも共有(同一 DataStore Flow で同期)。 */
@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val repository: SettingsRepository,
    premium: PremiumRepository,
) : ViewModel() {

    val theme: StateFlow<AppTheme> = repository.theme
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), AppTheme.Peach)

    /** GOプレミアム加入状態(設定の課金カード表示用)。 */
    val isPremium: StateFlow<Boolean> = premium.isPremiumActive

    /** 選択中の猫種(猫ピッカー用)。 */
    val catBreed: StateFlow<CatBreed> = repository.catBreed
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), CatBreed.Default)

    fun setTheme(theme: AppTheme) {
        viewModelScope.launch { repository.setTheme(theme) }
    }

    fun setCatBreed(breed: CatBreed) {
        viewModelScope.launch { repository.setCatBreed(breed) }
    }
}
