package com.goexercise.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.staticCompositionLocalOf

/**
 * iOS のカラートークンは Material3 の ColorScheme より項目が多い(restDay/missed/
 * historyAccent/settingsAccent/chipBackground/success/categoryColor 等)。そのため
 * Material3 へは中核トークンだけ写像し、**フル palette は [LocalAppPalette] 経由**で配る。
 * 画面側は `LocalAppPalette.current.restDay` のように iOS と同じ語彙で参照できる。
 */
val LocalAppPalette: ProvidableCompositionLocal<AppTheme> =
    staticCompositionLocalOf { AppTheme.Peach }

@Composable
fun GOExerciseTheme(
    theme: AppTheme = AppTheme.Peach,
    content: @Composable () -> Unit,
) {
    val scheme = if (theme.isDark) {
        darkColorScheme(
            primary = theme.primary,
            secondary = theme.secondary,
            background = theme.background,
            surface = theme.surface,
            onPrimary = theme.background,
            onBackground = theme.textPrimary,
            onSurface = theme.textPrimary,
            error = theme.missed,
        )
    } else {
        lightColorScheme(
            primary = theme.primary,
            secondary = theme.secondary,
            background = theme.background,
            surface = theme.surface,
            onPrimary = theme.surface,
            onBackground = theme.textPrimary,
            onSurface = theme.textPrimary,
            error = theme.missed,
        )
    }
    CompositionLocalProvider(LocalAppPalette provides theme) {
        MaterialTheme(
            colorScheme = scheme,
            typography = AppTypography,
            content = content,
        )
    }
}
