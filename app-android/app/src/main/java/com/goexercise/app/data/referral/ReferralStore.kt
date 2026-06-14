package com.goexercise.app.data.referral

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import com.goexercise.app.data.friends.FriendsService
import com.goexercise.app.domain.CatBreedAccess
import com.goexercise.app.domain.friends.FriendCode
import com.goexercise.app.domain.friends.ReferralConfirmation
import com.goexercise.app.domain.friends.ReferralEntryPolicy
import com.goexercise.app.domain.friends.ReferralSummary
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 友達紹介の状態を保持しアプリ全体へ供給する @Singleton ストア。iOS `ReferralStore` の移植。
 * 未サインイン時は何もしない(孤児アカウント防止)。
 */
@Singleton
class ReferralStore @Inject constructor(
    private val service: FriendsService,
    private val dataStore: DataStore<Preferences>,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val firstLaunchKey = longPreferencesKey("referral_first_launch_epoch_seconds")

    private val _summary = MutableStateFlow(ReferralSummary.EMPTY)
    val summary: StateFlow<ReferralSummary> = _summary.asStateFlow()
    private val _hasReferrer = MutableStateFlow(false)
    val hasReferrer: StateFlow<Boolean> = _hasReferrer.asStateFlow()
    private val _pendingWelcome = MutableStateFlow<ReferralConfirmation?>(null)
    val pendingWelcome: StateFlow<ReferralConfirmation?> = _pendingWelcome.asStateFlow()
    private val _pendingReferrerPops = MutableStateFlow<List<ReferralConfirmation>>(emptyList())
    val pendingReferrerPops: StateFlow<List<ReferralConfirmation>> = _pendingReferrerPops.asStateFlow()
    /** ⭐10 達成で全猫種解放したときの祝福(アカウント別 1 回限り)。iOS breedUnlockCelebrated 相当。 */
    private val _pendingBreedUnlock = MutableStateFlow(false)
    val pendingBreedUnlock: StateFlow<Boolean> = _pendingBreedUnlock.asStateFlow()
    private fun breedUnlockCelebratedKey(account: String) =
        booleanPreferencesKey("referral_breed_unlock_celebrated_$account")
    /** 現在の summary がどのアカウント(friend_code)由来かを記録し、口座跨ぎの stale を防ぐ
     *  (iOS summaryAccountCode 相当)。 */
    private val _summaryAccountCode = MutableStateFlow<String?>(null)
    /** 現在サインイン中だと判明しているアカウント(friend_code)。refresh で**summary 取得前に**
     *  先行更新し、resetForIdentityChange で null に戻す。Android では myProfile() が suspend で
     *  iOS のような同期 getter ガードが組めないため、これを reactive な突き合わせ対象にする。 */
    private val _currentAccountCode = MutableStateFlow<String?>(null)

    /** 現アカウント由来のときだけ通す星バッジ数(口座跨ぎ stale 防止)。表示は必ずこの口座ガード経由
     *  にする(iOS currentAccountStarBadges 相当)。直読み(summary.starBadges)は切替/復元直後に
     *  前アカウントの星を新アカウント文脈で描いてしまう。 */
    val currentAccountStarBadges: StateFlow<Int> =
        combine(_summary, _summaryAccountCode, _currentAccountCode) { summary, summaryCode, currentCode ->
            ReferralAccountScope.scoped(summary.starBadges, summaryCode, currentCode)
        }.stateIn(scope, SharingStarted.Eagerly, 0)

    /** 現アカウント由来のときだけ通す今月フリーズ加算(同じ口座ガード。iOS currentAccountFreezeBonus 相当)。 */
    val currentAccountFreezeBonus: StateFlow<Int> =
        combine(_summary, _summaryAccountCode, _currentAccountCode) { summary, summaryCode, currentCode ->
            ReferralAccountScope.scoped(summary.freezeBonusThisMonth, summaryCode, currentCode)
        }.stateIn(scope, SharingStarted.Eagerly, 0)

    /** 現アカウント由来の星で猫種解放済みか(口座跨ぎ stale entitlement 防止。iOS isBreedUnlocked(forAccount:) 相当)。 */
    fun isBreedUnlockedForCurrentAccount(): Boolean =
        CatBreedAccess.referralUnlocked(currentAccountStarBadges.value)
    /** 非同期 refresh の世代。identity 変更(reset)で進め、フェッチ中に identity が
     *  変わった場合に前アカウントの結果を commit しないための stale ガード(Codex R1)。 */
    @Volatile private var identityGeneration = 0
    private val _firstLaunchAt = MutableStateFlow<Instant?>(null)
    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    init {
        scope.launch {
            val prefs = dataStore.data.first()
            val existing = prefs[firstLaunchKey]
            if (existing != null) {
                _firstLaunchAt.value = Instant.ofEpochSecond(existing)
            } else {
                val now = Instant.now()
                _firstLaunchAt.value = now
                dataStore.edit { it[firstLaunchKey] = now.epochSecond }
            }
        }
    }

    fun canEnterCodeLater(now: Instant = Instant.now()): Boolean =
        ReferralEntryPolicy.canEnterCodeLater(_firstLaunchAt.value, now, _hasReferrer.value)

    private suspend fun isSignedIn(): Boolean = service.myProfile() != null

    /**
     * アカウント切替/サインアウト/削除で identity が変わった瞬間に**同期で**全状態を捨てる。
     * これが無いと、前アカウントの星/今月フリーズ/未消化ポップが新アカウントの文脈で
     * 一瞬(refresh 完了まで)使われ、口座スコープ漏れになる(iOS の口座ガードに対応)。
     * 呼び出しは FriendsViewModel.bumpIdentity(切替/復元/サインアウト/削除の中央点)。
     */
    fun resetForIdentityChange() {
        identityGeneration++ // 進行中の refresh が前アカウント値を commit するのを無効化(Codex R1)。
        _summary.value = ReferralSummary.EMPTY
        _hasReferrer.value = false
        _pendingWelcome.value = null
        _pendingReferrerPops.value = emptyList()
        _pendingBreedUnlock.value = false
        _summaryAccountCode.value = null
        _currentAccountCode.value = null // 口座ガードを即 0 に倒す(新アカウントの refresh が確定するまで)。
    }

    suspend fun refresh() {
        // 世代は**最初の suspend より前**に取得する。myProfile() 自体が suspend で、その中断中に
        // identity が変わると古い friendCode が返り得るため、直後にも再チェックして破棄する(Codex R2)。
        val gen = identityGeneration
        val account = service.myProfile()?.friendCode
        if (gen != identityGeneration) return // myProfile 中に reset された → 古い結果で何もしない
        if (account == null) {
            // 未サインイン(サインアウト/切替/削除後)は前アカウントの状態を持ち越さない。
            // 未消化ポップも捨て、次のユーザーに前アカウント宛の祝祭を出さない(監査 P2)。
            resetForIdentityChange()
            return
        }
        // 現アカウントは summary 取得**前に**先行確定させる。これで取得待ちの間も口座ガードが
        // 「summaryAccountCode(前) != currentAccountCode(新)」を検知して 0 を返せる(iOS の
        // 読み取り時 friendCode 突き合わせに対応する reactive 版)。
        _currentAccountCode.value = account
        val previousCode = _summaryAccountCode.value
        // **実際に別アカウントへ切り替わった時だけ**クリアする。previousCode==null は初回 refresh で
        // あり「切替」ではない(その場合 summary は既に EMPTY)。null を切替扱いすると、直前に
        // submitCode/confirm/poll がセットした hasReferrer/ポップを誤って消す(Codex R1 #2)。
        if (previousCode != null && previousCode != account) {
            _summary.value = ReferralSummary.EMPTY
            _hasReferrer.value = false
            _pendingWelcome.value = null
            _pendingReferrerPops.value = emptyList()
        }
        try {
            val summary = service.referralSummary()
            val hasReferrer = service.hasReferrer()
            // フェッチ中に identity が変わった(reset された)なら結果を破棄し、前アカウントの値を
            // 新アカウント文脈へ commit しない(stale commit 防止, Codex R1 #1)。
            if (gen != identityGeneration) return
            _summary.value = summary
            _hasReferrer.value = hasReferrer
            _summaryAccountCode.value = account
            // ⭐10 到達で全猫種解放。アカウント別に未祝いなら祝福ポップを一度だけ出す。
            if (summary.starBadges >= CatBreedAccess.BREED_UNLOCK_STARS) {
                val celebrated = dataStore.data.first()[breedUnlockCelebratedKey(account)] ?: false
                if (!celebrated) _pendingBreedUnlock.value = true
            }
        } catch (e: Exception) { _lastError.value = e.message }
    }

    suspend fun submitCode(raw: String): Boolean {
        val code = FriendCode.sanitize(raw)
        if (!FriendCode.isValid(code)) { _lastError.value = "招待コードは6文字です。もう一度確認してください"; return false }
        return try {
            if (service.myProfile() == null) service.signIn(displayName = "ねこの友", username = generatedUsername())
            service.submitInviteCode(code)
            _hasReferrer.value = true
            refresh()
            true
        } catch (e: Exception) { _lastError.value = e.message; false }
    }

    suspend fun confirmFirstRecordIfNeeded(hasFirstRecord: Boolean) {
        if (!isSignedIn() || !hasFirstRecord || !_hasReferrer.value) return
        try {
            service.confirmReferralIfEligible(true)?.let { _pendingWelcome.value = it; refresh() }
        } catch (e: Exception) { _lastError.value = e.message }
    }

    suspend fun pollReferrerPops() {
        if (!isSignedIn()) return
        try {
            val pops = service.unseenReferrerConfirmations()
            if (pops.isNotEmpty()) { _pendingReferrerPops.value = pops; refresh() }
        } catch (e: Exception) { _lastError.value = e.message }
    }

    fun consumeWelcome() { _pendingWelcome.value = null }
    fun consumeReferrerPops() { _pendingReferrerPops.value = emptyList() }
    fun consumeBreedUnlock() {
        _pendingBreedUnlock.value = false
        val account = _summaryAccountCode.value ?: return
        scope.launch { dataStore.edit { it[breedUnlockCelebratedKey(account)] = true } }
    }
    fun clearError() { _lastError.value = null }

    private fun generatedUsername(): String =
        "neko" + java.util.UUID.randomUUID().toString().replace("-", "").take(6).lowercase()
}
