package com.goexercise.app.presentation.settings

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.CatBreedAccess
import com.goexercise.app.domain.CatRank
import com.goexercise.app.ui.components.CatAvatar
import com.goexercise.app.ui.components.metalColor
import com.goexercise.app.ui.theme.AppTheme
import com.goexercise.app.ui.theme.LocalAppPalette

@Composable
fun SettingsRoute(onOpenPremium: () -> Unit = {}, viewModel: SettingsViewModel = hiltViewModel()) {
    val theme by viewModel.theme.collectAsStateWithLifecycle()
    val isPremium by viewModel.isPremium.collectAsStateWithLifecycle()
    val trialEligible by viewModel.isTrialEligible.collectAsStateWithLifecycle()
    val catBreed by viewModel.catBreed.collectAsStateWithLifecycle()
    val isBusy by viewModel.isBusy.collectAsStateWithLifecycle()
    val reminder by viewModel.reminder.collectAsStateWithLifecycle()
    val analyticsEnabled by viewModel.analyticsEnabled.collectAsStateWithLifecycle()
    val cycleTrackingEnabled by viewModel.cycleTrackingEnabled.collectAsStateWithLifecycle()
    val linkedProvider by viewModel.linkedProvider.collectAsStateWithLifecycle()
    val isLinkingAccount by viewModel.isLinkingAccount.collectAsStateWithLifecycle()
    val linkError by viewModel.linkError.collectAsStateWithLifecycle()
    val myFriendCode by viewModel.myFriendCode.collectAsStateWithLifecycle()
    val referralStarBadges by viewModel.referralStarBadges.collectAsStateWithLifecycle()
    val laterCode by viewModel.laterCode.collectAsStateWithLifecycle()
    val laterSubmitting by viewModel.laterSubmitting.collectAsStateWithLifecycle()
    val laterAccepted by viewModel.laterAccepted.collectAsStateWithLifecycle()
    val referralError by viewModel.referralError.collectAsStateWithLifecycle()
    val currentStreak by viewModel.currentStreak.collectAsStateWithLifecycle()
    val backupEnabled by viewModel.backupEnabled.collectAsStateWithLifecycle()
    val backupSyncing by viewModel.backupSyncing.collectAsStateWithLifecycle()
    val backupError by viewModel.backupError.collectAsStateWithLifecycle()
    val context = androidx.compose.ui.platform.LocalContext.current
    var deletedMsg by remember { mutableStateOf<String?>(null) }

    // Android 13+ は通知 ON 時に POST_NOTIFICATIONS を要求。許可されたら有効化する。
    val notifPermLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestPermission(),
    ) { granted -> if (granted) viewModel.setReminder(true, reminder.hour, reminder.minute) }

    SettingsContent(
        selected = theme,
        onSelect = viewModel::setTheme,
        isPremium = isPremium,
        trialEligible = trialEligible,
        onOpenPremium = onOpenPremium,
        catBreed = catBreed,
        onSelectBreed = viewModel::setCatBreed,
        isBusy = isBusy,
        statusMessage = deletedMsg,
        onExport = {
            viewModel.exportData { jsonText ->
                runCatching { shareJsonExport(context, jsonText) }
                    .onFailure { deletedMsg = "エクスポートに失敗しました" }
            }
        },
        onDeleteAll = {
            viewModel.deleteAllRecords { n -> deletedMsg = "${n} 件の記録を削除しました" }
        },
        reminder = reminder,
        onToggleReminder = { enabled ->
            if (enabled && android.os.Build.VERSION.SDK_INT >= 33 &&
                context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED
            ) {
                notifPermLauncher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
            } else {
                viewModel.setReminder(enabled, reminder.hour, reminder.minute)
            }
        },
        onSetReminderTime = { h, m -> viewModel.setReminder(reminder.enabled, h, m) },
        onSetEveningTime = viewModel::setEveningTime,
        onSetReminderCount = viewModel::setReminderCount,
        onSetReminderPersonality = viewModel::setReminderPersonality,
        analyticsEnabled = analyticsEnabled,
        onToggleAnalytics = viewModel::setAnalyticsEnabled,
        cycleTrackingEnabled = cycleTrackingEnabled,
        onToggleCycleTracking = viewModel::setCycleTrackingEnabled,
        linkedProvider = linkedProvider,
        isLinkingAccount = isLinkingAccount,
        linkError = linkError,
        onLinkApple = { viewModel.linkApple(context) },
        onLinkGoogle = { viewModel.linkGoogle(context) },
        myFriendCode = myFriendCode,
        referralStarBadges = referralStarBadges,
        canEnterCodeLater = viewModel.canEnterCodeLater,
        onShareInvite = { code ->
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, viewModel.inviteMessage(code))
            }
            context.startActivity(Intent.createChooser(intent, "友達を招待"))
        },
        laterCode = laterCode,
        onLaterCodeChange = viewModel::onLaterCodeChange,
        laterSubmitting = laterSubmitting,
        laterAccepted = laterAccepted,
        onSubmitLaterInvite = viewModel::submitLaterInvite,
        referralError = referralError,
        currentStreak = currentStreak,
        backupEnabled = backupEnabled,
        backupSyncing = backupSyncing,
        backupError = backupError,
        onToggleBackup = viewModel::setBackupEnabled,
        onBackupNow = viewModel::backupNow,
    )
}

@Composable
fun SettingsContent(
    selected: AppTheme,
    onSelect: (AppTheme) -> Unit = {},
    isPremium: Boolean = false,
    trialEligible: Boolean = false,
    onOpenPremium: () -> Unit = {},
    catBreed: CatBreed = CatBreed.Default,
    onSelectBreed: (CatBreed) -> Unit = {},
    isBusy: Boolean = false,
    statusMessage: String? = null,
    onExport: () -> Unit = {},
    onDeleteAll: () -> Unit = {},
    reminder: com.goexercise.app.data.settings.ReminderPrefs = com.goexercise.app.data.settings.ReminderPrefs(),
    onToggleReminder: (Boolean) -> Unit = {},
    onSetReminderTime: (Int, Int) -> Unit = { _, _ -> },
    onSetEveningTime: (Int, Int) -> Unit = { _, _ -> },
    onSetReminderCount: (Int) -> Unit = {},
    onSetReminderPersonality: (com.goexercise.app.domain.NotificationPersonality) -> Unit = {},
    analyticsEnabled: Boolean = true,
    onToggleAnalytics: (Boolean) -> Unit = {},
    cycleTrackingEnabled: Boolean = false,
    onToggleCycleTracking: (Boolean) -> Unit = {},
    myFriendCode: String? = null,
    referralStarBadges: Int = 0,
    canEnterCodeLater: Boolean = false,
    onShareInvite: (String) -> Unit = {},
    laterCode: String = "",
    onLaterCodeChange: (String) -> Unit = {},
    laterSubmitting: Boolean = false,
    laterAccepted: Boolean = false,
    onSubmitLaterInvite: () -> Unit = {},
    referralError: String? = null,
    currentStreak: Int = 0,
    backupEnabled: Boolean = false,
    backupSyncing: Boolean = false,
    backupError: String? = null,
    onToggleBackup: (Boolean) -> Unit = {},
    onBackupNow: () -> Unit = {},
    linkedProvider: String? = null,
    isLinkingAccount: Boolean = false,
    linkError: String? = null,
    onLinkApple: () -> Unit = {},
    onLinkGoogle: () -> Unit = {},
) {
    val palette = LocalAppPalette.current
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("設定", fontWeight = FontWeight.Bold, fontSize = 22.sp, color = palette.textPrimary)

        // アカウントとバックアップは機種変更時の命綱なので最上位に置く(iOS 設定再構成パリティ)。
        Text("アカウントとバックアップ", color = palette.textSecondary, fontSize = 13.sp)
        BackupSection(
            palette = palette,
            enabled = backupEnabled,
            syncing = backupSyncing,
            error = backupError,
            hasAccount = myFriendCode != null,
            onToggle = onToggleBackup,
            onBackupNow = onBackupNow,
            linkedProvider = linkedProvider,
            isLinking = isLinkingAccount,
            linkError = linkError,
            onLinkApple = onLinkApple,
            onLinkGoogle = onLinkGoogle,
        )

        PremiumCard(isPremium = isPremium, trialEligible = trialEligible, palette = palette, onClick = onOpenPremium)

        Text("あなたの猫", color = palette.textSecondary, fontSize = 13.sp)
        CatBreedPicker(
            selected = catBreed,
            palette = palette,
            isPremium = isPremium,
            referralUnlocked = CatBreedAccess.referralUnlocked(referralStarBadges),
            onSelect = onSelectBreed,
            onLockedTap = onOpenPremium,
        )

        Text("称号一覧（連続で進化）", color = palette.textSecondary, fontSize = 13.sp)
        CatRankLadderSection(palette, currentStreak)

        Text("通知", color = palette.textSecondary, fontSize = 13.sp)
        ReminderSection(palette, reminder, onToggleReminder, onSetReminderTime, onSetEveningTime, onSetReminderCount, onSetReminderPersonality)

        if (com.goexercise.app.AppFeatureFlags.isReferralActive) {
            Text("友達を招待", color = palette.textSecondary, fontSize = 13.sp)
            ReferralSection(
                palette = palette,
                myFriendCode = myFriendCode,
                starBadges = referralStarBadges,
                canEnterCodeLater = canEnterCodeLater,
                onShareInvite = onShareInvite,
                laterCode = laterCode,
                onLaterCodeChange = onLaterCodeChange,
                laterSubmitting = laterSubmitting,
                laterAccepted = laterAccepted,
                onSubmitLaterInvite = onSubmitLaterInvite,
                referralError = referralError,
            )
        }

        Text("テーマ", color = palette.textSecondary, fontSize = 13.sp)
        AppTheme.entries.forEach { theme ->
            ThemeRow(theme = theme, isSelected = theme == selected, onClick = { onSelect(theme) })
        }

        Text("データ管理", color = palette.textSecondary, fontSize = 13.sp)
        DataManagementSection(palette, isBusy, statusMessage, onExport, onDeleteAll)

        Text("プライバシー", color = palette.textSecondary, fontSize = 13.sp)
        AnalyticsSection(palette, analyticsEnabled, onToggleAnalytics)

        // 生理周期トラッキングのオプトイン(既定 OFF・プライバシー優先)。ON で体重タブに生理日記録 UI を出す。
        Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
            Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("生理周期トラッキング", color = palette.textPrimary, fontWeight = FontWeight.Bold)
                    Text(
                        "ON にすると体重タブに生理日の記録と周期オーバーレイが表示されます。端末内のみに保存。",
                        color = palette.textSecondary, fontSize = 12.sp,
                    )
                }
                Switch(checked = cycleTrackingEnabled, onCheckedChange = onToggleCycleTracking)
            }
        }
    }
}

/**
 * 記録のクラウドバックアップ(オプトイン)+ 機種変更復元の案内。iOS 設定の同セクション移植。
 * Apple/Google 連携(復元の鍵)は友達タブの連携 UI と同じアカウントを共有する。
 */
@Composable
private fun BackupSection(
    palette: AppTheme,
    enabled: Boolean,
    syncing: Boolean,
    error: String?,
    hasAccount: Boolean,
    onToggle: (Boolean) -> Unit,
    onBackupNow: () -> Unit,
    linkedProvider: String? = null,
    isLinking: Boolean = false,
    linkError: String? = null,
    onLinkApple: () -> Unit = {},
    onLinkGoogle: () -> Unit = {},
) {
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("記録をクラウドにバックアップ", color = palette.textPrimary, fontWeight = FontWeight.Bold)
                    Text(
                        "運動・体重・体調の記録をあなたのアカウントに保存し、機種変更(Android↔iPhone)や再インストールで復元できます。友達には共有されません。",
                        color = palette.textSecondary, fontSize = 12.sp,
                    )
                }
                Switch(checked = enabled, onCheckedChange = onToggle)
            }
            if (enabled) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable(enabled = !syncing) { onBackupNow() },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("今すぐバックアップ", color = palette.textPrimary)
                    Spacer(Modifier.weight(1f))
                    if (syncing) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                    }
                }
                error?.let { Text(it, color = Color(0xFFD32F2F), fontSize = 12.sp) }
            }
            // 認証(Apple/Google でバックアップ)を設定に集約(#14)。未連携=サインインボタン / 連携済=状態表示。
            if (linkedProvider != null) {
                Text("✓ $linkedProvider で連携済み。新しい端末で同じアカウントにサインインすると記録が戻ります。",
                    color = palette.textSecondary, fontSize = 11.sp)
            } else {
                Text("機種変更で確実に復元するには Apple か Google で連携してください(連携でバックアップが自動 ON)。",
                    color = palette.textSecondary, fontSize = 11.sp)
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = onLinkApple, enabled = !isLinking, modifier = Modifier.weight(1f)) {
                        Text("Apple で連携")
                    }
                    OutlinedButton(onClick = onLinkGoogle, enabled = !isLinking, modifier = Modifier.weight(1f)) {
                        Text("Google で連携")
                    }
                }
                if (isLinking) CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                linkError?.let { Text(it, color = Color(0xFFD32F2F), fontSize = 12.sp) }
            }
        }
    }
}

/** 匿名の利用状況分析(TelemetryDeck)の共有 ON/OFF。既定 ON・いつでもオプトアウト可。個人特定なし。 */
@Composable
private fun AnalyticsSection(palette: AppTheme, enabled: Boolean, onToggle: (Boolean) -> Unit) {
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("利用状況の分析を共有", color = palette.textPrimary, fontWeight = FontWeight.Bold)
                Text(
                    "アプリ改善のための匿名の利用データ(個人を特定しません)。OFF にすると一切送信しません。",
                    color = palette.textSecondary, fontSize = 12.sp,
                )
            }
            Switch(checked = enabled, onCheckedChange = onToggle)
        }
    }
}

/**
 * 11 種の猫から選ぶピッカー(4 列のグリッド)。verticalScroll 内なので LazyGrid は使わず手動チャンク。
 * 課金/紹介ゲート: 非プレミアムかつ紹介⭐<10 のとき「今の猫」以外はロック(淡色+🔒)、
 * ロック猫タップはペイウォールへ誘導(iOS UserCatPickerView パリティ)。
 */
@Composable
private fun CatBreedPicker(
    selected: CatBreed,
    palette: AppTheme,
    isPremium: Boolean,
    referralUnlocked: Boolean,
    onSelect: (CatBreed) -> Unit,
    onLockedTap: () -> Unit,
) {
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            CatBreed.entries.chunked(4).forEach { row ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { breed ->
                        val locked = CatBreedAccess.isLocked(breed, selected, isPremium, referralUnlocked)
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(12.dp))
                                .then(if (breed == selected) Modifier.border(2.dp, palette.primary, RoundedCornerShape(12.dp)) else Modifier)
                                .clickable { if (locked) onLockedTap() else onSelect(breed) }
                                .padding(vertical = 6.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                CatAvatar(breed = breed, size = 52.dp, modifier = Modifier.alpha(if (locked) 0.4f else 1f))
                                if (locked) Text("🔒", fontSize = 18.sp)
                            }
                            Text(breed.displayName, color = palette.textPrimary, fontSize = 10.sp, maxLines = 1)
                        }
                    }
                    repeat(4 - row.size) { Box(Modifier.weight(1f)) }
                }
            }
        }
    }
}

/**
 * 称号一覧（連続記録で進化する全11段）。iOS `CatRankGuideView` の移植。
 * 先頭に次目標ヒント（最高位なら賞賛）、各段はメタルドット + 称号名 + 到達日数。
 * 現在の称号に「いま」バッジ、到達済みは強調。目標を可視化して前進動機を作る。
 */
@Composable
private fun CatRankLadderSection(palette: AppTheme, currentStreak: Int) {
    val currentRank = CatRank.of(currentStreak).rank
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            // 次の目標（最高位なら賞賛）
            if (currentRank >= CatRank.thresholds.size) {
                Text(
                    "最高位「ぬしネコ」を達成！",
                    color = palette.primaryDeep,
                    fontWeight = FontWeight.Bold,
                    fontSize = 12.sp,
                )
            } else {
                val nextThreshold = CatRank.thresholds[currentRank]
                val nextTitle = CatRank.of(nextThreshold).title ?: ""
                val remaining = (nextThreshold - currentStreak).coerceAtLeast(0)
                Text(
                    "連続記録を続けると称号が進化。次は「$nextTitle」まで あと${remaining}日！",
                    color = palette.primaryDeep,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 12.sp,
                )
            }
            CatRank.thresholds.forEachIndexed { idx, threshold ->
                val rank = idx + 1
                val entry = CatRank.of(threshold)
                val isCurrent = rank == currentRank
                val achieved = currentStreak >= threshold
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        modifier = Modifier
                            .size(15.dp)
                            .clip(CircleShape)
                            .background(entry.metalKind?.let { metalColor(it) } ?: palette.textSecondary)
                            .border(0.5.dp, Color.White.copy(alpha = 0.55f), CircleShape),
                    )
                    Text(
                        entry.title ?: "",
                        color = if (achieved || isCurrent) palette.textPrimary else palette.textSecondary,
                        fontWeight = if (isCurrent) FontWeight.Black else FontWeight.SemiBold,
                        fontSize = 14.sp,
                        modifier = Modifier.padding(start = 10.dp),
                    )
                    if (isCurrent) {
                        Text(
                            "いま",
                            color = Color.White,
                            fontWeight = FontWeight.Black,
                            fontSize = 10.sp,
                            modifier = Modifier
                                .padding(start = 6.dp)
                                .background(palette.primary, RoundedCornerShape(50))
                                .padding(horizontal = 6.dp, vertical = 2.dp),
                        )
                    }
                    Box(Modifier.weight(1f))
                    Text(
                        "${threshold}日",
                        color = if (achieved) palette.primaryDeep else palette.textSecondary,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                    )
                }
            }
        }
    }
}

@Composable
private fun PremiumCard(isPremium: Boolean, trialEligible: Boolean, palette: AppTheme, onClick: () -> Unit) {
    Surface(
        color = palette.surface,
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, palette.primary.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("👑", fontSize = 22.sp)
            Column(Modifier.weight(1f)) {
                Text("GOプレミアム", color = palette.textPrimary, fontWeight = FontWeight.Bold)
                Text(
                    // トライアル消化済みは「14日間無料」を出さない(誤表示=審査リスク。Codex R4)。
                    when {
                        isPremium -> "加入済み・全機能が使えます"
                        trialEligible -> "14日間無料で全機能を解放"
                        else -> "全機能を解放"
                    },
                    color = palette.textSecondary,
                    fontSize = 12.sp,
                )
            }
            Text(if (isPremium) "✓" else "›", color = palette.primaryDeep, fontWeight = FontWeight.Bold, fontSize = 16.sp)
        }
    }
}

@Composable
private fun ThemeRow(theme: AppTheme, isSelected: Boolean, onClick: () -> Unit) {
    val palette = LocalAppPalette.current
    Surface(
        color = palette.surface,
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .then(
                if (isSelected) Modifier.border(2.dp, theme.primary, RoundedCornerShape(16.dp)) else Modifier,
            ),
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // テーマの primary/secondary/background をスウォッチで提示。
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Swatch(theme.primary)
                Swatch(theme.secondary)
                Swatch(theme.background)
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(theme.displayName, color = palette.textPrimary, fontWeight = FontWeight.Bold)
                Text(theme.hint, color = palette.textSecondary, fontSize = 12.sp)
            }
            if (isSelected) Text("✓", color = theme.primary, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun Swatch(color: Color) {
    Box(
        modifier = Modifier
            .size(20.dp)
            .clip(CircleShape)
            .background(color)
            .border(1.dp, Color(0x22000000), CircleShape),
    )
}

/** データのエクスポート / 全削除。審査の「ユーザーデータ削除」要件に対応(課金状態は対象外)。 */
@Composable
private fun DataManagementSection(
    palette: AppTheme,
    isBusy: Boolean,
    statusMessage: String?,
    onExport: () -> Unit,
    onDeleteAll: () -> Unit,
) {
    var confirmDelete by remember { mutableStateOf(false) }
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("運動・体重・体調の記録を JSON で書き出したり、すべて削除できます(課金状態は削除されません)。",
                fontSize = 12.sp, color = palette.textSecondary)
            OutlinedButton(onClick = onExport, enabled = !isBusy, modifier = Modifier.fillMaxWidth()) {
                if (isBusy) CircularProgressIndicator(modifier = Modifier.size(18.dp), color = palette.primary)
                else Text("📤 データをエクスポート", color = palette.textPrimary)
            }
            Button(
                onClick = { confirmDelete = true },
                enabled = !isBusy,
                colors = ButtonDefaults.buttonColors(containerColor = palette.chipBackground),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("🗑 すべての記録を削除", color = palette.primaryDeep, fontWeight = FontWeight.Bold)
            }
            if (statusMessage != null) {
                Text(statusMessage, fontSize = 12.sp, color = palette.primaryDeep)
            }
        }
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("すべての記録を削除しますか？") },
            text = { Text("運動・体重・体調の記録がすべて削除され、元に戻せません。事前にエクスポートをおすすめします。") },
            confirmButton = { TextButton(onClick = { onDeleteAll(); confirmDelete = false }) { Text("削除", color = palette.primaryDeep) } },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("キャンセル") } },
            containerColor = palette.surface,
        )
    }
}

/** 友達を招待: 共有(招待コード入り)/ 星バッジ数 / 後から招待コードを入力(初回7日以内)。 */
@Composable
private fun ReferralSection(
    palette: AppTheme,
    myFriendCode: String?,
    starBadges: Int,
    canEnterCodeLater: Boolean,
    onShareInvite: (String) -> Unit,
    laterCode: String,
    onLaterCodeChange: (String) -> Unit,
    laterSubmitting: Boolean,
    laterAccepted: Boolean,
    onSubmitLaterInvite: () -> Unit,
    referralError: String?,
) {
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // 招待コードが取れている時だけ共有行を出す(プロフィール取得前は非表示)。
            myFriendCode?.let { code ->
                Surface(
                    color = palette.surface,
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.dp, palette.primary.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
                        .clickable { onShareInvite(code) },
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Text("🎁", fontSize = 22.sp)
                        Column(Modifier.weight(1f)) {
                            Text("友達を招待する", color = palette.textPrimary, fontWeight = FontWeight.Bold)
                            Text(
                                "招待コードを共有すると、お互いに保険チケットがもらえます。",
                                color = palette.textSecondary, fontSize = 12.sp,
                            )
                        }
                        Text("›", color = palette.primaryDeep, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    }
                }
            }

            Text("⭐ 紹介した友達: ${starBadges} 人", color = palette.textPrimary, fontWeight = FontWeight.Bold)

            if (canEnterCodeLater) {
                if (laterAccepted) {
                    Text("招待コードを適用しました！", color = palette.primaryDeep, fontSize = 13.sp)
                } else {
                    com.goexercise.app.presentation.referral.InviteCodeField(
                        code = laterCode,
                        onCodeChange = onLaterCodeChange,
                        isSubmitting = laterSubmitting,
                        onSubmit = onSubmitLaterInvite,
                    )
                    referralError?.let { Text(it, color = palette.primaryDeep, fontSize = 12.sp) }
                }
            }
        }
    }
}

/** エクスポート JSON を cache/shared に書き出し、FileProvider 経由で共有する。 */
private fun shareJsonExport(context: Context, jsonText: String) {
    val dir = java.io.File(context.cacheDir, "shared").apply { mkdirs() }
    // 過去のエクスポート(プレーンな個人データ)を cache に溜めないよう、書き出し前に古い分を消す。
    dir.listFiles { f -> f.name.startsWith("goexercise-data-") }?.forEach { it.delete() }
    val file = java.io.File(dir, "goexercise-data-${System.currentTimeMillis()}.json")
    file.writeText(jsonText)
    val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "application/json"
        putExtra(Intent.EXTRA_STREAM, uri)
        // ClipData を付けないと chooser(intentresolver)のプレビューが URI を読めず Permission Denial になる。
        clipData = android.content.ClipData.newRawUri("export", uri)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    context.startActivity(Intent.createChooser(intent, "データをエクスポート"))
}

/** 毎日のリマインダー(ON/OFF + 時刻)。ON は通知権限取得後に有効化される(Route 側で要求)。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReminderSection(
    palette: AppTheme,
    reminder: com.goexercise.app.data.settings.ReminderPrefs,
    onToggle: (Boolean) -> Unit,
    onSetTime: (Int, Int) -> Unit,
    onSetEveningTime: (Int, Int) -> Unit = { _, _ -> },
    onSetCount: (Int) -> Unit = {},
    onSetPersonality: (com.goexercise.app.domain.NotificationPersonality) -> Unit = {},
) {
    var picker by remember { mutableStateOf<String?>(null) } // "morning" / "evening" / null
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("毎日のリマインダー", color = palette.textPrimary, fontWeight = FontWeight.Bold)
                    Text("運動を続けるための通知", color = palette.textSecondary, fontSize = 12.sp)
                }
                Switch(checked = reminder.enabled, onCheckedChange = onToggle)
            }
            if (reminder.enabled) {
                // 通知回数(1日1回=朝のみ / 2回=朝+夕)。
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("通知回数", color = palette.textSecondary, fontSize = 13.sp)
                    androidx.compose.foundation.layout.Spacer(Modifier.weight(1f))
                    listOf(1 to "1日1回", 2 to "1日2回").forEach { (c, label) ->
                        val sel = reminder.count == c
                        Surface(
                            color = if (sel) palette.primary else palette.chipBackground,
                            shape = RoundedCornerShape(50),
                            modifier = Modifier.padding(start = 6.dp).clickable { onSetCount(c) },
                        ) {
                            Text(label, fontSize = 12.sp, color = if (sel) androidx.compose.ui.graphics.Color.White else palette.textPrimary, modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp))
                        }
                    }
                }
                // 朝(1本目)時刻。
                ReminderTimeRow("通知時間1", reminder.hour, reminder.minute, palette) { picker = "morning" }
                // 夕(2本目)時刻 — 2回のときのみ。
                if (reminder.count > 1) {
                    ReminderTimeRow("通知時間2", reminder.eveningHour, reminder.eveningMinute, palette) { picker = "evening" }
                }
                // 性格(quiet/voice/friendDriven)。
                Text("通知の性格", color = palette.textSecondary, fontSize = 13.sp)
                com.goexercise.app.domain.NotificationPersonality
                    .visibleCases(com.goexercise.app.AppFeatureFlags.FRIENDS_ENABLED)
                    .forEach { p ->
                        val sel = reminder.personality == p
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth().clickable { onSetPersonality(p) }.padding(vertical = 4.dp),
                        ) {
                            androidx.compose.material3.RadioButton(selected = sel, onClick = { onSetPersonality(p) })
                            Column {
                                Text(p.displayName, color = palette.textPrimary, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                                Text(p.hint, color = palette.textSecondary, fontSize = 11.sp)
                            }
                        }
                    }
            }
        }
    }
    picker?.let { which ->
        val isMorning = which == "morning"
        val h = if (isMorning) reminder.hour else reminder.eveningHour
        val m = if (isMorning) reminder.minute else reminder.eveningMinute
        val state = rememberTimePickerState(initialHour = h, initialMinute = m, is24Hour = true)
        AlertDialog(
            onDismissRequest = { picker = null },
            title = { Text(if (isMorning) "通知時間1" else "通知時間2") },
            text = { TimePicker(state = state) },
            confirmButton = {
                TextButton(onClick = {
                    if (isMorning) onSetTime(state.hour, state.minute) else onSetEveningTime(state.hour, state.minute)
                    picker = null
                }) { Text("設定", color = palette.primaryDeep) }
            },
            dismissButton = { TextButton(onClick = { picker = null }) { Text("キャンセル") } },
            containerColor = palette.surface,
        )
    }
}

@Composable
private fun ReminderTimeRow(label: String, hour: Int, minute: Int, palette: AppTheme, onClick: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, color = palette.textSecondary, fontSize = 13.sp)
        androidx.compose.foundation.layout.Spacer(Modifier.weight(1f))
        TextButton(onClick = onClick) {
            Text("%02d:%02d".format(hour, minute), color = palette.primaryDeep, fontWeight = FontWeight.Bold)
        }
    }
}
