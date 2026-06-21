package com.goexercise.app.presentation.share

import androidx.compose.foundation.Image
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.shadow
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import com.goexercise.app.domain.PetBreed
import com.goexercise.app.domain.StreakLevel
import com.goexercise.app.share.StreakShareImageRenderer
import com.goexercise.app.ui.theme.LocalAppPalette
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** シェア画面のエントリ。VM から連続日数/猫種を購読して [StreakShareContent] に渡す。 */
@Composable
fun StreakShareRoute(
    onBack: () -> Unit = {},
    viewModel: StreakShareViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    StreakShareContent(
        streak = state.streak,
        breed = state.breed,
        gradient = state.gradient,
        onSelectGradient = viewModel::setGradient,
        onBack = onBack,
    )
}

/** ステートレスなシェア本体。カード画像をプレビューし、共有 chooser を開く。 */
@Composable
fun StreakShareContent(
    streak: Int,
    breed: PetBreed,
    gradient: com.goexercise.app.domain.ShareCardGradient = com.goexercise.app.domain.ShareCardGradient.Default,
    onSelectGradient: (com.goexercise.app.domain.ShareCardGradient) -> Unit = {},
    onBack: () -> Unit = {},
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    // 提示ごとに固定のポーズ seed(プレビューと実シェアで同じハッピーポーズが出るよう共有)。
    val poseSeed = rememberSaveable { (0..9999).random() }
    val gradColors = gradient.colors.map { androidx.compose.ui.graphics.Color(it) }

    // プレビューはコンパクトカード(iOS StreakShareCard 非fillFrame ≈縦横比0.82)。共有/保存は別途フル全画面比。
    val preview by produceState<ImageBitmap?>(initialValue = null, streak, breed, poseSeed, gradient) {
        value = withContext(Dispatchers.Default) {
            StreakShareImageRenderer.render(context, streak, breed, poseSeed, gradient, StreakShareImageRenderer.COMPACT_H).asImageBitmap()
        }
    }

    fun doSave() {
        scope.launch {
            val ok = StreakShareImageRenderer.saveToGallery(context, streak, breed, poseSeed, gradient)
            android.widget.Toast.makeText(context, if (ok) "写真に保存しました" else "保存に失敗しました", android.widget.Toast.LENGTH_SHORT).show()
        }
    }
    val saveLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) doSave() else android.widget.Toast.makeText(context, "保存には写真へのアクセス許可が必要です", android.widget.Toast.LENGTH_SHORT).show()
    }

    // iOS StreakShareSheet: 画面全体が選択グラデ背景。その上にコンパクトカード + ピッカー + ボタン。
    Box(modifier = Modifier.fillMaxSize().background(androidx.compose.ui.graphics.Brush.linearGradient(gradColors))) {
        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        ) {
            // コンパクトカード(自身のグラデ範囲が背景と異なるため浮いて見える=iOS と同型)。
            // iOS と同じく画面幅の大部分を占める大きさ(全幅)。影付き。
            preview?.let { bmp ->
                Image(
                    bitmap = bmp,
                    contentDescription = "${streak}日連続のシェア画像",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxWidth().aspectRatio(1080f / StreakShareImageRenderer.COMPACT_H)
                        .shadow(20.dp, RoundedCornerShape(32.dp)).clip(RoundedCornerShape(32.dp)),
                )
            } ?: CircularProgressIndicator(color = androidx.compose.ui.graphics.Color.White)

            // SNSで共有(黒@0.45 カプセル・白文字。iOS)。
            ShareCapsuleButton(
                text = if (streak > 0) "SNSで共有" else "まず1日記録してみよう",
                bg = androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.45f),
                enabled = streak > 0,
            ) { scope.launch { StreakShareImageRenderer.share(context, streak, breed, poseSeed, gradient) } }

            // 写真に保存(白@0.2 カプセル)。iOS。
            if (streak > 0) {
                ShareCapsuleButton(text = "写真に保存", bg = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.2f)) {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q ||
                        context.checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    ) doSave() else saveLauncher.launch(android.Manifest.permission.WRITE_EXTERNAL_STORAGE)
                }
            }

            // グラデ選択ドット(白縁。グラデ背景上で視認)。iOS ShareGradientPicker は
            // 「写真に保存」の**下**に置く(2026-06-19 パリティ: 以前はボタンの上で順序が iOS と逆だった)。
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                com.goexercise.app.domain.ShareCardGradient.entries.forEach { g ->
                    Box(
                        modifier = Modifier.size(38.dp).clip(CircleShape)
                            .background(androidx.compose.ui.graphics.Brush.linearGradient(g.colors.map { androidx.compose.ui.graphics.Color(it) }))
                            .then(
                                if (g == gradient) Modifier.border(3.dp, androidx.compose.ui.graphics.Color.White, CircleShape)
                                else Modifier.border(1.dp, androidx.compose.ui.graphics.Color.White.copy(alpha = 0.5f), CircleShape),
                            )
                            .clickable { onSelectGradient(g) },
                    )
                }
            }
        }
        // X 閉じる(右上・白)。iOS closeButtonOverlay。
        Box(
            modifier = Modifier.align(Alignment.TopEnd).padding(12.dp).size(36.dp).clip(CircleShape)
                .background(androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.3f)).clickable(onClick = onBack),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Filled.Close, contentDescription = "閉じる",
                tint = androidx.compose.ui.graphics.Color.White, modifier = Modifier.size(20.dp),
            )
        }
    }
}

/** iOS 共有シートのカプセルボタン(グラデ背景上・白文字)。 */
@Composable
private fun ShareCapsuleButton(text: String, bg: androidx.compose.ui.graphics.Color, enabled: Boolean = true, onClick: () -> Unit) {
    androidx.compose.material3.Surface(
        color = if (enabled) bg else bg.copy(alpha = 0.25f),
        shape = RoundedCornerShape(50),
        modifier = Modifier.fillMaxWidth().then(if (enabled) Modifier.clickable(onClick = onClick) else Modifier),
    ) {
        Text(
            text, color = androidx.compose.ui.graphics.Color.White, fontWeight = FontWeight.Bold,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(vertical = 14.dp),
        )
    }
}
