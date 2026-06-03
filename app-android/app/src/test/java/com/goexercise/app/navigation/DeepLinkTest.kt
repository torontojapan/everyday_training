package com.goexercise.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** iOS `DeepLinkRouterTests.swift` の純粋ロジック部分の移植(route / friendCode / resolve)。 */
class DeepLinkTest {

    @Test
    fun hostParsedAsRoute() {
        val hosts = listOf("home", "record", "history", "settings", "friends", "notification-settings", "streak-share")
        for (raw in hosts) {
            assertEquals(raw, DeepLink.route("goexercise://$raw")?.path)
        }
    }

    @Test
    fun uppercaseSchemeAccepted() {
        assertEquals(AppRoute.Record, DeepLink.route("GOEXERCISE://record"))
    }

    @Test
    fun unknownSchemeReturnsNil() {
        assertNull(DeepLink.route("https://example.com/record"))
    }

    @Test
    fun unknownHostReturnsNil() {
        assertNull(DeepLink.route("goexercise://nope"))
    }

    @Test
    fun friendCodeExtractionAndValidation() {
        assertEquals("ABC234", DeepLink.friendCode("goexercise://friends?code=ABC234"))
        assertEquals("ABC234", DeepLink.friendCode("goexercise://friends?code=abc234")) // 小文字は大文字化
        assertNull(DeepLink.friendCode("goexercise://friends")) // code 無し
        assertNull(DeepLink.friendCode("goexercise://friends?code=AB")) // 桁不足
        assertNull(DeepLink.friendCode("goexercise://friends?code=O0I1AB")) // 曖昧文字除去で桁不足
    }

    @Test
    fun resolveKeepsCodeWhenFriendsEnabled() {
        val (route, code) = DeepLink.resolve("goexercise://friends?code=ABC234", friendsEnabled = true)
        assertEquals(AppRoute.Friends, route)
        assertEquals("ABC234", code)
    }

    @Test
    fun resolveDropsCodeWhenFriendsDisabled() {
        val (route, code) = DeepLink.resolve("goexercise://friends?code=ABC234", friendsEnabled = false)
        assertEquals(AppRoute.Home, route)
        assertNull(code)
    }

    @Test
    fun resolveNonFriendsRouteHasNoCode() {
        val (route, code) = DeepLink.resolve("goexercise://settings?code=ABC234", friendsEnabled = true)
        assertEquals(AppRoute.Settings, route)
        assertNull(code)
    }
}
