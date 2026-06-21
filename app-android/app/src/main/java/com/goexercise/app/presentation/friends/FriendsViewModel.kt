package com.goexercise.app.presentation.friends

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.ensureActive
import com.goexercise.app.data.friends.AccountBackupStatus
import com.goexercise.app.data.friends.AccountLinkError
import com.goexercise.app.data.friends.FriendsError
import com.goexercise.app.data.friends.FriendsService
import com.goexercise.app.data.friends.RestoreOutcome
import com.goexercise.app.data.friends.SupabaseConfig
import com.goexercise.app.domain.friends.FriendProfile
import com.goexercise.app.domain.friends.FriendRequest
import com.goexercise.app.domain.friends.FriendSortOrder
import com.goexercise.app.domain.friends.FriendSorter
import com.goexercise.app.domain.friends.CheerKind
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * 友達画面の UI 状態。iOS `FriendsStore` の発行プロパティ群に対応(社交フローのみ)。
 * 連携/復元/削除(Phase 2)は #5 で追加する。
 */
data class FriendsUiState(
    val isSignedIn: Boolean = false,
    /** 能動操作での匿名サインイン中(welcome の spinner)。 */
    val isConnecting: Boolean = false,
    /** 友達一覧の取得中(初回ロードの spinner 判定)。 */
    val isLoading: Boolean = false,
    val profile: FriendProfile? = null,
    val friends: List<FriendProfile> = emptyList(),
    val requests: List<FriendRequest> = emptyList(),
    val sortOrder: FriendSortOrder = FriendSortOrder.StreakDesc,
    /** 応援送信中のコード(連打多重送信ガード)。iOS `cheeringCodes`。 */
    val cheeringCodes: Set<String> = emptySet(),
    val errorMessage: String? = null,
    /** 一時トースト(応援/申請/連携の結果)。表示後に [consumeToast] でクリア。 */
    val toast: String? = null,
    /** アカウント連携状態(匿名/Apple/Google)。#5。 */
    val backupStatus: AccountBackupStatus = AccountBackupStatus.Anonymous,
    /** 連携(バックアップ/復元/切替)処理中。連打ガード + UI spinner。 */
    val isLinkingAccount: Boolean = false,
    /** アカウント削除進行中。削除中は他操作をロックする(iOS isDeletingAccount)。 */
    val isDeletingAccount: Boolean = false,
) {
    val sortedFriends: List<FriendProfile> get() = FriendSorter.sort(friends, sortOrder)
}

/** 連携(Apple/Google 共通)の結果。`Collision` は「既存に切替/中止」の二択を促す。iOS LinkResult。 */
sealed interface LinkResult {
    data object Linked : LinkResult
    data object Collision : LinkResult
    data object Cancelled : LinkResult
    data class Failed(val message: String) : LinkResult
}

/** 復元(Apple/Google 共通)の結果。iOS RestoreResult。 */
sealed interface RestoreResult {
    data object Restored : RestoreResult
    data object Created : RestoreResult
    data object Cancelled : RestoreResult
    data class Failed(val message: String) : RestoreResult
}

/**
 * 友達バックエンドを駆動する VM。iOS `FriendsStore` の社交部分を移植。
 * [FriendsService] は @Singleton なので追加/ランキング画面が別 VM でも同一バックエンドを共有する。
 *
 * lazy 化: タブを開いただけでは匿名アカウントを作らない(孤児/プライバシー対策)。
 * welcome に留まり、「友達とつながる」= 能動操作の瞬間に初めて [connect] でサインインする。
 */
@HiltViewModel
class FriendsViewModel @Inject constructor(
    private val service: FriendsService,
    private val authCoordinator: AccountAuthCoordinator,
    private val settings: com.goexercise.app.data.settings.SettingsRepository,
    private val referralStore: com.goexercise.app.data.referral.ReferralStore,
    private val recordSync: com.goexercise.app.data.backup.RecordSyncCoordinator,
) : ViewModel() {

    private val _uiState = MutableStateFlow(FriendsUiState())
    val uiState: StateFlow<FriendsUiState> = _uiState.asStateFlow()

    val isMock: Boolean get() = service.isMock

    /** 自分のキャラ(welcome / プロフィールのアバター表示用。猫 or 犬)。
     *  友達カードは各友達の猫種(CatBreed)を使うが、自分の表示だけは犬対応の myPet を使う。 */
    val myBreed: StateFlow<com.goexercise.app.domain.PetBreed> = settings.myPet
        .stateIn(viewModelScope, kotlinx.coroutines.flow.SharingStarted.WhileSubscribed(5_000), com.goexercise.app.domain.PetBreed.Default)

    /** バックアップ促しを「あとで」で閉じてから 30 日以内か(永続)。true の間は BackupCard を出さない。 */
    val backupSuppressed: StateFlow<Boolean> = settings.backupPromptDismissedAt
        .map { d -> d != null && java.time.temporal.ChronoUnit.DAYS.between(d, java.time.LocalDate.now()) < 30 }
        .stateIn(viewModelScope, kotlinx.coroutines.flow.SharingStarted.WhileSubscribed(5_000), false)

    /** 「あとで」をタップ: 本日を記録(30 日沈黙を永続化)。iOS の dismiss 永続に対応。 */
    fun dismissBackupPrompt() {
        viewModelScope.launch { settings.dismissBackupPrompt(java.time.LocalDate.now()) }
    }

    /** ユーザー名検索の結果(AddFriendSheet 用)。iOS searchByUsername パリティ。 */
    private val _searchResults = MutableStateFlow<List<com.goexercise.app.domain.friends.FriendProfile>>(emptyList())
    val searchResults: StateFlow<List<com.goexercise.app.domain.friends.FriendProfile>> = _searchResults.asStateFlow()
    private val _isSearching = MutableStateFlow(false)
    val isSearching: StateFlow<Boolean> = _isSearching.asStateFlow()

    /** 検索中のジョブ(キーストロークごとに前のを cancel して古い応答で新しい結果を上書きしないように)。 */
    private var searchJob: kotlinx.coroutines.Job? = null

    /** ユーザー名(部分一致・2文字以上)で他ユーザーを検索する。iOS FriendAddView の search 相当。
     *  前の検索を cancel し、応答到着時にまだ有効(=より新しいクエリに置き換わっていない)なら反映する。 */
    fun searchByUsername(query: String) {
        val q = query.trim()
        searchJob?.cancel()
        if (q.length < 2) { _searchResults.value = emptyList(); _isSearching.value = false; return }
        searchJob = viewModelScope.launch {
            _isSearching.value = true
            val results = runCatching { service.searchByUsername(q) }.getOrDefault(emptyList())
            // cancel 済み(新しいクエリが来た / clearSearch された)なら古い結果は捨てる(iOS の Task.isCancelled 相当)。
            ensureActive()
            _searchResults.value = results
            _isSearching.value = false
        }
    }

    /** 検索結果をクリア(シートを閉じた時など)。進行中の検索も止める。 */
    fun clearSearch() {
        searchJob?.cancel()
        _searchResults.value = emptyList()
        _isSearching.value = false
    }

    /** 連携 UI の表示ゲート(既定 false = 連携 UI 非表示で従来挙動)。iOS isAccountLinkingEnabled。 */
    val isAccountLinkingEnabled: Boolean get() = SupabaseConfig.isAccountLinkingEnabled
    val appleLinkEnabled: Boolean get() = SupabaseConfig.appleLinkEnabled
    val googleLinkEnabled: Boolean get() = SupabaseConfig.googleLinkEnabled

    /** identity(サインイン中の uid)の世代。切替/復元/サインアウト/削除で進め、進行中の旧 load を無効化する
     *  (iOS identityGeneration。旧アカウントの友達/申請を新プロフィール上へ書かないため)。 */
    private var identityGeneration = 0
    private suspend fun bumpIdentity() {
        identityGeneration++
        // identity が変わったら紹介状態も取り直す。前アカウントの星/今月フリーズ/未消化ポップが
        // 新アカウントの文脈で漏れる口座スコープ漏れを防ぐ(iOS の friendCode 変化 → refresh に対応)。
        // まず同期で即リセットして stale を出さず、続けて新アカウントの値を非同期で取得する。
        referralStore.resetForIdentityChange()
        viewModelScope.launch { runCatching { referralStore.refresh() } }
        // 記録バックアップ: 前アカウント宛の削除キュー/wipe/同期時刻を**同期的に**破棄してから戻る
        // (口座跨ぎ wipe 防止, Codex P1。後続の restoreRecordBackup と順序を保証する)。
        runCatching { recordSync.resetForIdentityChange() }
    }

    /** 切替/復元の成功後: 新アカウントのバックアップがあれば取り込み、自動で ON にする(iOS と同じ)。 */
    private suspend fun restoreRecordBackup() {
        runCatching { recordSync.restoreAfterSignIn() }
    }

    /** サインイン済みのときだけ最新化(未サインインは welcome のまま、クラウドへ書き込まない)。 */
    fun refreshIfSignedIn() {
        viewModelScope.launch {
            if (service.myProfile() != null) load()
        }
    }

    /** welcome の「友達とつながる」。能動操作の瞬間に匿名サインイン → ロード。 */
    fun connect() {
        if (_uiState.value.isConnecting) return
        _uiState.update { it.copy(isConnecting = true, errorMessage = null) }
        viewModelScope.launch {
            try {
                service.signIn(displayName = DEFAULT_DISPLAY_NAME, username = generatedUsername())
                // 再インストール後の既存セッション等にバックアップが残っていれば取り込む
                // (新規匿名は空フェッチで no-op。iOS の friendCode 変化 → restoreAfterSignIn に対応)。
                restoreRecordBackup()
                load()
                // サインイン直後に紹介状態を取得して currentAccountCode/星バッジを確定させる。
                // これが無いとホームの紹介スター行(ReferralStarsRow)が次回起動まで出ない
                // (iOS は HomeView.onChange(friendCode) → referralStore.refresh() で更新する。本 connect が
                //  Android の friendCode 出現点なので同じ refresh をここで起こす)。
                if (com.goexercise.app.AppFeatureFlags.isReferralActive) {
                    runCatching { referralStore.refresh(); referralStore.pollReferrerPops() }
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = friendly(e)) }
            } finally {
                _uiState.update { it.copy(isConnecting = false) }
            }
        }
    }

    /**
     * タブを開いたら自動でアカウントを発行し、最初から友達コード画面を見せる(iOS と同じ
     * ワンステップ化。旧: welcome のボタンを押すまで作らない lazy 方式)。失敗時は welcome に
     * 留まり CTA が再試行を兼ねる。復元したい人は welcome/設定の Apple/Google 復元で切替できる。
     */
    fun ensureSignedIn() {
        viewModelScope.launch {
            if (service.myProfile() != null) {
                load()
            } else if (!_uiState.value.isConnecting && !_uiState.value.isLinkingAccount) {
                connect()
            }
        }
    }

    private suspend fun load() {
        val gen = identityGeneration
        val profile = service.myProfile() // suspend: この await 中に identity が変わり得る
        if (gen != identityGeneration) return // 切替/復元/サインアウトが割り込んだら以降の UI 書込みを破棄
        if (profile == null) {
            _uiState.update { it.copy(isSignedIn = false, profile = null, friends = emptyList(), requests = emptyList(), backupStatus = AccountBackupStatus.Anonymous) }
            return
        }
        _uiState.update { it.copy(isSignedIn = true, isLoading = it.friends.isEmpty()) }
        try {
            val friends = service.refreshFriends()
            val requests = service.pendingRequests()
            if (SupabaseConfig.isAccountLinkingEnabled) service.refreshBackupStatus()
            // await 中に identity が切替わっていたら旧アカウントの結果を捨てる(iOS と同じ)。stale でも
            // 自分が出したスピナーは残さない(isLoading をクリア。新世代の load/リセットが正状態を持つ)。
            if (gen == identityGeneration) {
                _uiState.update { it.copy(profile = profile, friends = friends, requests = requests, backupStatus = service.backupStatus, isLoading = false) }
                // サインイン済みなら未読の受信応援をチェックしてトースト表示(iOS の友達タブ受信トースト相当)。
                fetchReceivedCheers()
            } else {
                _uiState.update { it.copy(isLoading = false) }
            }
        } catch (e: Exception) {
            if (gen == identityGeneration) {
                _uiState.update { it.copy(profile = profile, isLoading = false, errorMessage = friendly(e)) }
            } else {
                _uiState.update { it.copy(isLoading = false) }
            }
        }
    }

    fun setSortOrder(order: FriendSortOrder) = _uiState.update { it.copy(sortOrder = order) }

    /** 表示名変更。iOS `updateDisplayName` 相当(publishMyProfile で反映)。 */
    fun rename(name: String) {
        val me = _uiState.value.profile ?: return
        val trimmed = name.trim()
        if (trimmed.isEmpty() || trimmed == me.displayName) return
        viewModelScope.launch {
            runCatching {
                service.publishMyProfile(me.copy(displayName = trimmed))
                _uiState.update { it.copy(profile = service.myProfile()) }
            }.onFailure { e -> _uiState.update { it.copy(errorMessage = friendly(e)) } }
        }
    }

    /** 初回「表示名を決める」カード(namePromptCard)を閉じたか。iOS `friends.didDismissNamePrompt`。 */
    val namePromptDismissed: StateFlow<Boolean> =
        settings.namePromptDismissed.stateIn(viewModelScope, kotlinx.coroutines.flow.SharingStarted.WhileSubscribed(5_000), false)

    /** namePromptCard の「あとで」。以後表示しない。 */
    fun dismissNamePrompt() {
        viewModelScope.launch { settings.setNamePromptDismissed(true) }
    }

    /** namePromptCard の「決定」。表示名を更新し、成功時のみ閉じる(失敗時は既定名のまま再度促す。iOS パリティ)。 */
    fun submitNamePrompt(name: String) {
        val me = _uiState.value.profile ?: return
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        viewModelScope.launch {
            runCatching {
                service.publishMyProfile(me.copy(displayName = trimmed))
                val updated = service.myProfile()
                _uiState.update { it.copy(profile = updated) }
                if (updated?.displayName == trimmed) settings.setNamePromptDismissed(true)
            }.onFailure { e -> _uiState.update { it.copy(errorMessage = friendly(e)) } }
        }
    }

    /** namePromptCard の表示可否。未 dismiss かつ表示名が自動既定のときだけ(iOS showNamePrompt)。 */
    fun shouldShowNamePrompt(profile: FriendProfile, dismissed: Boolean): Boolean =
        !dismissed && profile.displayName == DEFAULT_DISPLAY_NAME

    /** 友達コードで申請を送る。成功でトースト+再ロード、失敗はエラー文言を返す(追加シートが表示)。 */
    fun sendRequest(code: String, onResult: (success: Boolean, message: String) -> Unit = { _, _ -> }) {
        viewModelScope.launch {
            try {
                service.sendRequest(code.uppercase())
                load()
                val msg = "$code に友達申請を送りました"  // iOS は絵文字なし(🤝 を除去・絵文字全廃)
                _uiState.update { it.copy(toast = msg) }
                onResult(true, msg)
            } catch (e: Exception) {
                val msg = friendly(e)
                _uiState.update { it.copy(errorMessage = msg) }
                onResult(false, msg)
            }
        }
    }

    fun accept(request: FriendRequest) = mutate { service.acceptRequest(request) }
    fun decline(request: FriendRequest) = mutate { service.declineRequest(request) }
    fun removeFriend(profile: FriendProfile) = mutate { service.removeFriend(profile) }

    /** 共通: バックエンド変更 → 再ロード。失敗は errorMessage。 */
    private fun mutate(action: suspend () -> Unit) {
        viewModelScope.launch {
            try {
                action()
                load()
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = friendly(e)) }
            }
        }
    }

    /** 応援スタンプ送信。連打は cheeringCodes で多重送信ガード。一言コメント(message)は任意。 */
    fun cheer(kind: CheerKind, to: FriendProfile, message: String? = null) {
        val code = to.friendCode
        if (_uiState.value.cheeringCodes.contains(code)) return
        _uiState.update { it.copy(cheeringCodes = it.cheeringCodes + code) }
        viewModelScope.launch {
            try {
                service.sendCheer(kind, code, message)
                // iOS は送信時に下部トーストを出さない(詳細画面のインライン「『text』を送りました」のみ)。
                // → ここでは toast を出さず、確認は FriendDetailScreen のインライン表示に委ねる。
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = friendly(e)) }
            } finally {
                _uiState.update { it.copy(cheeringCodes = it.cheeringCodes - code) }
            }
        }
    }

    /** 友達コードをコピーした時のトースト(iOS「招待コードをコピーしました」)。 */
    fun notifyCodeCopied() {
        _uiState.update { it.copy(toast = "招待コードをコピーしました") }
    }

    /** 自分宛ての未読応援を取得し、最新1件をトーストで表示する(message 優先)。iOS の受信トースト相当。 */
    fun fetchReceivedCheers() {
        viewModelScope.launch {
            val cheers = runCatching { service.unseenReceivedCheers() }.getOrDefault(emptyList())
            val latest = cheers.maxByOrNull { it.createdAtEpochMs } ?: return@launch
            val (emoji, label) = CheerKind.receivedFromRaw(latest.kindRaw)
            _uiState.update { it.copy(toast = CheerToast.received(emoji, latest.fromDisplayName, label, latest.message, othersCount = cheers.size - 1)) }
        }
    }

    // ================= アカウント連携(#5)=================
    // **Android は鏡像**: Google=native id_token(Credential Manager)/ Apple=web/PKCE(Custom Tabs)。
    // 画面が Context を渡し、coordinator から id_token / WebAuthFlow を取得して Service へ流す。

    /** Apple でバックアップ(連携)。衝突なら Collision を返し UI が切替確認を出す。 */
    fun linkApple(context: Context, onResult: (LinkResult) -> Unit) =
        performLink(onResult) { service.linkAppleWeb(authCoordinator.appleWebFlow(context)) }

    /** Google でバックアップ(連携)。native id_token。 */
    fun linkGoogle(context: Context, onResult: (LinkResult) -> Unit) =
        performLink(onResult) { service.linkGoogleIdToken(authCoordinator.requestGoogleIdToken(context)) }

    private fun performLink(onResult: (LinkResult) -> Unit, op: suspend () -> Unit) {
        if (_uiState.value.isLinkingAccount) return
        _uiState.update { it.copy(isLinkingAccount = true, errorMessage = null) }
        viewModelScope.launch {
            val result: LinkResult = try {
                op()
                _uiState.update { it.copy(backupStatus = service.backupStatus, toast = "バックアップしました") }
                LinkResult.Linked
            } catch (e: AccountLinkError.AlreadyLinkedToAnotherAccount) {
                LinkResult.Collision
            } catch (e: AccountLinkError.Cancelled) {
                LinkResult.Cancelled
            } catch (e: Exception) {
                val msg = friendly(e)
                _uiState.update { it.copy(errorMessage = msg) }
                LinkResult.Failed(msg)
            } finally {
                _uiState.update { it.copy(isLinkingAccount = false) }
            }
            onResult(result)
        }
    }

    /** 衝突時「既存アカウントに切替」。現匿名データ破棄 → 既存アカウントをロード。 */
    fun switchToApple(context: Context) =
        performSwitch { service.switchToAppleWeb(authCoordinator.appleWebFlow(context)) }

    fun switchToGoogle(context: Context) =
        performSwitch { service.switchToGoogleIdToken(authCoordinator.requestGoogleIdToken(context)) }

    private fun performSwitch(op: suspend () -> Unit) {
        if (_uiState.value.isLinkingAccount) return
        _uiState.update { it.copy(isLinkingAccount = true, errorMessage = null) }
        viewModelScope.launch {
            try {
                op()
                bumpIdentity() // identity 境界: 旧 refresh を無効化し旧友達/申請を持ち越さない。
                restoreRecordBackup() // 切替先アカウントの記録バックアップがあれば取り込み+自動 ON
                _uiState.update { it.copy(friends = emptyList(), requests = emptyList()) }
                load()
                _uiState.update { it.copy(backupStatus = service.backupStatus, toast = "既存のアカウントに切り替えました") }
            } catch (e: AccountLinkError.Cancelled) {
                // 認可前キャンセル: identity 不変。何もしない。
            } catch (e: Exception) {
                // op() がセッションを変えた後に失敗した可能性 → identity 境界を張り直し、新セッションの
                // 状態へ寄せて旧プロフィール残留を防ぐ(iOS syncIdentityAfterFailure 相当)。
                recoverIdentityAfterFailure(e)
            } finally {
                _uiState.update { it.copy(isLinkingAccount = false) }
            }
        }
    }

    /** 連携(切替/復元)失敗後の identity 同期。セッションが変わっていても旧友達/申請を残さない。 */
    private suspend fun recoverIdentityAfterFailure(e: Throwable) {
        bumpIdentity()
        _uiState.update { it.copy(friends = emptyList(), requests = emptyList(), errorMessage = friendly(e)) }
        load()
    }

    /** welcome の復元入口。restored/created/cancelled/failed を区別して返す。 */
    fun restoreWithApple(context: Context, onResult: (RestoreResult) -> Unit) =
        performRestore(onResult) { service.restoreWithAppleWeb(authCoordinator.appleWebFlow(context)) }

    fun restoreWithGoogle(context: Context, onResult: (RestoreResult) -> Unit) =
        performRestore(onResult) { service.restoreWithGoogleIdToken(authCoordinator.requestGoogleIdToken(context)) }

    private fun performRestore(onResult: (RestoreResult) -> Unit, op: suspend () -> RestoreOutcome) {
        if (_uiState.value.isLinkingAccount) return
        _uiState.update { it.copy(isLinkingAccount = true, errorMessage = null) }
        viewModelScope.launch {
            val result: RestoreResult = try {
                val outcome = op()
                bumpIdentity()
                restoreRecordBackup() // 機種変更/再インストール: 記録バックアップがあれば取り込み+自動 ON
                _uiState.update { it.copy(friends = emptyList(), requests = emptyList()) }
                load()
                _uiState.update { it.copy(backupStatus = service.backupStatus) }
                if (outcome == RestoreOutcome.Restored) RestoreResult.Restored else RestoreResult.Created
            } catch (e: AccountLinkError.Cancelled) {
                RestoreResult.Cancelled
            } catch (e: Exception) {
                // 復元途中でセッションが変わった後の失敗に備え identity を張り直す(切替と対称)。
                recoverIdentityAfterFailure(e)
                RestoreResult.Failed(friendly(e))
            } finally {
                _uiState.update { it.copy(isLinkingAccount = false) }
            }
            onResult(result)
        }
    }

    /** 復元/切替の前に、現匿名セッションに失われると困るデータがあるか(上書き確認の要否)。 */
    suspend fun anonymousSessionHasData(): Boolean = service.anonymousSessionHasData()

    /** アカウント削除(審査 5.1.1(v))。成功で welcome に着地。失敗は errorMessage(サインアウトしない=再試行可)。 */
    fun deleteAccount() {
        if (_uiState.value.isDeletingAccount) return
        _uiState.update { it.copy(isDeletingAccount = true) }
        viewModelScope.launch {
            try {
                service.deleteAccount()
                bumpIdentity()
                _uiState.value = FriendsUiState() // welcome に着地(= 完了フィードバック)
            } catch (e: Exception) {
                _uiState.update { it.copy(isDeletingAccount = false, errorMessage = friendly(e)) }
            }
        }
    }

    fun signOut() {
        if (_uiState.value.isDeletingAccount) return // 削除進行中は signOut を弾く(部分削除防止, iOS)
        viewModelScope.launch {
            runCatching { service.signOut() }
            bumpIdentity()
            _uiState.value = FriendsUiState()
        }
    }

    fun consumeToast() = _uiState.update { it.copy(toast = null) }
    fun clearError() = _uiState.update { it.copy(errorMessage = null) }

    /** AccountLinkError / FriendsError は利用者向け日本語文言を持つ。それ以外は汎用文言に丸める。 */
    private fun friendly(e: Throwable): String = when (e) {
        is AccountLinkError -> e.message ?: GENERIC_ERROR
        is FriendsError -> e.message ?: GENERIC_ERROR
        else -> GENERIC_ERROR
    }

    companion object {
        const val DEFAULT_DISPLAY_NAME = "あなた"
        private const val GENERIC_ERROR = "通信に失敗しました。少し時間をおいて試してください。"

        /**
         * 匿名サインイン時の検索用 username 自動生成。iOS `FriendsStore.generatedUsername()` 完全移植
         * (`"neko" + UUID の英数字 6 文字 小文字`)。これが無いと自分ヘッダの @username 行が出ず
         * (FriendsScreen は username 非空時のみ描画)、username 検索もできない=iOS と非一致だった(2026-06-19 検出)。
         */
        fun generatedUsername(): String {
            val suffix = java.util.UUID.randomUUID().toString()
                .replace("-", "")
                .take(6)
                .lowercase()
            return "neko$suffix"
        }
    }
}
