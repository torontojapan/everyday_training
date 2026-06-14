# 友達紹介(リファラル)実装計画 (iOS / v1.1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (推奨) または superpowers:executing-plans でタスク単位に実装する。Steps は checkbox (`- [ ]`) で進捗管理する。

**Goal:** 既存の friend_code を招待コードに流用し、新規がオンボ(または登録7日以内の設定)でコード入力→自動友達化→新規の初運動記録で確定→双方へフリーズ+星バッジを付与しポップ表示する拡散ループを iOS に実装する。

**Architecture:** Supabase に新表 `referrals`(referee 主キー=1人1紹介者)を足し、確定はクライアント主導(新規が自分の referee 行を `total_achieved_days>=1` で confirmed に更新=既存 profile 公開経路に相乗り)。フリーズ会計は純関数 `RescueTicketAllowance.current(isPremium:referralBonus:)`(`min(5, base+bonus)`)に単一ソース化。紹介状態は `@Observable ReferralStore` が保持し、起動時ポーリング(紹介者ポップ)・初記録時確定(新規ポップ)・星バッジ数を供給する。UI は friendsEnabled ゲート下にオンボ入力欄・設定の後から入力欄・共有(招待する)ボタン・星バッジ・2種の確定ポップを追加する。

**Tech Stack:** Swift 6 / SwiftUI / @Observable / supabase-swift (PostgREST + Anonymous Auth) / XCTest(compile-gate)+ swiftc ネイティブ実行(純ロジック)。対象 `app/GOExercise`。

**前提/環境メモ:**
- スペック `docs/superpowers/specs/2026-06-05-friend-referral-design.md`。友達機能は v1.1 で解禁済 (`AppFeatureFlags.friendsEnabled == true`)。本機能は友達 BE に依存するため全面的に friendsEnabled ゲート下に置く。
- **ブランチ**: `feature/achievement-decorations` を継続(v1.1 グラブバッグ。装飾+猫種課金と同居)。
- **iOS シミュレータのテストランナーはハングするため `xcodebuild test` は実行しない**。検証は (a) 純ロジック=新規 `.swift` を一時 main と一緒に `swiftc` でビルドしてネイティブ実行、(b) XCTest ファイル=`build-for-testing` で**コンパイル**を緑にする、(c) UI/サービス=`xcodebuild build`。
- **XcodeGen 注意**: ソースはフォルダ自動収集(`project.yml:31`)。新規 `.swift` は所定フォルダに置けば自動でターゲットに入る。`xcodegen generate` を**実行しない**(本計画は新規ファイル追加のみで .pbxproj 手当て不要。もし実行が必要になったら直後に `git diff app/GOExercise/GOExercise/Resources/Info.plist` で `FriendsAppleLinkEnabled` / `TelemetryDeckAppID` が消えていないか必ず確認 — gotcha_xcodegen_infoplist_drop)。
- **iCloud 重複**: 一括リネーム後は `find app/GOExercise/build -name "* [0-9].*" -delete` で掃除(本計画では発生しない想定)。
- 確定経路はクライアント主導(spec §4.1)。Edge Function 化は v1 スコープ外。

**共通ビルドコマンド(以後 `BUILD=`, `TESTBUILD=` と表記):**
```bash
# UI/サービスのビルド検証
xcodebuild build -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'
# XCTest コンパイル検証 (実行はしない)
xcodebuild build-for-testing -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|TEST BUILD SUCCEEDED|BUILD FAILED'
```
作業ディレクトリは `app/GOExercise`(project.yml のある場所)。シミュレータ名はローカルの利用可能機種に合わせて可。

---

## ファイル構成 (作成/変更マップ)

**作成:**
- `app/GOExercise/GOExercise/Models/Referral.swift` — ドメイン型(`ReferralSummary` / `ReferralConfirmation`)+ `ReferralClock`(timestamp 解析・月判定)+ `ReferralEntryPolicy`(後から入力の許可判定)。すべて非 isolated・依存ゼロ=ネイティブ実行可。
- `app/GOExercise/GOExercise/Services/ReferralStore.swift` — `@Observable` 紹介状態ストア(summary / hasReferrer / pendingWelcome / pendingReferrerPops)。
- `app/GOExercise/GOExercise/Views/ReferralCelebrationSheet.swift` — 確定ポップ(新規=ウェルカム / 紹介者=参加通知)の共通シート。
- `app/GOExercise/GOExercise/Views/InviteCodeField.swift` — 招待コード入力欄の共通コンポーネント(オンボ・設定で再利用)。
- `app/GOExercise/GOExerciseTests/ReferralLogicTests.swift` — 純ロジック XCTest(コンパイルゲート)。
- `app/GOExercise/GOExerciseTests/ReferralStoreTests.swift` — Mock 経由のストア XCTest(コンパイルゲート)。
- `/tmp/referral_native_check.swift` — ネイティブ実行用の一時 main(コミットしない)。

**変更:**
- `supabase/schema.sql` — `referrals` 表 + GRANT + RLS を追記。
- `app/GOExercise/GOExercise/Services/RescueTicketStore.swift` — `RescueTicketAllowance` にボーナス対応オーバーロード追加。
- `app/GOExercise/GOExercise/ViewModels/HomeViewModel.swift` — `referralFreezeBonus` を受けて allowance に反映。
- `app/GOExercise/GOExercise/Services/AppFeatureFlags.swift` — `referralEnabled` キルスイッチ追加。
- `app/GOExercise/GOExercise/Services/FriendsService.swift` — protocol に紹介メソッド5本 + 既定実装を追加。
- `app/GOExercise/GOExercise/Services/MockFriendsService.swift` — 紹介メソッドの in-memory 実装。
- `app/GOExercise/GOExercise/Services/SupabaseFriendsService.swift` — 紹介メソッドの実装 + Row/Write 構造体。
- `app/GOExercise/GOExercise/App/GOExerciseApp.swift` — `ReferralStore` 生成・environment 注入・起動時ポーリング。
- `app/GOExercise/GOExercise/Views/UserCatPickerView.swift` — オンボに招待コード欄を追加。
- `app/GOExercise/GOExercise/Views/HomeView.swift` — 初記録時の確定フック + 新規ポップ提示 + allowance ボーナス受け渡し。
- `app/GOExercise/GOExercise/Views/SettingsView.swift` — 「友達を招待」共有ボタン・星バッジ表示・後から入力欄。

---

## Task 1: Supabase `referrals` 表 + RLS

**Files:**
- Modify: `supabase/schema.sql`(`cheers` ブロックの後、`-- ============ 権限` の前に挿入)

- [ ] **Step 1: 表 + index を追記**

`supabase/schema.sql` の `cheers` の index 行(`create index if not exists cheers_to_user_idx ...`)の直後に、空行を挟んで以下を追加:
```sql
-- ============ referrals (友達紹介。referee 主キー = 1人1紹介者) ============
create table if not exists public.referrals (
  referrer_user_id uuid not null references auth.users(id) on delete cascade,
  referee_user_id  uuid not null references auth.users(id) on delete cascade,
  status           text not null default 'pending',  -- pending / confirmed
  created_at       timestamptz not null default now(),
  confirmed_at     timestamptz,
  seen_by_referrer boolean not null default false,    -- 紹介者ポップ表示済みフラグ
  primary key (referee_user_id),                       -- 1人1紹介者 (ユニーク)
  check (referrer_user_id <> referee_user_id)          -- 自己紹介不可
);
create index if not exists referrals_referrer_idx on public.referrals (referrer_user_id, status);
```

- [ ] **Step 2: GRANT に referrals を追加**

`grant select, insert, update, delete on` の対象リスト(現在 `public.profiles, public.friend_requests, public.friendships, public.cheers`)に `, public.referrals` を加える:
```sql
grant select, insert, update, delete on
  public.profiles, public.friend_requests, public.friendships, public.cheers, public.referrals
  to authenticated;
```

- [ ] **Step 3: RLS 有効化 + ポリシーを追記**

`alter table public.cheers enable row level security;` の直後に追加:
```sql
alter table public.referrals enable row level security;
```
そして `cheers_delete` ポリシー定義の後(ファイル末尾)に追加:
```sql
-- referrals:
--  - insert: 自分が referee の行のみ作成可 (招待コードを入力した新規本人)。
--  - select: 当事者 (referrer / referee) のみ。
--  - update: referee は自分の行を confirm 可 / referrer は自分が紹介した行の
--    seen_by_referrer を更新可。当事者以外は不可。
--  - delete: 当事者のみ (アカウント削除導線で本人行を消すため)。
drop policy if exists referrals_insert on public.referrals;
create policy referrals_insert on public.referrals
  for insert to authenticated with check (auth.uid() = referee_user_id);
drop policy if exists referrals_select on public.referrals;
create policy referrals_select on public.referrals
  for select to authenticated using (auth.uid() = referrer_user_id or auth.uid() = referee_user_id);
drop policy if exists referrals_update on public.referrals;
create policy referrals_update on public.referrals
  for update to authenticated
  using (auth.uid() = referrer_user_id or auth.uid() = referee_user_id)
  with check (auth.uid() = referrer_user_id or auth.uid() = referee_user_id);
drop policy if exists referrals_delete on public.referrals;
create policy referrals_delete on public.referrals
  for delete to authenticated using (auth.uid() = referrer_user_id or auth.uid() = referee_user_id);
```

- [ ] **Step 4: アカウント削除との整合を確認(コードレビューのみ)**

`SupabaseFriendsService.deleteAccount()` / `signOut()` は `auth.users` を Edge Function で消す経路があり `referrals` も `on delete cascade` で連鎖削除される。クライアント側フォールバック削除(`signOut` の匿名データ削除・`deleteAccount` のフォールバック)には referrals の明示 delete を **Task 5 Step で追加**する(ここでは表側 RLS で当事者 delete を許可済み=準備完了)。本 Step は実装不要、整合確認のみ。

- [ ] **Step 5: commit**
```bash
git add supabase/schema.sql
git commit -m "feat(referral): Supabase referrals表(referee主キー/RLS当事者限定)を追加"
```

> 注: schema.sql は手動で Supabase SQL Editor に貼って Run する運用(`create table if not exists` で冪等)。本番反映は v1.1 アーカイブ前に実施。

---

## Task 2: フリーズ会計の単一ソース化(純ロジック・TDD)

**Files:**
- Modify: `app/GOExercise/GOExercise/Services/RescueTicketStore.swift`(末尾の `enum RescueTicketAllowance` を拡張)
- Test: `app/GOExercise/GOExerciseTests/ReferralLogicTests.swift`(新規・本タスクで作成)

- [ ] **Step 1: 失敗するテストを書く**

`app/GOExercise/GOExerciseTests/ReferralLogicTests.swift` を新規作成:
```swift
import XCTest
@testable import GOExercise

final class ReferralLogicTests: XCTestCase {

    // MARK: - RescueTicketAllowance (base + 紹介ボーナス, 月次上限5)
    func test_allowance_base_unchanged() {
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: false, referralBonus: 0), 1)
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: true,  referralBonus: 0), 4)
    }
    func test_allowance_addsBonus_clipsAt5() {
        // 無料1 + 紹介3 = 4
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: false, referralBonus: 3), 4)
        // 無料1 + 紹介10 → 上限5
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: false, referralBonus: 10), 5)
        // プレミアム4 + 紹介1 = 5
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: true, referralBonus: 1), 5)
        // プレミアム4 + 紹介5 → 上限5
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: true, referralBonus: 5), 5)
    }
    func test_allowance_negativeBonus_floored() {
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: false, referralBonus: -3), 1)
    }
    func test_allowance_oldAPI_delegates() {
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: false), 1)
        XCTAssertEqual(RescueTicketAllowance.current(isPremium: true), 4)
    }
}
```

- [ ] **Step 2: 実装**

`RescueTicketStore.swift` の `enum RescueTicketAllowance { ... }` を次に置換:
```swift
@MainActor
enum RescueTicketAllowance {
    /// 月次フリーズ上限(全員共通)。base(無料1/プレミアム4)に今月の紹介ボーナスを
    /// 加えても、ここを超えない。
    nonisolated static let monthlyCap = 5

    /// 後方互換: 紹介ボーナス無しの従来 API。
    static func current(isPremium: Bool) -> Int {
        current(isPremium: isPremium, referralBonus: 0)
    }

    /// base + 今月の紹介ボーナスを `monthlyCap` でクリップした月次付与枚数。
    /// base = 無料1 / プレミアム4(現行不変)。ボーナスは負値を 0 に丸める。
    /// nonisolated: 純粋な算術なのでネイティブ実行/任意スレッドから呼べる。
    nonisolated static func current(isPremium: Bool, referralBonus: Int) -> Int {
        let base = isPremium ? 4 : 1
        return min(monthlyCap, base + max(0, referralBonus))
    }
}
```

- [ ] **Step 3: ネイティブ実行で検証(本物の緑)**

`/tmp/referral_native_check.swift` を作成し、上の `current(isPremium:referralBonus:)` の本体だけ抜き出して assert する(@MainActor 回避のため算術を直書きでミラーし、実装と一致することを確認):
```swift
// /tmp/referral_native_check.swift  (コミットしない)
func current(isPremium: Bool, referralBonus: Int) -> Int {
    let base = isPremium ? 4 : 1
    return min(5, base + max(0, referralBonus))
}
assert(current(isPremium: false, referralBonus: 0) == 1)
assert(current(isPremium: true,  referralBonus: 0) == 4)
assert(current(isPremium: false, referralBonus: 3) == 4)
assert(current(isPremium: false, referralBonus: 10) == 5)
assert(current(isPremium: true,  referralBonus: 1) == 5)
assert(current(isPremium: false, referralBonus: -3) == 1)
print("RescueTicketAllowance OK")
```
Run:
```bash
swiftc -Onone /tmp/referral_native_check.swift -o /tmp/referral_native_check && /tmp/referral_native_check
```
Expected: `RescueTicketAllowance OK`(exit 0)。

- [ ] **Step 4: XCTest コンパイルを緑に**

Run: `TESTBUILD`(上記コマンド)
Expected: `TEST BUILD SUCCEEDED`(`error:` 無し)。

- [ ] **Step 5: commit**
```bash
git add app/GOExercise/GOExercise/Services/RescueTicketStore.swift app/GOExercise/GOExerciseTests/ReferralLogicTests.swift
git commit -m "feat(referral): フリーズallowanceに紹介ボーナス(上限5)を単一ソース化"
```

---

## Task 3: 紹介ドメイン型 + Clock + 入力許可ポリシー(純ロジック・TDD)

**Files:**
- Create: `app/GOExercise/GOExercise/Models/Referral.swift`
- Test: `app/GOExercise/GOExerciseTests/ReferralLogicTests.swift`(Task 2 で作成済 — テストを追記)

- [ ] **Step 1: 失敗するテストを追記**

`ReferralLogicTests` クラス内に追記:
```swift
    // MARK: - ReferralClock
    func test_clock_parsesPostgresTimestamps() {
        XCTAssertNotNil(ReferralClock.parseTimestamp("2026-06-05T12:00:00+00:00"))
        XCTAssertNotNil(ReferralClock.parseTimestamp("2026-06-05T12:00:00.123456+00:00"))
        XCTAssertNil(ReferralClock.parseTimestamp("not-a-date"))
    }
    func test_clock_isInMonth() {
        let cal = Calendar(identifier: .gregorian)
        let now = DateComponents(calendar: cal, year: 2026, month: 6, day: 20).date!
        XCTAssertTrue(ReferralClock.isInMonth("2026-06-01T00:00:00+00:00", of: now, calendar: cal))
        XCTAssertFalse(ReferralClock.isInMonth("2026-05-31T23:00:00+00:00", of: now, calendar: cal))
        XCTAssertFalse(ReferralClock.isInMonth(nil, of: now, calendar: cal))
    }

    // MARK: - ReferralEntryPolicy (設定からの「後から入力」)
    func test_entryPolicy_allowsWithinGrace_whenNoReferrer() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let day3 = start.addingTimeInterval(3 * 86400)
        XCTAssertTrue(ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: start, now: day3, hasExistingReferral: false))
    }
    func test_entryPolicy_blocksAfterGrace() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let day8 = start.addingTimeInterval(8 * 86400)
        XCTAssertFalse(ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: start, now: day8, hasExistingReferral: false))
    }
    func test_entryPolicy_blocksWhenAlreadyReferred() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let day1 = start.addingTimeInterval(86400)
        XCTAssertFalse(ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: start, now: day1, hasExistingReferral: true))
    }
    func test_entryPolicy_blocksWhenNoFirstLaunch() {
        XCTAssertFalse(ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: nil, now: Date(), hasExistingReferral: false))
    }
```

- [ ] **Step 2: 実装**

`app/GOExercise/GOExercise/Models/Referral.swift` を新規作成:
```swift
import Foundation

/// 自分の紹介状況の集計。
/// - starBadges: 累計 confirmed 紹介数(referrer 側・無制限の永続バニティ)。
/// - freezeBonusThisMonth: 今月 confirmed になった「自分向け」フリーズ加算
///   (= 今月 confirmed の referrer 件数 + 自分が referee で今月 confirmed なら +1)。
///   `RescueTicketAllowance.current(isPremium:referralBonus:)` に渡す。
struct ReferralSummary: Equatable, Sendable {
    var starBadges: Int
    var freezeBonusThisMonth: Int
    static let empty = ReferralSummary(starBadges: 0, freezeBonusThisMonth: 0)
}

/// 確定(confirmed)イベント1件。ポップ表示に使う。
struct ReferralConfirmation: Identifiable, Equatable, Sendable {
    enum Role: Sendable { case referrer, referee }
    let id: String              // referee_user_id (referrals の主キー = ユニーク)
    var friendDisplayName: String
    var role: Role
}

/// timestamptz 文字列の解析と「今月か」判定。supabase-swift のデコーダ戦略に依存せず
/// 文字列で受けて自前パースする(決定的・テスト可能)。
enum ReferralClock {
    static func parseTimestamp(_ iso: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)
    }
    static func monthKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)"
    }
    /// `iso`(timestamptz 文字列)が `now` と同じ暦月か。nil/解析不能は false。
    static func isInMonth(_ iso: String?, of now: Date, calendar: Calendar = .mondayFirst) -> Bool {
        guard let iso, let d = parseTimestamp(iso) else { return false }
        return monthKey(d, calendar: calendar) == monthKey(now, calendar: calendar)
    }
}

/// オンボ以外(設定)から招待コードを入力できるかの判定。新規性を担保するため
/// 初回起動から `graceDays` 以内 かつ まだ紹介者がいない場合のみ許可する。
enum ReferralEntryPolicy {
    static let graceDays = 7
    static func canEnterCodeLater(firstLaunchAt: Date?,
                                  now: Date,
                                  hasExistingReferral: Bool,
                                  graceDays: Int = graceDays) -> Bool {
        guard !hasExistingReferral, let start = firstLaunchAt else { return false }
        let days = Int(now.timeIntervalSince(start) / 86400)
        return days >= 0 && days <= graceDays
    }
}
```

- [ ] **Step 3: ネイティブ実行で検証**

`/tmp/referral_native_check.swift` を上書きして `Referral.swift` と一緒にビルド・実行(これらは依存ゼロ=そのままネイティブで動く):
```swift
// /tmp/referral_native_check.swift
import Foundation
// ReferralClock
assert(ReferralClock.parseTimestamp("2026-06-05T12:00:00+00:00") != nil)
assert(ReferralClock.parseTimestamp("2026-06-05T12:00:00.123456+00:00") != nil)
assert(ReferralClock.parseTimestamp("nope") == nil)
let cal = Calendar(identifier: .gregorian)
let now = DateComponents(calendar: cal, year: 2026, month: 6, day: 20).date!
assert(ReferralClock.isInMonth("2026-06-01T00:00:00+00:00", of: now, calendar: cal))
assert(!ReferralClock.isInMonth("2026-05-31T23:00:00+00:00", of: now, calendar: cal))
// ReferralEntryPolicy
let start = Date(timeIntervalSince1970: 1_000_000)
assert(ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: start, now: start.addingTimeInterval(3*86400), hasExistingReferral: false))
assert(!ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: start, now: start.addingTimeInterval(8*86400), hasExistingReferral: false))
assert(!ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: start, now: start.addingTimeInterval(86400), hasExistingReferral: true))
assert(!ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: nil, now: now, hasExistingReferral: false))
print("Referral domain OK")
```
Run:
```bash
swiftc -Onone app/GOExercise/GOExercise/Models/Referral.swift /tmp/referral_native_check.swift -o /tmp/referral_native_check && /tmp/referral_native_check
```
Expected: `Referral domain OK`。

> 注: `Calendar.mondayFirst` はアプリ拡張なのでネイティブ単体ビルドには含めない。テストでは `Calendar(identifier:.gregorian)` を渡し、`isInMonth` の既定引数(`.mondayFirst`)はアプリ内でのみ使う。

- [ ] **Step 4: XCTest コンパイル**

Run: `TESTBUILD`
Expected: `TEST BUILD SUCCEEDED`。

- [ ] **Step 5: commit**
```bash
git add app/GOExercise/GOExercise/Models/Referral.swift app/GOExercise/GOExerciseTests/ReferralLogicTests.swift
git commit -m "feat(referral): ドメイン型ReferralSummary/Confirmation+Clock+EntryPolicy(純ロジック)"
```

---

## Task 4: FriendsService protocol 拡張 + 既定実装 + Mock 実装

**Files:**
- Modify: `app/GOExercise/GOExercise/Services/FriendsService.swift`(protocol + extension)
- Modify: `app/GOExercise/GOExercise/Services/MockFriendsService.swift`
- Test: `app/GOExercise/GOExerciseTests/ReferralStoreTests.swift`(新規・但し本タスクでは Mock を直接叩く最小テストのみ)

- [ ] **Step 1: protocol にメソッドを追加**

`FriendsService.swift` の protocol 内、`func sendCheer(...)` の後・`func seedDemoFriendsIfNeeded()` の前に追加:
```swift
    // MARK: - 友達紹介 (リファラル)

    /// 招待コード(=紹介者の friend_code)を入力して自分を referee とする紹介行(pending)を
    /// 作成し、双方を自動で友達にする。自己/二重紹介/コード不明は throw。
    func submitInviteCode(_ code: String) async throws

    /// 自分(referee)の pending 紹介を、初運動記録到達時に confirmed へ更新する。
    /// 確定したら新規ポップ用の `ReferralConfirmation`(role=.referee)を返す。対象無し/既確定は nil。
    func confirmReferralIfEligible(hasFirstRecord: Bool) async throws -> ReferralConfirmation?

    /// 自分(referrer)が紹介し confirmed かつ未表示(seen_by_referrer=false)の確定を取得し、
    /// 取得分を seen=true にして返す(起動時ポーリング用、role=.referrer)。
    func unseenReferrerConfirmations() async throws -> [ReferralConfirmation]

    /// 星バッジ数(累計 confirmed 紹介)と今月のフリーズ加算を集計して返す。
    func referralSummary() async throws -> ReferralSummary

    /// 自分が referee の紹介行が既に存在するか(後から入力の可否判定に使う)。
    func hasReferrer() async throws -> Bool
```

- [ ] **Step 2: 既定実装(安全側 no-op)を追加**

`extension FriendsService { ... }` の中、`func deleteAccount()` 既定実装の後に追加:
```swift
    // 紹介を扱わないスタブ用の安全側既定。実バックエンド/Mock は override する。
    func submitInviteCode(_ code: String) async throws { throw FriendsServiceError.backendUnavailable }
    func confirmReferralIfEligible(hasFirstRecord: Bool) async throws -> ReferralConfirmation? { nil }
    func unseenReferrerConfirmations() async throws -> [ReferralConfirmation] { [] }
    func referralSummary() async throws -> ReferralSummary { .empty }
    func hasReferrer() async throws -> Bool { false }
```

- [ ] **Step 3: MockFriendsService に in-memory 実装を追加**

`MockFriendsService.swift` のプロパティ群(`sentCheers` の下)に状態を追加:
```swift
    /// referee 視点: 自分が入力した紹介(あれば1件)。(referrerCode, confirmed)。
    private var myReferral: (referrerCode: String, confirmed: Bool, confirmedAt: Date?)?
    /// referrer 視点: 自分が紹介した confirmed 件(seen フラグ付き)。表示名/日時を保持。
    private var inboundConfirmations: [(refereeName: String, at: Date, seen: Bool)] = []
```
そして `sendCheer(...)` の後に紹介メソッドを実装:
```swift
    // MARK: - 友達紹介 (Mock)

    func submitInviteCode(_ code: String) async throws {
        guard let me = myProfile else { throw FriendsServiceError.notSignedIn }
        let upper = code.uppercased()
        if upper == me.friendCode { throw FriendsServiceError.cannotAddSelf }
        if myReferral != nil { throw FriendsServiceError.duplicateRequest }
        guard let referrer = demoPool.first(where: { $0.friendCode == upper })
                ?? friends[upper] else { throw FriendsServiceError.codeNotFound }
        myReferral = (referrer.friendCode, false, nil)
        // 自動友達化(既に友達でなければ)。
        if friends[referrer.friendCode] == nil {
            var f = referrer; f.connectedSince = now()
            friends[referrer.friendCode] = f
            demoPool.removeAll { $0.friendCode == referrer.friendCode }
        }
    }

    func confirmReferralIfEligible(hasFirstRecord: Bool) async throws -> ReferralConfirmation? {
        guard hasFirstRecord, var r = myReferral, !r.confirmed else { return nil }
        r.confirmed = true; r.confirmedAt = now(); myReferral = r
        let name = friends[r.referrerCode]?.displayName ?? "ともだち"
        return ReferralConfirmation(id: myProfile?.friendCode ?? "me",
                                    friendDisplayName: name, role: .referee)
    }

    func unseenReferrerConfirmations() async throws -> [ReferralConfirmation] {
        let unseen = inboundConfirmations.enumerated().filter { !$0.element.seen }
        for (idx, _) in unseen { inboundConfirmations[idx].seen = true }
        return unseen.map {
            ReferralConfirmation(id: "ref-\($0.offset)", friendDisplayName: $0.element.refereeName, role: .referrer)
        }
    }

    func referralSummary() async throws -> ReferralSummary {
        let cal = Calendar.mondayFirst
        let monthKey: (Date) -> String = {
            let c = cal.dateComponents([.year, .month], from: $0); return "\(c.year ?? 0)-\(c.month ?? 0)"
        }
        let nowKey = monthKey(now())
        let stars = inboundConfirmations.count
        var bonus = inboundConfirmations.filter { monthKey($0.at) == nowKey }.count
        if let r = myReferral, r.confirmed, let at = r.confirmedAt, monthKey(at) == nowKey { bonus += 1 }
        return ReferralSummary(starBadges: stars, freezeBonusThisMonth: bonus)
    }

    func hasReferrer() async throws -> Bool { myReferral != nil }

    /// テスト用: 紹介者として誰かを紹介し confirmed になった状態を注入する。
    func _seedInboundConfirmation(refereeName: String, at: Date, seen: Bool = false) {
        inboundConfirmations.append((refereeName, at, seen))
    }
```
`signOut()` / `deleteAccount()` の in-memory クリアに以下2行を追加(両メソッドの `sentCheers.removeAll()` の後):
```swift
        myReferral = nil
        inboundConfirmations.removeAll()
```

- [ ] **Step 4: Mock 直叩きの最小テストを作る**

`app/GOExercise/GOExerciseTests/ReferralStoreTests.swift` を新規作成(Task 6 で拡張する。まずは Mock 実装の振る舞いを固定):
```swift
import XCTest
@testable import GOExercise

@MainActor
final class ReferralStoreTests: XCTestCase {

    private func makeMock() -> MockFriendsService {
        let suite = "referral.tests.\(UUID().uuidString)"
        return MockFriendsService(defaults: UserDefaults(suiteName: suite)!)
    }

    func test_submitInviteCode_autoFriends_andSetsHasReferrer() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "新規", username: "newbie")
        // demoPool の先頭 AKIRA1 を招待者にする
        try await svc.submitInviteCode("AKIRA1")
        let has = try await svc.hasReferrer()
        XCTAssertTrue(has)
        let friends = try await svc.refreshFriends()
        XCTAssertTrue(friends.contains { $0.friendCode == "AKIRA1" })
    }

    func test_submitInviteCode_rejectsDuplicate() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "新規", username: "newbie")
        try await svc.submitInviteCode("AKIRA1")
        do { try await svc.submitInviteCode("YUKINA"); XCTFail("should throw") }
        catch { XCTAssertTrue(error is FriendsServiceError) }
    }

    func test_confirm_returnsRefereePop_thenNilSecondTime() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "新規", username: "newbie")
        try await svc.submitInviteCode("AKIRA1")
        let pop = try await svc.confirmReferralIfEligible(hasFirstRecord: true)
        XCTAssertEqual(pop?.role, .referee)
        let again = try await svc.confirmReferralIfEligible(hasFirstRecord: true)
        XCTAssertNil(again)
    }

    func test_confirm_noFirstRecord_returnsNil() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "新規", username: "newbie")
        try await svc.submitInviteCode("AKIRA1")
        let pop = try await svc.confirmReferralIfEligible(hasFirstRecord: false)
        XCTAssertNil(pop)
    }

    func test_unseenReferrerConfirmations_markSeen() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "紹介者", username: "host")
        svc._seedInboundConfirmation(refereeName: "ともだちA", at: Date())
        let first = try await svc.unseenReferrerConfirmations()
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first.first?.role, .referrer)
        let second = try await svc.unseenReferrerConfirmations()
        XCTAssertTrue(second.isEmpty)   // 二度目は seen 済み
    }

    func test_referralSummary_starsAndMonthlyBonus() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "紹介者", username: "host")
        svc._seedInboundConfirmation(refereeName: "A", at: Date())
        svc._seedInboundConfirmation(refereeName: "B", at: Date())
        let s = try await svc.referralSummary()
        XCTAssertEqual(s.starBadges, 2)
        XCTAssertEqual(s.freezeBonusThisMonth, 2)
    }
}
```

- [ ] **Step 5: XCTest コンパイル**

Run: `TESTBUILD`
Expected: `TEST BUILD SUCCEEDED`(`error:` 無し)。
> 実行はできないため、ロジックの正しさは Mock 実装のコードレビューで担保する。次タスクの `ReferralStore` も同様。

- [ ] **Step 6: commit**
```bash
git add app/GOExercise/GOExercise/Services/FriendsService.swift app/GOExercise/GOExercise/Services/MockFriendsService.swift app/GOExercise/GOExerciseTests/ReferralStoreTests.swift
git commit -m "feat(referral): FriendsService紹介メソッド5本+既定実装+Mock実装+テスト"
```

---

## Task 5: SupabaseFriendsService の紹介メソッド実装

**Files:**
- Modify: `app/GOExercise/GOExercise/Services/SupabaseFriendsService.swift`

- [ ] **Step 1: Row/Write 構造体を追加**

ファイル末尾の `private struct CheerWrite: Encodable { ... }` の後に追加:
```swift
private struct ReferralRow: Decodable {
    let referrer_user_id: String
    let referee_user_id: String
    var status: String = "pending"
    var confirmed_at: String?
    var seen_by_referrer: Bool = false
}
private struct ReferralInsert: Encodable {
    let referrer_user_id: String
    let referee_user_id: String
}
private struct ReferralConfirmUpdate: Encodable {
    let status: String
    let confirmed_at: String
}
private struct ReferralSeenUpdate: Encodable {
    let seen_by_referrer: Bool
}
```

- [ ] **Step 2: 紹介メソッドを実装**

`SupabaseFriendsService` クラス内、`sendCheer(...)` の実装の後・`// MARK: - Helpers` の前に追加:
```swift
    // MARK: - 友達紹介 (リファラル)

    func submitInviteCode(_ code: String) async throws {
        let client = try requireClient()
        let uid = try await ensureUID()
        let target = code.uppercased()
        guard let me = myProfile, me.friendCode != target else { throw FriendsServiceError.cannotAddSelf }
        // 紹介者(referrer)を friend_code から解決。
        let rows: [ProfileRow] = try await client.from("profiles")
            .select().eq("friend_code", value: target).limit(1).execute().value
        guard let referrer = rows.first else { throw FriendsServiceError.codeNotFound }
        if referrer.user_id.lowercased() == uid.uuidString.lowercased() { throw FriendsServiceError.cannotAddSelf }
        // 1人1紹介者: 既に referee 行があれば不可。
        let existing: [ReferralRow] = try await client.from("referrals")
            .select().eq("referee_user_id", value: uid.uuidString).limit(1).execute().value
        if !existing.isEmpty { throw FriendsServiceError.duplicateRequest }
        // pending 紹介を作成(referee = 自分。RLS で referee 本人のみ insert 可)。
        try await client.from("referrals")
            .insert(ReferralInsert(referrer_user_id: referrer.user_id, referee_user_id: uid.uuidString))
            .execute()
        // 自動友達化(承認フローをスキップ。upsert は冪等)。
        try await upsertFriendship(client: client, a: uid.uuidString, b: referrer.user_id)
    }

    func confirmReferralIfEligible(hasFirstRecord: Bool) async throws -> ReferralConfirmation? {
        guard hasFirstRecord else { return nil }
        let client = try requireClient()
        let uid = try await ensureUID()
        let rows: [ReferralRow] = try await client.from("referrals")
            .select().eq("referee_user_id", value: uid.uuidString).limit(1).execute().value
        guard let row = rows.first, row.status == "pending" else { return nil }
        let nowISO = ISO8601DateFormatter().string(from: Date())
        try await client.from("referrals")
            .update(ReferralConfirmUpdate(status: "confirmed", confirmed_at: nowISO))
            .eq("referee_user_id", value: uid.uuidString).execute()
        let referrer: [ProfileRow] = try await client.from("profiles")
            .select().eq("user_id", value: row.referrer_user_id).limit(1).execute().value
        return ReferralConfirmation(id: uid.uuidString,
                                    friendDisplayName: referrer.first?.display_name ?? "ともだち",
                                    role: .referee)
    }

    func unseenReferrerConfirmations() async throws -> [ReferralConfirmation] {
        guard myProfile != nil, let session = try? await requireClient().auth.session else { return [] }
        let client = try requireClient()
        let uid = session.user.id.uuidString
        let rows: [ReferralRow] = try await client.from("referrals")
            .select().eq("referrer_user_id", value: uid)
            .eq("status", value: "confirmed").eq("seen_by_referrer", value: false)
            .execute().value
        guard !rows.isEmpty else { return [] }
        let refereeIDs = rows.map { $0.referee_user_id }
        let profs: [ProfileRow] = try await client.from("profiles")
            .select().in("user_id", values: refereeIDs).execute().value
        let byID = Dictionary(uniqueKeysWithValues: profs.map { ($0.user_id, $0) })
        // 取得分を seen=true にする(再ポップ防止)。
        try await client.from("referrals")
            .update(ReferralSeenUpdate(seen_by_referrer: true))
            .eq("referrer_user_id", value: uid)
            .eq("status", value: "confirmed").eq("seen_by_referrer", value: false)
            .execute()
        return rows.map { r in
            ReferralConfirmation(id: r.referee_user_id,
                                 friendDisplayName: byID[r.referee_user_id]?.display_name ?? "ともだち",
                                 role: .referrer)
        }
    }

    func referralSummary() async throws -> ReferralSummary {
        // 未サインインなら匿名アカウントを作らずに空を返す(孤児防止)。
        guard myProfile != nil, let session = try? await requireClient().auth.session else { return .empty }
        let client = try requireClient()
        let uid = session.user.id.uuidString
        let now = Date()
        let asReferrer: [ReferralRow] = try await client.from("referrals")
            .select().eq("referrer_user_id", value: uid).eq("status", value: "confirmed").execute().value
        let stars = asReferrer.count
        var bonus = asReferrer.filter { ReferralClock.isInMonth($0.confirmed_at, of: now) }.count
        let asReferee: [ReferralRow] = try await client.from("referrals")
            .select().eq("referee_user_id", value: uid).eq("status", value: "confirmed").limit(1).execute().value
        if let r = asReferee.first, ReferralClock.isInMonth(r.confirmed_at, of: now) { bonus += 1 }
        return ReferralSummary(starBadges: stars, freezeBonusThisMonth: bonus)
    }

    func hasReferrer() async throws -> Bool {
        guard myProfile != nil, let session = try? await requireClient().auth.session else { return false }
        let client = try requireClient()
        let rows: [ReferralRow] = try await client.from("referrals")
            .select().eq("referee_user_id", value: session.user.id.uuidString).limit(1).execute().value
        return !rows.isEmpty
    }
```

- [ ] **Step 3: アカウント削除/サインアウトに referrals を含める**

`signOut()` の匿名データ削除ブロック(`try? await client.from("friend_requests").delete()...` の直後)に追加:
```swift
            try? await client.from("referrals").delete()
                .or("referrer_user_id.eq.\(uid),referee_user_id.eq.\(uid)").execute()
```
`deleteAccount()` のフォールバック削除ブロック(`try await client.from("profiles").delete().eq("user_id", value: uid).execute()` の**前**)に追加:
```swift
        try await client.from("referrals").delete()
            .or("referrer_user_id.eq.\(uid),referee_user_id.eq.\(uid)").execute()
```

- [ ] **Step 4: ビルド検証**

Run: `BUILD`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 5: commit**
```bash
git add app/GOExercise/GOExercise/Services/SupabaseFriendsService.swift
git commit -m "feat(referral): SupabaseFriendsServiceに紹介の作成/確定/ポーリング/集計+削除連携"
```

---

## Task 6: ReferralStore + allowance への配線

**Files:**
- Create: `app/GOExercise/GOExercise/Services/ReferralStore.swift`
- Modify: `app/GOExercise/GOExercise/ViewModels/HomeViewModel.swift`
- Test: `app/GOExercise/GOExerciseTests/ReferralStoreTests.swift`(追記)

- [ ] **Step 1: ReferralStore を作成**

`app/GOExercise/GOExercise/Services/ReferralStore.swift`:
```swift
import Foundation
import Observation

/// 友達紹介の状態を保持しアプリ全体へ供給する @Observable ストア。
/// - summary: 星バッジ数 + 今月のフリーズ加算(HomeViewModel が allowance に反映)。
/// - hasReferrer: 自分が referee の紹介行が既にあるか(後から入力の可否)。
/// - pendingWelcome: 新規(される側)の即ポップ1件。
/// - pendingReferrerPops: 紹介者(する側)の起動時ポップ(複数可)。
@MainActor
@Observable
final class ReferralStore {
    private let service: any FriendsService
    private let defaults: UserDefaults
    /// 未サインインのとき紹介ポーリングで匿名アカウントを作らせないためのガード。
    private let isSignedIn: () -> Bool
    static let firstLaunchKey = "referral.firstLaunchAt.v1"

    var summary: ReferralSummary = .empty
    var hasReferrer = false
    var pendingWelcome: ReferralConfirmation?
    var pendingReferrerPops: [ReferralConfirmation] = []
    var lastError: String?
    private(set) var firstLaunchAt: Date

    init(service: any FriendsService,
         defaults: UserDefaults = .standard,
         isSignedIn: @escaping () -> Bool,
         now: Date = Date()) {
        self.service = service
        self.defaults = defaults
        self.isSignedIn = isSignedIn
        if let t = defaults.object(forKey: Self.firstLaunchKey) as? Double {
            firstLaunchAt = Date(timeIntervalSince1970: t)
        } else {
            firstLaunchAt = now
            defaults.set(now.timeIntervalSince1970, forKey: Self.firstLaunchKey)
        }
    }

    /// 設定からの「後から招待コードを入力」を出してよいか。
    var canEnterCodeLater: Bool {
        ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: firstLaunchAt,
                                              now: Date(),
                                              hasExistingReferral: hasReferrer)
    }

    /// 起動時/サインイン後に状態を取り込む。未サインインなら何もしない(孤児防止)。
    func refresh() async {
        guard isSignedIn() else { return }
        do {
            summary = try await service.referralSummary()
            hasReferrer = try await service.hasReferrer()
        } catch { lastError = error.localizedDescription }
    }

    /// 招待コードを送信(オンボ/設定)。成功で hasReferrer を立て再集計する。
    /// - Returns: 成功したか。
    @discardableResult
    func submitCode(_ raw: String) async -> Bool {
        let code = FriendCodeValidator.sanitize(raw)
        guard FriendCodeValidator.isValid(code) else {
            lastError = "招待コードは6文字です。もう一度確認してください"
            return false
        }
        do {
            try await service.submitInviteCode(code)
            hasReferrer = true
            await refresh()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// 初運動記録到達時に呼ぶ。確定したら新規ポップをセットする。
    func confirmFirstRecordIfNeeded(hasFirstRecord: Bool) async {
        guard isSignedIn(), hasFirstRecord, hasReferrer else { return }
        do {
            if let conf = try await service.confirmReferralIfEligible(hasFirstRecord: true) {
                pendingWelcome = conf
                await refresh()
            }
        } catch { lastError = error.localizedDescription }
    }

    /// 起動時に紹介者ポップを取り込む(取得分は seen 済みになる)。
    func pollReferrerPops() async {
        guard isSignedIn() else { return }
        do {
            let pops = try await service.unseenReferrerConfirmations()
            if !pops.isEmpty {
                pendingReferrerPops = pops
                await refresh()
            }
        } catch { lastError = error.localizedDescription }
    }

    func consumeWelcome() { pendingWelcome = nil }
    func consumeReferrerPops() { pendingReferrerPops = [] }
}
```

- [ ] **Step 2: HomeViewModel に紹介ボーナスを通す**

`HomeViewModel.swift:40` 付近の `private var isPremium = false` の下に追加:
```swift
    /// 今月の紹介フリーズ加算。refresh() で View から渡される。
    private var referralFreezeBonus = 0
```
`HomeViewModel.swift:42` の `rescueAllowance` を変更:
```swift
    private var rescueAllowance: Int {
        RescueTicketAllowance.current(isPremium: isPremium, referralBonus: referralFreezeBonus)
    }
```
`refresh(...)` シグネチャ(`HomeViewModel.swift:54-58`)に引数を追加し本体先頭で取り込む。`isPremium: Bool = false,` の次行に `referralFreezeBonus: Int = 0,` を足し、`self.isPremium = isPremium` の直後に:
```swift
        self.referralFreezeBonus = referralFreezeBonus
```

- [ ] **Step 3: HomeView の refresh 呼び出しでボーナスを渡す**

`HomeView.swift` 内の `viewModel.refresh(` 呼び出し箇所(複数あれば全て)に `referralFreezeBonus:` を追加する。HomeView に referralStore 環境を足してから渡す。まず HomeView の `@Environment` 宣言群(`@Environment(StoreKitManager.self)` 等の近く)に追加:
```swift
    @Environment(ReferralStore.self) private var referralStore
```
そして各 `viewModel.refresh(records: ..., isPremium: storeKit.isPremiumActive ...)` に引数を追加:
```swift
                                    referralFreezeBonus: referralStore.summary.freezeBonusThisMonth,
```
(既存の `isPremium:` 引数の直後に置く。引数名つきなので位置は問わない。)

- [ ] **Step 4: ReferralStore のテストを追記**

`ReferralStoreTests.swift` に追記:
```swift
    func test_store_submit_setsHasReferrer_andRefreshes() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "新規", username: "newbie")
        let store = ReferralStore(service: svc,
                                  defaults: UserDefaults(suiteName: "rs.\(UUID().uuidString)")!,
                                  isSignedIn: { true })
        let ok = await store.submitCode("akira1")   // 小文字でも sanitize で大文字化
        XCTAssertTrue(ok)
        XCTAssertTrue(store.hasReferrer)
    }

    func test_store_submit_invalidCode_setsError() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "新規", username: "newbie")
        let store = ReferralStore(service: svc,
                                  defaults: UserDefaults(suiteName: "rs.\(UUID().uuidString)")!,
                                  isSignedIn: { true })
        let ok = await store.submitCode("xx")        // 6文字未満
        XCTAssertFalse(ok)
        XCTAssertNotNil(store.lastError)
    }

    func test_store_confirmFirstRecord_setsWelcomePop() async throws {
        let svc = makeMock()
        try await svc.signIn(displayName: "新規", username: "newbie")
        let store = ReferralStore(service: svc,
                                  defaults: UserDefaults(suiteName: "rs.\(UUID().uuidString)")!,
                                  isSignedIn: { true })
        _ = await store.submitCode("AKIRA1")
        await store.confirmFirstRecordIfNeeded(hasFirstRecord: true)
        XCTAssertEqual(store.pendingWelcome?.role, .referee)
    }

    func test_store_notSignedIn_refreshIsNoop() async {
        let svc = makeMock()
        let store = ReferralStore(service: svc,
                                  defaults: UserDefaults(suiteName: "rs.\(UUID().uuidString)")!,
                                  isSignedIn: { false })
        await store.refresh()
        XCTAssertEqual(store.summary, .empty)
    }
```

- [ ] **Step 5: ビルド + XCTest コンパイル**

Run: `BUILD` then `TESTBUILD`
Expected: 両方成功(`BUILD SUCCEEDED` / `TEST BUILD SUCCEEDED`)。

- [ ] **Step 6: commit**
```bash
git add app/GOExercise/GOExercise/Services/ReferralStore.swift app/GOExercise/GOExercise/ViewModels/HomeViewModel.swift app/GOExercise/GOExercise/Views/HomeView.swift app/GOExercise/GOExerciseTests/ReferralStoreTests.swift
git commit -m "feat(referral): ReferralStore+allowance配線(HomeViewModel/HomeView)"
```

---

## Task 7: キルスイッチ・アプリ配線・起動時ポーリング

**Files:**
- Modify: `app/GOExercise/GOExercise/Services/AppFeatureFlags.swift`
- Modify: `app/GOExercise/GOExercise/App/GOExerciseApp.swift`

- [ ] **Step 1: referralEnabled フラグを追加**

`AppFeatureFlags.swift` の `static let friendsEnabled = true` の下に追加:
```swift
    /// 友達紹介(リファラル)を有効にするか。友達 BE 前提なので friendsEnabled と AND で使う。
    /// 単独で false にすれば紹介 UI/ポーリングだけを止められる(キルスイッチ)。
    static let referralEnabled = true

    /// 紹介機能を出してよいか(友達が有効 かつ 紹介が有効)。
    static var isReferralActive: Bool { friendsEnabled && referralEnabled }
```

- [ ] **Step 2: ReferralStore を生成し environment へ**

`GOExerciseApp.swift` の `@State private var friendsStore = ...`(:10)の直後で、同一サービスを共有するため friendsStore の service を再利用する形に変更する。`makeFriendsService()` は呼ぶたび別インスタンスを返すので、サービスを一度だけ作って両ストアへ渡す。:10-17 のストア宣言群を次に置換:
```swift
    @State private var themeStore = ThemeStore.shared
    private static let sharedFriendsService: any FriendsService = GOExerciseApp.makeFriendsService()
    @State private var friendsStore = FriendsStore(service: GOExerciseApp.sharedFriendsService)
    @State private var referralStore = ReferralStore(
        service: GOExerciseApp.sharedFriendsService,
        isSignedIn: { GOExerciseApp.sharedFriendsService.myProfile != nil }
    )
    @State private var routeState = RouteState()
    @State private var router = DeepLinkRouter.shared
    @State private var userCatPrefs = UserCatPreferences.shared
    @State private var storeKit = StoreKitManager()
    @State private var rescueTicketStore = RescueTicketStore.shared
```
> `isSignedIn` は `myProfile != nil` を直接参照(FriendsStore への循環参照を避ける)。Mock/Supabase とも `myProfile` がサインイン状態を表す。

- [ ] **Step 3: environment 注入**

`body` の environment チェーン(`GOExerciseApp.swift:45-49`)に追加(`.environment(rescueTicketStore)` の下):
```swift
                .environment(referralStore)
```

- [ ] **Step 4: 起動時に紹介者ポップをポーリング**

`.task { ... }`(:66)の中、`await storeKit.loadProducts()` の後に追加:
```swift
                    // 友達紹介: サインイン済みなら起動時に「紹介者ポップ」を取り込む。
                    // 未サインインは ReferralStore 側で no-op(匿名アカウントを作らない)。
                    if AppFeatureFlags.isReferralActive {
                        await referralStore.refresh()
                        await referralStore.pollReferrerPops()
                    }
```

- [ ] **Step 5: ビルド検証**

Run: `BUILD`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 6: commit**
```bash
git add app/GOExercise/GOExercise/Services/AppFeatureFlags.swift app/GOExercise/GOExercise/App/GOExerciseApp.swift
git commit -m "feat(referral): referralEnabledキルスイッチ+ReferralStore注入+起動時ポーリング"
```

---

## Task 8: 確定ポップ UI(共通シート)+ 新規ポップ提示 + 初記録フック

**Files:**
- Create: `app/GOExercise/GOExercise/Views/ReferralCelebrationSheet.swift`
- Modify: `app/GOExercise/GOExercise/Views/HomeView.swift`

- [ ] **Step 1: 確定ポップシートを作成**

`app/GOExercise/GOExercise/Views/ReferralCelebrationSheet.swift`:
```swift
import SwiftUI

/// 友達紹介の確定ポップ。新規(される側=ウェルカム)と紹介者(する側=参加通知)を
/// 同一レイアウトで出し分ける。複数の紹介者ポップは1枚にまとめて列挙する。
struct ReferralCelebrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let confirmations: [ReferralConfirmation]

    private var isWelcome: Bool { confirmations.first?.role == .referee }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 8)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Palette.primaryDeep.opacity(0.45),
                                                  Palette.primaryDeep.opacity(0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 132, height: 132)
                Image(systemName: isWelcome ? "sparkles" : "star.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Palette.primaryDeep)
            }
            Text(isWelcome ? "友達とつながりました!" : "紹介した友達が参加しました!")
                .font(Typography.title)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            VStack(spacing: 6) {
                if isWelcome {
                    Text("\(confirmations.first?.friendDisplayName ?? "ともだち") さんの招待で参加")
                        .font(Typography.body).foregroundStyle(Palette.textSecondary)
                    rewardRow(icon: "snowflake", text: "ウェルカム・フリーズ +1(今月)")
                } else {
                    ForEach(confirmations) { c in
                        Text("\(c.friendDisplayName) さんが参加!")
                            .font(Typography.body).foregroundStyle(Palette.textSecondary)
                    }
                    rewardRow(icon: "snowflake", text: "フリーズ +1(今月・上限5)")
                    rewardRow(icon: "star.fill", text: "星バッジ +\(confirmations.count)")
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Button {
                dismiss()
            } label: {
                Text("やったね!")
                    .font(Typography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Palette.primaryDeep, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .accessibilityIdentifier("referral-celebration-dismiss")
        }
        .padding(.top, 24)
        .background(Palette.background)
        .presentationDetents([.medium])
    }

    private func rewardRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Palette.primaryDeep)
            Text(text).font(Typography.body).foregroundStyle(Palette.textPrimary)
        }
    }
}
```
> 注: `Palette` / `Typography` はアプリ既存のデザイントークン(UserCatPickerView 等で使用)。シンボル名(`Palette.primaryDeep` / `Palette.background` / `Palette.textPrimary` / `Palette.textSecondary` / `Typography.title` / `Typography.headline` / `Typography.body`)は既存使用箇所に合わせている。ビルドエラーが出たら近傍の既存 View(`UserCatPickerView.swift`)のトークン名に合わせて修正する。

- [ ] **Step 2: HomeView に初記録フック + 2種ポップ提示を追加**

`HomeView.swift` で(Task 6 Step 3 で `@Environment(ReferralStore.self) private var referralStore` は追加済)。`syncMyFriendProfile()` の末尾(`Task { await friendsStore.publishMyProfile(updated) }` の後)に初記録フックを追加:
```swift
        // 友達紹介: 初運動記録(累計達成 >= 1)に到達したら自分の pending 紹介を確定する。
        if AppFeatureFlags.isReferralActive {
            let hasFirstRecord = viewModel.lifetimeStats.achievedDays >= 1
            Task { await referralStore.confirmFirstRecordIfNeeded(hasFirstRecord: hasFirstRecord) }
        }
```
> `syncMyFriendProfile()` の冒頭 `guard AppFeatureFlags.friendsEnabled else { return }` と `guard let current = friendsStore.profile else { return }` の早期 return より**後ろ**に置くこと(サインイン済み前提)。

HomeView の `body` のルート View に、新規ポップと紹介者ポップの sheet を追加する。`body` 内の最外 `.sheet`/`.fullScreenCover` 群の並びに合わせ、以下2つを追加(既存の modifier チェーン末尾に付ける):
```swift
        .sheet(isPresented: Binding(
            get: { referralStore.pendingWelcome != nil },
            set: { if !$0 { referralStore.consumeWelcome() } }
        )) {
            if let pop = referralStore.pendingWelcome {
                ReferralCelebrationSheet(confirmations: [pop])
            }
        }
        .sheet(isPresented: Binding(
            get: { !referralStore.pendingReferrerPops.isEmpty },
            set: { if !$0 { referralStore.consumeReferrerPops() } }
        )) {
            ReferralCelebrationSheet(confirmations: referralStore.pendingReferrerPops)
        }
```
> HomeView がどの View 階層に sheet を付けるべきか不明な場合は、`body` の `var body: some View { ... }` の最外 View(`ScrollView`/`NavigationStack` 等)の末尾に上記を追加する。2枚の sheet が同時 true になり得る場合 SwiftUI は片方を優先するが、welcome は初記録の即時・referrer は起動時なので実運用で同時発火はまれ。先に welcome を出し、dismiss 後に referrer ポップが残っていれば次回 onAppear で再評価される。

- [ ] **Step 3: ビルド検証**

Run: `BUILD`
Expected: `BUILD SUCCEEDED`。トークン名/`viewModel.lifetimeStats.achievedDays` のシンボルが合わない場合は近傍既存コードに合わせて修正(`HomeView.swift:407` で `viewModel.lifetimeStats.achievedDays` を使用済 = 正)。

- [ ] **Step 4: commit**
```bash
git add app/GOExercise/GOExercise/Views/ReferralCelebrationSheet.swift app/GOExercise/GOExercise/Views/HomeView.swift
git commit -m "feat(referral): 確定ポップ(新規ウェルカム/紹介者参加)+初記録フック"
```

---

## Task 9: 招待コード入力欄(共通)+ オンボ差し込み

**Files:**
- Create: `app/GOExercise/GOExercise/Views/InviteCodeField.swift`
- Modify: `app/GOExercise/GOExercise/Views/UserCatPickerView.swift`

- [ ] **Step 1: 入力欄コンポーネントを作成**

`app/GOExercise/GOExercise/Views/InviteCodeField.swift`:
```swift
import SwiftUI

/// 招待コード入力欄(オンボ・設定で再利用)。入力は自己補正(大文字化・許可文字のみ・6桁)。
/// 送信は親が closure で受ける。成功/失敗の文言は ReferralStore.lastError を親が表示する。
struct InviteCodeField: View {
    @Binding var code: String
    var isSubmitting: Bool
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("招待コードをお持ちですか?(任意)")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            Text("友達のコードを入れると、お互いにフリーズが増えます。")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 8) {
                TextField("ABC123", text: Binding(
                    get: { code },
                    set: { code = FriendCodeValidator.sanitize($0) }
                ))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("invite-code-field")

                Button(action: onSubmit) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("送信").fontWeight(.semibold)
                    }
                }
                .disabled(!FriendCodeValidator.isValid(code) || isSubmitting)
                .accessibilityIdentifier("invite-code-submit")
            }
        }
    }
}
```
> `Palette.surface` / `Typography.caption` が無ければ近傍既存トークンに置換(例 `Palette.background` / `Typography.body`)。ビルドで確認。

- [ ] **Step 2: オンボに入力欄を差し込む**

`UserCatPickerView.swift` に state を追加(`@State private var showPaywall = false` の下):
```swift
    @Environment(ReferralStore.self) private var referralStore
    @State private var inviteCode = ""
    @State private var isSubmittingInvite = false
    @State private var inviteAccepted = false
```
`body` の `LazyVGrid { ... }` ブロックの**後**(`.padding(.horizontal, 16)` の付いた grid の直後、`VStack` 内)に、オンボ時のみ入力欄を表示:
```swift
                    if isOnboarding && AppFeatureFlags.isReferralActive {
                        Group {
                            if inviteAccepted {
                                Label("招待コードを適用しました!", systemImage: "checkmark.seal.fill")
                                    .font(Typography.body)
                                    .foregroundStyle(Palette.primaryDeep)
                            } else {
                                InviteCodeField(code: $inviteCode, isSubmitting: isSubmittingInvite) {
                                    submitInvite()
                                }
                            }
                            if let err = referralStore.lastError, !inviteAccepted {
                                Text(err).font(Typography.caption).foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    }
```
そして `private var catPreview` の前(または `cell(_:)` の後)にヘルパーを追加:
```swift
    private func submitInvite() {
        isSubmittingInvite = true
        referralStore.lastError = nil
        Task {
            // 招待コード入力には匿名サインインが必要(能動操作なので opt-in に合致)。
            await friendsEnsureSignedIn()
            let ok = await referralStore.submitCode(inviteCode)
            isSubmittingInvite = false
            if ok { inviteAccepted = true }
        }
    }
```
招待にはサインインが要るため、`UserCatPickerView` に friendsStore も注入する。state 群に追加:
```swift
    @Environment(FriendsStore.self) private var friendsStore
```
そしてヘルパー:
```swift
    private func friendsEnsureSignedIn() async {
        await friendsStore.ensureSignedIn()
    }
```
> オンボ画面は app root の `.fullScreenCover` で出るため environment は親から継承される(Task 7 で `referralStore` を、既存で `friendsStore` を注入済)。

- [ ] **Step 3: ビルド検証**

Run: `BUILD`
Expected: `BUILD SUCCEEDED`。`Palette.surface`/`Typography.caption` 等のトークン未定義エラーが出たら既存トークンに置換して再ビルド。

- [ ] **Step 4: commit**
```bash
git add app/GOExercise/GOExercise/Views/InviteCodeField.swift app/GOExercise/GOExercise/Views/UserCatPickerView.swift
git commit -m "feat(referral): 招待コード入力欄(共通)+オンボに差し込み"
```

---

## Task 10: 設定の「友達を招待」共有 + 星バッジ + 後から入力

**Files:**
- Modify: `app/GOExercise/GOExercise/Views/SettingsView.swift`

- [ ] **Step 1: 設定の友達セクションに導線を追加**

`SettingsView.swift:110` の `if AppFeatureFlags.friendsEnabled { ... }` ブロック内に、紹介の Section を追加する。まず SettingsView に environment と state を追加(View の `@Environment`/`@State` 宣言群へ):
```swift
    @Environment(ReferralStore.self) private var referralStore
    @State private var showInviteShare = false
    @State private var laterInviteCode = ""
    @State private var isSubmittingLater = false
    @State private var laterAccepted = false
```
`if AppFeatureFlags.friendsEnabled {` ブロックの中(友達関連の行が並ぶ箇所)に追加:
```swift
                if AppFeatureFlags.isReferralActive {
                    Section("友達を招待") {
                        // 共有(招待する)= friend_code + 文面を共有シートへ。
                        if let code = friendsStore.profile?.friendCode {
                            ShareLink(item: inviteMessage(code: code)) {
                                Label("友達を招待する", systemImage: "square.and.arrow.up")
                            }
                            .accessibilityIdentifier("referral-invite-share")
                        }
                        // 星バッジ(累計紹介)。
                        HStack {
                            Label("紹介した友達", systemImage: "star.fill")
                            Spacer()
                            Text("\(referralStore.summary.starBadges) 人")
                                .foregroundStyle(Palette.textSecondary)
                        }
                        // 後から入力(登録7日以内 & 紹介者未登録のときだけ)。
                        if referralStore.canEnterCodeLater {
                            if laterAccepted {
                                Label("招待コードを適用しました!", systemImage: "checkmark.seal.fill")
                                    .foregroundStyle(Palette.primaryDeep)
                            } else {
                                InviteCodeField(code: $laterInviteCode, isSubmitting: isSubmittingLater) {
                                    submitLaterInvite()
                                }
                                if let err = referralStore.lastError {
                                    Text(err).font(Typography.caption).foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }
```

- [ ] **Step 2: ヘルパーを追加**

`SettingsView` の本体(`body` の外、struct 内)にヘルパーを追加:
```swift
    private func inviteMessage(code: String) -> String {
        "GOエクササイズで一緒に運動しよう!オンボーディングでこの招待コードを入れると、お互いにフリーズがもらえます → \(code)\nhttps://apps.apple.com/jp/app/id6774551663"
    }

    private func submitLaterInvite() {
        isSubmittingLater = true
        referralStore.lastError = nil
        Task {
            await friendsStore.ensureSignedIn()
            let ok = await referralStore.submitCode(laterInviteCode)
            isSubmittingLater = false
            if ok {
                laterAccepted = true
                // 既に初記録済みなら即確定を試みる(後から入力でも取りこぼさない)。
                await referralStore.confirmFirstRecordIfNeeded(hasFirstRecord: true)
            }
        }
    }
```
> App Store URL の数値 ID `6774551663` は release_identifiers メモの正本。`friendsStore` は SettingsView で既に環境注入済(`AppFeatureFlags.friendsEnabled` ブロックで友達 UI を使っているため)。未注入ならビルドエラーで判明するので `@Environment(FriendsStore.self) private var friendsStore` を追加する。

- [ ] **Step 3: ビルド検証**

Run: `BUILD`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 4: commit**
```bash
git add app/GOExercise/GOExercise/Views/SettingsView.swift
git commit -m "feat(referral): 設定に招待共有/星バッジ/後から入力(7日以内)を追加"
```

---

## Task 11: 統合ビルド + XCTest コンパイル + フラグ確認

**Files:** なし(検証のみ)

- [ ] **Step 1: フルビルド**

Run: `BUILD`
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 2: XCTest コンパイル(全テストターゲット)**

Run: `TESTBUILD`
Expected: `TEST BUILD SUCCEEDED`(`error:` 無し)。

- [ ] **Step 3: 純ロジックのネイティブ実行(再確認)**

Run(Task 2/3 の手順):
```bash
swiftc -Onone app/GOExercise/GOExercise/Models/Referral.swift /tmp/referral_native_check.swift -o /tmp/referral_native_check && /tmp/referral_native_check
```
Expected: `Referral domain OK`。

- [ ] **Step 4: Info.plist 退行チェック(念のため)**
```bash
git diff --stat app/GOExercise/GOExercise/Resources/Info.plist
```
Expected: 差分なし(本計画は xcodegen を実行しないため Info.plist は不変。差分が出ていたら `FriendsAppleLinkEnabled`/`TelemetryDeckAppID` の有無を確認)。

- [ ] **Step 5: 一時ファイル掃除**
```bash
rm -f /tmp/referral_native_check /tmp/referral_native_check.swift
```

- [ ] **Step 6: スコープ確認(コミット不要)**
- 全紹介 UI が `AppFeatureFlags.isReferralActive` ゲート下にあること(オンボ欄/設定 Section/ポップ/起動時ポーリング)。
- `referralEnabled = false` でビルドが通り紹介 UI が消えること(grep で `isReferralActive` 参照を確認)。

---

## Self-Review

**スペック網羅(spec 各節 → タスク):**
- §2 成立モデル(コード共有→オンボ入力→自動友達化→初記録で confirmed): 共有=Task10、入力=Task9/10、自動友達化=Task4/5(`submitInviteCode` 内 `upsertFriendship`)、初記録確定=Task8(`confirmFirstRecordIfNeeded`)+Task5(`confirmReferralIfEligible`)。✓
- §3 特典(月次上限5・base 不変・紹介ボーナス今月加算・星バッジ=件数算出): Task2(`current(isPremium:referralBonus:)`=`min(5, base+bonus)`)+Task5/6(`referralSummary` で星=count・bonus=今月件数)。✓
- §4 データモデル `referrals`(referee 主キー/RLS): Task1。✓
- §4.1 確定=profile 公開経路に相乗り(`total_achieved_days>=1` で referee 本人が更新): Task8(HomeView の publish 後に `achievedDays>=1` フック)+Task5(RLS referee 更新)。✓
- §5 通知(両者ポップ・push 不使用): 新規=即ポップ(Task8 welcome)/紹介者=起動時ポーリング(Task7 `pollReferrerPops`+Task8 sheet)。✓
- §6 不正対策: 1人1紹介者=PK(Task1)+`duplicateRequest`(Task4/5)、自己紹介不可=check 制約+`cannotAddSelf`、新規限定=オンボ+7日猶予(Task3 `ReferralEntryPolicy`/Task9/10)、初記録必須=Task8、月5頭打ち=Task2。✓
- §7 UI(オンボ任意入力/招待共有/星バッジ/2ポップ): Task8/9/10。✓
- §8 オープン事項: 後から入力=設定で7日以内(Task3/10 で決着)、オンボ差し込み箇所=`UserCatPickerView`(Task9)、allowance 単一ソース化=Task2、自動友達=自動承認扱い(Task5 upsertFriendship)。✓
- §9 ストア規約: アプリ内価値のみ・現金でない・核心機能を強制ゲートしない → 変更なし(コスメ的フリーズ/バッジ)。✓

**型整合チェック:**
- `RescueTicketAllowance.current(isPremium:referralBonus:)` — Task2 定義 → Task6 で `rescueAllowance` が使用。旧 `current(isPremium:)` は委譲で残す(既存呼び出し互換)。✓
- `ReferralSummary{starBadges, freezeBonusThisMonth}` — Task3 定義 → Task5/6 で生成 → Task6(allowance)/Task10(星バッジ)で参照。✓
- `ReferralConfirmation{id, friendDisplayName, role}` / `Role{referrer, referee}` — Task3 定義 → Task4/5 で生成 → Task8(ポップ)で参照。`isWelcome = role == .referee`。✓
- `ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt:now:hasExistingReferral:)` — Task3 定義 → Task6(`ReferralStore.canEnterCodeLater`)→ Task10 で参照。✓
- `ReferralClock.isInMonth(_:of:calendar:)` / `parseTimestamp` — Task3 定義 → Task5(`referralSummary`)で参照。✓
- service メソッド5本(`submitInviteCode`/`confirmReferralIfEligible`/`unseenReferrerConfirmations`/`referralSummary`/`hasReferrer`)— Task4 protocol 定義 → Task4 Mock/Task5 Supabase 実装 → Task6 `ReferralStore` が呼ぶ。シグネチャ一致。✓
- `ReferralStore`(`summary`/`hasReferrer`/`pendingWelcome`/`pendingReferrerPops`/`submitCode`/`confirmFirstRecordIfNeeded`/`pollReferrerPops`/`consumeWelcome`/`consumeReferrerPops`/`canEnterCodeLater`/`lastError`)— Task6 定義 → Task7/8/9/10 で参照。✓
- `AppFeatureFlags.isReferralActive` — Task7 定義 → Task7/8/9/10 で参照。✓

**プレースホルダ走査:** 各 Step に実コード/実コマンド/期待出力を記載。デザイントークン名(`Palette.*`/`Typography.*`)は既存コード由来だが env により未定義の可能性があるため「合わなければ近傍に合わせて修正」と明記(完全な代替不能箇所のみ)。

**既知の留意点(実装者向け):**
- `referralSummary`/`hasReferrer`/`unseen` は未サインイン時 `myProfile==nil` で空を返し `ensureUID` を呼ばない(孤児アカウント防止)。`submitInviteCode`/`confirmReferralIfEligible` は能動操作なので `ensureUID` で匿名サインインしてよい。
- timestamptz の自前パース(`ReferralClock`)に依存。Supabase の confirmed_at は UTC ISO8601。月境界は `.mondayFirst`(JST)で判定するため UTC との数時間ズレが月末跨ぎでまれに発生し得るが、フリーズ加算の1ヶ月誤差は実害小(spec の許容範囲)。
- 2枚のポップが同時 true になり得る稀ケースは SwiftUI が片方を優先。welcome 優先で、残りは次回 onAppear で再評価(Task8 注記)。
```
