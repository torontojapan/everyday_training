package com.goexercise.app.domain.friends

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * FriendCode / FriendCodeValidator のテスト。iOS には専用テストが無いため、
 * iOS の `FriendCodeValidator`(sanitize/isValid)と `DeepLinkRouterTests` の友達コード挙動から
 * 仕様を起こした。生成は乱数のため不変条件(桁数・許可文字)を検証する。
 */
class FriendCodeTest {

    @Test
    fun sanitizeUppercasesAndKeepsOnlyAllowed() {
        assertEquals("ABC234", FriendCodeValidator.sanitize("abc234"))
    }

    @Test
    fun sanitizeStripsAmbiguousAndClipsToSix() {
        // O/0/I/1 は除去。7 文字以上は 6 桁に切る。
        assertEquals("AB", FriendCodeValidator.sanitize("O0I1AB"))
        assertEquals("ABCDEF", FriendCodeValidator.sanitize("ABCDEFGH"))
        assertEquals("ABC23", FriendCodeValidator.sanitize("a b-c 2*3")) // 記号/空白除去
    }

    @Test
    fun isValidRequiresSixAllowedChars() {
        assertTrue(FriendCodeValidator.isValid("ABC234"))
        assertFalse(FriendCodeValidator.isValid("AB")) // 桁不足
        assertFalse(FriendCodeValidator.isValid("ABCDEFG")) // 桁超過
        assertFalse(FriendCodeValidator.isValid("ABC23O")) // 曖昧文字 O を含む
        assertFalse(FriendCodeValidator.isValid("abc234")) // 小文字は不可(sanitize 前)
    }

    @Test
    fun generateProducesSixAllowedChars() {
        repeat(200) {
            val code = FriendCode.generate()
            assertEquals(6, code.length)
            assertTrue(code.all { it in FriendCode.allowedCharacters })
            assertTrue(FriendCodeValidator.isValid(code))
        }
    }
}
