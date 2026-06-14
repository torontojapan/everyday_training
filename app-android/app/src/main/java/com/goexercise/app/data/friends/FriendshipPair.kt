package com.goexercise.app.data.friends

/**
 * friendships テーブルの (user_a, user_b) 順序対を作る純粋関数。
 *
 * **UUID の大小を正規化(小文字化)してから比較**する。これが無いと、片側が大文字 UUID
 * (iOS の `UUID.uuidString` は大文字)、片側が小文字だと `a < b` の結果がクライアント間で食い違い、
 * DB の `friendships_check (user_a < user_b)` 制約に違反して友達承認が壊れる(iOS で実際に起きた
 * ship-blocker の Android 側 防御層)。[FriendshipPairTest] で回帰を機械的に担保する。
 */
object FriendshipPair {
    fun ordered(a: String, b: String): Pair<String, String> {
        val x = a.lowercase()
        val y = b.lowercase()
        return if (x < y) x to y else y to x
    }
}
