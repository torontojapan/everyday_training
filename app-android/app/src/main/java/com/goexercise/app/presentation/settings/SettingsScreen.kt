package com.goexercise.app.presentation.settings

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
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
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
    SettingsContent(
        selected = theme,
        onSelect = viewModel::setTheme,
        isPremium = isPremium,
        onOpenPremium = onOpenPremium,
        catBreed = catBreed,
        onSelectBreed = viewModel::setCatBreed,
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

        Text("テーマ", color = palette.textSecondary, fontSize = 13.sp)
        AppTheme.entries.forEach { theme ->
            ThemeRow(theme = theme, isSelected = theme == selected, onClick = { onSelect(theme) })
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
