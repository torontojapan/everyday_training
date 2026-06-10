package com.goexercise.app.presentation.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.analytics.Analytics
import com.goexercise.app.analytics.AnalyticsEvent
import com.goexercise.app.data.referral.ReferralStore
import com.goexercise.app.data.settings.SettingsRepository
import com.goexercise.app.domain.CatBreed
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * オンボーディングの完了判定 + 確定。`isComplete` は **null=未判定**(DataStore 読込前のチラつき防止)。
 */
@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val settings: SettingsRepository,
    private val referralStore: ReferralStore,
) : ViewModel() {

    /** null=判定中 / false=未完了(オンボ表示) / true=完了(本編)。 */
    val isComplete: StateFlow<Boolean?> = settings.onboardingComplete
        .map<Boolean, Boolean?> { it }
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)

    private val _inviteCode = MutableStateFlow("")
    val inviteCode: StateFlow<String> = _inviteCode
    private val _inviteSubmitting = MutableStateFlow(false)
    val inviteSubmitting: StateFlow<Boolean> = _inviteSubmitting
    private val _inviteAccepted = MutableStateFlow(false)
    val inviteAccepted: StateFlow<Boolean> = _inviteAccepted
    val inviteError get() = referralStore.lastError

    fun onInviteCodeChange(v: String) { _inviteCode.value = v }
    fun submitInvite() {
        _inviteSubmitting.value = true
        referralStore.clearError()
        viewModelScope.launch {
            val ok = referralStore.submitCode(_inviteCode.value)
            _inviteSubmitting.value = false
            if (ok) _inviteAccepted.value = true
        }
    }

    /** 選んだ猫を保存してオンボーディングを完了する。 */
    fun complete(breed: CatBreed) {
        viewModelScope.launch {
            settings.setCatBreed(breed)
            settings.setOnboardingComplete()
            Analytics.track(AnalyticsEvent.OnboardingCompleted)
        }
    }
}
