@file:OptIn(ExperimentalMaterial3Api::class)

package com.goexercise.app.presentation.friends

import android.content.Intent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.offset
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.res.painterResource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.data.friends.FriendsLinkProvider
import com.goexercise.app.domain.rank
import com.goexercise.app.domain.friends.CheerKind
import com.goexercise.app.domain.friends.FriendCodeValidator
import com.goexercise.app.domain.friends.FriendProfile
import com.goexercise.app.domain.friends.FriendRequest
import com.goexercise.app.domain.friends.FriendSortOrder
import com.goexercise.app.ui.theme.AppTheme
import com.goexercise.app.ui.theme.LocalAppPalette
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 連携 UI(#5)のハンドラ束。Context 依存の連携呼び出しを Route 側で束ね、stateless な
 * [FriendsContent] へ渡す。既定は全 disabled(= 連携 UI 非表示で従来挙動)。
 */
data class FriendsLinkingHandlers(
    val enabled: Boolean = false,
    val appleEnabled: Boolean = false,
    val googleEnabled: Boolean = false,
    val onLinkApple: ((LinkResult) -> Unit) -> Unit = {},
    val onLinkGoogle: ((LinkResult) -> Unit) -> Unit = {},
    val onSwitchApple: () -> Unit = {},
    val onSwitchGoogle: () -> Unit = {},
    val onRestoreApple: ((RestoreResult) -> Unit) -> Unit = {},
    val onRestoreGoogle: ((RestoreResult) -> Unit) -> Unit = {},
    val onDelete: () -> Unit = {},
    val hasAnonymousData: suspend () -> Boolean = { false },
)

@Composable
fun FriendsRoute(
    onOpenRanking: () -> Unit = {},
    pendingFriendCode: String? = null,
    onCodeConsumed: () -> Unit = {},
    viewModel: FriendsViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val myBreed by viewModel.myBreed.collectAsStateWithLifecycle()
    val backupSuppressed by viewModel.backupSuppressed.collectAsStateWithLifecycle()
    val searchResults by viewModel.searchResults.collectAsStateWithLifecycle()
    val isSearching by viewModel.isSearching.collectAsStateWithLifecycle()
    val context = LocalContext.current
    // タブを開いたら自動でアカウントを発行(iOS と同じワンステップ化。失敗時は welcome+再試行)。
    LaunchedEffect(Unit) { viewModel.ensureSignedIn() }
    // 追加/ランキングから戻る・アプリ復帰のたびに最新化(別 VM の add がサーバを変えるため)。
    LifecycleResumeEffect(Unit) {
        viewModel.refreshIfSignedIn()
        onPauseOrDispose { }
    }
    val linking = FriendsLinkingHandlers(
        enabled = viewModel.isAccountLinkingEnabled,
        appleEnabled = viewModel.appleLinkEnabled,
        googleEnabled = viewModel.googleLinkEnabled,
        onLinkApple = { cb -> viewModel.linkApple(context, cb) },
        onLinkGoogle = { cb -> viewModel.linkGoogle(context, cb) },
        onSwitchApple = { viewModel.switchToApple(context) },
        onSwitchGoogle = { viewModel.switchToGoogle(context) },
        onRestoreApple = { cb -> viewModel.restoreWithApple(context, cb) },
        onRestoreGoogle = { cb -> viewModel.restoreWithGoogle(context, cb) },
        onDelete = viewModel::deleteAccount,
        hasAnonymousData = viewModel::anonymousSessionHasData,
    )
    FriendsContent(
        state = state,
        initialAddCode = pendingFriendCode,
        onAddCodeConsumed = onCodeConsumed,
        onConnect = viewModel::connect,
        onRename = viewModel::rename,
        onSendRequest = { code -> viewModel.sendRequest(code) },
        searchResults = searchResults,
        isSearching = isSearching,
        onSearch = viewModel::searchByUsername,
        onClearSearch = viewModel::clearSearch,
        onAccept = viewModel::accept,
        onDecline = viewModel::decline,
        onRemove = viewModel::removeFriend,
        onCheer = viewModel::cheer,
        onSetSort = viewModel::setSortOrder,
        onSignOut = viewModel::signOut,
        onOpenRanking = onOpenRanking,
        onToastConsumed = viewModel::consumeToast,
        onClearError = viewModel::clearError,
        linking = linking,
        myBreed = myBreed,
        persistedBackupDismissed = backupSuppressed,
        onDismissBackupPersist = viewModel::dismissBackupPrompt,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FriendsContent(
    state: FriendsUiState,
    initialAddCode: String? = null,
    onAddCodeConsumed: () -> Unit = {},
    onConnect: () -> Unit = {},
    onRename: (String) -> Unit = {},
    onSendRequest: (String) -> Unit = {},
    searchResults: List<FriendProfile> = emptyList(),
    isSearching: Boolean = false,
    onSearch: (String) -> Unit = {},
    onClearSearch: () -> Unit = {},
    onAccept: (FriendRequest) -> Unit = {},
    onDecline: (FriendRequest) -> Unit = {},
    onRemove: (FriendProfile) -> Unit = {},
    onCheer: (CheerKind, FriendProfile, String?) -> Unit = { _, _, _ -> },
    onSetSort: (FriendSortOrder) -> Unit = {},
    onSignOut: () -> Unit = {},
    onOpenRanking: () -> Unit = {},
    onToastConsumed: () -> Unit = {},
    onClearError: () -> Unit = {},
    linking: FriendsLinkingHandlers = FriendsLinkingHandlers(),
    myBreed: com.goexercise.app.domain.CatBreed = com.goexercise.app.domain.CatBreed.Default,
    persistedBackupDismissed: Boolean = false,
    onDismissBackupPersist: () -> Unit = {},
) {
    val palette = LocalAppPalette.current
    val scope = rememberCoroutineScope()

    var addSheetCode by remember { mutableStateOf<String?>(null) }
    var showAdd by remember { mutableStateOf(false) }
    var cheerTarget by remember { mutableStateOf<FriendProfile?>(null) }

    // 連携(#5)ダイアログ状態。
    var collisionProvider by remember { mutableStateOf<FriendsLinkProvider?>(null) }
    var restoreConfirmProvider by remember { mutableStateOf<FriendsLinkProvider?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }
    var backupDismissed by remember { mutableStateOf(false) } // セッション内「あとで」(即時非表示)。永続は persistedBackupDismissed。

    // 連携失敗→Collision のとき切替確認を出す。
    fun handleLink(result: LinkResult, provider: FriendsLinkProvider) {
        if (result is LinkResult.Collision) collisionProvider = provider
    }
    // 復元入口: 匿名残存データがあれば上書き確認、無ければ即実行。
    fun startRestore(provider: FriendsLinkProvider) {
        scope.launch {
            if (linking.hasAnonymousData()) {
                restoreConfirmProvider = provider
            } else if (provider == FriendsLinkProvider.Apple) {
                linking.onRestoreApple {}
            } else {
                linking.onRestoreGoogle {}
            }
        }
    }

    // deep link コードは「安全に提示できる時だけ」消費する(iOS tryPresentPendingAdd 相当)。
    // nav 側の pendingFriendCode は rememberSaveable なので、提示前に画面が再生成されても
    // コードは失われない。未サインインなら壁を出さず裏で connect() し、サインイン後に
    // この effect が再走して提示する。他シートが開いている間は提示せず、閉じれば再開する。
    LaunchedEffect(initialAddCode, state.isSignedIn, showAdd, cheerTarget) {
        val code = initialAddCode ?: return@LaunchedEffect
        if (!state.isSignedIn) {
            if (!state.isConnecting) onConnect()
            return@LaunchedEffect
        }
        if (showAdd || cheerTarget != null) return@LaunchedEffect
        addSheetCode = code
        showAdd = true
        onAddCodeConsumed() // 提示が確定してから nav 側のコードを消費する。
    }

    Box(modifier = Modifier.fillMaxSize().background(palette.background)) {
        when {
            state.isSignedIn && state.profile != null -> SignedInBody(
                state = state,
                palette = palette,
                onRename = onRename,
                onAccept = onAccept,
                onDecline = onDecline,
                onCheer = onCheer,
                onSetSort = onSetSort,
                onSignOut = onSignOut,
                onOpenRanking = onOpenRanking,
                onClearError = onClearError,
                onAddClick = { addSheetCode = null; showAdd = true },
                onRemove = onRemove,
                onOpenCheerPicker = { cheerTarget = it },
                linking = linking,
                backupDismissed = backupDismissed || persistedBackupDismissed,
                onDismissBackup = { backupDismissed = true; onDismissBackupPersist() },
                onBackupApple = { linking.onLinkApple { r -> handleLink(r, FriendsLinkProvider.Apple) } },
                onBackupGoogle = { linking.onLinkGoogle { r -> handleLink(r, FriendsLinkProvider.Google) } },
                onDeleteClick = { confirmDelete = true },
                myBreed = myBreed,
            )
            state.isConnecting -> ConnectingBody(palette)
            else -> WelcomeBody(
                palette = palette,
                errorMessage = state.errorMessage,
                onConnect = onConnect,
                linking = linking,
                isLinking = state.isLinkingAccount,
                onRestoreApple = { startRestore(FriendsLinkProvider.Apple) },
                onRestoreGoogle = { startRestore(FriendsLinkProvider.Google) },
                myBreed = myBreed,
            )
        }

        // トースト(応援/申請/連携の結果)を下部に。
        ToastOverlay(state.toast, palette, onToastConsumed)
    }

    // 連携の衝突: 既存アカウントに切替(現データ破棄)か中止の二択。
    collisionProvider?.let { provider ->
        AlertDialog(
            onDismissRequest = { collisionProvider = null },
            title = { Text("このアカウントは既に別のデータに紐づいています") },
            text = { Text("切り替えると、いまの端末の友達・コードは失われます。") },
            confirmButton = {
                TextButton(onClick = {
                    if (provider == FriendsLinkProvider.Apple) linking.onSwitchApple() else linking.onSwitchGoogle()
                    collisionProvider = null
                }) { Text("既存のアカウントに切り替える", color = palette.primaryDeep) }
            },
            dismissButton = { TextButton(onClick = { collisionProvider = null }) { Text("中止") } },
        )
    }

    // 復元前の上書き確認(匿名残存データあり)。
    restoreConfirmProvider?.let { provider ->
        AlertDialog(
            onDismissRequest = { restoreConfirmProvider = null },
            title = { Text("この端末のデータが置き換わることがあります") },
            text = { Text("この端末で進めている友達やコードは、復元するアカウントの内容に置き換わることがあります。") },
            confirmButton = {
                TextButton(onClick = {
                    if (provider == FriendsLinkProvider.Apple) linking.onRestoreApple {} else linking.onRestoreGoogle {}
                    restoreConfirmProvider = null
                }) { Text("${provider.displayName} で復元する", color = palette.primaryDeep) }
            },
            dismissButton = { TextButton(onClick = { restoreConfirmProvider = null }) { Text("キャンセル") } },
        )
    }

    // アカウント削除(審査 5.1.1(v))。
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("アカウントを削除しますか？") },
            text = { Text("友達・コード・応援などすべてのデータが完全に削除され、元に戻せません。バックアップ済みでも復元できなくなります。") },
            confirmButton = {
                TextButton(onClick = { linking.onDelete(); confirmDelete = false }) {
                    Text("アカウントを削除", color = palette.primaryDeep)
                }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("キャンセル") } },
        )
    }

    if (showAdd) {
        val sheetState = rememberModalBottomSheetState()
        ModalBottomSheet(
            onDismissRequest = { showAdd = false; onClearSearch() },
            sheetState = sheetState,
            containerColor = palette.background,
        ) {
            AddFriendSheet(
                palette = palette,
                initialCode = addSheetCode,
                onSend = { code ->
                    onSendRequest(code)
                    onClearSearch()
                    showAdd = false
                },
                searchResults = searchResults,
                isSearching = isSearching,
                onSearch = onSearch,
            )
        }
    }

    cheerTarget?.let { friend ->
        ModalBottomSheet(
            onDismissRequest = { cheerTarget = null },
            containerColor = palette.background,
        ) {
            FriendDetailSheet(
                friend = friend,
                palette = palette,
                onSend = { kind, message ->
                    onCheer(kind, friend, message)
                    cheerTarget = null
                },
                onRemove = {
                    onRemove(friend)
                    cheerTarget = null
                },
            )
        }
    }
}

/**
 * 友達詳細シート(iOS FriendDetailView 相当)。プロフィール/連続・通算・今日の状態を見せ、
 * その場で応援を送る・友達を解除する。アバタータップの到達先=この詳細(送信経路は detail に統一)。
 */
@Composable
private fun FriendDetailSheet(
    friend: FriendProfile,
    palette: AppTheme,
    onSend: (CheerKind, String?) -> Unit,
    onRemove: () -> Unit,
) {
    var confirmRemove by remember { mutableStateOf(false) }
    val rank = com.goexercise.app.domain.CatRank.of(friend.currentStreak)
    Column(
        Modifier.padding(horizontal = 20.dp).padding(top = 8.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(friend.displayName, fontSize = 20.sp, fontWeight = FontWeight.Black, color = palette.textPrimary)
        if (friend.username.isNotBlank()) {
            Text("@${friend.username}", fontSize = 13.sp, color = palette.textSecondary)
        }
        rank.title?.let { Text(it, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = palette.primaryDeep) }
        // 連続 / 通算 / 今日。
        Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
            DetailStat("連続", "${friend.currentStreak}日", palette)
            DetailStat("通算", "${friend.totalAchievedDays}日", palette)
            DetailStat("今日", if (friend.todayAchieved) "達成" else "まだ", palette)
        }
        // 今週の達成: 本人ホームの週ストリップと同じ状態別表示(運動◎/休養休/フリーズ○/未達×/未来-/今日)。
        // Bool で潰すと休養/フリーズ/実運動を区別できず「全部緑✓」に見えた不具合を解消(iOS 1.3 パリティ)。
        val weekStatuses = friend.weeklyStatusesOrEmpty
        Column(
            Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("今週の達成", fontWeight = FontWeight.Bold, color = palette.textPrimary)
                Text("${weekStatuses.count { it.countsAsAchieved }} / 7 日", fontSize = 12.sp, color = palette.textSecondary)
            }
            FriendWeekStrip(weekStatuses)
        }
        // 応援コンポーザ(プリセット + 一言 + 送信)。
        CheerPickerSheet(friend, palette, onSend)
        TextButton(onClick = { confirmRemove = true }) {
            Text("友達を解除", color = palette.missed)
        }
    }
    if (confirmRemove) {
        AlertDialog(
            onDismissRequest = { confirmRemove = false },
            title = { Text("友達を解除しますか?") },
            text = { Text("${friend.displayName} さんとの友達を解除します。再びつながるにはコードの交換が必要です。") },
            confirmButton = { TextButton(onClick = { confirmRemove = false; onRemove() }) { Text("解除", color = palette.missed) } },
            dismissButton = { TextButton(onClick = { confirmRemove = false }) { Text("キャンセル") } },
        )
    }
}

@Composable
private fun DetailStat(label: String, value: String, palette: AppTheme) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, fontSize = 17.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
        Text(label, fontSize = 11.sp, color = palette.textSecondary)
    }
}

/**
 * 友達詳細の「今週の達成」週ストリップ(月→日)。本人ホーム [WeekStrip] と同じ
 * 記号(◎/○/休/×/-/・)+ [colorForStatus] の状態別配色で描画する(iOS 1.3 FriendWeekStripView パリティ)。
 * 入力は 7 要素の DailyStatus(FriendProfile.weeklyStatusesOrEmpty)。
 */
@Composable
private fun FriendWeekStrip(statuses: List<com.goexercise.app.domain.DailyStatus>) {
    val palette = LocalAppPalette.current
    val labels = listOf("月", "火", "水", "木", "金", "土", "日")
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        statuses.take(7).forEachIndexed { i, status ->
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(labels.getOrElse(i) { "" }, color = palette.textSecondary, fontSize = 11.sp)
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(com.goexercise.app.ui.theme.colorForStatus(status)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(text = status.symbol, fontSize = 14.sp)
                }
            }
        }
    }
}

// MARK: - Welcome / connecting

@Composable
private fun ConnectingBody(palette: AppTheme) {
    Column(
        modifier = Modifier.fillMaxSize().padding(28.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        CircularProgressIndicator(color = palette.primary)
        Text("準備しています…", fontSize = 13.sp, color = palette.textSecondary)
    }
}

@Composable
private fun WelcomeBody(
    palette: AppTheme,
    errorMessage: String?,
    onConnect: () -> Unit,
    linking: FriendsLinkingHandlers = FriendsLinkingHandlers(),
    isLinking: Boolean = false,
    onRestoreApple: () -> Unit = {},
    onRestoreGoogle: () -> Unit = {},
    myBreed: com.goexercise.app.domain.CatBreed = com.goexercise.app.domain.CatBreed.Default,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(8.dp))
        com.goexercise.app.ui.components.CatImage(
            breed = myBreed,
            state = com.goexercise.app.domain.CatState.WaitingMorning,
            modifier = Modifier.size(120.dp),
        )
        Text("友達と一緒に続けよう", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
        Text(
            "つながると、おたがいの連続記録を見て応援し合えます。\nメールもパスワードも不要です。",
            fontSize = 13.sp,
            color = palette.textSecondary,
            textAlign = TextAlign.Center,
        )
        if (errorMessage != null) {
            Text(errorMessage, fontSize = 13.sp, color = palette.primaryDeep, textAlign = TextAlign.Center)
        }
        Button(
            onClick = onConnect,
            colors = ButtonDefaults.buttonColors(containerColor = palette.primary),
            modifier = Modifier.fillMaxWidth(),
            // 連携有効時は「この端末で始める」(復元入口を併設, iOS connectButtonLabel)。
        ) {
            Text(if (linking.enabled) "👥  この端末で始める" else "👥  友達とつながる", color = Color.White, fontWeight = FontWeight.SemiBold)
        }
        // 以前 Apple/Google 連携した人の復元入口(連携有効時のみ)。
        if (linking.enabled) {
            RestoreSection(palette, linking, isLinking, onRestoreApple, onRestoreGoogle)
        }
        ShareAppCard(palette)
    }
}

/** welcome の復元入口。以前連携した人が新端末/再インストールで友達/コードを取り戻す。 */
@Composable
private fun RestoreSection(
    palette: AppTheme,
    linking: FriendsLinkingHandlers,
    isLinking: Boolean,
    onRestoreApple: () -> Unit,
    onRestoreGoogle: () -> Unit,
) {
    Column(
        Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("以前連携した方はこちら", fontSize = 12.sp, color = palette.textSecondary)
        if (isLinking) {
            CircularProgressIndicator(color = palette.primary, modifier = Modifier.size(28.dp))
        } else {
            if (linking.appleEnabled) {
                OutlinedButton(onClick = onRestoreApple, modifier = Modifier.fillMaxWidth()) { Text(" Apple で復元") }
            }
            if (linking.googleEnabled) {
                OutlinedButton(onClick = onRestoreGoogle, modifier = Modifier.fillMaxWidth()) { Text("G Google で復元") }
            }
        }
    }
}

@Composable
private fun ShareAppCard(palette: AppTheme) {
    val context = LocalContext.current
    Surface(
        color = palette.surface,
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clickable {
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, "GO エクササイズで一緒に運動しよう！\nhttps://goexercise.app")
                }
                context.startActivity(Intent.createChooser(intent, "シェア"))
            },
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text("📤", fontSize = 20.sp)
            Text("このアプリを友達にシェア", fontSize = 15.sp, color = palette.textPrimary)
            Spacer(Modifier.weight(1f))
            Text("›", fontSize = 18.sp, color = palette.textSecondary)
        }
    }
}

// MARK: - Signed in

@Composable
private fun SignedInBody(
    state: FriendsUiState,
    palette: AppTheme,
    onRename: (String) -> Unit,
    onAccept: (FriendRequest) -> Unit,
    onDecline: (FriendRequest) -> Unit,
    onCheer: (CheerKind, FriendProfile, String?) -> Unit,
    onSetSort: (FriendSortOrder) -> Unit,
    onSignOut: () -> Unit,
    onOpenRanking: () -> Unit,
    onClearError: () -> Unit,
    onAddClick: () -> Unit,
    onRemove: (FriendProfile) -> Unit,
    onOpenCheerPicker: (FriendProfile) -> Unit,
    linking: FriendsLinkingHandlers = FriendsLinkingHandlers(),
    backupDismissed: Boolean = false,
    onDismissBackup: () -> Unit = {},
    onBackupApple: () -> Unit = {},
    onBackupGoogle: () -> Unit = {},
    onDeleteClick: () -> Unit = {},
    myBreed: com.goexercise.app.domain.CatBreed = com.goexercise.app.domain.CatBreed.Default,
) {
    val profile = state.profile ?: return
    // 削除進行中は他操作を不可にして競合(部分削除)を防ぐ。
    val locked = state.isDeletingAccount
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("友達", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
            Spacer(Modifier.weight(1f))
            OutlinedButton(onClick = onAddClick, enabled = !locked) { Text("＋ 追加") }
        }

        if (state.errorMessage != null) {
            ErrorBanner(state.errorMessage, palette, onClearError)
        }

        ProfileHeaderCard(profile, palette, onRename, myBreed)

        // バックアップ促し: 連携有効・未バックアップ・トリガー(友達1人以上 or 7日連続)・未dismiss。
        val showBackup = linking.enabled && !state.backupStatus.isBackedUp && !backupDismissed &&
            (state.friends.isNotEmpty() || profile.currentStreak >= 7)
        if (showBackup) {
            BackupCard(palette, linking, state.isLinkingAccount, onBackupApple, onBackupGoogle, onDismissBackup)
        }

        ShareAppCard(palette)

        if (state.requests.isNotEmpty()) {
            RequestsSection(state.requests, palette, onAccept, onDecline)
        }

        FriendsSection(state, palette, onSetSort, onOpenRanking, onCheer, onRemove, onOpenCheerPicker)

        TextButton(onClick = onSignOut, enabled = !locked, modifier = Modifier.padding(top = 12.dp)) {
            Text("サインアウト", color = palette.textSecondary, fontSize = 13.sp)
        }

        // アカウント削除(審査 5.1.1(v))。連携有効時のみ表示。
        if (linking.enabled) {
            TextButton(onClick = onDeleteClick, enabled = !locked) {
                Text(if (locked) "削除しています…" else "アカウントを削除", color = palette.primaryDeep, fontSize = 13.sp)
            }
        }
    }
}

/** 機種変でも友達を引き継ぐバックアップ促しカード。iOS backupCard 相当。 */
@Composable
private fun BackupCard(
    palette: AppTheme,
    linking: FriendsLinkingHandlers,
    isLinking: Boolean,
    onBackupApple: () -> Unit,
    onBackupGoogle: () -> Unit,
    onDismiss: () -> Unit,
) {
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("友達を機種変でも引き継ぐ", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
            Text(
                "バックアップすると、機種変更や再インストールでも友達とコードを引き継げます。メールやパスワードは不要です。",
                fontSize = 12.sp,
                color = palette.textSecondary,
            )
            if (isLinking) {
                Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = palette.primary, modifier = Modifier.size(28.dp)) }
            } else {
                if (linking.googleEnabled) {
                    Button(onClick = onBackupGoogle, colors = ButtonDefaults.buttonColors(containerColor = palette.primary), modifier = Modifier.fillMaxWidth()) {
                        Text("G Google でバックアップ", color = Color.White, fontWeight = FontWeight.SemiBold)
                    }
                }
                if (linking.appleEnabled) {
                    Button(onClick = onBackupApple, colors = ButtonDefaults.buttonColors(containerColor = palette.primary), modifier = Modifier.fillMaxWidth()) {
                        Text(" Apple でバックアップ", color = Color.White, fontWeight = FontWeight.SemiBold)
                    }
                }
                TextButton(onClick = onDismiss) { Text("あとで", color = palette.textSecondary, fontSize = 13.sp) }
            }
        }
    }
}

@Composable
private fun ProfileHeaderCard(
    profile: FriendProfile,
    palette: AppTheme,
    onRename: (String) -> Unit,
    myBreed: com.goexercise.app.domain.CatBreed = com.goexercise.app.domain.CatBreed.Default,
) {
    var showQr by remember { mutableStateOf(false) }
    var showRename by remember { mutableStateOf(false) }
    val context = LocalContext.current

    Surface(color = palette.surface, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                com.goexercise.app.ui.components.CatAvatar(breed = myBreed, size = 56.dp)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(profile.displayName, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
                        Text(
                            "✏️",
                            fontSize = 13.sp,
                            modifier = Modifier.clickable { showRename = true },
                        )
                    }
                    if (profile.username.isNotBlank()) {
                        Text("@${profile.username}", fontSize = 13.sp, color = palette.textSecondary)
                    }
                    Text("🔥 ${profile.currentStreak} 日連続", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = palette.primaryDeep)
                }
            }

            Surface(color = palette.chipBackground, shape = RoundedCornerShape(14.dp)) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("あなたの友達コード", fontSize = 12.sp, color = palette.textSecondary)
                            Text(
                                profile.friendCode,
                                fontSize = 24.sp,
                                fontWeight = FontWeight.Black,
                                fontFamily = FontFamily.Monospace,
                                color = palette.primaryDeep,
                            )
                        }
                        IconChip("📤", palette) {
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(
                                    Intent.EXTRA_TEXT,
                                    friendShareText(profile.friendCode, profile.username, profile.currentStreak),
                                )
                            }
                            context.startActivity(Intent.createChooser(intent, "友達コードを共有"))
                        }
                        Spacer(Modifier.width(8.dp))
                        IconChip(if (showQr) "🔳" else "▦", palette) { showQr = !showQr }
                    }
                    if (showQr) {
                        val qr = remember(profile.friendCode) { QrCode.generate(friendInviteUrl(profile.friendCode)) }
                        if (qr != null) {
                            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                                Surface(color = Color.White, shape = RoundedCornerShape(12.dp)) {
                                    Image(
                                        bitmap = qr,
                                        contentDescription = "友達コードの QR",
                                        modifier = Modifier.padding(8.dp).size(160.dp),
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showRename) {
        var text by remember { mutableStateOf(if (profile.displayName == FriendsViewModel.DEFAULT_DISPLAY_NAME) "" else profile.displayName) }
        ModalBottomSheet(onDismissRequest = { showRename = false }, containerColor = palette.background) {
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("表示名を変更", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
                Text("友達に表示される名前です。いつでも変更できます。", fontSize = 13.sp, color = palette.textSecondary)
                OutlinedTextField(value = text, onValueChange = { text = it }, singleLine = true, modifier = Modifier.fillMaxWidth())
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(onClick = { showRename = false }) { Text("キャンセル") }
                    Spacer(Modifier.weight(1f))
                    Button(
                        onClick = { onRename(text); showRename = false },
                        enabled = text.trim().isNotEmpty(),
                        colors = ButtonDefaults.buttonColors(containerColor = palette.primary),
                    ) { Text("変更", color = Color.White) }
                }
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

@Composable
private fun IconChip(emoji: String, palette: AppTheme, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(palette.background)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Text(emoji, fontSize = 16.sp) }
}

@Composable
private fun RequestsSection(
    requests: List<FriendRequest>,
    palette: AppTheme,
    onAccept: (FriendRequest) -> Unit,
    onDecline: (FriendRequest) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("申請が届いています (${requests.size})", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
        requests.forEach { request ->
            Surface(color = palette.surface, shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth()) {
                Row(
                    Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Avatar(palette, 36.dp)
                    Column(Modifier.weight(1f)) {
                        Text(request.fromProfile.displayName, fontSize = 15.sp, color = palette.textPrimary)
                        Text(
                            "@${request.fromProfile.username} · 🔥 ${request.fromProfile.currentStreak} 日連続",
                            fontSize = 12.sp,
                            color = palette.textSecondary,
                        )
                    }
                    Button(
                        onClick = { onAccept(request) },
                        colors = ButtonDefaults.buttonColors(containerColor = palette.primary),
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 14.dp, vertical = 6.dp),
                    ) { Text("承認", color = Color.White, fontSize = 13.sp) }
                    TextButton(onClick = { onDecline(request) }) { Text("✕", color = palette.textSecondary) }
                }
            }
        }
    }
}

@Composable
private fun FriendsSection(
    state: FriendsUiState,
    palette: AppTheme,
    onSetSort: (FriendSortOrder) -> Unit,
    onOpenRanking: () -> Unit,
    onCheer: (CheerKind, FriendProfile, String?) -> Unit,
    onRemove: (FriendProfile) -> Unit,
    onOpenCheerPicker: (FriendProfile) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("友達 (${state.friends.size})", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
            Spacer(Modifier.weight(1f))
            if (state.friends.isNotEmpty()) {
                RankingChip(palette, onOpenRanking)
                Spacer(Modifier.width(8.dp))
                SortMenu(state.sortOrder, palette, onSetSort)
            }
        }
        when {
            state.isLoading && state.friends.isEmpty() -> Box(
                Modifier.fillMaxWidth().padding(vertical = 28.dp),
                contentAlignment = Alignment.Center,
            ) { CircularProgressIndicator(color = palette.primary) }
            state.friends.isEmpty() -> FriendsEmptyState(palette)
            // 公園(猫グリッド)表示に一本化(iOS FriendsParkView パリティ)。
            // アバタータップ → 応援ピッカー / 長押し → 解除メニュー。
            else -> FriendsParkGrid(
                friends = state.sortedFriends,
                palette = palette,
                onTap = onOpenCheerPicker,
                onRemove = onRemove,
            )
        }
    }
}

/**
 * 友達を猫アバターのグリッドで並べる「公園」表示。iOS `FriendsParkView` 移植。
 * 今日達成は大きく濃く、未達成は小さく薄く。縦スクロール Column 内に置くため非 Lazy の
 * chunked Row グリッドにする(LazyVerticalGrid は無限高さでクラッシュするため使わない)。
 */
@Composable
private fun FriendsParkGrid(
    friends: List<FriendProfile>,
    palette: AppTheme,
    onTap: (FriendProfile) -> Unit,
    onRemove: (FriendProfile) -> Unit,
) {
    Surface(
        shape = RoundedCornerShape(22.dp),
        color = Color(0xFFEFF6E6), // 公園らしい淡い緑
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            friends.chunked(3).forEach { row ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    row.forEach { friend ->
                        Box(Modifier.weight(1f)) { ParkAvatar(friend, palette, onTap, onRemove) }
                    }
                    // 端数行は空セルで埋めて左寄せを保つ。
                    repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
}

@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
private fun ParkAvatar(
    friend: FriendProfile,
    palette: AppTheme,
    onTap: (FriendProfile) -> Unit,
    onRemove: (FriendProfile) -> Unit,
) {
    val context = LocalContext.current
    var showMenu by remember { mutableStateOf(false) }
    val breed = friend.myCatBreed ?: com.goexercise.app.domain.CatBreed.Default
    val active = friend.todayAchieved
    val resId = remember(breed) {
        context.resources.getIdentifier(breed.avatarAssetName, "drawable", context.packageName)
            .takeIf { it != 0 }
            ?: context.resources.getIdentifier(com.goexercise.app.domain.CatBreed.FALLBACK_AVATAR, "drawable", context.packageName)
    }
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier.combinedClickable(
            onClick = { onTap(friend) },
            onLongClick = { showMenu = true },
        ),
    ) {
        Box(contentAlignment = Alignment.TopEnd) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(76.dp)
                    .clip(CircleShape)
                    .background(Color(breed.tintArgb).copy(alpha = if (active) 0.30f else 0.18f)),
            ) {
                if (resId != 0) {
                    Image(
                        painter = painterResource(resId),
                        contentDescription = null,
                        modifier = Modifier
                            .size(if (active) 74.dp else 66.dp)
                            .clip(CircleShape)
                            .alpha(if (active) 1f else 0.72f),
                    )
                }
            }
            if (active) {
                Text("✅", fontSize = 15.sp, modifier = Modifier.offset(x = 2.dp, y = (-2).dp))
            }
        }
        Text(
            friend.displayName,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = palette.textPrimary,
            maxLines = 1,
        )
        Text("🐾 ${friend.currentStreak}", fontSize = 10.sp, fontWeight = FontWeight.Black, color = palette.primaryDeep)
        DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
            DropdownMenuItem(text = { Text("友達を解除") }, onClick = { showMenu = false; onRemove(friend) })
        }
    }
}

@Composable
private fun RankingChip(palette: AppTheme, onClick: () -> Unit) {
    Surface(
        color = palette.settingsAccent.copy(alpha = 0.18f),
        shape = RoundedCornerShape(50),
        modifier = Modifier.clickable(onClick = onClick),
    ) {
        Text(
            "🏆 順位を見る",
            fontSize = 12.sp,
            color = palette.settingsAccent,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
        )
    }
}

@Composable
private fun SortMenu(current: FriendSortOrder, palette: AppTheme, onSetSort: (FriendSortOrder) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        Surface(
            color = palette.chipBackground,
            shape = RoundedCornerShape(50),
            modifier = Modifier.clickable { expanded = true },
        ) {
            Text("⇅ ${current.label}", fontSize = 12.sp, color = palette.textPrimary, modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp))
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            FriendSortOrder.entries.forEach { order ->
                DropdownMenuItem(text = { Text(order.label) }, onClick = { onSetSort(order); expanded = false })
            }
        }
    }
}

@Composable
private fun Pill(text: String, fg: Color, bg: Color) {
    Surface(color = bg, shape = RoundedCornerShape(50)) {
        Text(text, fontSize = 12.sp, color = fg, modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp))
    }
}

@Composable
private fun Avatar(palette: AppTheme, size: androidx.compose.ui.unit.Dp) {
    Box(
        modifier = Modifier.size(size).clip(CircleShape).background(palette.primary.copy(alpha = 0.20f)),
        contentAlignment = Alignment.Center,
    ) { Text("🐱", fontSize = (size.value * 0.55f).sp) }
}

@Composable
private fun FriendsEmptyState(palette: AppTheme) {
    Surface(color = palette.surface, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth()) {
        Column(
            Modifier.padding(vertical = 28.dp, horizontal = 16.dp).fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("🐱", fontSize = 64.sp)
            Text("まだ友達がいません", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = palette.textPrimary)
            Text(
                "上の「＋ 追加」から、友達コードや QR でつながろう。\n猫があなたの友達を待っています。",
                fontSize = 12.sp,
                color = palette.textSecondary,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun ErrorBanner(message: String, palette: AppTheme, onClear: () -> Unit) {
    Surface(color = palette.chipBackground, shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("⚠️", fontSize = 16.sp)
            Text(message, fontSize = 13.sp, color = palette.textPrimary, modifier = Modifier.weight(1f))
            TextButton(onClick = onClear) { Text("閉じる", color = palette.primaryDeep, fontSize = 13.sp) }
        }
    }
}

// MARK: - Add friend sheet

/** スキャンした文字列から友達コードを抽出。goexercise://friends?code=XXX または生6桁を受理(iOS QRScannerView パリティ)。 */
private fun extractFriendCode(scanned: String): String? {
    val raw = scanned.trim()
    // 1) URL のクエリ code=
    val fromQuery = raw.substringAfter("code=", "").substringBefore("&")
    FriendCodeValidator.sanitize(fromQuery).let { if (FriendCodeValidator.isValid(it)) return it }
    // 2) 生の6桁コード
    FriendCodeValidator.sanitize(raw).let { if (FriendCodeValidator.isValid(it)) return it }
    return null
}

@Composable
private fun AddFriendSheet(
    palette: AppTheme,
    initialCode: String?,
    onSend: (String) -> Unit,
    searchResults: List<FriendProfile> = emptyList(),
    isSearching: Boolean = false,
    onSearch: (String) -> Unit = {},
) {
    var code by remember { mutableStateOf(initialCode ?: "") }
    // アプリ内QRスキャナ(#8)。読み取った goexercise://friends?code=XXX または生6桁から友達コードを抽出。
    val scanLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        com.journeyapps.barcodescanner.ScanContract(),
    ) { result ->
        result.contents?.let { extractFriendCode(it)?.let { c -> code = c } }
    }
    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("友達を追加", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
        Text("友達コードで申請を送ります。", fontSize = 13.sp, color = palette.textSecondary)
        OutlinedTextField(
            value = code,
            onValueChange = { code = FriendCodeValidator.sanitize(it) },
            label = { Text("6桁の英数字") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters),
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedButton(
            onClick = {
                scanLauncher.launch(
                    com.journeyapps.barcodescanner.ScanOptions().apply {
                        setDesiredBarcodeFormats(com.journeyapps.barcodescanner.ScanOptions.QR_CODE)
                        setPrompt("友達のQRコードを枠に合わせてください")
                        setBeepEnabled(false)
                        setOrientationLocked(false)
                    },
                )
            },
            modifier = Modifier.fillMaxWidth(),
        ) { Text("QRコードを読み取る") }
        if (code.isNotEmpty() && !FriendCodeValidator.isValid(code)) {
            Text("友達コードは 6 桁の英数字です (O / 0 / I / 1 は使われません)", fontSize = 12.sp, color = palette.textSecondary)
        }
        Button(
            onClick = { onSend(code) },
            enabled = FriendCodeValidator.isValid(code),
            colors = ButtonDefaults.buttonColors(containerColor = palette.primary),
            modifier = Modifier.fillMaxWidth(),
        ) { Text("✈ 申請を送る", color = Color.White) }

        // ユーザー名で検索(部分一致・2文字以上)。iOS FriendAddView の検索セクション パリティ。
        Spacer(Modifier.height(8.dp))
        Text("ユーザー名で検索", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
        var query by remember { mutableStateOf("") }
        OutlinedTextField(
            value = query,
            onValueChange = { query = it; onSearch(it) },
            label = { Text("ユーザー名(一部でも可)") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        if (isSearching) {
            CircularProgressIndicator(color = palette.primary, modifier = Modifier.size(20.dp))
        }
        searchResults.forEach { p ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(p.displayName, fontWeight = FontWeight.Bold, color = palette.textPrimary)
                    Text("@${p.username} · ${p.currentStreak}日連続", fontSize = 12.sp, color = palette.textSecondary)
                }
                OutlinedButton(onClick = { onSend(p.friendCode) }) { Text("申請") }
            }
        }
        if (query.trim().length >= 2 && !isSearching && searchResults.isEmpty()) {
            Text("見つかりませんでした", fontSize = 12.sp, color = palette.textSecondary)
        }
        Spacer(Modifier.height(8.dp))
    }
}

// MARK: - Cheer picker

@Composable
private fun CheerPickerSheet(friend: FriendProfile, palette: AppTheme, onSend: (CheerKind, String?) -> Unit) {
    // 一言コメント(任意・30字)。プリセットをタップすると欄に反映され、自由入力も可。
    var message by rememberSaveable { mutableStateOf("") }
    Column(
        Modifier.padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("${friend.displayName} に応援を送る", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            CheerKind.entries.forEach { kind ->
                Surface(
                    color = palette.chipBackground,
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.weight(1f).clickable { onSend(kind, message.trim().ifBlank { null }) },
                ) {
                    Column(
                        Modifier.padding(vertical = 14.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        Text(kind.emoji, fontSize = 26.sp)
                        Text(kind.label, fontSize = 12.sp, color = palette.textPrimary)
                    }
                }
            }
        }
        OutlinedTextField(
            value = message,
            onValueChange = { if (it.length <= 30) message = it },
            placeholder = { Text("一言そえる(任意・30字)", fontSize = 13.sp) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
    }
}

// MARK: - Toast

@Composable
private fun androidx.compose.foundation.layout.BoxScope.ToastOverlay(
    toast: String?,
    palette: AppTheme,
    onConsumed: () -> Unit,
) {
    if (toast != null) {
        LaunchedEffect(toast) {
            delay(2000)
            onConsumed()
        }
        Surface(
            color = palette.surface,
            shape = RoundedCornerShape(50),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 24.dp),
        ) {
            Text(toast, fontSize = 13.sp, color = palette.textPrimary, modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp))
        }
    }
}
