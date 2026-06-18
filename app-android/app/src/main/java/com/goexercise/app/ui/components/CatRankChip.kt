package com.goexercise.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pets
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.goexercise.app.domain.CatRank
import com.goexercise.app.domain.MetalKind

/** メタリック称号チップ。rank0(連続7日未満)は何も描かない。iOS RankBadge 相当。*/
@Composable
fun CatRankChip(rank: CatRank, modifier: Modifier = Modifier, compact: Boolean = false) {
    val title = rank.title ?: return
    val metal = rank.metalKind ?: return
    val (hi, lo) = metalColors(metal)
    Row(
        modifier
            .background(Brush.linearGradient(listOf(hi, lo)), RoundedCornerShape(50))
            .border(0.75.dp, Color.White.copy(alpha = 0.6f), RoundedCornerShape(50))
            .padding(horizontal = if (compact) 8.dp else 11.dp, vertical = if (compact) 3.dp else 5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        // iOS RankBadge: 先頭に pawprint アイコン + 称号。
        Icon(
            Icons.Filled.Pets, contentDescription = null,
            tint = Color.Black.copy(alpha = 0.78f),
            modifier = Modifier.size(if (compact) 11.dp else 13.dp),
        )
        Text(
            title,
            color = Color.Black.copy(alpha = 0.78f),
            fontSize = if (compact) 11.sp else 13.sp,
            fontWeight = FontWeight.Black,
        )
    }
}

/** spec の RGB を正本にしたメタル色(明→暗の2色)。+/- は ±8% 明度。*/
private fun metalColors(kind: MetalKind): Pair<Color, Color> {
    fun c(r: Double, g: Double, b: Double, d: Double): Color {
        fun ch(v: Double) = ((v + d).coerceIn(0.0, 1.0)).toFloat()
        return Color(ch(r), ch(g), ch(b))
    }
    val v = when (kind) {
        MetalKind.Bronze -> listOf(0.74, 0.45, 0.20, 0.0)
        MetalKind.BronzePlus -> listOf(0.74, 0.45, 0.20, 0.08)
        MetalKind.Silver -> listOf(0.62, 0.66, 0.71, 0.0)
        MetalKind.SilverPlus -> listOf(0.62, 0.66, 0.71, 0.08)
        MetalKind.GoldMinus -> listOf(1.0, 0.76, 0.24, -0.06)
        MetalKind.Gold -> listOf(1.0, 0.76, 0.24, 0.0)
        MetalKind.GoldPlus -> listOf(1.0, 0.76, 0.24, 0.08)
        MetalKind.Platinum -> listOf(0.72, 0.80, 0.94, 0.0)
        MetalKind.Rainbow -> listOf(1.0, 0.76, 0.24, 0.0)
    }
    val r = v[0]; val g = v[1]; val b = v[2]; val lum = v[3]
    return c(r, g, b, lum + 0.16) to c(r, g, b, lum - 0.16)
}
