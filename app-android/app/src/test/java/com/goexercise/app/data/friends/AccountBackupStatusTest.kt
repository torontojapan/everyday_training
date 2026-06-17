package com.goexercise.app.data.friends

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * バックアップ状態の表示文言検証(iOS 1.3 パリティ)。
 * 回帰: Apple/Google 両方連携時に1つだけ拾うと並び順依存で誤表示になっていた
 * (Apple なのに「Google アカウントでバックアップ中」)。全プロバイダを列挙する。
 */
class AccountBackupStatusTest {

    @Test
    fun `anonymous has no providers`() {
        assertEquals(emptyList<String>(), AccountBackupStatus.Anonymous.providerNames)
        assertNull(AccountBackupStatus.Anonymous.providerName)
        assertNull(AccountBackupStatus.Anonymous.linkedProvidersDisplay)
        assertEquals("アカウントでバックアップ中", AccountBackupStatus.Anonymous.backupStatusText)
    }

    @Test
    fun `lists all linked providers regardless of array order`() {
        // 配列順が google 先頭でも Apple が必ず含まれる(旧バグは google だけ表示)。
        val both = AccountBackupStatus(isBackedUp = true, providerNames = listOf("google", "apple"))
        assertEquals("Google・Apple アカウントでバックアップ中", both.backupStatusText)
        assertEquals("Google・Apple", both.linkedProvidersDisplay)
    }

    @Test
    fun `single provider reads naturally`() {
        val apple = AccountBackupStatus(isBackedUp = true, providerName = "apple")
        assertEquals("Apple アカウントでバックアップ中", apple.backupStatusText)
        assertEquals("Apple", apple.linkedProvidersDisplay)
        assertEquals("apple", apple.providerName) // 後方互換アクセサ

        val google = AccountBackupStatus(isBackedUp = true, providerName = "google")
        assertEquals("Google アカウントでバックアップ中", google.backupStatusText)
    }

    @Test
    fun `backward-compatible constructor wraps single provider into list`() {
        val s = AccountBackupStatus(isBackedUp = true, providerName = "apple")
        assertEquals(listOf("apple"), s.providerNames)
    }
}
