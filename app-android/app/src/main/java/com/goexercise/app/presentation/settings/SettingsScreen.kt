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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.ui.components.CatAvatar
import com.goexercise.app.ui.theme.AppTheme
import com.goexercise.app.ui.theme.LocalAppPalette

@Composable
fun SettingsRoute(onOpenPremium: () -> Unit = {}, viewModel: SettingsViewModel = hiltViewModel()) {
    val theme by viewModel.theme.collectAsStateWithLifecycle()
    val isPremium by viewModel.isPremium.collectAsStateWithLifecycle()
    val catBreed by viewModel.catBreed.collectAsStateWithLifecycle()
    val isBusy by viewModel.isBusy.collectAsStateWithLifecycle()
    val reminder by viewModel.reminder.collectAsStateWithLifecycle()
    val analyticsEnabled by viewModel.analyticsEnabled.collectAsStateWithLifecycle()
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
        analyticsEnabled = analyticsEnabled,
        onToggleAnalytics = viewModel::setAnalyticsEnabled,
    )
}

@Composable
fun SettingsContent(
    selected: AppTheme,
    onSelect: (AppTheme) -> Unit = {},
    isPremium: Boolean = false,
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
    analyticsEnabled: Boolean = true,
    onToggleAnalytics: (Boolean) -> Unit = {},
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

        PremiumCard(isPremium = isPremium, palette = palette, onClick = onOpenPremium)

        Text("あなたの猫", color = palette.textSecondary, fontSize = 13.sp)
        CatBreedPicker(selected = catBreed, palette = palette, onSelect = onSelectBreed)

        Text("通知", color = palette.textSecondary, fontSize = 13.sp)
        ReminderSection(palette, reminder, onToggleReminder, onSetReminderTime)

        Text("テーマ", color = palette.textSecondary, fontSize = 13.sp)
        AppTheme.entries.forEach { theme ->
            ThemeRow(theme = theme, isSelected = theme == selected, onClick = { onSelect(theme) })
        }

        Text("データ管理", color = palette.textSecondary, fontSize = 13.sp)
        DataManagementSection(palette, isBusy, statusMessage, onExport, onDeleteAll)

        Text("プライバシー", color = palette.textSecondary, fontSize = 13.sp)
        AnalyticsSection(palette, analyticsEnabled, onToggleAnalytics)
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

/** 11 種の猫から選ぶピッカー(4 列のグリッド)。verticalScroll 内なので LazyGrid は使わず手動チャンク。 */
@Composable
private fun CatBreedPicker(selected: CatBreed, palette: AppTheme, onSelect: (CatBreed) -> Unit) {
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            CatBreed.entries.chunked(4).forEach { row ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { breed ->
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(12.dp))
                                .then(if (breed == selected) Modifier.border(2.dp, palette.primary, RoundedCornerShape(12.dp)) else Modifier)
                                .clickable { onSelect(breed) }
                                .padding(vertical = 6.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            CatAvatar(breed = breed, size = 52.dp)
                            Text(breed.displayName, color = palette.textPrimary, fontSize = 10.sp, maxLines = 1)
                        }
                    }
                    repeat(4 - row.size) { Box(Modifier.weight(1f)) }
                }
            }
        }
    }
}

@Composable
private fun PremiumCard(isPremium: Boolean, palette: AppTheme, onClick: () -> Unit) {
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
                    if (isPremium) "加入済み・全機能が使えます" else "14日間無料で全機能を解放",
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
) {
    var showTimePicker by remember { mutableStateOf(false) }
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
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("時刻", color = palette.textSecondary, fontSize = 13.sp)
                    androidx.compose.foundation.layout.Spacer(Modifier.weight(1f))
                    TextButton(onClick = { showTimePicker = true }) {
                        Text("%02d:%02d".format(reminder.hour, reminder.minute), color = palette.primaryDeep, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
    if (showTimePicker) {
        val state = rememberTimePickerState(initialHour = reminder.hour, initialMinute = reminder.minute, is24Hour = true)
        AlertDialog(
            onDismissRequest = { showTimePicker = false },
            title = { Text("通知の時刻") },
            text = { TimePicker(state = state) },
            confirmButton = { TextButton(onClick = { onSetTime(state.hour, state.minute); showTimePicker = false }) { Text("設定", color = palette.primaryDeep) } },
            dismissButton = { TextButton(onClick = { showTimePicker = false }) { Text("キャンセル") } },
            containerColor = palette.surface,
        )
    }
}
