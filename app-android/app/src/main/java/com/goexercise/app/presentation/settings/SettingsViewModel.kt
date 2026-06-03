package com.goexercise.app.presentation.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.settings.SettingsRepository
import com.goexercise.app.ui.theme.AppTheme
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/** 設定の VM。テーマの購読/更新。ルートの App() とも共有(同一 DataStore Flow で同期)。 */
@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val repository: SettingsRepository,
) : ViewModel() {

    val theme: StateFlow<AppTheme> = repository.theme
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), AppTheme.Peach)

    fun setTheme(theme: AppTheme) {
        viewModelScope.launch { repository.setTheme(theme) }
    }
}
