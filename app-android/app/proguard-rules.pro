# R8 / ProGuard ルール(release minify 用)。Compose/Hilt/Room/Billing/supabase-kt/ktor は各依存の
# consumer rules を同梱しているため、ここでは本アプリ固有の取りこぼし(kotlinx.serialization の
# @Serializable モデル / 動的解決リソース)だけを明示する。

# ---- kotlinx.serialization ----
# @Serializable は合成 $$serializer を持ち、リフレクションで解決される。本アプリのモデルを保護する。
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers @kotlinx.serialization.Serializable class com.goexercise.app.** {
    *** Companion;
    *** INSTANCE;
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.goexercise.app.**$$serializer { *; }
# enum の serialName 解決のため値を保持(WorkoutCategory 等は rawValue=SerialName で iOS 互換)。
-keepclassmembers enum com.goexercise.app.** { *; }

# ---- Supabase 行モデル(postgrest が JSON decode する DTO)----
-keep class com.goexercise.app.data.friends.ProfileRow { *; }
-keep class com.goexercise.app.data.friends.FriendshipRow { *; }
-keep class com.goexercise.app.data.friends.RequestRow { *; }
-keep class com.goexercise.app.data.friends.RequestWrite { *; }
-keep class com.goexercise.app.data.friends.CheerWrite { *; }

# ---- TelemetryDeck の任意 kotlinx-datetime 参照 ----
# TelemetryDeck SDK の CalendarParameterProvider が kotlinx.datetime.* を参照するが、本アプリは
# 同ライブラリを同梱しない(該当 provider 未使用)。R8 full-mode は未解決参照をエラー化するため
# 警告抑制(AGP 生成 missing_rules.txt と一致)。実行時は当該コードパスに到達しない。
-dontwarn kotlinx.datetime.Clock$System
-dontwarn kotlinx.datetime.Instant

# ---- 動的リソース解決(getIdentifier)----
# 猫 77 画像は cat_<breed>_<state> を resources.getIdentifier で解決するため、コード参照が無く
# R8 のコード解析からは未使用に見える。リソース保持は res/raw/keep.xml(tools:keep)で行う。
# ここはコード側の getIdentifier ヘルパが消えないよう保持する。
-keep class com.goexercise.app.ui.components.CatImageKt { *; }
