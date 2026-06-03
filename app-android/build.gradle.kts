// Top-level build file. Plugins are declared here with `apply false`
// and applied per-module. Versions come from gradle/libs.versions.toml.
plugins {
    // AGP 9 は Kotlin ビルトイン。`org.jetbrains.kotlin.android` は適用しない。
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.hilt) apply false
    alias(libs.plugins.ksp) apply false
}
