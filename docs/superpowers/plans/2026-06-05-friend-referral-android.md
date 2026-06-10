# 友達紹介(リファラル)実装計画 (Android / v1.1)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development。Steps は checkbox(`- [ ]`)で進捗管理。**iOS版(`2026-06-05-friend-referral-ios.md`)の鏡像移植**。Supabase `referrals` 表+RLSは共有BEに既に追加済(iOS Task1)なので Android はクライアントのみ。

**Goal:** friend_code を招待コードに流用し、オンボ/設定でコード入力→自動友達化→新規の初運動記録(achievedDays≥1)で確定→双方にフリーズ+星バッジ(2種ポップ)。iOSとデータ・挙動互換。

**Architecture:** 確定はクライアント主導(`HomeViewModel` の profile 自動publish経路に相乗り)。フリーズ月次枠を `RescueTicketAllowance.current(isPremium, referralBonus)=minOf(5, base+bonus)` に単一ソース化。紹介状態は Hilt `@Singleton ReferralStore`(StateFlow)が保持し、起動時ポーリング・初記録確定・星バッジ・今月ボーナスを供給。UIは `AppFeatureFlags.isReferralActive`(FRIENDS_ENABLED && REFERRAL_ENABLED)ゲート下。

**Tech Stack:** Kotlin / Jetpack Compose / Hilt / DataStore / supabase-kt 3.6(postgrest+auth)/ JUnit4。対象 `app-android`(`:app`, package `com.goexercise.app`)。**Androidの単体テストは実行可能**(iOSと違いランナー正常)→ 純ロジック・Mockサービスは `./gradlew :app:testDebugUnitTest` で実行検証する。

**ブランチ:** `feature/android-referral`(作成済、現HEAD=iOS v1.1込みから分岐)。

**環境/ビルド注意(メモリ参照):**
- ビルドは **JAVA_HOME を JetBrains Runtime(JBR)** にして実行(`gradlew` がJDK17を要求)。実装者は `JAVA_HOME` 未設定でこけたら Android Studio 同梱 JBR(例 `/Applications/Android Studio.app/Contents/jbr/Contents/Home`)を設定する。
- repo は iCloud 同期下 → ビルド前に重複掃除: `find app-android/app/build -name "* [0-9].*" -delete 2>/dev/null; find app-android/build -name "* [0-9].*" -delete 2>/dev/null`(`build/reports 2` 等が湧くとビルド破壊)。
- 既存スキーマ列は iOS と一致(`profiles` に total_achieved_days 等)。`referrals` 表は共有BEに追加済(本番Supabaseでの SQL Run は iOS計画の出荷前ステップで実施)。

**共通コマンド(以後 `TEST=`, `BUILD=` と表記):**
```bash
# 作業ディレクトリ
cd /Users/jun/Documents/Business_Project_Management/serial_training/app-android
# iCloud重複掃除(毎回先に)
find app/build -name "* [0-9].*" -delete 2>/dev/null; find build -name "* [0-9].*" -delete 2>/dev/null
# 単体テスト(実行される)
./gradlew :app:testDebugUnitTest
# コンパイル/ビルド
./gradlew :app:assembleDebug
```
`JAVA_HOME` が必要なら各コマンド前に `export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`(存在を確認して使う)。

---

## ファイル構成

**作成:**
- `app/src/main/java/com/goexercise/app/domain/friends/Referral.kt` — `ReferralSummary`/`ReferralConfirmation`/`ReferralClock`/`ReferralEntryPolicy`(純Kotlin)。
- `app/src/main/java/com/goexercise/app/data/referral/ReferralStore.kt` — `@Singleton` 状態ホルダ(StateFlow)。
- `app/src/main/java/com/goexercise/app/data/referral/ReferralModule.kt` — Hilt provide(必要なら。`@Singleton` class は `@Inject constructor` で自動提供可なので最小化)。
- `app/src/main/java/com/goexercise/app/presentation/referral/ReferralCelebrationDialog.kt` — 確定ポップ(AlertDialog)。
- `app/src/main/java/com/goexercise/app/presentation/referral/InviteCodeField.kt` — 招待コード入力欄(Composable・再利用)。
- テスト: `app/src/test/java/com/goexercise/app/domain/ReferralLogicTest.kt`, `app/src/test/java/com/goexercise/app/data/ReferralServiceTest.kt`。

**変更:**
- `domain/RescueTicket.kt` — `RescueTicketAllowance.current(isPremium, referralBonus)` 追加。
- `AppFeatureFlags.kt` — `REFERRAL_ENABLED` + `isReferralActive`。
- `data/friends/FriendsService.kt` — interface に紹介5メソッド(default)+ Referral Row/Write + Mock 実装。
- `data/friends/SupabaseFriendsService.kt` — 紹介5メソッド実装 + 削除連携。
- `presentation/rescue/RescueViewModel.kt` — allowance にボーナス反映。
- `presentation/home/HomeViewModel.kt` — 初記録確定フック。
- `MainActivity.kt` or `GOExerciseApp.kt` — 起動時ポーリング。
- `presentation/onboarding/OnboardingScreen.kt`(+`OnboardingViewModel.kt`)— 招待コード欄。
- `presentation/settings/SettingsScreen.kt`(+`SettingsViewModel.kt`)— 招待共有/星バッジ/後から入力。
- `presentation/home/HomeScreen.kt` or `HomeRoute` — 確定ポップ提示。

---

## Task 1: フラグ + allowance ボーナス(純ロジック・TDD・実行検証)

**Files:**
- Modify: `app/src/main/java/com/goexercise/app/AppFeatureFlags.kt`
- Modify: `app/src/main/java/com/goexercise/app/domain/RescueTicket.kt`
- Test: `app/src/test/java/com/goexercise/app/domain/ReferralLogicTest.kt`(新規)

- [ ] **Step 1: 失敗するテスト**

`ReferralLogicTest.kt` を新規作成:
```kotlin
package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Test

class ReferralLogicTest {
    @Test fun allowance_base_unchanged() {
        assertEquals(1, RescueTicketAllowance.current(isPremium = false, referralBonus = 0))
        assertEquals(4, RescueTicketAllowance.current(isPremium = true, referralBonus = 0))
    }
    @Test fun allowance_addsBonus_clipsAt5() {
        assertEquals(4, RescueTicketAllowance.current(isPremium = false, referralBonus = 3))
        assertEquals(5, RescueTicketAllowance.current(isPremium = false, referralBonus = 10))
        assertEquals(5, RescueTicketAllowance.current(isPremium = true, referralBonus = 1))
        assertEquals(5, RescueTicketAllowance.current(isPremium = true, referralBonus = 5))
    }
    @Test fun allowance_negativeBonus_floored() {
        assertEquals(1, RescueTicketAllowance.current(isPremium = false, referralBonus = -3))
    }
    @Test fun allowance_oldApi_delegates() {
        assertEquals(1, RescueTicketAllowance.current(isPremium = false))
        assertEquals(4, RescueTicketAllowance.current(isPremium = true))
    }
}
```

- [ ] **Step 2: テスト失敗を確認** Run: `TEST`(`./gradlew :app:testDebugUnitTest`)→ `current(isPremium, referralBonus)` 未定義でコンパイルエラー。

- [ ] **Step 3: 実装** `RescueTicket.kt` の `object RescueTicketAllowance` を次に置換:
```kotlin
/** 連続記録フリーズ(保険チケット)の月次付与枠。iOS `RescueTicketAllowance` の移植。 */
object RescueTicketAllowance {
    /** 月次フリーズ上限(全員共通)。base + 今月紹介ボーナスもこれを超えない。 */
    const val MONTHLY_CAP = 5

    /** 後方互換: 紹介ボーナス無しの従来 API。GOプレミアムなら月4、無料なら月1。 */
    fun current(isPremium: Boolean): Int = current(isPremium, referralBonus = 0)

    /** base + 今月紹介ボーナスを MONTHLY_CAP でクリップ。ボーナス負値は0に丸め。 */
    fun current(isPremium: Boolean, referralBonus: Int): Int {
        val base = if (isPremium) 4 else 1
        return minOf(MONTHLY_CAP, base + maxOf(0, referralBonus))
    }
}
```

- [ ] **Step 4: フラグ追加** `AppFeatureFlags.kt` の `const val FRIENDS_ENABLED: Boolean = true` の下に:
```kotlin
    /** 友達紹介(リファラル)を有効にするか。友達BE前提なので FRIENDS_ENABLED と AND。 */
    const val REFERRAL_ENABLED: Boolean = true

    /** 紹介機能を出してよいか(友達有効 かつ 紹介有効)。 */
    val isReferralActive: Boolean get() = FRIENDS_ENABLED && REFERRAL_ENABLED
```

- [ ] **Step 5: テスト成功確認** Run: `TEST` → `BUILD SUCCESSFUL`、`ReferralLogicTest` 4件 PASS(レポート `app/build/reports/tests/testDebugUnitTest/index.html` でも確認可)。

- [ ] **Step 6: commit**
```bash
cd /Users/jun/Documents/Business_Project_Management/serial_training
git add app-android/app/src/main/java/com/goexercise/app/domain/RescueTicket.kt app-android/app/src/main/java/com/goexercise/app/AppFeatureFlags.kt app-android/app/src/test/java/com/goexercise/app/domain/ReferralLogicTest.kt
git commit -m "feat(android-referral): allowanceに紹介ボーナス(上限5)+ referralEnabledフラグ"
```

---

## Task 2: 紹介ドメイン型(純ロジック・TDD・実行検証)

**Files:**
- Create: `app/src/main/java/com/goexercise/app/domain/friends/Referral.kt`
- Test: `app/src/test/java/com/goexercise/app/domain/ReferralLogicTest.kt`(追記)

- [ ] **Step 1: 失敗するテストを追記** `ReferralLogicTest` クラス内に追記:
```kotlin
    @Test fun clock_parsesTimestamps() {
        assertNotNull(ReferralClock.parseTimestamp("2026-06-05T12:00:00+00:00"))
        assertNotNull(ReferralClock.parseTimestamp("2026-06-05T12:00:00.123456+00:00"))
        assertNull(ReferralClock.parseTimestamp("nope"))
    }
    @Test fun clock_isInMonth_utc() {
        val now = java.time.OffsetDateTime.parse("2026-06-20T00:00:00+00:00").toInstant()
        assertTrue(ReferralClock.isInMonth("2026-06-01T00:00:00+00:00", now))
        assertFalse(ReferralClock.isInMonth("2026-05-31T23:00:00+00:00", now))
        assertFalse(ReferralClock.isInMonth(null, now))
    }
    @Test fun entryPolicy_allowsWithinGrace_whenNoReferrer() {
        val start = java.time.Instant.ofEpochSecond(1_000_000)
        assertTrue(ReferralEntryPolicy.canEnterCodeLater(start, start.plusSeconds(3*86400), hasExistingReferral = false))
    }
    @Test fun entryPolicy_blocksAfterGrace() {
        val start = java.time.Instant.ofEpochSecond(1_000_000)
        assertFalse(ReferralEntryPolicy.canEnterCodeLater(start, start.plusSeconds(8*86400), hasExistingReferral = false))
    }
    @Test fun entryPolicy_blocksWhenAlreadyReferred() {
        val start = java.time.Instant.ofEpochSecond(1_000_000)
        assertFalse(ReferralEntryPolicy.canEnterCodeLater(start, start.plusSeconds(86400), hasExistingReferral = true))
    }
    @Test fun entryPolicy_blocksWhenNoFirstLaunch() {
        assertFalse(ReferralEntryPolicy.canEnterCodeLater(null, java.time.Instant.now(), hasExistingReferral = false))
    }
```
ファイル冒頭の import に追加: `import org.junit.Assert.assertNotNull`, `assertNull`, `assertTrue`, `assertFalse`。

- [ ] **Step 2: 実装** `Referral.kt` を新規作成:
```kotlin
package com.goexercise.app.domain.friends

import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

/**
 * 自分の紹介状況の集計。iOS `ReferralSummary` の移植。
 * - starBadges: 累計 confirmed 紹介数(referrer側・無制限)。
 * - freezeBonusThisMonth: 今月 confirmed の自分向けフリーズ加算
 *   (= 今月 confirmed の referrer 件数 + 自分が referee で今月 confirmed なら +1)。
 *   `RescueTicketAllowance.current(isPremium, referralBonus)` に渡す。
 */
data class ReferralSummary(
    val starBadges: Int,
    val freezeBonusThisMonth: Int,
) {
    companion object { val EMPTY = ReferralSummary(0, 0) }
}

/** 確定(confirmed)イベント1件。ポップ表示に使う。 */
data class ReferralConfirmation(
    val id: String,              // referee_user_id(referrals 主キー=ユニーク)
    val friendDisplayName: String,
    val role: Role,
) {
    enum class Role { REFERRER, REFEREE }
}

/** timestamptz 文字列の解析と「今月か(UTC)」判定。iOS `ReferralClock` の移植。 */
object ReferralClock {
    fun parseTimestamp(iso: String): Instant? = try {
        OffsetDateTime.parse(iso, DateTimeFormatter.ISO_OFFSET_DATE_TIME).toInstant()
    } catch (e: Exception) {
        try { Instant.parse(iso) } catch (e2: Exception) { null }
    }

    private fun monthKey(instant: Instant): Int {
        val d = instant.atZone(ZoneOffset.UTC)
        return d.year * 100 + d.monthValue
    }

    /** `iso`(timestamptz)が `now` と同じ暦月(UTC)か。null/解析不能は false。 */
    fun isInMonth(iso: String?, now: Instant): Boolean {
        val parsed = iso?.let { parseTimestamp(it) } ?: return false
        return monthKey(parsed) == monthKey(now)
    }
}

/**
 * オンボ以外(設定)から招待コードを入力できるかの判定。iOS `ReferralEntryPolicy` の移植。
 * 初回起動から graceDays 以内 かつ まだ紹介者がいない場合のみ許可。
 */
object ReferralEntryPolicy {
    const val GRACE_DAYS = 7
    fun canEnterCodeLater(
        firstLaunchAt: Instant?,
        now: Instant,
        hasExistingReferral: Boolean,
        graceDays: Int = GRACE_DAYS,
    ): Boolean {
        if (hasExistingReferral || firstLaunchAt == null) return false
        val days = (now.epochSecond - firstLaunchAt.epochSecond) / 86400
        return days in 0..graceDays.toLong()
    }
}
```

- [ ] **Step 3: テスト成功確認** Run: `TEST` → 全テスト PASS(allowance 4 + 新 6 = 10件)。

- [ ] **Step 4: commit**
```bash
cd /Users/jun/Documents/Business_Project_Management/serial_training
git add app-android/app/src/main/java/com/goexercise/app/domain/friends/Referral.kt app-android/app/src/test/java/com/goexercise/app/domain/ReferralLogicTest.kt
git commit -m "feat(android-referral): ドメイン型Summary/Confirmation+Clock+EntryPolicy(純ロジック)"
```

---

## Task 3: FriendsService 紹介メソッド(interface default + Row + Mock 実装)+ テスト

**Files:**
- Modify: `app/src/main/java/com/goexercise/app/data/friends/FriendsService.kt`
- Test: `app/src/test/java/com/goexercise/app/data/ReferralServiceTest.kt`(新規)

- [ ] **Step 1: Referral Row/Write を追加** `FriendsService.kt` の `CheerWrite` data class の後に:
```kotlin
@Serializable
data class ReferralRow(
    @SerialName("referrer_user_id") val referrerUserId: String,
    @SerialName("referee_user_id") val refereeUserId: String,
    @SerialName("status") val status: String = "pending",
    @SerialName("confirmed_at") val confirmedAt: String? = null,
    @SerialName("seen_by_referrer") val seenByReferrer: Boolean = false,
)

@Serializable
data class ReferralInsert(
    @SerialName("referrer_user_id") val referrerUserId: String,
    @SerialName("referee_user_id") val refereeUserId: String,
)

@Serializable
data class ReferralConfirmUpdate(
    @SerialName("status") val status: String,
    @SerialName("confirmed_at") val confirmedAt: String,
)

@Serializable
data class ReferralSeenUpdate(
    @SerialName("seen_by_referrer") val seenByReferrer: Boolean,
)
```

- [ ] **Step 2: interface に default メソッドを追加** `interface FriendsService` 内、`publishMyProfile` の後(アカウント連携セクションの前)に:
```kotlin
    // ---- 友達紹介(リファラル)。既定は安全側 no-op。実装は Supabase/Mock が override ----
    suspend fun submitInviteCode(code: String) { throw FriendsError.NotSignedIn }
    suspend fun confirmReferralIfEligible(hasFirstRecord: Boolean): ReferralConfirmation? = null
    suspend fun unseenReferrerConfirmations(): List<ReferralConfirmation> = emptyList()
    suspend fun referralSummary(): ReferralSummary = ReferralSummary.EMPTY
    suspend fun hasReferrer(): Boolean = false
```
冒頭 import に追加: `import com.goexercise.app.domain.friends.ReferralConfirmation`, `import com.goexercise.app.domain.friends.ReferralSummary`。

- [ ] **Step 3: MockFriendsService に実装** `MockFriendsService` クラスの private フィールド(`backup` の下)に状態追加:
```kotlin
    // referee 視点: 自分が入力した紹介(あれば1件)。
    private var myReferral: MockReferral? = null
    // referrer 視点: 自分が紹介し confirmed になった件(seen フラグ付き)。
    private val inbound = mutableListOf<MockInbound>()
    private data class MockReferral(val referrerCode: String, var confirmed: Boolean, var confirmedAt: java.time.Instant?)
    private data class MockInbound(val refereeName: String, val at: java.time.Instant, var seen: Boolean)
```
`publishMyProfile` 実装の後に紹介メソッドを追加:
```kotlin
    override suspend fun submitInviteCode(code: String) {
        val meNow = me ?: throw FriendsError.NotSignedIn
        val upper = code.uppercase()
        if (upper == meNow.friendCode) throw FriendsError.CannotAddSelf
        if (myReferral != null) throw FriendsError.DuplicateRequest
        // 紹介者は既知コード(友達/受信申請)なら誰でも可。無ければデモとして合成。
        val referrer = friends.firstOrNull { it.friendCode == upper }
            ?: incoming.firstOrNull { it.fromProfile.friendCode == upper }?.fromProfile
            ?: FriendProfile(friendCode = upper, username = "user_$upper", displayName = "紹介者", currentStreak = 1, totalAchievedDays = 1, todayAchieved = true)
        myReferral = MockReferral(referrer.friendCode, confirmed = false, confirmedAt = null)
        if (friends.none { it.friendCode == referrer.friendCode }) friends.add(referrer)
        incoming.removeAll { it.fromProfile.friendCode == referrer.friendCode }
    }

    override suspend fun confirmReferralIfEligible(hasFirstRecord: Boolean): ReferralConfirmation? {
        val r = myReferral ?: return null
        if (!hasFirstRecord || r.confirmed) return null
        r.confirmed = true; r.confirmedAt = java.time.Instant.now()
        val name = friends.firstOrNull { it.friendCode == r.referrerCode }?.displayName ?: "ともだち"
        return ReferralConfirmation(id = me?.friendCode ?: "me", friendDisplayName = name, role = ReferralConfirmation.Role.REFEREE)
    }

    override suspend fun unseenReferrerConfirmations(): List<ReferralConfirmation> {
        val unseen = inbound.filter { !it.seen }
        unseen.forEach { it.seen = true }
        return unseen.mapIndexed { i, c -> ReferralConfirmation(id = "ref-$i", friendDisplayName = c.refereeName, role = ReferralConfirmation.Role.REFERRER) }
    }

    override suspend fun referralSummary(): ReferralSummary {
        val now = java.time.Instant.now()
        fun sameMonth(t: java.time.Instant): Boolean {
            val a = t.atZone(java.time.ZoneOffset.UTC); val b = now.atZone(java.time.ZoneOffset.UTC)
            return a.year == b.year && a.monthValue == b.monthValue
        }
        val stars = inbound.size
        var bonus = inbound.count { sameMonth(it.at) }
        myReferral?.let { if (it.confirmed && it.confirmedAt?.let(::sameMonth) == true) bonus++ }
        return ReferralSummary(starBadges = stars, freezeBonusThisMonth = bonus)
    }

    override suspend fun hasReferrer(): Boolean = myReferral != null

    /** テスト用: 紹介者として誰かを紹介し confirmed になった状態を注入する。 */
    fun seedInboundConfirmation(refereeName: String, at: java.time.Instant = java.time.Instant.now(), seen: Boolean = false) {
        inbound.add(MockInbound(refereeName, at, seen))
    }
```
`signOut()` と `deleteAccount()` の本体に追加(`backup = AccountBackupStatus.Anonymous` の近く):
```kotlin
        myReferral = null
        inbound.clear()
```
冒頭 import に追加: `import com.goexercise.app.domain.friends.ReferralConfirmation`, `import com.goexercise.app.domain.friends.ReferralSummary`。

- [ ] **Step 4: Mock テスト(runBlocking で実行)** `ReferralServiceTest.kt` を新規作成:
```kotlin
package com.goexercise.app.data

import com.goexercise.app.data.friends.MockFriendsService
import com.goexercise.app.domain.friends.ReferralConfirmation
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class ReferralServiceTest {
    @Test fun submit_autoFriends_andHasReferrer() = runBlocking {
        val svc = MockFriendsService()
        svc.signIn("新規", "newbie")
        svc.submitInviteCode("ABC234")  // seedDemo の友達コード
        assertTrue(svc.hasReferrer())
        assertTrue(svc.refreshFriends().any { it.friendCode == "ABC234" })
    }
    @Test fun submit_rejectsDuplicate() = runBlocking {
        val svc = MockFriendsService(); svc.signIn("新規", "newbie")
        svc.submitInviteCode("ABC234")
        try { svc.submitInviteCode("XYZ789"); fail("should throw") } catch (e: Exception) { /* ok */ }
    }
    @Test fun confirm_returnsRefereePop_thenNull() = runBlocking {
        val svc = MockFriendsService(); svc.signIn("新規", "newbie")
        svc.submitInviteCode("ABC234")
        assertEquals(ReferralConfirmation.Role.REFEREE, svc.confirmReferralIfEligible(true)?.role)
        assertNull(svc.confirmReferralIfEligible(true))
    }
    @Test fun confirm_noFirstRecord_null() = runBlocking {
        val svc = MockFriendsService(); svc.signIn("新規", "newbie")
        svc.submitInviteCode("ABC234")
        assertNull(svc.confirmReferralIfEligible(false))
    }
    @Test fun unseen_markSeen() = runBlocking {
        val svc = MockFriendsService(); svc.signIn("紹介者", "host")
        svc.seedInboundConfirmation("ともだちA")
        assertEquals(1, svc.unseenReferrerConfirmations().size)
        assertTrue(svc.unseenReferrerConfirmations().isEmpty())
    }
    @Test fun summary_starsAndBonus() = runBlocking {
        val svc = MockFriendsService(); svc.signIn("紹介者", "host")
        svc.seedInboundConfirmation("A"); svc.seedInboundConfirmation("B")
        val s = svc.referralSummary()
        assertEquals(2, s.starBadges)
        assertEquals(2, s.freezeBonusThisMonth)
    }
}
```

- [ ] **Step 5: テスト実行** Run: `TEST` → 全 PASS(`ReferralServiceTest` 6件含む)。

- [ ] **Step 6: commit**
```bash
cd /Users/jun/Documents/Business_Project_Management/serial_training
git add app-android/app/src/main/java/com/goexercise/app/data/friends/FriendsService.kt app-android/app/src/test/java/com/goexercise/app/data/ReferralServiceTest.kt
git commit -m "feat(android-referral): FriendsService紹介メソッド(default+Row+Mock実装)+テスト"
```

---

## Task 4: SupabaseFriendsService の紹介メソッド実装

**Files:**
- Modify: `app/src/main/java/com/goexercise/app/data/friends/SupabaseFriendsService.kt`

- [ ] **Step 1: 紹介メソッドを実装** `publishMyProfile` 実装の後・連携セクションの前に追加:
```kotlin
    // ================= 友達紹介(リファラル)=================

    override suspend fun submitInviteCode(code: String) {
        val uid = ensureUid()
        val target = code.uppercase()
        val me = profileRow(uid)
        if (me?.friendCode == target) throw FriendsError.CannotAddSelf
        val referrer = profileRowByCode(target) ?: throw FriendsError.CodeNotFound
        if (referrer.userId == uid) throw FriendsError.CannotAddSelf
        // 1人1紹介者: 既に referee 行があれば不可。
        val existing = client.from("referrals").select {
            filter { eq("referee_user_id", uid) }; limit(1)
        }.decodeList<ReferralRow>()
        if (existing.isNotEmpty()) throw FriendsError.DuplicateRequest
        // pending 紹介を作成(referee=自分。RLS で referee 本人のみ insert 可)。
        client.from("referrals").insert(ReferralInsert(referrerUserId = referrer.userId, refereeUserId = uid))
        // 自動友達化(承認スキップ。upsert は冪等)。
        val (a, b) = orderedPair(uid, referrer.userId)
        client.from("friendships").upsert(FriendshipRow(userA = a, userB = b, status = "active")) { onConflict = "user_a,user_b" }
    }

    override suspend fun confirmReferralIfEligible(hasFirstRecord: Boolean): ReferralConfirmation? {
        if (!hasFirstRecord) return null
        val uid = ensureUid()
        val row = client.from("referrals").select {
            filter { eq("referee_user_id", uid) }; limit(1)
        }.decodeList<ReferralRow>().firstOrNull() ?: return null
        if (row.status != "pending") return null
        val nowIso = java.time.OffsetDateTime.now(java.time.ZoneOffset.UTC)
            .format(java.time.format.DateTimeFormatter.ISO_OFFSET_DATE_TIME)
        client.from("referrals").update(ReferralConfirmUpdate(status = "confirmed", confirmedAt = nowIso)) {
            filter { eq("referee_user_id", uid) }
        }
        val referrerName = profileRow(row.referrerUserId)?.displayName ?: "ともだち"
        return ReferralConfirmation(id = uid, friendDisplayName = referrerName, role = ReferralConfirmation.Role.REFEREE)
    }

    override suspend fun unseenReferrerConfirmations(): List<ReferralConfirmation> {
        // 未サインインなら匿名アカウントを作らず空(ensureUid 不使用)。
        val uid = client.auth.currentUserOrNull()?.id ?: return emptyList()
        val rows = client.from("referrals").select {
            filter { eq("referrer_user_id", uid); eq("status", "confirmed"); eq("seen_by_referrer", false) }
        }.decodeList<ReferralRow>()
        if (rows.isEmpty()) return emptyList()
        val refereeIds = rows.map { it.refereeUserId }
        val byId = client.from("profiles").select { filter { isIn("user_id", refereeIds) } }
            .decodeList<ProfileRow>().associateBy { it.userId }
        client.from("referrals").update(ReferralSeenUpdate(seenByReferrer = true)) {
            filter { eq("referrer_user_id", uid); eq("status", "confirmed"); eq("seen_by_referrer", false) }
        }
        return rows.map { r ->
            ReferralConfirmation(id = r.refereeUserId, friendDisplayName = byId[r.refereeUserId]?.displayName ?: "ともだち", role = ReferralConfirmation.Role.REFERRER)
        }
    }

    override suspend fun referralSummary(): ReferralSummary {
        val uid = client.auth.currentUserOrNull()?.id ?: return ReferralSummary.EMPTY
        val now = java.time.Instant.now()
        val asReferrer = client.from("referrals").select {
            filter { eq("referrer_user_id", uid); eq("status", "confirmed") }
        }.decodeList<ReferralRow>()
        val stars = asReferrer.size
        var bonus = asReferrer.count { com.goexercise.app.domain.friends.ReferralClock.isInMonth(it.confirmedAt, now) }
        val asReferee = client.from("referrals").select {
            filter { eq("referee_user_id", uid); eq("status", "confirmed") }; limit(1)
        }.decodeList<ReferralRow>().firstOrNull()
        if (asReferee != null && com.goexercise.app.domain.friends.ReferralClock.isInMonth(asReferee.confirmedAt, now)) bonus++
        return ReferralSummary(starBadges = stars, freezeBonusThisMonth = bonus)
    }

    override suspend fun hasReferrer(): Boolean {
        val uid = client.auth.currentUserOrNull()?.id ?: return false
        return client.from("referrals").select {
            filter { eq("referee_user_id", uid) }; limit(1)
        }.decodeList<ReferralRow>().isNotEmpty()
    }
```
冒頭 import に追加: `import com.goexercise.app.domain.friends.ReferralConfirmation`, `import com.goexercise.app.domain.friends.ReferralSummary`。

- [ ] **Step 2: 削除連携** `deleteAccount()` の Stage2 フォールバックで `client.from("profiles").delete...` の前に追加:
```kotlin
        client.from("referrals").delete { filter { or { eq("referrer_user_id", uid); eq("referee_user_id", uid) } } }
```

- [ ] **Step 3: ビルド検証** Run: `BUILD`(`./gradlew :app:assembleDebug`)→ `BUILD SUCCESSFUL`。
  - supabase-kt の `.update(value) { filter {...} }` / `.insert(value)` / `.select { filter { isIn(...) } }` の API は既存コードと同型(`acceptRequest`/`refreshFriends`/`sendRequest` 参照)。コンパイルエラーが出たら既存の動く呼び出しに合わせて修正(例: `update` の引数順・ラムダ形)。修正した点は報告。

- [ ] **Step 4: commit**
```bash
cd /Users/jun/Documents/Business_Project_Management/serial_training
git add app-android/app/src/main/java/com/goexercise/app/data/friends/SupabaseFriendsService.kt
git commit -m "feat(android-referral): SupabaseFriendsServiceに紹介の作成/確定/ポーリング/集計+削除連携"
```

---

## Task 5: ReferralStore(@Singleton・StateFlow・Hilt)

**Files:**
- Create: `app/src/main/java/com/goexercise/app/data/referral/ReferralStore.kt`

**Context:** Hilt は `@Singleton class ... @Inject constructor(...)` を自動提供する(別 module 不要)。`DataStore<Preferences>` は既に Hilt で提供されている(`RescueTicketRepositoryImpl` が `@Inject constructor(dataStore: DataStore<Preferences>)` で受けている = 同じ依存を受けられる)。`FriendsService` は `FriendsModule` で `@Singleton` 提供済。

- [ ] **Step 1: 実装** `ReferralStore.kt` を新規作成:
```kotlin
package com.goexercise.app.data.referral

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import com.goexercise.app.data.friends.FriendsService
import com.goexercise.app.domain.friends.FriendCode
import com.goexercise.app.domain.friends.ReferralConfirmation
import com.goexercise.app.domain.friends.ReferralEntryPolicy
import com.goexercise.app.domain.friends.ReferralSummary
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 友達紹介の状態を保持しアプリ全体へ供給する @Singleton ストア。iOS `ReferralStore` の移植。
 * - summary: 星バッジ数 + 今月フリーズ加算(RescueViewModel が allowance に反映)。
 * - hasReferrer: 自分が referee の紹介行が既にあるか(後から入力の可否)。
 * - pendingWelcome / pendingReferrerPops: 確定ポップ2種。
 * 未サインイン時は何もしない(孤児アカウント防止)。
 */
@Singleton
class ReferralStore @Inject constructor(
    private val service: FriendsService,
    private val dataStore: DataStore<Preferences>,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val firstLaunchKey = longPreferencesKey("referral_first_launch_epoch_seconds")

    private val _summary = MutableStateFlow(ReferralSummary.EMPTY)
    val summary: StateFlow<ReferralSummary> = _summary.asStateFlow()
    private val _hasReferrer = MutableStateFlow(false)
    val hasReferrer: StateFlow<Boolean> = _hasReferrer.asStateFlow()
    private val _pendingWelcome = MutableStateFlow<ReferralConfirmation?>(null)
    val pendingWelcome: StateFlow<ReferralConfirmation?> = _pendingWelcome.asStateFlow()
    private val _pendingReferrerPops = MutableStateFlow<List<ReferralConfirmation>>(emptyList())
    val pendingReferrerPops: StateFlow<List<ReferralConfirmation>> = _pendingReferrerPops.asStateFlow()
    private val _firstLaunchAt = MutableStateFlow<Instant?>(null)
    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    init {
        scope.launch {
            val prefs = dataStore.data.first()
            val existing = prefs[firstLaunchKey]
            if (existing != null) {
                _firstLaunchAt.value = Instant.ofEpochSecond(existing)
            } else {
                val now = Instant.now()
                _firstLaunchAt.value = now
                dataStore.edit { it[firstLaunchKey] = now.epochSecond }
            }
        }
    }

    /** 設定からの「後から入力」を出してよいか(同期 snapshot 判定)。 */
    fun canEnterCodeLater(now: Instant = Instant.now()): Boolean =
        ReferralEntryPolicy.canEnterCodeLater(_firstLaunchAt.value, now, _hasReferrer.value)

    private suspend fun isSignedIn(): Boolean = service.myProfile() != null

    suspend fun refresh() {
        if (!isSignedIn()) return
        try {
            _summary.value = service.referralSummary()
            _hasReferrer.value = service.hasReferrer()
        } catch (e: Exception) { _lastError.value = e.message }
    }

    /** 招待コード送信(オンボ/設定)。未サインインなら匿名サインインしてから送る。 */
    suspend fun submitCode(raw: String): Boolean {
        val code = FriendCode.sanitize(raw)
        if (!FriendCode.isValid(code)) { _lastError.value = "招待コードは6文字です。もう一度確認してください"; return false }
        return try {
            if (service.myProfile() == null) service.signIn(displayName = "ねこの友", username = generatedUsername())
            service.submitInviteCode(code)
            _hasReferrer.value = true
            refresh()
            true
        } catch (e: Exception) { _lastError.value = e.message; false }
    }

    /** 初運動記録到達時に呼ぶ。確定したら新規ポップをセット。 */
    suspend fun confirmFirstRecordIfNeeded(hasFirstRecord: Boolean) {
        if (!isSignedIn() || !hasFirstRecord || !_hasReferrer.value) return
        try {
            service.confirmReferralIfEligible(true)?.let { _pendingWelcome.value = it; refresh() }
        } catch (e: Exception) { _lastError.value = e.message }
    }

    /** 起動時に紹介者ポップを取り込む(取得分は seen 済みになる)。 */
    suspend fun pollReferrerPops() {
        if (!isSignedIn()) return
        try {
            val pops = service.unseenReferrerConfirmations()
            if (pops.isNotEmpty()) { _pendingReferrerPops.value = pops; refresh() }
        } catch (e: Exception) { _lastError.value = e.message }
    }

    fun consumeWelcome() { _pendingWelcome.value = null }
    fun consumeReferrerPops() { _pendingReferrerPops.value = emptyList() }
    fun clearError() { _lastError.value = null }

    private fun generatedUsername(): String = "neko" + java.util.UUID.randomUUID().toString().replace("-", "").take(6).lowercase()
}
```

- [ ] **Step 2: FriendCode に sanitize/isValid があるか確認** `domain/friends/FriendCode.kt`(または FriendProfile 周辺)を読み、`FriendCode.sanitize(String): String` と `FriendCode.isValid(String): Boolean` が存在するか確認。**無ければ追加する**(iOS `FriendCodeValidator` 相当):
```kotlin
// FriendCode object 内に追加(既存の generate() の近く)
private const val ALLOWED = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
fun sanitize(raw: String): String =
    raw.uppercase().filter { it in ALLOWED }.take(6)
fun isValid(code: String): Boolean =
    code.length == 6 && code.all { it in ALLOWED }
```
(FriendCode の現定義を読み、length/alphabet 定数が既にあればそれを使い回す。重複定義を避ける。)

- [ ] **Step 3: ビルド検証** Run: `BUILD` → `BUILD SUCCESSFUL`。Hilt が `ReferralStore` を `@Singleton @Inject` で解決できることを確認(DataStore<Preferences> と FriendsService は既存提供)。

- [ ] **Step 4: commit**
```bash
cd /Users/jun/Documents/Business_Project_Management/serial_training
git add app-android/app/src/main/java/com/goexercise/app/data/referral/ReferralStore.kt app-android/app/src/main/java/com/goexercise/app/domain/friends/
git commit -m "feat(android-referral): ReferralStore(@Singleton/StateFlow)+ FriendCode sanitize/isValid"
```

---

## Task 6: allowance 配線 + 初記録確定フック + 起動時ポーリング

**Files:**
- Modify: `app/src/main/java/com/goexercise/app/presentation/rescue/RescueViewModel.kt`
- Modify: `app/src/main/java/com/goexercise/app/presentation/home/HomeViewModel.kt`
- Modify: `app/src/main/java/com/goexercise/app/MainActivity.kt`

- [ ] **Step 1: RescueViewModel に紹介ボーナスを反映** `RescueViewModel.kt` を読み、`@Inject constructor` に `private val referralStore: ReferralStore` を追加。`RescueTicketAllowance.current(isPremium)` を呼ぶ2箇所(:55, :67 付近)を `RescueTicketAllowance.current(isPremium, referralStore.summary.value.freezeBonusThisMonth)` に変更。import 追加 `com.goexercise.app.data.referral.ReferralStore`。
  - 注: `summary` は StateFlow なので `.value` で同期 snapshot を取る(allowance 計算は同期)。起動時 `referralStore.refresh()`(Task6 Step3)で値が入る。

- [ ] **Step 2: HomeViewModel に初記録確定フックを追加** `HomeViewModel.kt` の init ブロック(stats 変化で `publishMyProfile` する箇所, :124-145 付近)を読む。`@Inject constructor` に `private val referralStore: ReferralStore` を追加。publish を行う `if (signature changed)` ブロックの後(publish 呼び出しと同じ collect 内)で、`AppFeatureFlags.isReferralActive` のとき確定を試みる:
```kotlin
                if (com.goexercise.app.AppFeatureFlags.isReferralActive) {
                    referralStore.confirmFirstRecordIfNeeded(state.lifetimeStats.achievedDays >= 1)
                }
```
(`state` は collect 中の `HomeUiState`。`lifetimeStats.achievedDays` は既に publish で使っている値。publish 同様 myProfile!=null 前提の流れに置く。)import 追加 `com.goexercise.app.data.referral.ReferralStore`。

- [ ] **Step 3: 起動時ポーリング** `MainActivity.kt`(`@AndroidEntryPoint`)に `ReferralStore` を注入し、起動時に refresh + pollReferrerPops。MainActivity に:
```kotlin
    @javax.inject.Inject lateinit var referralStore: com.goexercise.app.data.referral.ReferralStore
```
`onCreate` の `super.onCreate(...)` 後・setContent 周辺で:
```kotlin
        if (com.goexercise.app.AppFeatureFlags.isReferralActive) {
            lifecycleScope.launch {
                referralStore.refresh()
                referralStore.pollReferrerPops()
            }
        }
```
import 追加 `androidx.lifecycle.lifecycleScope`, `kotlinx.coroutines.launch`(未importなら)。
  - `@AndroidEntryPoint` 済なので field injection 可。`referralStore` は @Singleton。

- [ ] **Step 4: ビルド検証** Run: `BUILD` → `BUILD SUCCESSFUL`。

- [ ] **Step 5: commit**
```bash
cd /Users/jun/Documents/Business_Project_Management/serial_training
git add app-android/app/src/main/java/com/goexercise/app/presentation/rescue/RescueViewModel.kt app-android/app/src/main/java/com/goexercise/app/presentation/home/HomeViewModel.kt app-android/app/src/main/java/com/goexercise/app/MainActivity.kt
git commit -m "feat(android-referral): allowance配線(RescueVM)+初記録確定フック(HomeVM)+起動ポーリング"
```

---

## Task 7: 確定ポップ(AlertDialog)

**Files:**
- Create: `app/src/main/java/com/goexercise/app/presentation/referral/ReferralCelebrationDialog.kt`
- Modify: `app/src/main/java/com/goexercise/app/presentation/home/HomeScreen.kt`(or HomeRoute)

- [ ] **Step 1: ポップ Composable を作成** 既存の `MilestoneCelebrationDialog`(HomeScreen.kt 付近)を読み、同じ palette/AlertDialog スタイルに合わせて `ReferralCelebrationDialog.kt` を作成:
```kotlin
package com.goexercise.app.presentation.referral

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp
import com.goexercise.app.domain.friends.ReferralConfirmation

/**
 * 友達紹介の確定ポップ。新規(される側=ウェルカム)と紹介者(する側=参加通知)を出し分け。
 * 複数の紹介者ポップは1枚に列挙。iOS `ReferralCelebrationSheet` 相当。
 */
@Composable
fun ReferralCelebrationDialog(confirmations: List<ReferralConfirmation>, onDismiss: () -> Unit) {
    if (confirmations.isEmpty()) return
    val isWelcome = confirmations.first().role == ReferralConfirmation.Role.REFEREE
    val title = if (isWelcome) "友達とつながりました！" else "紹介した友達が参加しました！"
    val body = if (isWelcome) {
        "${confirmations.first().friendDisplayName} さんの招待で参加\n❄️ ウェルカム・フリーズ +1(今月)"
    } else {
        confirmations.joinToString("\n") { "${it.friendDisplayName} さんが参加！" } +
            "\n❄️ フリーズ +1(今月・上限5)\n⭐ 星バッジ +${confirmations.size}"
    }
    AlertDialog(
        onDismissRequest = onDismiss,
        icon = { Text(if (isWelcome) "✨" else "⭐", fontSize = 40.sp) },
        title = { Text(title, textAlign = TextAlign.Center) },
        text = { Text(body, textAlign = TextAlign.Center) },
        confirmButton = { TextButton(onClick = onDismiss) { Text("やったね！") } },
    )
}
```
(既存 `MilestoneCelebrationDialog` が `containerColor = palette.surface` 等を使っていれば合わせる。実装者は近傍に合わせて palette を適用。)

- [ ] **Step 2: HomeRoute で提示** `HomeScreen.kt` の `HomeRoute`(`MilestoneCelebrationDialog` を出している箇所)で、`ReferralStore` を `hiltViewModel` 経由ではなく **HomeViewModel 経由で公開**するのが簡単。HomeViewModel に referralStore の StateFlow を中継する公開プロパティを足す:
  - `HomeViewModel.kt` に追加: `val pendingWelcome = referralStore.pendingWelcome`、`val pendingReferrerPops = referralStore.pendingReferrerPops`、`fun consumeWelcome() = referralStore.consumeWelcome()`、`fun consumeReferrerPops() = referralStore.consumeReferrerPops()`。
  - `HomeRoute` で収集して提示:
```kotlin
    val welcome by viewModel.pendingWelcome.collectAsStateWithLifecycle()
    val referrerPops by viewModel.pendingReferrerPops.collectAsStateWithLifecycle()
    if (com.goexercise.app.AppFeatureFlags.isReferralActive) {
        welcome?.let { ReferralCelebrationDialog(listOf(it)) { viewModel.consumeWelcome() } }
        if (referrerPops.isNotEmpty()) ReferralCelebrationDialog(referrerPops) { viewModel.consumeReferrerPops() }
    }
```
import 追加(`ReferralCelebrationDialog`, `collectAsStateWithLifecycle` が既存なら流用)。

- [ ] **Step 3: ビルド検証** Run: `BUILD` → `BUILD SUCCESSFUL`。

- [ ] **Step 4: commit**
```bash
cd /Users/jun/Documents/Business_Project_Management/serial_training
git add app-android/app/src/main/java/com/goexercise/app/presentation/referral/ReferralCelebrationDialog.kt app-android/app/src/main/java/com/goexercise/app/presentation/home/HomeScreen.kt app-android/app/src/main/java/com/goexercise/app/presentation/home/HomeViewModel.kt
git commit -m "feat(android-referral): 確定ポップ(新規ウェルカム/紹介者参加)AlertDialog + Home提示"
```

---

## Task 8: 招待コード入力欄 + オンボ差し込み

**Files:**
- Create: `app/src/main/java/com/goexercise/app/presentation/referral/InviteCodeField.kt`
- Modify: `app/src/main/java/com/goexercise/app/presentation/onboarding/OnboardingScreen.kt`
- Modify: `app/src/main/java/com/goexercise/app/presentation/onboarding/OnboardingViewModel.kt`

- [ ] **Step 1: 入力欄 Composable** `InviteCodeField.kt` を作成:
```kotlin
package com.goexercise.app.presentation.referral

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.goexercise.app.domain.friends.FriendCode

/** 招待コード入力欄(オンボ・設定で再利用)。入力は自己補正(大文字化・許可文字・6桁)。 */
@Composable
fun InviteCodeField(
    code: String,
    onCodeChange: (String) -> Unit,
    isSubmitting: Boolean,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("招待コードをお持ちですか？（任意）", style = MaterialTheme.typography.titleSmall)
        Text("友達のコードを入れると、お互いにフリーズが増えます。", style = MaterialTheme.typography.bodySmall)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            OutlinedTextField(
                value = code,
                onValueChange = { onCodeChange(FriendCode.sanitize(it)) },
                placeholder = { Text("ABC123") },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            Button(onClick = onSubmit, enabled = FriendCode.isValid(code) && !isSubmitting) {
                if (isSubmitting) CircularProgressIndicator(modifier = Modifier.size(18.dp)) else Text("送信")
            }
        }
    }
}
```

- [ ] **Step 2: OnboardingViewModel に紹介送信を追加** `OnboardingViewModel.kt` の `@Inject constructor` に `private val referralStore: ReferralStore` を追加。StateFlow と submit を公開:
```kotlin
    private val _inviteCode = kotlinx.coroutines.flow.MutableStateFlow("")
    val inviteCode: kotlinx.coroutines.flow.StateFlow<String> = _inviteCode
    private val _inviteSubmitting = kotlinx.coroutines.flow.MutableStateFlow(false)
    val inviteSubmitting: kotlinx.coroutines.flow.StateFlow<Boolean> = _inviteSubmitting
    private val _inviteAccepted = kotlinx.coroutines.flow.MutableStateFlow(false)
    val inviteAccepted: kotlinx.coroutines.flow.StateFlow<Boolean> = _inviteAccepted
    val inviteError get() = referralStore.lastError

    fun onInviteCodeChange(v: String) { _inviteCode.value = v }
    fun submitInvite() {
        _inviteSubmitting.value = true
        referralStore.clearError()
        viewModelScope.launch {
            val ok = referralStore.submitCode(_inviteCode.value)
            _inviteSubmitting.value = false
            if (ok) _inviteAccepted.value = true
        }
    }
```
import 追加: `com.goexercise.app.data.referral.ReferralStore`, `androidx.lifecycle.viewModelScope`, `kotlinx.coroutines.launch`。

- [ ] **Step 3: OnboardingScreen に欄を差し込む** `OnboardingScreen.kt` を読み、breed グリッドの後・finish ボタンの前に、onboarding かつ `AppFeatureFlags.isReferralActive` のとき `InviteCodeField` を表示。`OnboardingScreen` は `onFinish: (CatBreed)->Unit` の stateless composable なので、紹介 state を渡すために `OnboardingRoute`(hiltViewModel を持つ composable)側で `OnboardingViewModel` の invite StateFlow を集めて `InviteCodeField` を描画する。`OnboardingRoute`(または OnboardingScreen を呼ぶ親)で:
```kotlin
    val inviteCode by viewModel.inviteCode.collectAsStateWithLifecycle()
    val submitting by viewModel.inviteSubmitting.collectAsStateWithLifecycle()
    val accepted by viewModel.inviteAccepted.collectAsStateWithLifecycle()
    val inviteErr by viewModel.inviteError.collectAsStateWithLifecycle()
```
そして breed グリッドと finish の間に:
```kotlin
        if (com.goexercise.app.AppFeatureFlags.isReferralActive) {
            if (accepted) {
                Text("招待コードを適用しました！")
            } else {
                InviteCodeField(code = inviteCode, onCodeChange = viewModel::onInviteCodeChange, isSubmitting = submitting, onSubmit = viewModel::submitInvite)
                inviteErr?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            }
        }
```
(OnboardingScreen の実構造に合わせて差し込み位置/配線を調整。OnboardingScreen が breed と finish を内包する単一 composable なら、invite UI もそこに引数で渡すか、Route 側でラップする。実装者は最小改変で配線し、差し込み位置を報告。)

- [ ] **Step 4: ビルド検証** Run: `BUILD` → `BUILD SUCCESSFUL`。

- [ ] **Step 5: commit**
```bash
cd /Users/jun/Documents/Business_Project_Management/serial_training
git add app-android/app/src/main/java/com/goexercise/app/presentation/referral/InviteCodeField.kt app-android/app/src/main/java/com/goexercise/app/presentation/onboarding/
git commit -m "feat(android-referral): 招待コード入力欄 + オンボに差し込み"
```

---

## Task 9: 設定の招待共有 + 星バッジ + 後から入力

**Files:**
- Modify: `app/src/main/java/com/goexercise/app/presentation/settings/SettingsViewModel.kt`
- Modify: `app/src/main/java/com/goexercise/app/presentation/settings/SettingsScreen.kt`

- [ ] **Step 1: SettingsViewModel に紹介を公開** `@Inject constructor` に `private val referralStore: ReferralStore` と `private val friendsService: FriendsService` を追加(friendsService は friendCode 取得用。既に注入済なら流用)。公開:
```kotlin
    val referralSummary = referralStore.summary
    private val _myFriendCode = kotlinx.coroutines.flow.MutableStateFlow<String?>(null)
    val myFriendCode: kotlinx.coroutines.flow.StateFlow<String?> = _myFriendCode
    val canEnterCodeLater get() = referralStore.canEnterCodeLater()
    private val _laterCode = kotlinx.coroutines.flow.MutableStateFlow("")
    val laterCode: kotlinx.coroutines.flow.StateFlow<String> = _laterCode
    private val _laterSubmitting = kotlinx.coroutines.flow.MutableStateFlow(false)
    val laterSubmitting: kotlinx.coroutines.flow.StateFlow<Boolean> = _laterSubmitting
    private val _laterAccepted = kotlinx.coroutines.flow.MutableStateFlow(false)
    val laterAccepted: kotlinx.coroutines.flow.StateFlow<Boolean> = _laterAccepted
    val referralError get() = referralStore.lastError

    init { viewModelScope.launch { _myFriendCode.value = friendsService.myProfile()?.friendCode; referralStore.refresh() } }
    fun onLaterCodeChange(v: String) { _laterCode.value = v }
    fun inviteMessage(code: String): String =
        "GOエクササイズで一緒に運動しよう！オンボーディングでこの招待コードを入れると、お互いにフリーズがもらえます → $code\nhttps://play.google.com/store/apps/details?id=com.goexercise.app"
    fun submitLaterInvite() {
        _laterSubmitting.value = true; referralStore.clearError()
        viewModelScope.launch {
            val ok = referralStore.submitCode(_laterCode.value)
            _laterSubmitting.value = false
            if (ok) _laterAccepted.value = true
            // 確定は Home の初記録フックに委ねる(幽霊確定を防ぐため here では confirm しない)。
        }
    }
```
import 追加: ReferralStore, FriendsService, viewModelScope, launch。

- [ ] **Step 2: SettingsScreen に紹介セクション** `SettingsScreen.kt` を読み、friends/データ管理セクションの並びに、`AppFeatureFlags.isReferralActive` ゲートで「友達を招待」セクションを追加。共有は `Intent.ACTION_SEND`(text/plain、既存の `shareJsonExport` パターン参照):
```kotlin
        if (com.goexercise.app.AppFeatureFlags.isReferralActive) {
            // 見出し(既存セクションの書式に合わせる)
            val code by viewModel.myFriendCode.collectAsStateWithLifecycle()
            val summary by viewModel.referralSummary.collectAsStateWithLifecycle()
            // 招待する(共有)
            code?.let { c ->
                SettingsRow(/* 既存の行コンポーネント or ListItem */ title = "友達を招待する", onClick = {
                    val msg = viewModel.inviteMessage(c)
                    val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                        type = "text/plain"; putExtra(android.content.Intent.EXTRA_TEXT, msg)
                    }
                    context.startActivity(android.content.Intent.createChooser(intent, "友達を招待"))
                })
            }
            // 星バッジ
            Text("紹介した友達: ${summary.starBadges} 人")
            // 後から入力(7日以内 & 紹介者未登録)
            if (viewModel.canEnterCodeLater) {
                val accepted by viewModel.laterAccepted.collectAsStateWithLifecycle()
                if (accepted) {
                    Text("招待コードを適用しました！")
                } else {
                    val lcode by viewModel.laterCode.collectAsStateWithLifecycle()
                    val sub by viewModel.laterSubmitting.collectAsStateWithLifecycle()
                    val err by viewModel.referralError.collectAsStateWithLifecycle()
                    InviteCodeField(code = lcode, onCodeChange = viewModel::onLaterCodeChange, isSubmitting = sub, onSubmit = viewModel::submitLaterInvite)
                    err?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                }
            }
        }
```
(SettingsScreen の実コンポーネント(行/セクションの作法)に合わせて整える。`context` は `LocalContext.current`。実装者は既存 UI コンポーネントを使って体裁を合わせ、差し込み位置を報告。`InviteCodeField` import。)

- [ ] **Step 3: ビルド検証** Run: `BUILD` → `BUILD SUCCESSFUL`。

- [ ] **Step 4: commit**
```bash
cd /Users/jun/Documents/Business_Project_Management/serial_training
git add app-android/app/src/main/java/com/goexercise/app/presentation/settings/
git commit -m "feat(android-referral): 設定に招待共有/星バッジ/後から入力(7日以内)"
```

---

## Task 10: 統合ビルド + 全テスト + 掃除

**Files:** なし(検証)

- [ ] **Step 1: iCloud 重複掃除 + クリーンビルド**
```bash
cd /Users/jun/Documents/Business_Project_Management/serial_training/app-android
find app/build -name "* [0-9].*" -delete 2>/dev/null; find build -name "* [0-9].*" -delete 2>/dev/null
./gradlew :app:assembleDebug 2>&1 | tail -5
```
Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 2: 全単体テスト実行**
```bash
./gradlew :app:testDebugUnitTest 2>&1 | tail -8
```
Expected: `BUILD SUCCESSFUL`。`ReferralLogicTest`(10)+ `ReferralServiceTest`(6)含め全 PASS、既存 ~150 テストも緑(回帰なし)。

- [ ] **Step 3: キルスイッチ確認** `grep -rn "isReferralActive" app/src/main` で UI/ポーリング/フック全箇所がゲートされていることを確認(Settings/Onboarding/Home/MainActivity)。

- [ ] **Step 4: スコープ確認** `git log --oneline feature/friends-release..HEAD`(or 分岐元..HEAD)で Android 紹介コミットのみが乗っていること、`app-android` 以外を触っていないことを確認。

---

## Self-Review

**iOS パリティ:**
- データモデル `referrals`(共有BE)・確定=クライアント主導(profile publish 相乗り)・月次ボーナス clip5・星バッジ=件数算出・1人1紹介者・自己紹介不可・新規初記録ゲート・孤児防止(passive read は currentUserOrNull、active は ensureUid)— すべて iOS と同設計。
- 型整合: `ReferralSummary`/`ReferralConfirmation(Role)`/`ReferralClock.isInMonth`/`ReferralEntryPolicy.canEnterCodeLater` を Task2 定義 → Task3/4/5 で使用。`RescueTicketAllowance.current(isPremium, referralBonus)` を Task1 定義 → Task6(RescueVM)で使用。service 5メソッドを Task3(interface+Mock)→ Task4(Supabase)実装 → Task5(ReferralStore)が呼ぶ。
- UTC 月判定: `ReferralClock` は `atZone(UTC)` で月キー化(iOS の monthKey UTC 固定と一致)。テストの `2026-05-31T23:00:00+00:00`=May が機種TZに依らず false。

**Android 固有の留意点(実装者向け):**
- supabase-kt の `.update(value){ filter{} }` / `.insert(value)` / `.select{ filter{ isIn() } }` は既存 `SupabaseFriendsService` の呼び出しと同型。型が合わなければ**同ファイルの動く呼び出しに合わせて**修正し報告。
- `ReferralStore.canEnterCodeLater()` は `_firstLaunchAt`(init で DataStore から非同期ロード)の snapshot を読む。初回起動直後の極短時間は null=false になり得る(設定画面到達時には解決済み=実害なし)。
- 確定ポップ2枚同時 true は稀(welcome=初記録時/referrer=起動時)。Compose は両 AlertDialog を順に出せるが、同時表示は welcome 優先で良い(実害小)。
- Mock の `submitInviteCode` は既知コード(友達/受信申請)優先、無ければ合成 friend を作る(UI 動作確認用)。実 Supabase は profiles を引く。
- `FriendCode.sanitize/isValid` は Task5 Step2 で存在確認・無ければ追加(重複定義回避)。
- ビルドは JAVA_HOME=JBR・iCloud重複掃除を毎回。テストは実行されるので緑を必ず確認(iOS と違い compile だけで済ませない)。
