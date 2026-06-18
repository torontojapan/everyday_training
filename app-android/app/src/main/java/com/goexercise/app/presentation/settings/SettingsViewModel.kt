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
import androidx.glance.appwidget.updateAll
import com.goexercise.app.widget.StreakWidget
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
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
    private val authCoordinator: com.goexercise.app.presentation.friends.AccountAuthCoordinator,
    @ApplicationContext private val appContext: android.content.Context,
) : ViewModel() {

    // --- 認証(Apple/Google でバックアップ)を設定に集約(#14。iOS は設定に集約・友達タブから撤去) ---

    /** 連携済みプロバイダ表示名(複数連携は「Apple・Google」/null=匿名)。設定で「未連携=サインインボタン/連携済=状態表示」に使う。 */
    private val _linkedProvider = MutableStateFlow<String?>(friendsService.backupStatus.linkedProvidersDisplay)
    val linkedProvider: StateFlow<String?> = _linkedProvider.asStateFlow()
    private val _isLinkingAccount = MutableStateFlow(false)
    val isLinkingAccount: StateFlow<Boolean> = _isLinkingAccount.asStateFlow()
    private val _linkError = MutableStateFlow<String?>(null)
    val linkError: StateFlow<String?> = _linkError.asStateFlow()

    /** Apple でバックアップ(連携)。連携後にバックアップを自動 ON にする(iOS パリティ)。 */
    fun linkApple(context: android.content.Context) =
        performLink { friendsService.linkAppleWeb(authCoordinator.appleWebFlow(context)) }

    /** Google でバックアップ(連携)。native id_token。 */
    fun linkGoogle(context: android.content.Context) =
        performLink { friendsService.linkGoogleIdToken(authCoordinator.requestGoogleIdToken(context)) }

    private fun performLink(op: suspend () -> Unit) {
        if (_isLinkingAccount.value) return
        _isLinkingAccount.value = true
        _linkError.value = null
        viewModelScope.launch {
            try {
                op()
                // 連携は匿名 uid をそのまま Apple/Google に紐付ける(identity 不変)。続けてバックアップを自動 ON。
                recordSync.enableBackup()
                _linkedProvider.value = friendsService.backupStatus.linkedProvidersDisplay
            } catch (e: com.goexercise.app.data.friends.AccountLinkError.Cancelled) {
                // ユーザーキャンセルは無言で戻す。
            } catch (e: Exception) {
                _linkError.value = "サインインに失敗しました: ${e.message}"
            } finally {
                _isLinkingAccount.value = false
            }
        }
    }

    fun clearLinkError() { _linkError.value = null }

    /** アカウント削除(審査 Guideline 5.1.1(v))。本人データを完全消去し、ローカルのアカウント表示も初期化する。 */
    fun deleteAccount(onDone: (Boolean) -> Unit = {}) {
        viewModelScope.launch {
            val ok = runCatching { friendsService.deleteAccount() }.isSuccess
            if (ok) {
                _myFriendCode.value = null
                _linkedProvider.value = null
                // identity 消滅後は同期状態をリセット(口座跨ぎ wipe 防止。FriendsVM の identity 切替と同じ)。
                runCatching { recordSync.resetForIdentityChange() }
            }
            onDone(ok)
        }
    }

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

    /** トライアル適格(消化済みなら false)。課金カードの「14日間無料」誤表示を防ぐ(Codex R4)。 */
    val isTrialEligible: StateFlow<Boolean> = premium.isTrialEligible

    /** 選択中の猫種(猫ピッカー用)。 */
    val catBreed: StateFlow<CatBreed> = repository.catBreed
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), CatBreed.Default)

    fun setTheme(theme: AppTheme) {
        viewModelScope.launch { repository.setTheme(theme) }
    }

    fun setCatBreed(breed: CatBreed) {
        // 課金/紹介ゲート(UI迂回時の多層防御): 非プレミアムかつ紹介⭐<10 は「今の猫」以外に変更できない。
        // 口座ガード経由で判定し、切替/復元直後に前アカウントの星で誤解放しない。
        val unlocked = referralStore.isBreedUnlockedForCurrentAccount()
        if (CatBreedAccess.isLocked(breed, catBreed.value, isPremium.value, unlocked)) return
        viewModelScope.launch { repository.setCatBreed(breed) }
    }

    /** 毎日のリマインダー設定(ON/OFF + 朝/夕時刻 + 回数 + 性格)。 */
    val reminder: StateFlow<ReminderPrefs> = notificationPrefs.prefs
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ReminderPrefs())

    /** 永続化 + AlarmManager 反映(朝常時/夕は count>1)。性格/回数変更でも即 reschedule。 */
    private fun applyReminder(prefs: ReminderPrefs) {
        viewModelScope.launch {
            notificationPrefs.update(prefs)
            reminderScheduler.apply(prefs)
        }
    }

    /** ON/OFF + 朝(1本目)時刻。enabled=true は通知権限取得後に呼ぶこと(後方互換シグネチャ)。 */
    fun setReminder(enabled: Boolean, hour: Int, minute: Int) =
        applyReminder(reminder.value.copy(enabled = enabled, hour = hour, minute = minute))

    /** 夕(2本目)時刻。 */
    fun setEveningTime(hour: Int, minute: Int) =
        applyReminder(reminder.value.copy(eveningHour = hour, eveningMinute = minute))

    /** 1日の通知回数(1=朝のみ / 2=朝+夕)。 */
    fun setReminderCount(count: Int) =
        applyReminder(reminder.value.copy(count = count.coerceIn(1, 2)))

    /** 通知の性格(quiet/voice/friendDriven)。 */
    fun setReminderPersonality(personality: com.goexercise.app.domain.NotificationPersonality) =
        applyReminder(reminder.value.copy(personality = personality))

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

    /** 達成時の振動(haptic)トグル。既定 ON。iOS CelebrationPreferences.hapticEnabled 相当。 */
    val hapticEnabled: StateFlow<Boolean> = repository.hapticEnabled
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), true)

    fun setHapticEnabled(enabled: Boolean) {
        viewModelScope.launch { repository.setHapticEnabled(enabled) }
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
                // 全削除後にホームウィジェットを即リフレッシュ(古い連続日数/今日達成の残留を防ぐ。
                // iOS の全削除後 WidgetCenter.reloadAllTimelines 相当)。
                runCatching { StreakWidget().updateAll(appContext) }
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

    /** 紹介サマリの星バッジ数(設定の招待カード表示用)。口座ガード経由で読み、切替/復元直後に
     *  前アカウントの星を表示しない(iOS currentAccountStarBadges 相当)。 */
    val referralStarBadges: StateFlow<Int> = referralStore.currentAccountStarBadges

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
