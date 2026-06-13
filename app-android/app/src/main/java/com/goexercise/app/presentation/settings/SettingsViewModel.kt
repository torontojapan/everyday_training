package com.goexercise.app.presentation.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.analytics.Analytics
import com.goexercise.app.analytics.AnalyticsEvent
import com.goexercise.app.data.DataManagementRepository
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.billing.PremiumRepository
import com.goexercise.app.data.rescue.RescueTicketRepository
import com.goexercise.app.data.settings.NotificationPrefsRepository
import com.goexercise.app.data.settings.ReminderPrefs
import com.goexercise.app.data.settings.SettingsRepository
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.CatBreedAccess
import com.goexercise.app.domain.StreakCalculator
import com.goexercise.app.notification.ReminderScheduler
import com.goexercise.app.ui.theme.AppTheme
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Clock
import java.time.LocalDate
import javax.inject.Inject

/** 設定の VM。テーマ/猫/プレミアム + データ管理(エクスポート/全削除)。ルートの App() と共有。 */
@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val repository: SettingsRepository,
    premium: PremiumRepository,
    private val dataManagement: DataManagementRepository,
    private val notificationPrefs: NotificationPrefsRepository,
    private val reminderScheduler: ReminderScheduler,
    workoutRepository: WorkoutRepository,
    rescueTickets: RescueTicketRepository,
    private val clock: Clock,
    private val referralStore: com.goexercise.app.data.referral.ReferralStore,
    private val friendsService: com.goexercise.app.data.friends.FriendsService,
    private val recordSync: com.goexercise.app.data.backup.RecordSyncCoordinator,
    private val health: com.goexercise.app.data.settings.HealthRepository,
) : ViewModel() {

    /** 生理周期トラッキングのオプトイン状態(既定 OFF)。ON で体重タブに生理日記録 UI を出す。 */
    val cycleTrackingEnabled: StateFlow<Boolean> = health.prefs
        .map { it.cycleTrackingEnabled }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    fun setCycleTrackingEnabled(on: Boolean) {
        viewModelScope.launch { health.setCycleTrackingEnabled(on) }
    }

    /** 現在の連続記録(称号一覧の現在地「いま」/次目標「あとN日」表示用)。
     *  記録 + 保険救済日から StreakCalculator で算出。Home と同一の寛容判定。 */
    val currentStreak: StateFlow<Int> = combine(
        workoutRepository.observeRecords(),
        rescueTickets.rescuedDates,
    ) { records, rescued ->
        StreakCalculator.currentStreak(records, LocalDate.now(clock), rescued)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), 0)

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
        // 課金/紹介ゲート(UI迂回時の多層防御): 非プレミアムかつ紹介⭐<10 は「今の猫」以外に変更できない。
        val unlocked = CatBreedAccess.referralUnlocked(referralSummary.value.starBadges)
        if (CatBreedAccess.isLocked(breed, catBreed.value, isPremium.value, unlocked)) return
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

    /** 匿名の利用状況分析(TelemetryDeck)を共有するか。既定 true(匿名 ON)。設定でオプトアウト可。 */
    val analyticsEnabled: StateFlow<Boolean> = repository.analyticsEnabled
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), true)

    /** 分析共有の ON/OFF。永続化 + 即時に送信ゲートを反映(App 側の購読も拾うがラグを無くす)。 */
    fun setAnalyticsEnabled(enabled: Boolean) {
        viewModelScope.launch {
            repository.setAnalyticsEnabled(enabled)
            Analytics.consentGranted = enabled
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

    // --- アカウントとバックアップ(記録のクラウド保存。iOS 設定の同セクション移植) ---

    /** バックアップのオプトイン状態(既定 OFF)。 */
    val backupEnabled: StateFlow<Boolean> = recordSync.isEnabled
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    /** 同期中(今すぐバックアップのスピナー)。 */
    val backupSyncing: StateFlow<Boolean> = recordSync.isSyncing

    /** 直近の同期/復元エラー(利用者向け文言)。 */
    val backupError: StateFlow<String?> = recordSync.lastError

    /** トグル: ON は(未サインインなら)匿名アカウント発行→全量同期、OFF は同期停止のみ。 */
    fun setBackupEnabled(on: Boolean) {
        viewModelScope.launch {
            if (on) {
                recordSync.enableBackup()
                _myFriendCode.value = friendsService.myProfile()?.friendCode // ON で初めてアカウントができた場合に反映
            } else {
                recordSync.disableBackup()
            }
        }
    }

    /** 「今すぐバックアップ」。 */
    fun backupNow() {
        viewModelScope.launch { recordSync.syncNow() }
    }

    // --- 友達を招待(共有 / 星バッジ / 後から入力) ---

    /** 紹介サマリ(星バッジ数など)。 */
    val referralSummary = referralStore.summary

    /** 自分の招待コード(共有メッセージ用)。プロフィール取得後に埋める。 */
    private val _myFriendCode = MutableStateFlow<String?>(null)
    val myFriendCode: StateFlow<String?> = _myFriendCode

    /** 初回起動から7日以内かつ未紹介なら、後から招待コードを入れられる。 */
    val canEnterCodeLater: Boolean get() = referralStore.canEnterCodeLater()

    private val _laterCode = MutableStateFlow("")
    val laterCode: StateFlow<String> = _laterCode
    private val _laterSubmitting = MutableStateFlow(false)
    val laterSubmitting: StateFlow<Boolean> = _laterSubmitting
    private val _laterAccepted = MutableStateFlow(false)
    val laterAccepted: StateFlow<Boolean> = _laterAccepted
    val referralError get() = referralStore.lastError

    fun onLaterCodeChange(v: String) { _laterCode.value = v }

    fun inviteMessage(code: String): String =
        "GOエクササイズで一緒に運動しよう！オンボーディングでこの招待コードを入れると、お互いに保険チケットがもらえます → $code\n" +
            "https://play.google.com/store/apps/details?id=com.goexercise.app"

    fun submitLaterInvite() {
        _laterSubmitting.value = true
        referralStore.clearError()
        viewModelScope.launch {
            val ok = referralStore.submitCode(_laterCode.value)
            _laterSubmitting.value = false
            if (ok) _laterAccepted.value = true
            // 確定は Home の初記録フックに委ねる(幽霊確定を防ぐためここでは confirm しない)。
        }
    }

    init {
        viewModelScope.launch {
            _myFriendCode.value = friendsService.myProfile()?.friendCode
            referralStore.refresh()
        }
    }
}
