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
import androidx.compose.foundation.text.BasicTextField
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.automirrored.filled.Sort
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Campaign
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.LocalDrink
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.ArrowCircleUp
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.PersonAddAlt1
import androidx.compose.material.icons.filled.PersonRemove
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Pets
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
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
import com.goexercise.app.ui.theme.AppType
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
    val namePromptDismissed by viewModel.namePromptDismissed.collectAsStateWithLifecycle()
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
        onCopyCode = viewModel::notifyCodeCopied,
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
        showNamePrompt = state.profile?.let { viewModel.shouldShowNamePrompt(it, namePromptDismissed) } ?: false,
        onSubmitName = viewModel::submitNamePrompt,
        onDismissNamePrompt = viewModel::dismissNamePrompt,
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
    onCopyCode: () -> Unit = {},
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
    showNamePrompt: Boolean = false,
    onSubmitName: (String) -> Unit = {},
    onDismissNamePrompt: () -> Unit = {},
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
                onCopyCode = onCopyCode,
                onAccept = onAccept,
                onDecline = onDecline,
                onCheer = onCheer,
                onSetSort = onSetSort,
                onSignOut = onSignOut,
                onOpenRanking = onOpenRanking,
                onClearError = onClearError,
                onReload = onConnect,
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
                showNamePrompt = showNamePrompt,
                onSubmitName = onSubmitName,
                onDismissNamePrompt = onDismissNamePrompt,
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
                onDismiss = { showAdd = false; onClearSearch() },
            )
        }
    }

    cheerTarget?.let { friend ->
        // iOS FriendDetailView は NavigationStack のフル画面。Android も全画面 Dialog で再現。
        androidx.compose.ui.window.Dialog(
            onDismissRequest = { cheerTarget = null },
            properties = androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false),
        ) {
            FriendDetailScreen(
                friend = friend,
                palette = palette,
                onClose = { cheerTarget = null },
                // 送信しても画面は閉じない(iOS はインライン「…を送りました」確認を出す)。
                onSend = { kind, message -> onCheer(kind, friend, message) },
                onRemove = {
                    onRemove(friend)
                    cheerTarget = null
                },
            )
        }
    }
}

/**
 * 友達詳細(全画面)。iOS FriendDetailView パリティ: hero / 今日の運動 / 今週の達成 / 統計3タイル /
 * 応援(入力欄+送信ボタン+プリセット+送信確認) / 解除。全画面 Dialog 内に表示。
 */
@Composable
private fun FriendDetailScreen(
    friend: FriendProfile,
    palette: AppTheme,
    onClose: () -> Unit,
    onSend: (CheerKind, String?) -> Unit,
    onRemove: () -> Unit,
) {
    var confirmRemove by remember { mutableStateOf(false) }
    val rank = com.goexercise.app.domain.CatRank.of(friend.currentStreak)
    val todayIdx = remember { (java.time.LocalDate.now().dayOfWeek.value - 1).coerceIn(0, 6) } // Mon=0..Sun=6
    Surface(color = palette.background, modifier = Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize()) {
            // トップバー: 中央タイトル(友達名) + 閉じる(右)。iOS navigationTitle(inline) + 閉じる。
            Box(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 12.dp)) {
                Text(friend.displayName, fontSize = 17.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary, modifier = Modifier.align(Alignment.Center))
                com.goexercise.app.ui.components.SheetCloseButton(onClick = onClose, modifier = Modifier.align(Alignment.CenterEnd))
            }
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                FriendDetailHero(friend, rank, palette)
                FriendTodayCard(friend, palette)
                // 今週の達成(本人ホーム週ストリップと同じ状態別表示 + 今日強調)。
                Surface(color = palette.surface, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("今週の達成", fontWeight = FontWeight.Bold, color = palette.textPrimary)
                            Text("${friend.weeklyStatusesOrEmpty.count { it.countsAsAchieved }} / 7 日", fontSize = 12.sp, color = palette.textSecondary)
                        }
                        FriendWeekStrip(friend.weeklyStatusesOrEmpty, todayIdx)
                    }
                }
                FriendStatsRow(friend, rank, palette)
                FriendCheerSection(friend, palette, onSend)
                Spacer(Modifier.height(4.dp))
                // 解除: bordered red + person.crop.circle.badge.minus(iOS パリティ)。
                OutlinedButton(
                    onClick = { confirmRemove = true },
                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFFD32F2F)),
                    colors = androidx.compose.material3.ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFFD32F2F)),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(Icons.Filled.PersonRemove, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.size(8.dp))
                    Text("友達を解除")
                }
            }
        }
    }
    if (confirmRemove) {
        AlertDialog(
            onDismissRequest = { confirmRemove = false },
            title = { Text("${friend.displayName} を友達から外しますか？") },
            text = { Text("再度つながるには友達コードで申請が必要です。") },
            confirmButton = { TextButton(onClick = { confirmRemove = false; onRemove() }) { Text("友達を解除", color = Color(0xFFD32F2F)) } },
            dismissButton = { TextButton(onClick = { confirmRemove = false }) { Text("キャンセル") } },
        )
    }
}

/** hero: グラデ猫アバター(132)+ 名前 + @user · friendCode(mono) + 称号バッジ + 最終更新。iOS heroHeader。 */
@Composable
private fun FriendDetailHero(friend: FriendProfile, rank: com.goexercise.app.domain.CatRank, palette: AppTheme) {
    val breed = com.goexercise.app.domain.friends.FriendAvatarResolver.resolve(friend)
    val tint = Color(breed.tintArgb)
    Surface(color = palette.surface, shape = RoundedCornerShape(24.dp), modifier = Modifier.fillMaxWidth()) {
        Column(
            Modifier.fillMaxWidth().padding(vertical = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                Modifier.size(132.dp).clip(CircleShape)
                    .background(Brush.linearGradient(listOf(tint.copy(alpha = 0.50f), tint.copy(alpha = 0.15f)))),
                contentAlignment = Alignment.Center,
            ) {
                com.goexercise.app.ui.components.CatImage(
                    breed = breed,
                    state = com.goexercise.app.domain.CatState.WaitingMorning,
                    modifier = Modifier.fillMaxSize().padding(10.dp),
                )
            }
            // iOS FriendDetailView 名前 = Typography.title(.largeTitle ~34pt)。AppType.title に一致。
            Text(friend.displayName, style = AppType.title, color = palette.textPrimary)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (friend.username.isNotBlank()) Text("@${friend.username}", fontSize = 12.sp, color = palette.textSecondary)
                Text("·", color = palette.textSecondary)
                Text(friend.friendCode, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = palette.primaryDeep, fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace)
            }
            if (rank.title != null) com.goexercise.app.ui.components.CatRankChip(rank)
            friend.lastUpdated?.let { Text("最終更新 ${relativeJa(it)}", fontSize = 12.sp, color = palette.textSecondary) }
        }
    }
}

/** 今日の運動カード。iOS todayCard: 見出し + 達成/未達成バッジ + カテゴリchip + 種目別詳細 or 名前 or fallback。 */
@Composable
private fun FriendTodayCard(friend: FriendProfile, palette: AppTheme) {
    Surface(color = palette.surface, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("今日の運動", fontWeight = FontWeight.Bold, color = palette.textPrimary, modifier = Modifier.weight(1f))
                if (friend.todayAchieved) {
                    CapsuleBadge(Icons.Filled.CheckCircle, "達成", palette.success, palette.success.copy(alpha = 0.18f))
                } else {
                    CapsuleBadge(Icons.Filled.HourglassEmpty, "未達成", palette.textSecondary, palette.chipBackground)
                }
            }
            if (friend.todayAchieved) {
                friend.todayCategoryName?.let { cat ->
                    Box(Modifier.clip(CircleShape).background(palette.chipBackground).padding(horizontal = 10.dp, vertical = 5.dp)) {
                        Text(cat, fontSize = 12.sp, color = palette.primaryDeep)
                    }
                }
                val details = friend.todayExerciseDetails
                when {
                    details != null && details.isNotEmpty() -> Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        details.forEach { d ->
                            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Box(Modifier.padding(top = 6.dp).size(6.dp).clip(CircleShape).background(palette.primary))
                                Column {
                                    Text(d.name, color = palette.textPrimary)
                                    if (d.summary.isNotEmpty()) Text(d.summary, fontSize = 12.sp, color = palette.textSecondary)
                                }
                            }
                        }
                    }
                    friend.todayExerciseNames.isNotEmpty() -> Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        friend.todayExerciseNames.forEach { name ->
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Box(Modifier.size(6.dp).clip(CircleShape).background(palette.primary))
                                Text(name, color = palette.textPrimary)
                            }
                        }
                    }
                    else -> Text("詳細は共有されていません", fontSize = 12.sp, color = palette.textSecondary)
                }
            } else {
                Text("今日はまだ運動の記録がありません", fontSize = 12.sp, color = palette.textSecondary)
            }
        }
    }
}

@Composable
private fun CapsuleBadge(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, content: Color, bg: Color) {
    Row(
        Modifier.clip(CircleShape).background(bg).padding(horizontal = 10.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(icon, contentDescription = null, tint = content, modifier = Modifier.size(14.dp))
        Text(label, fontSize = 12.sp, color = content)
    }
}

/** 統計3タイル(連続日数/累計達成日/つながって)。iOS statsCard。つながっては connectedSince があるときだけ。 */
@Composable
private fun FriendStatsRow(friend: FriendProfile, rank: com.goexercise.app.domain.CatRank, palette: AppTheme) {
    val tierColor = rank.metalKind?.let { com.goexercise.app.ui.components.metalColor(it) } ?: palette.textSecondary
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        FriendStatTile(Icons.Filled.Pets, "${friend.currentStreak}", "連続日数", palette.primaryDeep, Modifier.weight(1f), palette)
        FriendStatTile(Icons.Filled.EmojiEvents, "${friend.totalAchievedDays}", "累計達成日", tierColor, Modifier.weight(1f), palette)
        friend.connectedSince?.let { since ->
            val days = maxOf(1L, java.time.temporal.ChronoUnit.DAYS.between(since, java.time.Instant.now()))
            FriendStatTile(Icons.Filled.People, "$days", "つながって", palette.secondary, Modifier.weight(1f), palette)
        }
    }
}

@Composable
private fun FriendStatTile(icon: androidx.compose.ui.graphics.vector.ImageVector, value: String, label: String, accent: Color, modifier: Modifier, palette: AppTheme) {
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = modifier) {
        Column(Modifier.padding(vertical = 14.dp).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Icon(icon, contentDescription = null, tint = accent, modifier = Modifier.size(22.dp))
            Text(value, fontSize = 20.sp, fontWeight = FontWeight.Black, color = accent)
            Text(label, fontSize = 11.sp, color = palette.textSecondary)
        }
    }
}

/** 応援(入力欄 + 送信ボタン + 2列プリセット + 送信確認)。iOS cheerSection。プリセットは入力欄に反映、送信は↑ボタン。 */
@Composable
private fun FriendCheerSection(friend: FriendProfile, palette: AppTheme, onSend: (CheerKind, String?) -> Unit) {
    var cheerText by rememberSaveable { mutableStateOf("") }
    var sent by remember { mutableStateOf<String?>(null) }
    Surface(color = palette.surface, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("応援を送る", fontWeight = FontWeight.Bold, color = palette.textPrimary)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(
                    Modifier.weight(1f).clip(RoundedCornerShape(12.dp)).background(palette.chipBackground).padding(horizontal = 12.dp, vertical = 10.dp),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    if (cheerText.isEmpty()) Text("応援メッセージ(30字まで)", color = palette.textSecondary, fontSize = 14.sp)
                    androidx.compose.foundation.text.BasicTextField(
                        value = cheerText,
                        onValueChange = { if (it.length <= 30) cheerText = it },
                        singleLine = true,
                        textStyle = androidx.compose.ui.text.TextStyle(color = palette.textPrimary, fontSize = 14.sp),
                        cursorBrush = androidx.compose.ui.graphics.SolidColor(palette.primary),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                val canSend = cheerText.trim().isNotEmpty()
                Icon(
                    Icons.Filled.ArrowCircleUp, contentDescription = "応援を送信",
                    tint = if (canSend) palette.primary else palette.textSecondary.copy(alpha = 0.4f),
                    modifier = Modifier.size(30.dp).clip(CircleShape).clickable(enabled = canSend) {
                        val text = cheerText.trim()
                        val kind = CheerKind.entries.firstOrNull { it.label == text } ?: CheerKind.Fight
                        onSend(kind, text); sent = text; cheerText = ""
                    },
                )
            }
            CheerKind.entries.chunked(2).forEach { rowKinds ->
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    rowKinds.forEach { kind ->
                        val selected = cheerText == kind.label
                        Row(
                            Modifier.weight(1f).clip(RoundedCornerShape(14.dp))
                                .background(if (selected) palette.primary.copy(alpha = 0.18f) else palette.chipBackground)
                                .clickable { cheerText = kind.label }
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            Icon(cheerIcon(kind), contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(18.dp))
                            Text(kind.label, color = palette.textPrimary, fontSize = 14.sp)
                        }
                    }
                    if (rowKinds.size == 1) Spacer(Modifier.weight(1f))
                }
            }
            sent?.let { msg ->
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(palette.success.copy(alpha = 0.12f)).padding(10.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = palette.success, modifier = Modifier.size(16.dp))
                    Text("「$msg」を送りました", fontSize = 12.sp, color = palette.textPrimary)
                }
                LaunchedEffect(msg) { delay(2400); sent = null }
            }
        }
    }
}

/** 相対時刻(ja): N分前 / N時間前 / N日前。iOS RelativeDateTimeFormatter 相当(簡易)。 */
private fun relativeJa(instant: java.time.Instant): String {
    val sec = java.time.temporal.ChronoUnit.SECONDS.between(instant, java.time.Instant.now()).coerceAtLeast(0)
    return when {
        sec < 60 -> "たった今"
        sec < 3600 -> "${sec / 60}分前"
        sec < 86400 -> "${sec / 3600}時間前"
        else -> "${sec / 86400}日前"
    }
}

/**
 * 友達詳細の「今週の達成」週ストリップ(月→日)。本人ホーム [WeekStrip] と同じ
 * 記号(◎/○/休/×/-/・)+ [colorForStatus] の状態別配色で描画する(iOS 1.3 FriendWeekStripView パリティ)。
 * 入力は 7 要素の DailyStatus(FriendProfile.weeklyStatusesOrEmpty)。
 */
@Composable
private fun FriendWeekStrip(statuses: List<com.goexercise.app.domain.DailyStatus>, today: Int = -1) {
    val palette = LocalAppPalette.current
    val labels = listOf("月", "火", "水", "木", "金", "土", "日")
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        statuses.take(7).forEachIndexed { i, status ->
            val isToday = i == today
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                // iOS: 今日はラベルを primaryDeep 太字に。
                Text(
                    labels.getOrElse(i) { "" },
                    color = if (isToday) palette.primaryDeep else palette.textSecondary,
                    fontSize = 11.sp,
                    fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal,
                )
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        // iOS: 今日セルは primary@0.95 強調。それ以外は状態別配色。
                        .background(if (isToday) palette.primary.copy(alpha = 0.95f) else com.goexercise.app.ui.theme.colorForStatus(status)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(text = status.symbol, fontSize = 14.sp, color = if (isToday) Color.White else palette.textPrimary)
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
            modifier = Modifier.size(140.dp),
        )
        // iOS friendsWelcomeBody タイトル = Typography.title(.largeTitle ~34pt)。
        Text("友達と一緒に続けよう", style = AppType.title, color = palette.textPrimary)
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
            Icon(Icons.Filled.People, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
            Text(if (linking.enabled) "この端末で始める" else "友達とつながる", color = Color.White, fontWeight = FontWeight.SemiBold)
        }
        // iOS パリティ: バックアップ/復元は設定「アカウントとバックアップ」とオンボーディングに集約し、
        // 友達 welcome からは撤去(iOS friendsWelcomeBody は復元入口を持たない)。
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
                OutlinedButton(onClick = onRestoreApple, modifier = Modifier.fillMaxWidth()) {
                    com.goexercise.app.ui.components.AppleLogo(tint = palette.textPrimary)
                    Spacer(Modifier.width(8.dp))
                    Text("Apple で復元")
                }
            }
            if (linking.googleEnabled) {
                OutlinedButton(onClick = onRestoreGoogle, modifier = Modifier.fillMaxWidth()) {
                    com.goexercise.app.ui.components.GoogleLogo()
                    Spacer(Modifier.width(8.dp))
                    Text("Google で復元")
                }
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
            Icon(Icons.Filled.IosShare, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(20.dp))
            Text("このアプリを友達にシェア", fontSize = 15.sp, color = palette.textPrimary)
            Spacer(Modifier.weight(1f))
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = palette.textSecondary, modifier = Modifier.size(18.dp))
        }
    }
}

// MARK: - Signed in

@Composable
private fun SignedInBody(
    state: FriendsUiState,
    palette: AppTheme,
    onRename: (String) -> Unit,
    onCopyCode: () -> Unit = {},
    onAccept: (FriendRequest) -> Unit,
    onDecline: (FriendRequest) -> Unit,
    onCheer: (CheerKind, FriendProfile, String?) -> Unit,
    onSetSort: (FriendSortOrder) -> Unit,
    onSignOut: () -> Unit,
    onOpenRanking: () -> Unit,
    onClearError: () -> Unit,
    onReload: () -> Unit,
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
    showNamePrompt: Boolean = false,
    onSubmitName: (String) -> Unit = {},
    onDismissNamePrompt: () -> Unit = {},
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
        // iOS navigationTitle("友達") inline = 中央タイトル + 右上の追加アイコン(toolbar)。
        Box(Modifier.fillMaxWidth()) {
            Text("友達", style = com.goexercise.app.ui.theme.AppType.screenTitle, color = palette.textPrimary, modifier = Modifier.align(Alignment.Center))
            androidx.compose.material3.IconButton(onClick = onAddClick, enabled = !locked, modifier = Modifier.align(Alignment.CenterEnd)) {
                Icon(Icons.Filled.PersonAddAlt1, contentDescription = "友達を追加", tint = if (locked) palette.textSecondary else palette.primaryDeep)
            }
        }

        if (state.errorMessage != null) {
            ErrorBanner(state.errorMessage, palette, onClearError, onReload = onReload)
        }

        ProfileHeaderCard(profile, palette, onRename, myBreed, onCopyCode)

        // 初回のみ: 表示名を決める軽いインライン入力(スキップ可)。iOS namePromptCard(profileHeader 直下)。
        if (showNamePrompt) {
            NamePromptCard(palette, onSubmit = onSubmitName, onDismiss = onDismissNamePrompt)
        }

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

        FriendsSection(state, palette, onSetSort, onOpenRanking, onCheer, onRemove, onOpenCheerPicker, myBreed)

        // iOS build 12: サインアウトは廃止、アカウント削除は設定「アカウントとバックアップ」へ集約。
        // よって友達画面にはどちらも置かない(認証は復元のための「鍵」に過ぎないため)。
    }
}

/** 初回のみの「表示名を決めてね」インライン入力カード。iOS namePromptCard 相当。 */
@Composable
private fun NamePromptCard(palette: AppTheme, onSubmit: (String) -> Unit, onDismiss: () -> Unit) {
    var text by remember { mutableStateOf("") }
    val trimmed = text.trim()
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("表示名を決めましょう", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
            Text("友達に表示される名前です。あとからいつでも変更できます。", fontSize = 12.sp, color = palette.textSecondary)
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                singleLine = true,
                placeholder = { Text("例: ジュン", fontSize = 14.sp) },
                modifier = Modifier.fillMaxWidth(),
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onDismiss) {
                    Text("あとで", fontSize = 13.sp, color = palette.textSecondary)
                }
                Spacer(Modifier.weight(1f))
                TextButton(onClick = { onSubmit(trimmed) }, enabled = trimmed.isNotEmpty()) {
                    Text(
                        "決定",
                        fontWeight = FontWeight.SemiBold,
                        color = if (trimmed.isNotEmpty()) palette.primaryDeep else palette.textSecondary.copy(alpha = 0.4f),
                    )
                }
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
                        com.goexercise.app.ui.components.GoogleLogo()
                        Spacer(Modifier.width(8.dp))
                        Text("Google でバックアップ", color = Color.White, fontWeight = FontWeight.SemiBold)
                    }
                }
                if (linking.appleEnabled) {
                    Button(onClick = onBackupApple, colors = ButtonDefaults.buttonColors(containerColor = palette.primary), modifier = Modifier.fillMaxWidth()) {
                        com.goexercise.app.ui.components.AppleLogo(tint = Color.White)
                        Spacer(Modifier.width(8.dp))
                        Text("Apple でバックアップ", color = Color.White, fontWeight = FontWeight.SemiBold)
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
    onCopyCode: () -> Unit = {},
) {
    var showQr by remember { mutableStateOf(false) }
    var showRename by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val clipboard = androidx.compose.ui.platform.LocalClipboardManager.current

    Surface(color = palette.surface, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                com.goexercise.app.ui.components.CatAvatar(breed = myBreed, size = 56.dp)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        // iOS profileHeader は Typography.title(.largeTitle ~34pt)。AppType.title に一致させる。
                        Text(profile.displayName, style = AppType.title, color = palette.textPrimary)
                        Icon(
                            Icons.Filled.Edit, contentDescription = "名前を編集", tint = palette.textSecondary,
                            modifier = Modifier.size(16.dp).clickable { showRename = true },
                        )
                    }
                    if (profile.username.isNotBlank()) {
                        Text("@${profile.username}", fontSize = 13.sp, color = palette.textSecondary)
                    }
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Icon(Icons.Filled.Pets, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(15.dp))
                        Text("${profile.currentStreak} 日連続", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = palette.primaryDeep)
                    }
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
                        IconChip(Icons.Filled.ContentCopy, palette, "友達コードをコピー") {
                            clipboard.setText(androidx.compose.ui.text.AnnotatedString(profile.friendCode))
                            onCopyCode() // iOS: 「招待コードをコピーしました」トースト
                        }
                        Spacer(Modifier.width(8.dp))
                        IconChip(Icons.Filled.IosShare, palette, "友達コードを共有") {
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
                        IconChip(Icons.Filled.QrCode, palette, "QRコード") { showQr = !showQr }
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
                            // iOS パリティ: QR の下に読み取り手順のキャプション。
                            Text(
                                "相手のアプリの 友達 → ＋ →「QRコードを読み取る」で読んでもらうと追加できます。",
                                fontSize = 11.sp, color = palette.textSecondary, textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth(),
                            )
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

/** 応援種別 → Material アイコン。iOS CheerKind.symbolName(megaphone/bolt/waterbottle/pawprint)に対応。 */
private fun cheerIcon(kind: CheerKind): androidx.compose.ui.graphics.vector.ImageVector = when (kind) {
    CheerKind.Fight -> Icons.Filled.Campaign
    CheerKind.WontLose -> Icons.Filled.Bolt
    CheerKind.Protein -> Icons.Filled.LocalDrink
    CheerKind.CatPunch -> Icons.Filled.Pets
}

@Composable
private fun IconChip(icon: androidx.compose.ui.graphics.vector.ImageVector, palette: AppTheme, contentDescription: String?, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(palette.background)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Icon(icon, contentDescription = contentDescription, tint = palette.primaryDeep, modifier = Modifier.size(20.dp)) }
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
                    // iOS: 申請者の実猫アバター(paw プレースホルダでなく決定論的猫)。
                    com.goexercise.app.ui.components.CatAvatar(
                        breed = com.goexercise.app.domain.friends.FriendAvatarResolver.resolve(request.fromProfile),
                        size = 36.dp,
                    )
                    Column(Modifier.weight(1f)) {
                        Text(request.fromProfile.displayName, fontSize = 15.sp, color = palette.textPrimary)
                        Text(
                            "@${request.fromProfile.username} · ${request.fromProfile.currentStreak} 日連続",
                            fontSize = 12.sp,
                            color = palette.textSecondary,
                        )
                    }
                    Button(
                        onClick = { onAccept(request) },
                        colors = ButtonDefaults.buttonColors(containerColor = palette.primary),
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 14.dp, vertical = 6.dp),
                    ) { Text("承認", color = Color.White, fontSize = 13.sp) }
                    TextButton(onClick = { onDecline(request) }) { Icon(Icons.Filled.Close, contentDescription = "却下", tint = palette.textSecondary, modifier = Modifier.size(18.dp)) }
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
    myBreed: com.goexercise.app.domain.CatBreed = com.goexercise.app.domain.CatBreed.Default,
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
            state.friends.isEmpty() -> FriendsEmptyState(palette, myBreed)
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
    // 未設定は friendCode 由来の決定論的猫(iOS FriendAvatarResolver。Default 固定にしない)。
    val breed = com.goexercise.app.domain.friends.FriendAvatarResolver.resolve(friend)
    val active = friend.todayAchieved
    val resId = remember(breed) {
        context.resources.getIdentifier(breed.avatarAssetName, "drawable", context.packageName)
            .takeIf { it != 0 }
            ?: context.resources.getIdentifier(com.goexercise.app.domain.CatBreed.FALLBACK_AVATAR, "drawable", context.packageName)
    }
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
        // iOS: park の長押し解除は無い(解除は詳細から)。タップのみ。
        modifier = Modifier.clickable { onTap(friend) },
    ) {
        Box(contentAlignment = Alignment.BottomCenter, modifier = Modifier.size(width = 80.dp, height = 88.dp)) {
            // 接地の影楕円(iOS FriendsParkView の Ellipse shadow)。
            Box(
                Modifier.align(Alignment.BottomCenter).size(width = 52.dp, height = 8.dp)
                    .clip(CircleShape).background(Color.Black.copy(alpha = 0.12f)),
            )
            Box(contentAlignment = Alignment.TopEnd, modifier = Modifier.align(Alignment.TopCenter)) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(80.dp)
                        .clip(CircleShape)
                        .background(Color(breed.tintArgb).copy(alpha = if (active) 0.30f else 0.18f)),
                ) {
                    if (resId != 0) {
                        Image(
                            painter = painterResource(resId),
                            contentDescription = null,
                            modifier = Modifier
                                .size(if (active) 78.dp else 70.dp)
                                .clip(CircleShape)
                                .alpha(if (active) 1f else 0.72f),
                        )
                    }
                }
                if (active) {
                    // iOS: checkmark.seal + 白縁(背景円)。
                    Box(
                        Modifier.size(18.dp).clip(CircleShape).background(palette.background).offset(x = 2.dp, y = (-2).dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(Icons.Filled.CheckCircle, contentDescription = "今日達成", tint = palette.success, modifier = Modifier.size(15.dp))
                    }
                }
            }
        }
        Text(
            friend.displayName,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = palette.textPrimary,
            maxLines = 1,
        )
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            Icon(Icons.Filled.Pets, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(11.dp))
            Text("${friend.currentStreak}", fontSize = 10.sp, fontWeight = FontWeight.Black, color = palette.primaryDeep)
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
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Icon(Icons.Filled.EmojiEvents, contentDescription = null, tint = palette.settingsAccent, modifier = Modifier.size(14.dp))
            Text("順位を見る", fontSize = 12.sp, color = palette.settingsAccent)
        }
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
            Row(
                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(Icons.AutoMirrored.Filled.Sort, contentDescription = null, tint = palette.textPrimary, modifier = Modifier.size(14.dp))
                Text(current.label, fontSize = 12.sp, color = palette.textPrimary)
            }
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
    ) { Icon(Icons.Filled.Pets, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(size * 0.5f)) }
}

@Composable
private fun FriendsEmptyState(palette: AppTheme, myBreed: com.goexercise.app.domain.CatBreed = com.goexercise.app.domain.CatBreed.Default) {
    // iOS friendsEmptyState はカード無しの素の VStack(中央寄せ)。猫はユーザーの選択種を使う。
    Column(
        Modifier.fillMaxWidth().padding(vertical = 28.dp, horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // iOS friendsEmptyState: cat 124 + opacity 0.95 / 見出し Typography.headline(17)。
        com.goexercise.app.ui.components.CatImage(breed = myBreed, state = com.goexercise.app.domain.CatState.WaitingMorning, modifier = Modifier.size(124.dp).alpha(0.95f))
        Text("まだ友達がいません", fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = palette.textPrimary)
        Text(
            "右上の + から、友達コードでつながろう。\n猫があなたの友達を待っています。",
            fontSize = 12.sp,
            color = palette.textSecondary,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun ErrorBanner(message: String, palette: AppTheme, onClear: () -> Unit, onReload: (() -> Unit)? = null) {
    Surface(color = palette.chipBackground, shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth()) {
        // iOS errorBanner: アイコン + 縦積み(メッセージ上・更新/閉じるを下の行に)。赤を避け primaryDeep。
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Icons.Filled.Warning, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(16.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(message, fontSize = 13.sp, color = palette.textPrimary)
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    onReload?.let {
                        Text("更新", color = palette.primaryDeep, fontSize = 13.sp, modifier = Modifier.clickable(onClick = it))
                    }
                    Text("閉じる", color = palette.primaryDeep, fontSize = 13.sp, modifier = Modifier.clickable(onClick = onClear))
                }
            }
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
    onDismiss: () -> Unit = {},
) {
    var code by remember { mutableStateOf(initialCode ?: "") }
    // アプリ内QRスキャナ(#8)。読み取った goexercise://friends?code=XXX または生6桁から友達コードを抽出。
    val scanLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        com.journeyapps.barcodescanner.ScanContract(),
    ) { result ->
        result.contents?.let { extractFriendCode(it)?.let { c -> code = c } }
    }
    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        // iOS navigation inline title(中央)+ 閉じる(右・iOS26 カプセル)。
        Box(Modifier.fillMaxWidth()) {
            Text("友達を追加", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary, modifier = Modifier.align(Alignment.Center))
            com.goexercise.app.ui.components.SheetCloseButton(onClick = onDismiss, modifier = Modifier.align(Alignment.CenterEnd))
        }
        // iOS は Form の inset-grouped セクション。白カードに「入力欄/申請を送る/QR」を行で並べ、
        // hairline divider で区切る(Material の白枠 OutlinedTextField や塗りボタンは使わない=CLAUDE.md)。
        val valid = FriendCodeValidator.isValid(code)
        Text("友達コードで追加", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = palette.textSecondary)
        Surface(color = palette.surface, shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth()) {
            Column {
                // 入力欄(カード上の素のテキスト行。iOS Form TextField)。
                Box(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp), contentAlignment = Alignment.CenterStart) {
                    if (code.isEmpty()) Text("6文字の英数字 (例: ABC123)", color = palette.textSecondary, fontSize = 15.sp)
                    BasicTextField(
                        value = code,
                        onValueChange = { code = FriendCodeValidator.sanitize(it) },
                        singleLine = true,
                        textStyle = TextStyle(color = palette.textPrimary, fontSize = 15.sp),
                        cursorBrush = SolidColor(palette.primary),
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                FormRowDivider(palette)
                // 申請を送る(iOS Label paperplane.fill。コード無効時は dim=disabled)。
                FormActionRow(Icons.AutoMirrored.Filled.Send, "申請を送る", enabled = valid, palette) { if (valid) onSend(code) }
                FormRowDivider(palette)
                // QRコードを読み取る(常に活性)。
                FormActionRow(Icons.Filled.QrCode, "QRコードを読み取る", enabled = true, palette) {
                    scanLauncher.launch(
                        com.journeyapps.barcodescanner.ScanOptions().apply {
                            setDesiredBarcodeFormats(com.journeyapps.barcodescanner.ScanOptions.QR_CODE)
                            setPrompt("友達のQRコードを枠に合わせてください")
                            setBeepEnabled(false)
                            setOrientationLocked(false)
                        },
                    )
                }
            }
        }
        if (code.isNotEmpty() && !valid) {
            Text("友達コードは 6 桁の英数字です (O / 0 / I / 1 は使われません)", fontSize = 12.sp, color = palette.textSecondary)
        }

        // ユーザー名で検索(部分一致・2文字以上)。iOS FriendAddView の検索セクション パリティ。
        Spacer(Modifier.height(8.dp))
        var query by remember { mutableStateOf("") }
        var hasSearched by remember { mutableStateOf(false) }
        Text("ユーザー名で検索", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = palette.textSecondary)
        Surface(color = palette.surface, shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth()) {
            Column {
                // 入力欄 + 検索(同一行。iOS Form HStack)。
                Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                        if (query.isEmpty()) Text("ユーザー名 (一部でも可)", color = palette.textSecondary, fontSize = 15.sp)
                        BasicTextField(
                            value = query,
                            onValueChange = { query = it; if (it.trim().isEmpty()) hasSearched = false },
                            singleLine = true,
                            textStyle = TextStyle(color = palette.textPrimary, fontSize = 15.sp),
                            cursorBrush = SolidColor(palette.primary),
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                    val canSearch = query.trim().length >= 2
                    Text(
                        "検索", fontSize = 15.sp,
                        color = if (canSearch) palette.primary else palette.textSecondary.copy(alpha = 0.4f),
                        modifier = Modifier
                            .clickable(enabled = canSearch) { onSearch(query.trim()); hasSearched = true }
                            .padding(start = 12.dp),
                    )
                }
                if (isSearching) {
                    FormRowDivider(palette)
                    Box(Modifier.fillMaxWidth().padding(12.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = palette.primary, modifier = Modifier.size(20.dp))
                    }
                }
                searchResults.forEach { p ->
                    FormRowDivider(palette)
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(p.displayName, fontSize = 15.sp, color = palette.textPrimary)
                            Text("@${p.username} · ${p.currentStreak}日連続", fontSize = 12.sp, color = palette.textSecondary)
                        }
                        Text(
                            "申請", fontSize = 12.sp, color = Color.White,
                            modifier = Modifier
                                .clip(CircleShape).background(palette.primary)
                                .clickable { onSend(p.friendCode) }
                                .padding(horizontal = 12.dp, vertical = 5.dp),
                        )
                    }
                }
                if (hasSearched && query.trim().length >= 2 && !isSearching && searchResults.isEmpty()) {
                    FormRowDivider(palette)
                    Text("該当するユーザーは見つかりませんでした", fontSize = 12.sp, color = palette.textSecondary, modifier = Modifier.padding(16.dp))
                }
            }
        }
        Spacer(Modifier.height(8.dp))
    }
}

/** iOS Form の行区切り hairline(左 16dp inset)。 */
@Composable
private fun FormRowDivider(palette: AppTheme) {
    Box(Modifier.fillMaxWidth().padding(start = 16.dp).height(1.dp).background(palette.textSecondary.copy(alpha = 0.12f)))
}

/** iOS Form の Button(Label アイコン+文言・tint 色・左寄せ行)。disabled は淡色。 */
@Composable
private fun FormActionRow(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, enabled: Boolean, palette: AppTheme, onClick: () -> Unit) {
    val tint = if (enabled) palette.primary else palette.textSecondary.copy(alpha = 0.4f)
    Row(
        Modifier.fillMaxWidth().clickable(enabled = enabled, onClick = onClick).padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(18.dp))
        Text(label, fontSize = 15.sp, color = tint)
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
                        Icon(cheerIcon(kind), contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(26.dp))
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
                .padding(bottom = 64.dp), // iOS: タブバーと被らないよう 64(旧 24 は浮島タブと衝突)
        ) {
            Text(toast, fontSize = 13.sp, color = palette.textPrimary, modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp))
        }
    }
}
