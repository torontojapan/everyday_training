package com.goexercise.app.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.goexercise.app.R

/**
 * 認証ボタン用のブランドロゴ。iOS のサインインボタン(Apple/Google マーク付き)とのパリティ。
 * - Apple: 単色マーク。背景に応じて tint(ダーク=白 / ライト=黒)。
 * - Google: 公式 4 色 "G"。ブランド規約上 tint しない固定色。
 */
@Composable
fun AppleLogo(tint: Color, size: Int = 18) {
    Icon(
        painter = painterResource(R.drawable.ic_apple_logo),
        contentDescription = null,
        tint = tint,
        modifier = Modifier.size(size.dp),
    )
}

@Composable
fun GoogleLogo(size: Int = 18) {
    Image(
        painter = painterResource(R.drawable.ic_google_g),
        contentDescription = null,
        modifier = Modifier.size(size.dp),
    )
}
