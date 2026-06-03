package com.goexercise.app.data.friends

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest

/**
 * Supabase クライアント生成。supabase-kt 3.x の API。
 * このファイルがコンパイルできること = createSupabaseClient / Auth / Postgrest / Functions の
 * API 実在確認(P1b-1 PoC の第一段。実通信は anon key 設定 + 実機で別途)。
 */
object SupabaseClientFactory {
    fun create(url: String, anonKey: String): SupabaseClient =
        createSupabaseClient(supabaseUrl = url, supabaseKey = anonKey) {
            install(Auth)
            install(Postgrest)
            install(Functions)
        }
}
