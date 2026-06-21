package com.goexercise.app.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.goexercise.app.domain.CatRank
import com.goexercise.app.ui.theme.LocalAppPalette
import kotlinx.coroutines.delay

/**
 * 小節目(称号アップ / 週間連続)の軽量・非侵襲トースト。画面上部に半透明の角丸サーフェスで
 * 称号チップ + メッセージを出し、~2秒でフェードして自動的に閉じる。大節目シート(MilestoneCelebrationDialog)
 * とは別物で、ユーザー操作を遮らない(タップ不要・自動消滅)。iOS の控えめなランクアップ演出ミラー。
 */
@Composable
fun RankCelebrationOverlay(
    rank: CatRank,
    message: String,
    onFinished: () -> Unit,
    species: com.goexercise.app.domain.PetSpecies = com.goexercise.app.domain.PetSpecies.Cat,
) {
    val palette = LocalAppPalette.current
    var visible by remember { mutableStateOf(false) }
    val fade by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = tween(durationMillis = 320),
        label = "rankCelebrationFade",
    )
    // iOS は上から spring で「降りてくる」(offset -80→8)。Android も同じドロップインで動きを揃える。
    val dropY by animateFloatAsState(
        targetValue = if (visible) 0f else -80f,
        animationSpec = androidx.compose.animation.core.spring(
            dampingRatio = 0.7f, stiffness = androidx.compose.animation.core.Spring.StiffnessMediumLow,
        ),
        label = "rankCelebrationDrop",
    )

    LaunchedEffect(Unit) {
        visible = true
        delay(2000)
        visible = false
        delay(320) // フェードアウトを見せてから親に通知
        onFinished()
    }

    // 画面全体を覆わず、上部に幅いっぱい・高さは中身ぶんだけの帯として配置する
    // (fillMaxSize だと下部の「記録する」等のタップを奪う恐れがある。pointer modifier も付けない)。
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .wrapContentHeight()
            .padding(top = 24.dp),
        contentAlignment = Alignment.TopCenter,
    ) {
        Surface(
            color = palette.surface.copy(alpha = 0.94f),
            shape = RoundedCornerShape(50),
            shadowElevation = 6.dp,
            modifier = Modifier
                .offset(y = dropY.dp)
                .alpha(fade)
                .padding(horizontal = 20.dp),
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                if (rank.rank > 0) {
                    CatRankChip(rank = rank, compact = true, species = species)
                }
                Text(
                    text = message,
                    color = palette.textPrimary,
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp,
                )
            }
        }
    }
}
