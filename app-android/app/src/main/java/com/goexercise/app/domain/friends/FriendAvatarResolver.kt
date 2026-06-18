package com.goexercise.app.domain.friends

import com.goexercise.app.domain.CatBreed

/**
 * 友達アバターの猫種解決。iOS `FriendAvatarResolver` (BuddyAvatar.swift) の移植。
 * 相手が共有している `myCatBreed` を使い、未設定なら friendCode から決定論的に 1 種を当てる。
 * iOS と同一の FNV-1a(32bit) ハッシュ + CatBreed 並び順なので、同じ友達は両 OS で同じ猫になる。
 */
object FriendAvatarResolver {
    fun resolve(profile: FriendProfile): CatBreed = profile.myCatBreed ?: defaultBreed(profile.friendCode)

    fun defaultBreed(friendCode: String): CatBreed {
        val all = CatBreed.entries
        return all[stableHash(friendCode) % all.size]
    }

    /** iOS の stableHash と完全一致(FNV-1a 32bit, 符号ビットを落として正の Int に)。 */
    private fun stableHash(string: String): Int {
        var hash = 0x811c9dc5.toInt() // 2166136261 (UInt32) のビットパターン
        for (b in string.toByteArray(Charsets.UTF_8)) {
            hash = hash xor (b.toInt() and 0xFF)
            hash *= 0x01000193 // 32bit wrapping multiply(Kotlin Int は自然に折り返す)
        }
        return hash and 0x7fffffff
    }
}
