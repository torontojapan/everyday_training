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
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.BugReport
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Celebration
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Pets
import androidx.compose.material.icons.filled.PrivacyTip
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Vibration
import androidx.compose.material.icons.filled.Widgets
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.MilitaryTech
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
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
import com.goexercise.app.ui.theme.AppType
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
    val hapticEnabled by viewModel.hapticEnabled.collectAsStateWithLifecycle()
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
        hapticEnabled = hapticEnabled,
        onToggleHaptic = viewModel::setHapticEnabled,
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
        onDeleteAccount = { viewModel.deleteAccount { ok -> deletedMsg = if (ok) "アカウントを削除しました" else "削除に失敗しました" } },
        onShareApp = {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, "GOエクササイズで一緒に運動しよう！\nhttps://play.google.com/store/apps/details?id=com.goexercise.app")
            }
            runCatching { context.startActivity(Intent.createChooser(intent, "シェア")) }
        },
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
    hapticEnabled: Boolean = true,
    onToggleHaptic: (Boolean) -> Unit = {},
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
    onDeleteAccount: () -> Unit = {},
    onShareApp: () -> Unit = {},
) {
    val palette = LocalAppPalette.current
    // iOS 設定は階層型(カスタマイズ/記録と共有/通知設定/データとプライバシー/情報・サポート/特典一覧 をサブページへ)。
    var page by rememberSaveable { mutableStateOf(SettingsPage.Main) }
    if (page != SettingsPage.Main) {
        androidx.activity.compose.BackHandler { page = SettingsPage.Main }
    }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        when (page) {
            SettingsPage.Main -> {
                Text("設定", style = AppType.screenTitle, color = palette.textPrimary, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)

                // アカウントとバックアップ(機種変更の命綱なので最上位)。
                SectionLabel("アカウントとバックアップ")
                BackupSection(
                    palette = palette, enabled = backupEnabled, syncing = backupSyncing, error = backupError,
                    hasAccount = myFriendCode != null, onToggle = onToggleBackup, onBackupNow = onBackupNow,
                    linkedProvider = linkedProvider, isLinking = isLinkingAccount, linkError = linkError,
                    onLinkApple = onLinkApple, onLinkGoogle = onLinkGoogle, onDeleteAccount = onDeleteAccount,
                )

                // プレミアム & 特典。
                SectionLabel("プレミアム & 特典")
                SettingsCard {
                    EntryRow(Icons.Filled.IosShare, "アプリを友達にシェア", onClick = onShareApp)
                    RowDivider()
                    // iOS パリティ: 加入中は「GOプレミアム 加入中」表示行(非遷移)、未加入はアップグレード行。
                    // 「14日間無料」はトライアル適格(isEligibleForIntroOffer)のときだけ出す(消化済みの誤表示防止)。
                    if (isPremium) {
                        PremiumActiveRow()
                    } else {
                        EntryRow(Icons.Filled.WorkspacePremium, "GOプレミアムにアップグレード", trailing = if (trialEligible) "14日間無料" else null, onClick = onOpenPremium)
                    }
                    RowDivider()
                    EntryRow(Icons.Filled.MilitaryTech, "プレミアム特典・称号一覧", showChevron = true) { page = SettingsPage.RankLadder }
                }
                if (com.goexercise.app.AppFeatureFlags.isReferralActive) {
                    ReferralSection(
                        palette = palette, myFriendCode = myFriendCode, starBadges = referralStarBadges,
                        canEnterCodeLater = canEnterCodeLater, onShareInvite = onShareInvite,
                        laterCode = laterCode, onLaterCodeChange = onLaterCodeChange,
                        laterSubmitting = laterSubmitting, laterAccepted = laterAccepted,
                        onSubmitLaterInvite = onSubmitLaterInvite, referralError = referralError,
                    )
                }

                // アプリ設定(各サブページへ)。
                SectionLabel("アプリ設定")
                SettingsCard {
                    EntryRow(Icons.Filled.Palette, "カスタマイズ", showChevron = true) { page = SettingsPage.Customize }
                    RowDivider()
                    EntryRow(Icons.Filled.EditNote, "記録と共有", showChevron = true) { page = SettingsPage.RecordSharing }
                    RowDivider()
                    EntryRow(Icons.Filled.Notifications, "通知設定", showChevron = true) { page = SettingsPage.Notifications }
                    RowDivider()
                    // ウィジェット追加方法(iOS パリティ)。端末のホーム長押し→ウィジェットの一般手順を案内。
                    var showWidgetHelp by remember { mutableStateOf(false) }
                    EntryRow(Icons.Filled.Widgets, "ウィジェットの追加方法を見る") { showWidgetHelp = true }
                    if (showWidgetHelp) {
                        AlertDialog(
                            onDismissRequest = { showWidgetHelp = false },
                            confirmButton = { TextButton(onClick = { showWidgetHelp = false }) { Text("閉じる") } },
                            title = { Text("ウィジェットを追加する") },
                            text = { WidgetGuideContent(palette) },
                        )
                    }
                }
                SettingsCard {
                    EntryRow(Icons.Filled.Security, "データ & プライバシー", showChevron = true) { page = SettingsPage.DataPrivacy }
                    RowDivider()
                    EntryRow(Icons.AutoMirrored.Filled.HelpOutline, "情報・サポート", showChevron = true) { page = SettingsPage.Info }
                }
            }

            SettingsPage.Customize -> SubPage("カスタマイズ", onBack = { page = SettingsPage.Main }) {
                SectionLabel("テーマカラー")
                AppTheme.entries.forEach { theme ->
                    ThemeRow(theme = theme, isSelected = theme == selected, onClick = { onSelect(theme) })
                }
                SectionLabel("自分のキャラ")
                CatBreedPicker(
                    selected = catBreed, palette = palette, isPremium = isPremium,
                    referralUnlocked = CatBreedAccess.referralUnlocked(referralStarBadges),
                    onSelect = onSelectBreed, onLockedTap = onOpenPremium,
                )
                // 達成時の振動トグル(iOS CustomizationSettingsPage の haptic-toggle)。
                SettingsCard {
                    Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon(Icons.Filled.Vibration, contentDescription = null, tint = palette.textPrimary, modifier = Modifier.size(22.dp))
                        Text("達成時の振動", style = AppType.body, color = palette.textPrimary, modifier = Modifier.weight(1f))
                        Switch(checked = hapticEnabled, onCheckedChange = onToggleHaptic)
                    }
                }
            }

            SettingsPage.RecordSharing -> SubPage("記録と共有", onBack = { page = SettingsPage.Main }) {
                // 体調・周期トグル(iOS: 「体調・周期を記録する」+ footer)。
                SettingsCard {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("体調・周期を記録する", style = AppType.headline, color = palette.textPrimary, modifier = Modifier.weight(1f))
                            Switch(checked = cycleTrackingEnabled, onCheckedChange = onToggleCycleTracking)
                        }
                        Text("ON にすると記録画面に「今日は生理日」スイッチが出て、履歴に印で表示されます。端末内のみに保存。", style = AppType.caption, color = palette.textSecondary)
                    }
                }
                // 休養ルール(展開式 4 項目。iOS RecordSharingSettingsPage の DisclosureGroup 相当)。
                RestRuleCard(palette)
            }

            SettingsPage.Notifications -> SubPage("通知設定", onBack = { page = SettingsPage.Main }) {
                ReminderSection(palette, reminder, onToggleReminder, onSetReminderTime, onSetEveningTime, onSetReminderCount, onSetReminderPersonality)
            }

            SettingsPage.DataPrivacy -> SubPage("データ & プライバシー", onBack = { page = SettingsPage.Main }) {
                SectionLabel("データ管理")
                DataManagementSection(palette, isBusy, statusMessage, onExport, onDeleteAll)
                SectionLabel("プライバシー")
                AnalyticsSection(palette, analyticsEnabled, onToggleAnalytics)
            }

            SettingsPage.Info -> SubPage("情報・サポート", onBack = { page = SettingsPage.Main }) {
                InfoSupportSection()
            }

            SettingsPage.RankLadder -> SubPage("プレミアム特典・称号一覧", onBack = { page = SettingsPage.Main }) {
                SectionLabel("プレミアム特典")
                PerkGuideSection(palette)
                SectionLabel("称号一覧(連続で進化)")
                CatRankLadderSection(palette, currentStreak)
            }
        }
    }
}

/** 設定のサブページ識別子。iOS の NavigationLink 階層に対応。 */
private enum class SettingsPage { Main, Customize, RecordSharing, Notifications, DataPrivacy, Info, RankLadder }

/** セクション見出し(iOS List のセクションヘッダ相当)。 */
@Composable
private fun SectionLabel(text: String) {
    Text(text, color = LocalAppPalette.current.textSecondary, style = AppType.caption, modifier = Modifier.padding(top = 4.dp, start = 4.dp))
}

/** カード(中に行をまとめる。iOS insetGrouped セクション相当)。 */
@Composable
private fun SettingsCard(content: @Composable ColumnScope.() -> Unit) {
    Surface(color = LocalAppPalette.current.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(content = content)
    }
}

@Composable
private fun RowDivider() {
    HorizontalDivider(color = LocalAppPalette.current.textSecondary.copy(alpha = 0.12f), modifier = Modifier.padding(start = 52.dp))
}

/** アイコン + タイトル + (任意の右側テキスト/chevron) の設定行。iOS Label 行相当。 */
@Composable
private fun EntryRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    trailing: String? = null,
    showChevron: Boolean = false,
    onClick: () -> Unit,
) {
    val palette = LocalAppPalette.current
    Row(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // iOS 設定の行アイコンは濃色(charcoal)。アクセント色にしない。
        Icon(icon, contentDescription = null, tint = palette.textPrimary, modifier = Modifier.size(22.dp))
        Text(title, style = AppType.body, color = palette.textPrimary, modifier = Modifier.weight(1f))
        trailing?.let { Text(it, style = AppType.caption, color = palette.primaryDeep) }
        if (showChevron) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = palette.textSecondary, modifier = Modifier.size(20.dp))
    }
}

/** プレミアム加入中の表示行(非遷移)。iOS の premium-active-row(crown.fill + 「GOプレミアム 加入中」)相当。 */
@Composable
private fun PremiumActiveRow() {
    val palette = LocalAppPalette.current
    Row(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Filled.WorkspacePremium, contentDescription = null, tint = palette.primary, modifier = Modifier.size(22.dp))
        Text("GOプレミアム 加入中", style = AppType.body, color = palette.textPrimary, modifier = Modifier.weight(1f))
    }
}

/** サブページの枠(戻る + タイトル + 内容)。iOS の push 画面相当。 */
@Composable
private fun SubPage(title: String, onBack: () -> Unit, content: @Composable () -> Unit) {
    val palette = LocalAppPalette.current
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier.size(36.dp).clip(androidx.compose.foundation.shape.CircleShape).background(palette.chipBackground).clickable(onClick = onBack),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る", tint = palette.primaryDeep, modifier = Modifier.size(20.dp))
        }
        Text(title, style = AppType.sectionTitle, color = palette.textPrimary)
    }
    content()
}

/** 情報・サポート(問い合わせ/アプリ情報/各種リンク)。iOS InfoSupportSettingsPage 相当。 */
@Composable
private fun InfoSupportSection() {
    val palette = LocalAppPalette.current
    val context = LocalContext.current
    fun open(url: String) { runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url))) } }
    // 問い合わせ(意見・不具合)は Google フォームへ(iOS FeedbackComposer.supportFormURL と同一)。
    val supportFormUrl = "https://forms.gle/Ljbaj4MvW2YPmyJ99"
    SettingsCard {
        EntryRow(Icons.AutoMirrored.Filled.Chat, "ご意見・ご要望を送る", showChevron = true) { open(supportFormUrl) }
        RowDivider()
        EntryRow(Icons.Filled.BugReport, "不具合を報告する", showChevron = true) { open(supportFormUrl) }
    }
    SettingsCard {
        Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("GOエクササイズ", style = AppType.body, color = palette.textPrimary, modifier = Modifier.weight(1f))
            val ver = runCatching { context.packageManager.getPackageInfo(context.packageName, 0).versionName }.getOrNull() ?: ""
            Text("v$ver", style = AppType.caption, color = palette.textSecondary)
        }
        RowDivider()
        // サブスクリプションの管理は Play ストアのサブスク画面へ(iOS は apps.apple.com/account/subscriptions)。
        EntryRow(Icons.Filled.CreditCard, "サブスクリプションを管理", showChevron = true) { open("https://play.google.com/store/account/subscriptions") }
        RowDivider()
        EntryRow(Icons.Filled.PrivacyTip, "プライバシーポリシー", showChevron = true) { open("https://torontojapan.github.io/everyday_training/privacy/") }
        RowDivider()
        EntryRow(Icons.Filled.Description, "利用規約", showChevron = true) { open("https://torontojapan.github.io/everyday_training/terms/") }
        RowDivider()
        EntryRow(Icons.AutoMirrored.Filled.HelpOutline, "サポート", showChevron = true) { open("https://torontojapan.github.io/everyday_training/support/") }
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
    onDeleteAccount: () -> Unit = {},
) {
    var confirmDelete by remember { mutableStateOf(false) }
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
            // 認証(Apple/Google でバックアップ)を設定に集約。未連携=ブランド認証ボタン / 連携済=状態表示+削除。
            if (linkedProvider != null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(Icons.Filled.Verified, contentDescription = null, tint = palette.success, modifier = Modifier.size(16.dp))
                    Text("$linkedProvider で連携済み。新しい端末で同じアカウントにサインインすると記録が戻ります。",
                        color = palette.textSecondary, fontSize = 11.sp)
                }
            } else {
                Text("機種変更で確実に復元するには Apple か Google で連携してください(連携でバックアップが自動 ON)。",
                    color = palette.textSecondary, fontSize = 11.sp)
                // ブランド準拠ボタン(Apple=黒地白文字+白ロゴ / Google=白地枠線+4色Gマーク)。iOS の AppleID/GoogleSignIn ボタン相当。
                Surface(
                    color = Color.Black, shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.fillMaxWidth().then(if (isLinking) Modifier else Modifier.clickable { onLinkApple() }),
                ) {
                    Row(
                        Modifier.fillMaxWidth().padding(vertical = 12.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        com.goexercise.app.ui.components.AppleLogo(tint = Color.White)
                        Spacer(Modifier.width(8.dp))
                        Text("Apple でサインイン", color = Color.White, fontWeight = FontWeight.SemiBold)
                    }
                }
                Surface(
                    color = palette.surface, shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.fillMaxWidth().border(1.dp, palette.textSecondary.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
                        .then(if (isLinking) Modifier else Modifier.clickable { onLinkGoogle() }),
                ) {
                    Row(
                        Modifier.fillMaxWidth().padding(vertical = 12.dp),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        com.goexercise.app.ui.components.GoogleLogo()
                        Spacer(Modifier.width(8.dp))
                        // iOS 設定は GoogleSignInButton(title: "Google で続ける")。
                        Text("Google で続ける", color = palette.textPrimary, fontWeight = FontWeight.SemiBold)
                    }
                }
                if (isLinking) CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                linkError?.let { Text(it, color = Color(0xFFD32F2F), fontSize = 12.sp) }
            }
            // アカウント削除(審査 Guideline 5.1.1(v))。iOS は profile!=nil(匿名含む)で表示 → アカウントがあれば表示。
            if (hasAccount) {
                Row(
                    Modifier.fillMaxWidth().clickable { confirmDelete = true },
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(Icons.Filled.Delete, contentDescription = null, tint = Color(0xFFD32F2F), modifier = Modifier.size(18.dp))
                    Text("アカウントを削除", color = Color(0xFFD32F2F), fontWeight = FontWeight.Bold)
                }
            }
        }
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("アカウントを削除しますか？") },
            text = { Text("アカウントとクラウドのバックアップが完全に削除され、元に戻せません。端末内の記録は残ります。") },
            confirmButton = { TextButton(onClick = { onDeleteAccount(); confirmDelete = false }) { Text("アカウントを削除", color = Color(0xFFD32F2F)) } },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("キャンセル") } },
        )
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
                                if (locked) Icon(Icons.Filled.Lock, contentDescription = "ロック中", tint = palette.textSecondary, modifier = Modifier.size(18.dp))
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

/** 休養ルール(展開式 4 項目)。iOS RecordSharingSettingsPage の DisclosureGroup「週 2 日まで…」相当。 */
@Composable
private fun RestRuleCard(palette: AppTheme) {
    var expanded by remember { mutableStateOf(false) }
    val bullets = listOf(
        "月曜〜日曜の同じ週で、達成できなかった日のうち最大 2 日を自動的に「休」と記録します。",
        "3 日目以降の未達成日は × になり、その時点で連続記録がリセットされます。",
        "既に休が割り当てられた日は履歴カレンダーで「休」と表示されます。",
        "運動不可な日が増えそうな週は、保険チケット (無料は月1回 / GOプレミアムは月4回) で別途救済できます。",
    )
    SettingsCard {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth().clickable { expanded = !expanded },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(Icons.Filled.Bedtime, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(20.dp))
                Text("週 2 日まで休んでも連続記録は続きます", style = AppType.body, color = palette.textPrimary, modifier = Modifier.weight(1f))
                Icon(
                    Icons.Filled.ExpandMore, contentDescription = null, tint = palette.textSecondary,
                    modifier = Modifier.size(20.dp).then(if (expanded) Modifier.rotate(180f) else Modifier),
                )
            }
            if (expanded) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    bullets.forEach { b ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("・", style = AppType.caption, color = palette.textSecondary)
                            Text(b, style = AppType.caption, color = palette.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

/** プレミアム特典の内訳(展開式 5 項目)。iOS PerkGuideSection 相当。 */
@Composable
private fun PerkGuideSection(palette: AppTheme) {
    var expanded by remember { mutableStateOf(false) }
    data class Perk(val icon: androidx.compose.ui.graphics.vector.ImageVector, val title: String, val detail: String)
    val perks = listOf(
        Perk(Icons.Filled.AcUnit, "保険チケット", "無料は月1 / プレミアムは月4。友達紹介で +1(上限5)。招待された人はウェルカム +1。"),
        Perk(Icons.Filled.Star, "友達紹介", "1人紹介ごとに⭐と保険チケット。⭐10個で好きな猫が無料で選べるようになります。"),
        Perk(Icons.Filled.MilitaryTech, "称号 & 背景の進化", "連続記録を続けると猫の称号が上がり(全11段)、背景も豪華に進化します。下の「称号一覧」で目標を確認できます。"),
        Perk(Icons.Filled.Pets, "猫種", "無料はオレンジ。プレミアム、または⭐10で全11種から選べます。"),
        Perk(Icons.Filled.Pets, "連続記録の節目", "連続記録のマイルストーンでお祝い演出が出ます。"), // iOS pawprint.fill
    )
    SettingsCard {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth().clickable { expanded = !expanded },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Icon(Icons.Filled.CardGiftcard, contentDescription = null, tint = palette.textPrimary, modifier = Modifier.size(20.dp))
                Text("無料でもらえる特典・達成", style = AppType.body, color = palette.textPrimary, modifier = Modifier.weight(1f))
                Icon(
                    Icons.Filled.ExpandMore, contentDescription = null, tint = palette.textSecondary,
                    modifier = Modifier.size(20.dp).then(if (expanded) Modifier.rotate(180f) else Modifier),
                )
            }
            if (expanded) {
                perks.forEach { p ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Icon(p.icon, contentDescription = null, tint = palette.primary, modifier = Modifier.size(20.dp).padding(top = 2.dp))
                        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(p.title, style = AppType.headline, color = palette.textPrimary)
                            Text(p.detail, style = AppType.caption, color = palette.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

/** ウィジェット追加ガイド(iOS WidgetSetupGuideSheet の 5 ステップ + 表示内容)。Android の追加手順に合わせた文言。 */
@Composable
private fun WidgetGuideContent(palette: AppTheme) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        val steps = listOf(
            "ホーム画面の空いている場所を長押し" to "アイコンが揺れたら編集モードです。",
            "「ウィジェット」をタップ" to "ウィジェット一覧が開きます。",
            "「GOエクササイズ」を探す" to "一覧からアプリを選びます。",
            "Small または Medium を選ぶ" to "好みのサイズを選択します。",
            "ホーム画面にドラッグして配置" to "位置はあとから自由に動かせます。",
        )
        steps.forEachIndexed { i, step ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(24.dp).clip(CircleShape).background(palette.primary), contentAlignment = Alignment.Center) {
                    Text("${i + 1}", color = Color.White, fontWeight = FontWeight.Black, fontSize = 13.sp)
                }
                Column(Modifier.weight(1f)) {
                    Text(step.first, style = AppType.body, color = palette.textPrimary)
                    Text(step.second, style = AppType.caption, color = palette.textSecondary)
                }
            }
        }
        Text("ウィジェットに表示される内容", style = AppType.headline, color = palette.textPrimary, modifier = Modifier.padding(top = 4.dp))
        listOf("今日の残り時間(深夜0時まで)", "週間達成率と進捗リング", "猫キャラのひとことメッセージ", "タップでアプリを即起動").forEach { b ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = palette.primary, modifier = Modifier.size(14.dp))
                Text(b, style = AppType.caption, color = palette.textSecondary)
            }
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
            if (isSelected) Icon(Icons.Filled.Verified, contentDescription = "選択中", tint = theme.primary, modifier = Modifier.size(20.dp))
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
                if (isBusy) {
                    CircularProgressIndicator(modifier = Modifier.size(18.dp), color = palette.primary)
                } else {
                    Icon(Icons.Filled.IosShare, contentDescription = null, tint = palette.textPrimary, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.size(8.dp))
                    Text("データを書き出す", color = palette.textPrimary)
                }
            }
            Button(
                onClick = { confirmDelete = true },
                enabled = !isBusy,
                colors = ButtonDefaults.buttonColors(containerColor = palette.chipBackground),
                modifier = Modifier.fillMaxWidth(),
            ) {
                // iOS パリティ: 破壊的操作は赤(.red)。
                Icon(Icons.Filled.Delete, contentDescription = null, tint = Color(0xFFD32F2F), modifier = Modifier.size(18.dp))
                Spacer(Modifier.size(8.dp))
                Text("すべての記録を削除", color = Color(0xFFD32F2F), fontWeight = FontWeight.Bold)
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
            confirmButton = { TextButton(onClick = { onDeleteAll(); confirmDelete = false }) { Text("削除", color = Color(0xFFD32F2F)) } },
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
                        Icon(Icons.Filled.CardGiftcard, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(22.dp))
                        Column(Modifier.weight(1f)) {
                            Text("友達を招待する", color = palette.textPrimary, fontWeight = FontWeight.Bold)
                            Text(
                                "招待コードを共有すると、お互いに保険チケットがもらえます。",
                                color = palette.textSecondary, fontSize = 12.sp,
                            )
                        }
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(18.dp))
                    }
                }
            }

            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Filled.Star, contentDescription = null, tint = Color(0xFFFFC107), modifier = Modifier.size(18.dp))
                Text("紹介した友達: ${starBadges} 人", color = palette.textPrimary, fontWeight = FontWeight.Bold)
            }

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
