package com.goexercise.app.navigation

import com.goexercise.app.AppFeatureFlags
import com.goexercise.app.domain.friends.FriendCodeValidator
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

/**
 * `goexercise://<host>[?code=...]` の解析。iOS `DeepLinkRouter`(route/friendCode/resolve)の移植。
 * **android.net.Uri を使わず手動パース**して plain JVM の unit test で検証できるようにする
 * (iOS の `host ?? path` 抽出と同等)。
 */
object DeepLink {

    private const val SCHEME = "goexercise"

    private data class Parsed(val scheme: String, val host: String, val query: String?)

    private fun parse(uri: String): Parsed? {
        val sep = uri.indexOf("://")
        if (sep < 0) return null
        val scheme = uri.substring(0, sep).lowercase()
        val rest = uri.substring(sep + 3)
        val beforeQuery = rest.substringBefore('?')
        val query = if ('?' in rest) rest.substringAfter('?') else null
        // host = authority(/より前)。空なら path 部分にフォールバック(iOS の host ?? path)。
        val host = beforeQuery.substringBefore('/').ifBlank { beforeQuery.trim('/') }
        return Parsed(scheme, host.lowercase(), query)
    }

    /** scheme 不一致/未知ホストは null。 */
    fun route(uri: String): AppRoute? {
        val parsed = parse(uri) ?: return null
        if (parsed.scheme != SCHEME) return null
        return AppRoute.fromPath(parsed.host)
    }

    /** `?code=` を抽出し sanitize + 検証。不在/不正は null。 */
    fun friendCode(uri: String): String? {
        val parsed = parse(uri) ?: return null
        val rawValue = parsed.query
            ?.split("&")
            ?.firstOrNull { it.startsWith("code=") }
            ?.substringAfter("=")
            ?: return null
        val decoded = runCatching { URLDecoder.decode(rawValue, StandardCharsets.UTF_8.name()) }.getOrDefault(rawValue)
        val sanitized = FriendCodeValidator.sanitize(decoded)
        return if (FriendCodeValidator.isValid(sanitized)) sanitized else null
    }

    /**
     * route をパースし feature flag でゲートする(iOS DeepLinkRouter.resolve)。
     * **friends に着地する時だけ**検証済みコードを返す(home 振替時は code を破棄)。
     */
    fun resolve(uri: String, friendsEnabled: Boolean = AppFeatureFlags.FRIENDS_ENABLED): Pair<AppRoute?, String?> {
        val raw = route(uri) ?: return null to null
        val gated = AppFeatureFlags.resolvedRoute(raw, friendsEnabled)
        val code = if (gated == AppRoute.Friends) friendCode(uri) else null
        return gated to code
    }
}
