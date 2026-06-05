package com.goexercise.app.data.referral

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import com.goexercise.app.data.friends.FriendsService
import com.goexercise.app.domain.friends.FriendCode
import com.goexercise.app.domain.friends.ReferralConfirmation
import com.goexercise.app.domain.friends.ReferralEntryPolicy
import com.goexercise.app.domain.friends.ReferralSummary
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
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

    suspend fun refresh() {
        if (!isSignedIn()) return
        try {
            _summary.value = service.referralSummary()
            _hasReferrer.value = service.hasReferrer()
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
    fun clearError() { _lastError.value = null }

    private fun generatedUsername(): String =
        "neko" + java.util.UUID.randomUUID().toString().replace("-", "").take(6).lowercase()
}
