package com.goexercise.app.domain.friends

import kotlin.random.Random
import kotlin.random.asKotlinRandom

/**
 * 友達コードの生成。iOS `FriendCode`(FriendProfile.swift)の 1:1 移植。
 * **クライアント生成 + UNIQUE 衝突リトライ方式**(サーバ採番ではない。Codexレビュー是正)。
 * Android も同一アルファベット・同一桁数で生成し、iOS と friend code 名前空間を共有する。
 */
object FriendCode {
    const val LENGTH = 6

    /** 24 文字 + 8 数字。視認性で紛らわしい O / 0 / I / 1 を除外。 */
    const val ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

    val allowedCharacters: Set<Char> = ALPHABET.toSet()

    /** 紛らわしい文字を除いたランダム 6 文字コード。実際の重複回避(UNIQUE リトライ)は repo 層。 */
    // 既定は CSPRNG(SecureRandom)。kotlin.random.Random は非暗号論的で予測され得るため、
    // 友達コードのような推測耐性が要る値は SecureRandom を使う。テスト時は random を注入して決定化する。
    fun generate(random: Random = java.security.SecureRandom().asKotlinRandom()): String =
        (0 until LENGTH).map { ALPHABET[random.nextInt(ALPHABET.length)] }.joinToString("")

    /** 入力補正。[FriendCodeValidator.sanitize] への委譲(ReferralStore など呼び出し側の利便性)。 */
    fun sanitize(raw: String): String = FriendCodeValidator.sanitize(raw)

    /** コード妥当性。[FriendCodeValidator.isValid] への委譲。 */
    fun isValid(code: String): Boolean = FriendCodeValidator.isValid(code)
}

/**
 * 入力補正。iOS `FriendCodeValidator` の移植。
 * 入力欄を「打つそばから自己補正」させるため: 大文字化 → 許可文字だけ残す → 6 桁に切る。
 */
object FriendCodeValidator {
    fun sanitize(raw: String): String =
        raw.uppercase()
            .filter { it in FriendCode.allowedCharacters }
            .take(FriendCode.LENGTH)

    fun isValid(code: String): Boolean =
        code.length == FriendCode.LENGTH && code.all { it in FriendCode.allowedCharacters }
}
