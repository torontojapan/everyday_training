package com.goexercise.app.ui.theme

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.SelfImprovement
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material.icons.filled.SportsGymnastics
import androidx.compose.ui.graphics.vector.ImageVector
import com.goexercise.app.domain.WorkoutCategory

/**
 * カテゴリ → アイコン。iOS `WorkoutCategory.symbolName`(SF Symbol)に対応する Material アイコン。
 * cardio=figure.run / strength=dumbbell.fill / yoga=figure.mind.and.body /
 * stretch=figure.cooldown / fasciaRelease=figure.flexibility / other=sparkles。
 */
fun categoryIcon(category: WorkoutCategory): ImageVector = when (category) {
    WorkoutCategory.Cardio -> Icons.Filled.DirectionsRun
    WorkoutCategory.Strength -> Icons.Filled.FitnessCenter
    WorkoutCategory.Yoga -> Icons.Filled.SelfImprovement
    WorkoutCategory.Stretch -> Icons.Filled.SportsGymnastics
    WorkoutCategory.FasciaRelease -> Icons.Filled.Spa
    WorkoutCategory.Other -> Icons.Filled.AutoAwesome
}
