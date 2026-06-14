package com.goexercise.app.data.friends

import org.junit.Assert.assertEquals
import org.junit.Test

class FriendshipPairTest {

    @Test
    fun ordersAscending() {
        assertEquals("aaa" to "bbb", FriendshipPair.ordered("bbb", "aaa"))
        assertEquals("aaa" to "bbb", FriendshipPair.ordered("aaa", "bbb"))
    }

    @Test
    fun normalizesCase_soMixedCaseUuidsOrderConsistently() {
        // iOS は UUID を大文字(UUID.uuidString)で送り得る。大小を正規化しないと、片側が
        // "ABC", 片側が "abd" のとき "ABC" < "abd"(大文字は小さい)で順序が食い違い、
        // friendships_check(user_a < user_b)違反になる。小文字化で常に一致させる。
        val a = "ABC00000-0000-0000-0000-000000000000"
        val b = "abd00000-0000-0000-0000-000000000000"
        val fromUpper = FriendshipPair.ordered(a, b)
        val fromLower = FriendshipPair.ordered(a.lowercase(), b.lowercase())
        assertEquals(fromLower, fromUpper)
        assertEquals(a.lowercase() to b.lowercase(), fromUpper)
    }

    @Test
    fun isSymmetric_sameResultRegardlessOfArgOrder() {
        // 申請受諾(insert)と解除(delete)で引数順が違っても同じ対になる(でないと delete が外れる)。
        val x = "User-AAAA"
        val y = "user-zzzz"
        assertEquals(FriendshipPair.ordered(x, y), FriendshipPair.ordered(y, x))
    }
}
