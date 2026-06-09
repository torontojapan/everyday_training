package com.goexercise.app.data.friends

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.serializer.KotlinXSerializer
import kotlinx.serialization.json.Json

/**
 * Supabase クライアント生成。supabase-kt 3.x の API。
 * このファイルがコンパイルできること = createSupabaseClient / Auth / Postgrest / Functions の
 * API 実在確認(P1b-1 PoC の第一段。実通信は anon key 設定 + 実機で別途)。
 */
object SupabaseClientFactory {
    fun create(url: String, anonKey: String): SupabaseClient =
        createSupabaseClient(supabaseUrl = url, supabaseKey = anonKey) {
            // encodeDefaults=true が必須: kotlinx.serialization の既定(false)だと、Kotlin の既定値と
            // 一致するフィールド(例: username="", display_name="あなた", status="active", streak=0)が
            // upsert ペイロードから脱落し、NOT NULL 列で 23502 エラーになる(iOS の Swift Codable は
            // 常に全フィールド送信 = それに揃える)。ignoreUnknownKeys=true は DB 側の追加列
            // (my_cat_breed / weekly_achievements / updated_at 等)を decode で無視するため、
            // coerceInputValues=true は null→既定の防御。
            defaultSerializer = KotlinXSerializer(
                Json {
                    encodeDefaults = true
                    ignoreUnknownKeys = true
                    coerceInputValues = true
                },
            )
            install(Auth)
            install(Postgrest)
            install(Functions)
        }
}
