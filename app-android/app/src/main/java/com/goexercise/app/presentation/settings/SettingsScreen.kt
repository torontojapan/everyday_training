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
import com.goexercise.app.ui.theme.AppTheme
import com.goexercise.app.ui.theme.LocalAppPalette

@Composable
fun SettingsRoute(viewModel: SettingsViewModel = hiltViewModel()) {
    val theme by viewModel.theme.collectAsStateWithLifecycle()
    SettingsContent(selected = theme, onSelect = viewModel::setTheme)
}

@Composable
fun SettingsContent(selected: AppTheme, onSelect: (AppTheme) -> Unit = {}) {
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
        Text("テーマ", color = palette.textSecondary, fontSize = 13.sp)
        AppTheme.entries.forEach { theme ->
            ThemeRow(theme = theme, isSelected = theme == selected, onClick = { onSelect(theme) })
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
