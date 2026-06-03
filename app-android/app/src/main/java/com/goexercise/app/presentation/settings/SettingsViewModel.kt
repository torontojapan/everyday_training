package com.goexercise.app.presentation.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.analytics.Analytics
import com.goexercise.app.analytics.AnalyticsEvent
import com.goexercise.app.data.DataManagementRepository
import com.goexercise.app.data.billing.PremiumRepository
import com.goexercise.app.data.settings.NotificationPrefsRepository
import com.goexercise.app.data.settings.ReminderPrefs
import com.goexercise.app.data.settings.SettingsRepository
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.notification.ReminderScheduler
import com.goexercise.app.ui.theme.AppTheme
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Clock
import javax.inject.Inject

/** 設定の VM。テーマ/猫/プレミアム + データ管理(エクスポート/全削除)。ルートの App() と共有。 */
@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val repository: SettingsRepository,
    premium: PremiumRepository,
    private val dataManagement: DataManagementRepository,
    private val notificationPrefs: NotificationPrefsRepository,
    private val reminderScheduler: ReminderScheduler,
    private val clock: Clock,
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

    /** 毎日のリマインダー設定(ON/OFF + 時刻)。 */
    val reminder: StateFlow<ReminderPrefs> = notificationPrefs.prefs
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ReminderPrefs())

    /** リマインダーを設定(保存 + AlarmManager 予約/解除)。enabled=true は通知権限取得後に呼ぶこと。 */
    fun setReminder(enabled: Boolean, hour: Int, minute: Int) {
        viewModelScope.launch {
            notificationPrefs.set(enabled, hour, minute)
            if (enabled) reminderScheduler.schedule(hour, minute) else reminderScheduler.cancel()
        }
    }

    /** データ管理処理中(エクスポート/削除)。連打ガード + UI スピナー。 */
    private val _isBusy = MutableStateFlow(false)
    val isBusy: StateFlow<Boolean> = _isBusy.asStateFlow()

    /** 全記録を JSON 文字列にして返す(画面側でファイル化+共有)。 */
    fun exportData(onReady: (String) -> Unit) {
        if (_isBusy.value) return
        _isBusy.value = true
        viewModelScope.launch {
            try {
                onReady(dataManagement.exportJson(clock.instant()))
                Analytics.track(AnalyticsEvent.DataExported)
            } finally {
                _isBusy.value = false
            }
        }
    }

    /** 運動/体重/体調の全記録を削除(課金状態は対象外)。 */
    fun deleteAllRecords(onDone: (Int) -> Unit = {}) {
        if (_isBusy.value) return
        _isBusy.value = true
        viewModelScope.launch {
            try {
                onDone(dataManagement.deleteAllRecords())
                Analytics.track(AnalyticsEvent.DataDeleted)
            } finally {
                _isBusy.value = false
            }
        }
    }
}
