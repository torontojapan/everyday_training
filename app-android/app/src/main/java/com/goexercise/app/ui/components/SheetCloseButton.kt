package com.goexercise.app.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.goexercise.app.ui.theme.LocalAppPalette

/**
 * シート/詳細画面の「閉じる」ボタン。iOS 26 のナビゲーションバー・ボタンは淡いカプセル(グラス)背景で
 * 描画されるため、Android も chipBackground の丸カプセルに primaryDeep テキストで合わせる
 * (旧: 素のテキストボタン → iOS golden と不一致だった)。
 */
@Composable
fun SheetCloseButton(onClick: () -> Unit, modifier: Modifier = Modifier, label: String = "閉じる") {
    val palette = LocalAppPalette.current
    Surface(
        color = palette.chipBackground,
        shape = RoundedCornerShape(50),
        modifier = modifier.clickable(onClick = onClick),
    ) {
        Text(
            label,
            color = palette.primaryDeep,
            fontWeight = FontWeight.SemiBold,
            fontSize = 15.sp,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
        )
    }
}
