import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

// Supabase 接続情報は local.properties(gitignore)から BuildConfig へ注入(iOS の Secrets.xcconfig 相当)。
// 未設定なら空文字 → SupabaseConfig.isConfigured=false で friends は Mock フォールバック。
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun secret(key: String): String = (localProps.getProperty(key) ?: "").trim()

// Compile with the JDK running Gradle (Android Studio's JBR 21) but emit JVM 17
// bytecode. Avoids Gradle toolchain auto-provisioning (no JDK 17 installed locally).
kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

android {
    namespace = "com.goexercise.app"
    compileSdk = 36
    // Only build-tools 36.1.0 / 37.0.0 are installed locally; pin to an installed one
    // so AGP does not try to auto-download a different version (no cmdline-tools yet).
    buildToolsVersion = "36.1.0"

    defaultConfig {
        applicationId = "com.goexercise.app"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"

        // iOS と同一 Supabase プロジェクトを共有(friend code 名前空間共有)。
        buildConfigField("String", "SUPABASE_HOST", "\"${secret("SUPABASE_HOST")}\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"${secret("SUPABASE_ANON_KEY")}\"")

        // アカウント連携(#5 / Phase2)の有効化ゲート。iOS Info.plist FriendsApple/GoogleLinkEnabled 相当。
        // 既定 false(= 連携 UI 非表示で従来挙動)。Supabase コンソール設定 + Credential Manager の
        // Web Client ID が揃ってから true にする(#10 実通信)。
        buildConfigField("Boolean", "FRIENDS_APPLE_LINK_ENABLED", secret("FRIENDS_APPLE_LINK_ENABLED").ifBlank { "false" })
        buildConfigField("Boolean", "FRIENDS_GOOGLE_LINK_ENABLED", secret("FRIENDS_GOOGLE_LINK_ENABLED").ifBlank { "false" })
        // Google native(Credential Manager)用 Web Client ID。未設定なら Google 連携は実行不可。
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"${secret("GOOGLE_WEB_CLIENT_ID")}\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

// Room スキーマを app/schemas に出力(exportSchema=true)。将来の migration テストの基準。
ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.navigation.compose)

    implementation(libs.hilt.android)
    implementation(libs.androidx.hilt.navigation.compose)
    ksp(libs.hilt.compiler)

    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)

    implementation(libs.androidx.datastore.preferences)
    implementation(libs.kotlinx.serialization.json)

    // Supabase(friends バックエンド, iOS と同一プロジェクト共有)。
    implementation(platform(libs.supabase.bom))
    implementation(libs.supabase.auth)
    implementation(libs.supabase.postgrest)
    implementation(libs.supabase.functions)
    implementation(libs.ktor.client.okhttp)

    // QR コード生成 (友達コードの招待リンクを QR 化)。pure-Java で実通信不要。
    implementation(libs.zxing.core)

    testImplementation(libs.junit)

    debugImplementation(libs.androidx.ui.tooling)
}
