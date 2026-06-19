package com.goexercise.app.presentation.share

import androidx.compose.foundation.Image
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
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
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.MonthlyReviewBuilder
import com.goexercise.app.share.HighlightShareImageRenderer
import com.goexercise.app.ui.theme.LocalAppPalette
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** ハイライト共有画面のエントリ。VM から集計済み Review/猫種を購読して本体に渡す。 */
@Composable
fun HighlightShareRoute(
    onBack: () -> Unit = {},
    viewModel: HighlightShareViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    HighlightShareContent(
        review = state.review,
        kind = state.kind,
        breed = state.breed,
        streakLabel = state.streakLabel,
        gradient = state.gradient,
        onSelectGradient = viewModel::setGradient,
        onBack = onBack,
    )
}

/** ステートレス本体。カード画像をプレビューし、共有 chooser / 写真に保存を提供する。 */
@Composable
fun HighlightShareContent(
    review: MonthlyReviewBuilder.Review?,
    kind: HighlightShareImageRenderer.Kind,
    breed: CatBreed,
    streakLabel: String,
    gradient: com.goexercise.app.domain.ShareCardGradient? = null,
    onSelectGradient: (com.goexercise.app.domain.ShareCardGradient) -> Unit = {},
    onBack: () -> Unit = {},
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val poseSeed = rememberSaveable { (0..9999).random() }
    // 画面背景は「選択グラデ or 種別既定色」(iOS は MonthlyReviewSheet 全面が activeGradient)。
    val bgColors = (gradient?.colors ?: kind.gradient).map { androidx.compose.ui.graphics.Color(it) }

    // プレビューはコンパクトカード(iOS MonthlyReviewCard 非fillFrame)。共有/保存は別途フル全画面比。
    val preview by produceState<ImageBitmap?>(initialValue = null, review, breed, poseSeed, gradient) {
        val r = review
        value = if (r == null) null else withContext(Dispatchers.Default) {
            HighlightShareImageRenderer.render(context, r, kind, breed, streakLabel, poseSeed, gradient, HighlightShareImageRenderer.COMPACT_H).asImageBitmap()
        }
    }

    fun doSave() {
        val r = review ?: return
        scope.launch {
            val ok = HighlightShareImageRenderer.saveToGallery(context, r, kind, breed, streakLabel, poseSeed, gradient)
            android.widget.Toast.makeText(context, if (ok) "写真に保存しました" else "保存に失敗しました", android.widget.Toast.LENGTH_SHORT).show()
        }
    }
    val saveLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestPermission(),
    ) { granted -> if (granted) doSave() else android.widget.Toast.makeText(context, "保存には写真へのアクセス許可が必要です", android.widget.Toast.LENGTH_SHORT).show() }

    Box(modifier = Modifier.fillMaxSize().background(androidx.compose.ui.graphics.Brush.linearGradient(bgColors))) {
        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        ) {
            // iOS と同じく画面幅の大部分を占めるコンパクトカード(全幅)。影付き。
            preview?.let { bmp ->
                Image(
                    bitmap = bmp,
                    contentDescription = "${kind.title}のシェア画像",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxWidth().aspectRatio(1080f / HighlightShareImageRenderer.COMPACT_H)
                        .shadow(20.dp, RoundedCornerShape(32.dp)).clip(RoundedCornerShape(32.dp)),
                )
            } ?: CircularProgressIndicator(color = androidx.compose.ui.graphics.Color.White)

            // グラデ選択ドット(白縁。グラデ背景上で視認。再タップで種別既定色へ)。iOS ShareGradientPicker。
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

            if (review != null) {
                ShareCapsuleButton(text = "SNSで共有", bg = androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.45f)) {
                    scope.launch { HighlightShareImageRenderer.share(context, review, kind, breed, streakLabel, poseSeed, gradient) }
                }
                ShareCapsuleButton(text = "写真に保存", bg = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.2f)) {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q ||
                        context.checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    ) doSave() else saveLauncher.launch(android.Manifest.permission.WRITE_EXTERNAL_STORAGE)
                }
            }
        }
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
private fun ShareCapsuleButton(text: String, bg: androidx.compose.ui.graphics.Color, onClick: () -> Unit) {
    androidx.compose.material3.Surface(
        color = bg, shape = RoundedCornerShape(50),
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
    ) {
        Text(
            text, color = androidx.compose.ui.graphics.Color.White, fontWeight = FontWeight.Bold,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(vertical = 14.dp),
        )
    }
}
