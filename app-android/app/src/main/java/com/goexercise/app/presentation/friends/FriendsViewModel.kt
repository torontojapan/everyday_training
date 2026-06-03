package com.goexercise.app.presentation.friends

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.data.friends.FriendsError
import com.goexercise.app.data.friends.FriendsService
import com.goexercise.app.domain.friends.FriendProfile
import com.goexercise.app.domain.friends.FriendRequest
import com.goexercise.app.domain.friends.FriendSortOrder
import com.goexercise.app.domain.friends.FriendSorter
import com.goexercise.app.domain.friends.CheerKind
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
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
    /** 一時トースト(応援/申請の結果)。表示後に [consumeToast] でクリア。 */
    val toast: String? = null,
) {
    val sortedFriends: List<FriendProfile> get() = FriendSorter.sort(friends, sortOrder)
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
) : ViewModel() {

    private val _uiState = MutableStateFlow(FriendsUiState())
    val uiState: StateFlow<FriendsUiState> = _uiState.asStateFlow()

    val isMock: Boolean get() = service.isMock

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
                service.signIn(displayName = DEFAULT_DISPLAY_NAME, username = "")
                load()
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = friendly(e)) }
            } finally {
                _uiState.update { it.copy(isConnecting = false) }
            }
        }
    }

    private suspend fun load() {
        val profile = service.myProfile()
        if (profile == null) {
            _uiState.update { it.copy(isSignedIn = false, profile = null, friends = emptyList(), requests = emptyList()) }
            return
        }
        _uiState.update { it.copy(isSignedIn = true, isLoading = it.friends.isEmpty()) }
        try {
            val friends = service.refreshFriends()
            val requests = service.pendingRequests()
            _uiState.update { it.copy(profile = profile, friends = friends, requests = requests, isLoading = false) }
        } catch (e: Exception) {
            _uiState.update { it.copy(profile = profile, isLoading = false, errorMessage = friendly(e)) }
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

    /** 友達コードで申請を送る。成功でトースト+再ロード、失敗はエラー文言を返す(追加シートが表示)。 */
    fun sendRequest(code: String, onResult: (success: Boolean, message: String) -> Unit = { _, _ -> }) {
        viewModelScope.launch {
            try {
                service.sendRequest(code.uppercase())
                load()
                val msg = "$code に友達申請を送りました 🤝"
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

    /** 応援スタンプ送信。連打は cheeringCodes で多重送信ガード。 */
    fun cheer(kind: CheerKind, to: FriendProfile) {
        val code = to.friendCode
        if (_uiState.value.cheeringCodes.contains(code)) return
        _uiState.update { it.copy(cheeringCodes = it.cheeringCodes + code) }
        viewModelScope.launch {
            try {
                service.sendCheer(kind, code)
                _uiState.update { it.copy(toast = "${kind.emoji} ${to.displayName} に ${kind.label} を送りました") }
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = friendly(e)) }
            } finally {
                _uiState.update { it.copy(cheeringCodes = it.cheeringCodes - code) }
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            runCatching { service.signOut() }
            _uiState.value = FriendsUiState()
        }
    }

    fun consumeToast() = _uiState.update { it.copy(toast = null) }
    fun clearError() = _uiState.update { it.copy(errorMessage = null) }

    /** FriendsError は利用者向けの日本語文言を持つ。それ以外は汎用文言に丸める。 */
    private fun friendly(e: Throwable): String = when (e) {
        is FriendsError -> e.message ?: GENERIC_ERROR
        else -> GENERIC_ERROR
    }

    companion object {
        const val DEFAULT_DISPLAY_NAME = "あなた"
        private const val GENERIC_ERROR = "通信に失敗しました。少し時間をおいて試してください。"
    }
}
