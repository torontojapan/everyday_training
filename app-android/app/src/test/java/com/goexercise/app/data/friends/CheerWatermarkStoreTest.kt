package com.goexercise.app.data.friends

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CheerWatermarkStoreTest {

    /** in-memory Backing(SharedPreferences の差替え)。 */
    private class FakeBacking : CheerWatermarkStore.Backing {
        val map = mutableMapOf<String, Long>()
        override fun getLong(key: String): Long? = map[key]
        override fun putLong(key: String, value: Long) { map[key] = value }
    }

    @Test
    fun unset_returnsNull() {
        val store = CheerWatermarkStore(FakeBacking())
        assertNull(store.lastSeen("uid-1"))
    }

    @Test
    fun setThenGet_roundTrips() {
        val store = CheerWatermarkStore(FakeBacking())
        store.setLastSeen("uid-1", 12_345L)
        assertEquals(12_345L, store.lastSeen("uid-1"))
    }

    @Test
    fun uidIsCaseInsensitive() {
        // 同一ユーザーが端末/OS をまたいでも同じ watermark を指すよう uid を小文字正規化する。
        val backing = FakeBacking()
        val store = CheerWatermarkStore(backing)
        store.setLastSeen("ABC-DEF", 777L)
        assertEquals(777L, store.lastSeen("abc-def"))
        assertEquals(777L, store.lastSeen("Abc-Def"))
        // 物理キーは 1 本だけ(大小違いで二重化しない)。
        assertEquals(1, backing.map.size)
    }

    @Test
    fun differentUids_areIndependent() {
        val store = CheerWatermarkStore(FakeBacking())
        store.setLastSeen("uid-a", 100L)
        store.setLastSeen("uid-b", 200L)
        assertEquals(100L, store.lastSeen("uid-a"))
        assertEquals(200L, store.lastSeen("uid-b"))
        assertNull(store.lastSeen("uid-c"))
    }
}
