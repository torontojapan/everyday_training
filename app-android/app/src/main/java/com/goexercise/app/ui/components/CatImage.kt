package com.goexercise.app.ui.components

import android.content.Context
import android.os.Build
import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.CatState

/**
 * ユーザーの猫(breed × state = 77 画像のうち 1 枚)を描画する。iOS `CatStateView` 相当。
 * drawable は `getIdentifier` で動的解決し、欠損時は **orange の同 state → 既定アバター**へフォールバック
 * (iOS の fallbackAssetName と同方針。生成漏れでも「画像が出ない」を防ぐ)。
 *
 * 注意: `getIdentifier` 解決の drawable は R8 で strip され得るため、minify 有効化時(#10/Release)は
 * `cat_*` の keep ルールが必要。
 */
@Composable
fun CatImage(
    breed: CatBreed,
    state: CatState,
    modifier: Modifier = Modifier,
    contentDescription: String? = state.displayName,
    useShaker: Boolean = false,
) {
    val context = LocalContext.current
    val resId = remember(breed, state, useShaker) {
        if (useShaker) resolveShakerDrawable(context, breed) else resolveCatDrawable(context, breed, state)
    }
    if (resId != 0) {
        val painter = painterResource(resId)
        // iOS catSilhouetteContrast 相当: どのテーマ背景でもシルエットを立たせる二重影。
        // 暗シャドウ=明テーマ(白猫など)での分離 / 白グロー=暗(midnight)テーマ(黒・ハチワレ)での分離。
        // 同じ painter を tint して描くので猫の alpha 形状に沿う(矩形影にならない)。
        // **blur は API31+ のみ有効**(RenderEffect)。API26-30 では blur が無視され「硬い」シルエットに
        // なり parity が崩れる(Codex 指摘)ため、ソフト影が出せる端末だけ適用し、旧端末は素の画像にする。
        // 注: matchParentSize は Box の自前サイズ(呼び出し側が .size()/.fillMaxSize() を渡す前提)に追従する。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Box(modifier, contentAlignment = Alignment.Center) {
                Image(
                    painter = painter,
                    contentDescription = null,
                    contentScale = ContentScale.Fit,
                    colorFilter = ColorFilter.tint(Color.White),
                    modifier = Modifier.matchParentSize().alpha(0.5f).blur(3.dp), // 暗背景での分離
                )
                Image(
                    painter = painter,
                    contentDescription = null,
                    contentScale = ContentScale.Fit,
                    colorFilter = ColorFilter.tint(Color.Black),
                    modifier = Modifier.matchParentSize().offset(y = 1.5.dp).alpha(0.22f).blur(3.dp), // 明背景での分離
                )
                Image(
                    painter = painter,
                    contentDescription = contentDescription,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.matchParentSize(),
                )
            }
        } else {
            // API26-30: ソフト blur 不可 → 硬いシルエットを避けて素の画像(従来挙動)。
            Image(
                painter = painter,
                contentDescription = contentDescription,
                contentScale = ContentScale.Fit,
                modifier = modifier,
            )
        }
    } else {
        // 解決不能(理論上は無い。R8 が cat_* を strip した release 等の保険)→ 絵文字にフォールバック。
        Box(modifier, contentAlignment = Alignment.Center) {
            BasicText(text = state.emoji, style = TextStyle(fontSize = 40.sp))
        }
    }
}

/**
 * 円形アバター(tint 背景 + クリップ)。友達一覧/プロフィール/welcome 用。
 */
@Composable
fun CatAvatar(
    breed: CatBreed,
    state: CatState = CatState.WaitingMorning,
    size: Dp = 56.dp,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            // iOS FriendAvatarView は breed tint を 0.22 で控えめに敷く(iOS パリティ)。
            .background(Color(breed.tintArgb).copy(alpha = 0.22f)),
        contentAlignment = Alignment.Center,
    ) {
        CatImage(
            breed = breed,
            state = state,
            modifier = Modifier.fillMaxSize().padding(size * 0.06f),
        )
    }
}

@DrawableRes
private fun resolveCatDrawable(context: Context, breed: CatBreed, state: CatState): Int {
    drawableId(context, breed.assetName(state))?.let { return it }
    drawableId(context, CatBreed.fallbackAssetName(state))?.let { return it }
    drawableId(context, CatBreed.FALLBACK_AVATAR)?.let { return it }
    // 最終フォールバック: 透明 1px 相当を避け、必ず存在する orange 既定を返す前提だが、
    // 万一の欠損に備え android のデフォルト(ic_menu系は使わず)→ 0 は painterResource で例外になるため
    // ここに来ることは無い想定(orange 7 state は必ず同梱)。
    return drawableId(context, "cat_orange_waitingmorning") ?: 0
}

/**
 * シェイカー(補給)版の解決。iOS の 3 段フォールバック相当:
 * breed.shakerAssetName → breed.avatarAssetName → orange のシェイカー → (通常の resolveCatDrawable へ委譲)。
 */
@DrawableRes
private fun resolveShakerDrawable(context: Context, breed: CatBreed): Int {
    drawableId(context, breed.shakerAssetName)?.let { return it }
    drawableId(context, breed.avatarAssetName)?.let { return it }
    drawableId(context, "cat_orange_waitingmorning_shaker")?.let { return it }
    return resolveCatDrawable(context, breed, CatState.WaitingMorning)
}

private fun drawableId(context: Context, name: String): Int? =
    context.resources.getIdentifier(name, "drawable", context.packageName).takeIf { it != 0 }
