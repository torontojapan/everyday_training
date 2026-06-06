# 計画② ストリーク・フリーズ復活(D)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 連続が途切れた後 **4日以内** なら、ホームのポップから**フリーズ(既存 RescueTicketStore)で連続を復活**できる導線を追加する。無料枠で復活でき、枠切れなら既存 `PremiumPaywallSheet(.freeze)` へ誘導。節度(ディスミス可・1起動1回・4日失効・処理済み break は再表示しない)。

**Architecture:** 新規の純ロジック `StreakFreezeWindow.evaluate(...)` が「直近4日以内に missed 日をフリーズで橋渡しすれば連続が復活する」状況を検出し `(revivable, missedDates, freezesNeeded, hasEnough)` を返す。`HomeViewModel` が refresh 時に評価して `reviveWindow` を公開、`applyRevive()` で missedDates に `RescueTicketStore.useTicket` を適用。`HomeView` が `StreakRevivePopup`(sheet)を提示し、復活成功時は計画①の `RankCelebrationOverlay` を流用して復活演出、枠切れは paywall。処理済み break は UserDefaults に記録して再表示を抑止。

**Tech Stack:** Swift / SwiftUI / iOS17 / XCTest。純ロジックは swiftc ネイティブ検証、UI は xcodebuild build + simctl スクショ 3LLM(checklist D15-19)。

**正本spec:** `docs/superpowers/specs/2026-06-06-achievement-luxury-design.md`(D節)。**検証**: `2026-06-06-decoration-verification-checklist.md`(D: 15-19)。
**前提**: 計画①完了(branch `feature/referral-rewards-v12`)。`CatRank`/`RankCelebrationOverlay`/`RankBadge` 利用可。

---

## 調査で確定した事実(着工前に必読)

1. **DailyStatus**(`AchievementEvaluator.swift`): `.achieved/.rest/.missed/.future/.todayPending/.todayAchieved`。`AchievementEvaluator.dailyStatus(for:records:restDays:rescuedDates:today:calendar:)`。**rescuedDates に含む日は `.achieved` 扱い**(=フリーズで橋渡し)。rest 日は `RestDayResolver.restDaySet(for:records:today:limit:2:calendar:)` が週前半の未達成日を最大2日 rest 化(連続を切らない)。
2. **StreakCalculator.currentStreak(records:today:rescuedDates:restLimit:2:calendar:)**: 今日から後方へ、`.achieved/.todayAchieved`=+1 / `.rest`=skip / それ以外=stop。→ missed 日を rescuedDates に足せば連続が伸びる。
3. **RescueTicketStore**(`@MainActor @Observable`, `.shared`): `useTicket(on:allowance:) -> Bool`(枠切れ/同日二重で false)、`remainingTickets(today:allowance:) -> Int`、`rescuedDates() -> Set<Date>`。`RescueTicketAllowance.current(isPremium:referralBonus:) -> Int`(無料1/プレミアム4、上限5)。
4. **HomeViewModel**: `refresh(records:streakExtendedThisRun:weightLoss:isPremium:referralFreezeBonus:anchorDate:)`。公開: `streak`(StreakState)/`todayStatus`/`statuses`/`lifetimeStats`/`rescueTicketAvailable`/`isComebackToday`。private: `isPremium`/`referralFreezeBonus`/`rescueAllowance`/`rescueTicketStore`/`dateProvider`/`calendar`。`useRescueTicketToday() -> Bool` あり。init: `HomeViewModel(dateProvider:calendar:rescueTicketStore:)`(テスト注入可。`FixedDateProvider(date:)`)。
5. **既存 `isComebackToday`**(おかえりカード): 昨日 `.missed` + 今日未達 + 累計≥3。**本機能(復活ポップ)とは別物で共存**。コーディネーション: 復活ポップは「revivable な break がある」時のみ出すので comeback より限定的。同時表示は許容(ポップは sheet、カードは本文)だが、復活でフリーズ適用後は break が解消し comeback も自然に消える。
6. **PremiumPaywallSheet**: `enum Context { case weight, freeze, general }`。提示パターン: `@State showPremiumPaywall` + `.sheet(isPresented:){ PremiumPaywallSheet(store: storeKit, context: .freeze) }`(StatsView 既存)。HomeView には storeKit が `@Environment` で入っている。
7. **RescueTicketUseView**(Stats タブ)は手動でカレンダーから任意日をフリーズする既存機能。本ポップはホームの「いま切れた連続を今すぐ復活」proactive 導線で別物・共存。
8. **WorkoutRecord** `.date`(startOfDay)、`AchievementEvaluator.isAchieved(record:)`。`WorkoutStore.today`=`calendar.startOfDay(for: dateProvider.currentDate())`。

### ファイル構成(計画②で触る範囲)

| 区分 | パス | 役割 |
|---|---|---|
| 新規 | `GOExercise/Services/StreakFreezeWindow.swift` | 純ロジック(Foundation のみ・swiftc検証): 4日グレースの復活可否/missed日/必要枚数 |
| 新規 | `GOExercise/Views/StreakRevivePopup.swift` | 復活ポップ(sheet本体)。残枠に応じてフリーズ使用 or paywall 誘導 |
| 新規 | `GOExercise/Services/ReviveDismissStore.swift` | 処理済み break を UserDefaults 記録し再表示抑止(純・テスト可) |
| 改 | `GOExercise/ViewModels/HomeViewModel.swift` | refresh で window 評価 → `reviveWindow` 公開、`applyRevive() -> CatRank?`、`potentialReviveStreak` |
| 改 | `GOExercise/Views/HomeView.swift` | ポップ sheet 提示(1起動1回・未処理時)+ 復活演出(RankCelebrationOverlay 流用)+ paywall + 処理済み記録 |
| 新規テスト | `GOExerciseTests/StreakFreezeWindowTests.swift` | 4日境界/複数日/休息日混在/残枠0/復活後 |
| 新規テスト | `GOExerciseTests/HomeViewModelReviveTests.swift` | VM の window 公開/applyRevive |

### スコープ外(YAGNI)
- 殿堂/実績画面、消耗型IAP復活(しない)、weightLoss 改変。Stats の RescueTicketUseView は不変。

---

## Phase 0: `StreakFreezeWindow` 純ロジック(TDD・swiftc)

### Task 1: `StreakFreezeWindow.evaluate`

**Files:**
- Create: `app/GOExercise/GOExercise/Services/StreakFreezeWindow.swift`
- Create (一時): `/tmp/FreezeHarness.swift`
- Create: `app/GOExercise/GOExerciseTests/StreakFreezeWindowTests.swift`

設計: 昨日から後方へ最大 `lookback`(4)日走査。`.missed` 日を集め、`.rest` は skip(連続を切らないので freeze 不要)、`.achieved`(前の連続の頭)に当たったら revivable 確定で停止。lookback 内に achieved が見つからなければ break が古すぎ→復活不可。

```
evaluate(records, today, rescuedDates, remainingFreezes, lookback=4) -> Result:
  cursor = today - 1day（今日は todayPending なので break 対象外）
  missedDates = []; scanned = 0; foundPrior = false
  while scanned < lookback:
    status = dailyStatus(cursor, restDays=restDaySet(cursor,...), rescuedDates, today)
    switch status:
      .achieved/.todayAchieved: foundPrior = true; break loop
      .rest: cursor-=1; scanned+=1; continue   // rest は freeze 不要
      .missed: missedDates.append(cursor); cursor-=1; scanned+=1; continue
      else (.future/.todayPending): break loop
  revivable = foundPrior && !missedDates.isEmpty
  freezesNeeded = missedDates.count
  hasEnough = remainingFreezes >= freezesNeeded
```

- [ ] **Step 1: swiftc ハーネス `/tmp/FreezeHarness.swift`**(`StreakFreezeWindow` + 依存を実コードからコンパイル)

依存(`AchievementEvaluator`/`RestDayResolver`/`StreakCalculator`/`WorkoutRecord`/`ExerciseItem`/`WorkoutCategory`/`Calendar+`)は SwiftUI を含むものがあると swiftc native 実行不可。**まず依存の import を確認**: `AchievementEvaluator.swift`/`RestDayResolver.swift`/`StreakCalculator.swift` が `import Foundation` のみかを確認(`grep -l "import SwiftUI"`)。SwiftUI 非依存なら下記ハーネスで native 実行可能。`WorkoutRecord` は `@Model`(SwiftData)なので **テスト用の軽量プロトコル経由**にはせず、`StreakFreezeWindow` は `dailyStatus` の結果(status 列)だけに依存する設計にして、ハーネスでは status を直接与えるミニ版で純判定部を検証する。

→ 方針: `StreakFreezeWindow` を **2層**にする。
  - `Decision.evaluate(statuses: [DailyStatus], remainingFreezes: Int, lookback: Int) -> Result`(純粋・配列入力・swiftc/Foundation のみで完全テスト可)。`statuses[0]`=昨日, `statuses[1]`=一昨日… の順。
  - `StreakFreezeWindow.evaluate(records:today:rescuedDates:remainingFreezes:lookback:calendar:)`(records→statuses 列を作って `Decision.evaluate` に委譲。`AchievementEvaluator`/`RestDayResolver` 利用。SwiftData 依存があるため XCTest 側で検証)。

ハーネスは `Decision` を検証:

```swift
// /tmp/FreezeHarness.swift  → cp /tmp/FreezeHarness.swift /tmp/main.swift
import Foundation
func ok(_ c: Bool, _ m: String){ if !c { print("FAIL: \(m)"); exit(1) } }
typealias R = StreakFreezeWindow.Result
// 昨日 missed, 一昨日 achieved → 1枚で復活
var r = StreakFreezeWindow.Decision.evaluate(statuses: [.missed, .achieved], remainingFreezes: 1, lookback: 4)
ok(r.revivable && r.freezesNeeded == 1 && r.missedOffsets == [1] && r.hasEnough, "1日gap 残1")
// 残0 → revivable だが hasEnough false
r = StreakFreezeWindow.Decision.evaluate(statuses: [.missed, .achieved], remainingFreezes: 0, lookback: 4)
ok(r.revivable && !r.hasEnough, "残0")
// 3日連続 missed → 一昨々日 achieved。lookback4 内、3枚必要
r = StreakFreezeWindow.Decision.evaluate(statuses: [.missed, .missed, .missed, .achieved], remainingFreezes: 4, lookback: 4)
ok(r.revivable && r.freezesNeeded == 3 && r.missedOffsets == [1,2,3], "3日gap")
// 5日 missed(achieved が lookback 外)→ 復活不可
r = StreakFreezeWindow.Decision.evaluate(statuses: [.missed, .missed, .missed, .missed, .achieved], remainingFreezes: 5, lookback: 4)
ok(!r.revivable, "5日gap 期限切れ")
// 休息日混在: 昨日 missed, 一昨日 rest, その前 achieved → rest は freeze 不要、1枚で復活
r = StreakFreezeWindow.Decision.evaluate(statuses: [.missed, .rest, .achieved], remainingFreezes: 1, lookback: 4)
ok(r.revivable && r.freezesNeeded == 1 && r.missedOffsets == [1], "休息日混在")
// 昨日 achieved(連続継続中)→ revivable false
r = StreakFreezeWindow.Decision.evaluate(statuses: [.achieved, .achieved], remainingFreezes: 1, lookback: 4)
ok(!r.revivable && r.freezesNeeded == 0, "切れてない")
// 全部 missed で achieved 無し(新規/長期放置)→ 復活不可
r = StreakFreezeWindow.Decision.evaluate(statuses: [.missed, .missed, .missed, .missed], remainingFreezes: 5, lookback: 4)
ok(!r.revivable, "前の連続なし")
print("ALL PASS")
```

- [ ] **Step 2: 実行して失敗を確認**

Run: `cp /tmp/FreezeHarness.swift /tmp/main.swift; cd app/GOExercise/GOExercise/Services && swiftc StreakFreezeWindow.swift /tmp/main.swift -o /tmp/fz 2>&1 | head`
注: `DailyStatus` が `AchievementEvaluator.swift` 定義。swiftc には `AchievementEvaluator.swift` も渡す必要があるが、それが Foundation のみかを Step 1 で確認済みの前提。`DailyStatus` だけ使うので、`AchievementEvaluator.swift` を一緒にコンパイル: `swiftc AchievementEvaluator.swift StreakFreezeWindow.swift /tmp/main.swift ...`。`AchievementEvaluator` が `WorkoutRecord`(SwiftData)に触れると native 不可 → その場合は **`DailyStatus` enum を `StreakFreezeWindow` から参照できる形で**(同 enum を使う)、ハーネス用に `DailyStatus` を含む最小ファイルだけ渡す。実装者はまず `grep "enum DailyStatus" -r` で定義場所と依存を確認し、`DailyStatus` を Foundation-only で切り出せるか判断。**`DailyStatus` は既に `String, Codable, CaseIterable, Sendable` で Foundation のみ**なので、`AchievementEvaluator.swift` 全体が SwiftData 依存なら `DailyStatus` を別ファイル化せず、ハーネスに `DailyStatus` の複製定義は作らず、`Decision.evaluate` の引数型を `DailyStatus` にしたうえで **`AchievementEvaluator.swift` から `DailyStatus` 部分のみを含む一時ファイル**を作って一緒にコンパイルする(複製は禁止のため、確認の結果 SwiftData 非依存ならそのまま渡す)。

Expected: 失敗(`StreakFreezeWindow` 未定義)。

- [ ] **Step 3: `StreakFreezeWindow.swift` を実装**

```swift
// app/GOExercise/GOExercise/Services/StreakFreezeWindow.swift
import Foundation

/// 連続が途切れた後「4日グレース」内で、フリーズ(rescue ticket)を missed 日に
/// 適用すれば連続が復活する状況を検出する純ロジック。
/// 2層: `Decision`(status 列だけの純判定・swiftc 完全テスト可)+ records 入口。
enum StreakFreezeWindow {
    struct Result: Equatable {
        /// 復活可能(直近グレース内に missed 日があり、その手前に連続の頭がある)。
        let revivable: Bool
        /// フリーズを当てるべき「今日からの日数オフセット」(1=昨日, 2=一昨日…)。
        let missedOffsets: [Int]
        /// 必要フリーズ枚数(= missed 日数)。
        let freezesNeeded: Int
        /// 残枠が足りるか。
        let hasEnough: Bool
    }

    enum Decision {
        /// statuses[0]=昨日, [1]=一昨日… の順(古い方向)。
        static func evaluate(statuses: [DailyStatus], remainingFreezes: Int, lookback: Int) -> Result {
            var missedOffsets: [Int] = []
            var foundPrior = false
            var i = 0
            while i < lookback && i < statuses.count {
                switch statuses[i] {
                case .achieved, .todayAchieved:
                    foundPrior = true
                    i = lookback // stop
                case .rest:
                    break // freeze 不要、連続も切らない → 次へ
                case .missed:
                    missedOffsets.append(i + 1) // offset 1=昨日
                default:
                    // .future/.todayPending は後方走査では現れない想定。安全側で停止。
                    i = lookback
                    continue
                }
                if foundPrior { break }
                i += 1
            }
            let revivable = foundPrior && !missedOffsets.isEmpty
            let need = missedOffsets.count
            return Result(
                revivable: revivable,
                missedOffsets: revivable ? missedOffsets : [],
                freezesNeeded: revivable ? need : 0,
                hasEnough: revivable && remainingFreezes >= need
            )
        }
    }
}
```

- [ ] **Step 4: swiftc で PASS**

実装者は Step 2 の確認に従い、`DailyStatus` を含む最小コンパイル単位で:
Run: `cp /tmp/FreezeHarness.swift /tmp/main.swift; cd app/GOExercise/GOExercise/Services && swiftc <DailyStatus を含むファイル群> StreakFreezeWindow.swift /tmp/main.swift -o /tmp/fz && /tmp/fz`
Expected: `ALL PASS`

- [ ] **Step 5: records 入口を追加(同ファイル末尾、`enum StreakFreezeWindow` 内)**

```swift
    /// records から status 列(昨日→過去)を作り `Decision` に委譲する本番入口。
    static func evaluate(
        records: [WorkoutRecord],
        today: Date,
        rescuedDates: Set<Date>,
        remainingFreezes: Int,
        lookback: Int = 4,
        calendar: Calendar = .mondayFirst
    ) -> Result {
        let todayStart = calendar.startOfDay(for: today)
        var statuses: [DailyStatus] = []
        for offset in 1...lookback {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { break }
            let restDays = RestDayResolver.restDaySet(for: day, records: records, today: todayStart, calendar: calendar)
            let s = AchievementEvaluator.dailyStatus(
                for: day, records: records, restDays: restDays,
                rescuedDates: rescuedDates, today: todayStart, calendar: calendar)
            statuses.append(s)
        }
        let raw = Decision.evaluate(statuses: statuses, remainingFreezes: remainingFreezes, lookback: lookback)
        // offset → 実日付に変換した missedDates も欲しい呼び出し側向けヘルパは VM 側で行う
        return raw
    }

    /// offset 群(1=昨日…)を実際の Date(startOfDay)に変換。
    static func missedDates(forOffsets offsets: [Int], today: Date, calendar: Calendar = .mondayFirst) -> [Date] {
        let todayStart = calendar.startOfDay(for: today)
        return offsets.compactMap { calendar.date(byAdding: .day, value: -$0, to: todayStart) }
    }
```

- [ ] **Step 6: XCTest `StreakFreezeWindowTests.swift`**(records 入口を実データで)

```swift
import XCTest
@testable import GOExercise

final class StreakFreezeWindowTests: XCTestCase {
    private let cal: Calendar = .mondayFirst
    private func rec(_ daysAgo: Int, from today: Date) -> WorkoutRecord {
        WorkoutRecord(date: cal.date(byAdding: .day, value: -daysAgo, to: today)!,
                      category: .strength,
                      exercises: [ExerciseItem(id: UUID(), name: "スクワット", durationSeconds: 120, reps: nil, sets: nil, memo: nil)],
                      memo: nil, calendar: cal)
    }
    /// 土曜固定で rest 自動補完の影響を避ける(comeback テストと同方針)。
    private func saturday() -> Date {
        var d = cal.startOfDay(for: Date())
        for _ in 0...7 { if cal.component(.weekday, from: d) == 7 { return d }; d = cal.date(byAdding: .day, value: 1, to: d)! }
        return d
    }
    func test_pure_decision_boundaries() {
        let r4 = StreakFreezeWindow.Decision.evaluate(statuses: [.missed,.missed,.missed,.achieved], remainingFreezes: 4, lookback: 4)
        XCTAssertTrue(r4.revivable); XCTAssertEqual(r4.freezesNeeded, 3)
        let r5 = StreakFreezeWindow.Decision.evaluate(statuses: [.missed,.missed,.missed,.missed,.achieved], remainingFreezes: 5, lookback: 4)
        XCTAssertFalse(r5.revivable)
        let rest = StreakFreezeWindow.Decision.evaluate(statuses: [.missed,.rest,.achieved], remainingFreezes: 1, lookback: 4)
        XCTAssertTrue(rest.revivable); XCTAssertEqual(rest.freezesNeeded, 1)
        let zero = StreakFreezeWindow.Decision.evaluate(statuses: [.missed,.achieved], remainingFreezes: 0, lookback: 4)
        XCTAssertTrue(zero.revivable); XCTAssertFalse(zero.hasEnough)
    }
    func test_records_entry_yesterdayMissed_priorStreak() {
        let today = saturday()
        // 2..9 日前に記録(連続)→ 昨日(1日前)だけ空白 = missed
        let records = (2...9).map { rec($0, from: today) }
        let r = StreakFreezeWindow.evaluate(records: records, today: today, rescuedDates: [], remainingFreezes: 1)
        XCTAssertTrue(r.revivable)
        XCTAssertEqual(r.freezesNeeded, 1)
        let dates = StreakFreezeWindow.missedDates(forOffsets: r.missedOffsets, today: today)
        XCTAssertEqual(dates.first, cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: today)))
    }
    func test_records_entry_rescuedYesterday_notRevivable() {
        let today = saturday()
        let records = (2...9).map { rec($0, from: today) }
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: today))!
        let r = StreakFreezeWindow.evaluate(records: records, today: today, rescuedDates: [yesterday], remainingFreezes: 1)
        XCTAssertFalse(r.revivable, "昨日 rescue 済み=achieved → 切れてない")
    }
}
```

- [ ] **Step 7: コミット**

```bash
git add app/GOExercise/GOExercise/Services/StreakFreezeWindow.swift app/GOExercise/GOExerciseTests/StreakFreezeWindowTests.swift
git commit -m "feat(D): StreakFreezeWindow 4日グレース復活判定(純ロジック・2層)" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 1: HomeViewModel に復活ウィンドウ + applyRevive

### Task 2: `ReviveDismissStore`(処理済み break の記録)

**Files:**
- Create: `app/GOExercise/GOExercise/Services/ReviveDismissStore.swift`

break を一意化するキー = 「最古 missed 日の startOfDay timeIntervalSince1970」。復活 or 「今回はしない」でそのキーを記録し、同 break では再表示しない。

```swift
// app/GOExercise/GOExercise/Services/ReviveDismissStore.swift
import Foundation

/// 復活ポップを「処理済み(復活 or 見送り)」にした break を記録し、
/// 同じ break での再提示を抑止する(節度・ダークパターン回避)。
struct ReviveDismissStore {
    private let defaults: UserDefaults
    private let key = "revive.handledBreakKeys"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// break キー = 最古 missed 日(startOfDay)の epoch 秒(Int 文字列)。
    static func breakKey(missedDates: [Date], calendar: Calendar = .mondayFirst) -> String? {
        guard let oldest = missedDates.map({ calendar.startOfDay(for: $0) }).max(by: { $0 < $1 }) == nil
            ? missedDates.min() : missedDates.min() else { return nil }
        return String(Int(calendar.startOfDay(for: oldest).timeIntervalSince1970))
    }
    func isHandled(_ key: String) -> Bool {
        (defaults.array(forKey: key) as? [String] ?? handled()).contains(key)
    }
    func handled() -> [String] { defaults.array(forKey: key) as? [String] ?? [] }
    func markHandled(_ key: String) {
        var all = handled()
        guard !all.contains(key) else { return }
        all.append(key)
        // 肥大化防止: 直近32件だけ保持。
        if all.count > 32 { all = Array(all.suffix(32)) }
        defaults.set(all, forKey: key)
    }
}
```

> 注: 上記 `breakKey` は分かりにくいので実装時に下記へ単純化すること(レビュー指摘回避):
> ```swift
> static func breakKey(missedDates: [Date], calendar: Calendar = .mondayFirst) -> String? {
>     guard let oldest = missedDates.map({ calendar.startOfDay(for: $0) }).min() else { return nil }
>     return String(Int(oldest.timeIntervalSince1970))
> }
> ```
> また `isHandled`/`markHandled` は同一 `key`(=defaults キー)を使う実装ミスに注意。**defaults 用キー(`handledBreakKeys`)と break キーを混同しない**こと。下記が正:
> ```swift
> private let storeKey = "revive.handledBreakKeys"
> func handled() -> [String] { defaults.array(forKey: storeKey) as? [String] ?? [] }
> func isHandled(_ breakKey: String) -> Bool { handled().contains(breakKey) }
> func markHandled(_ breakKey: String) { var a = handled(); guard !a.contains(breakKey) else { return }; a.append(breakKey); if a.count > 32 { a = Array(a.suffix(32)) }; defaults.set(a, forKey: storeKey) }
> ```

- [ ] **Step 1: 上記の「正」実装で `ReviveDismissStore.swift` を作成**(`storeKey` と `breakKey` を明確に分離)。
- [ ] **Step 2: 軽量テストを `StreakFreezeWindowTests` に追記**(別 suite UserDefaults で isHandled/markHandled/breakKey 安定性)。
- [ ] **Step 3: ビルド + コミット** `feat(D): ReviveDismissStore 処理済みbreak記録`

### Task 3: HomeViewModel に reviveWindow / applyRevive

**Files:** Modify `app/GOExercise/GOExercise/ViewModels/HomeViewModel.swift`

- [ ] **Step 1: プロパティ追加**(他の公開 var 群の近く)

```swift
    /// 復活ウィンドウ(nil=対象外)。HomeView がポップ提示判定に使う。
    var reviveWindow: StreakFreezeWindow.Result?
    /// 復活したら到達する連続日数(ポップのコピー「連続◯日」に使用)。
    var potentialReviveStreak: Int = 0
```

- [ ] **Step 2: `refresh()` 末尾で評価を追加**

`refresh` 内、`isComebackToday` を計算している箇所の後に:

```swift
        // 復活ウィンドウ(4日グレース)。残枠は月次 allowance から算出。
        let remaining = rescueTicketStore.remainingTickets(today: today, allowance: rescueAllowance)
        let rescued = rescueTicketStore.rescuedDates()
        let window = StreakFreezeWindow.evaluate(
            records: records, today: today, rescuedDates: rescued,
            remainingFreezes: remaining, calendar: calendar)
        reviveWindow = window.revivable ? window : nil
        if window.revivable {
            // missed 日をすべて rescued と仮定したときの連続(復活後の連続日数)。
            let missed = StreakFreezeWindow.missedDates(forOffsets: window.missedOffsets, today: today, calendar: calendar)
            let hypothetical = rescued.union(missed.map { calendar.startOfDay(for: $0) })
            potentialReviveStreak = StreakCalculator.currentStreak(
                records: records, today: today, rescuedDates: hypothetical, calendar: calendar)
        } else {
            potentialReviveStreak = 0
        }
```

(`today`/`records` は refresh 内のローカル。`rescueAllowance` は既存 private computed)

- [ ] **Step 3: `applyRevive()` メソッド追加**

```swift
    /// 復活ウィンドウの missed 日すべてにフリーズを適用し、連続を復活させる。
    /// - Returns: 復活後の `CatRank`(復活演出用)。適用不可(枠不足/window無)なら nil。
    @discardableResult
    func applyRevive() -> CatRank? {
        guard let window = reviveWindow, window.hasEnough else { return nil }
        let today = calendar.startOfDay(for: dateProvider.currentDate())
        let missed = StreakFreezeWindow.missedDates(forOffsets: window.missedOffsets, today: today, calendar: calendar)
        var applied = 0
        for day in missed {
            if rescueTicketStore.useTicket(on: day, allowance: rescueAllowance) { applied += 1 }
        }
        guard applied == missed.count else { return nil } // 全日適用できなければ失敗扱い
        return CatRank(currentStreak: potentialReviveStreak)
    }
```

- [ ] **Step 4: XCTest `HomeViewModelReviveTests.swift`**(FixedDateProvider + 別 suite RescueTicketStore)

```swift
import XCTest
@testable import GOExercise

@MainActor
final class HomeViewModelReviveTests: XCTestCase {
    private let cal: Calendar = .mondayFirst
    private func rec(_ daysAgo: Int, from today: Date) -> WorkoutRecord {
        WorkoutRecord(date: cal.date(byAdding: .day, value: -daysAgo, to: today)!, category: .strength,
                      exercises: [ExerciseItem(id: UUID(), name: "スクワット", durationSeconds: 120, reps: nil, sets: nil, memo: nil)],
                      memo: nil, calendar: cal)
    }
    private func saturday() -> Date {
        var d = cal.startOfDay(for: Date()); for _ in 0...7 { if cal.component(.weekday, from: d) == 7 { return d }; d = cal.date(byAdding: .day, value: 1, to: d)! }; return d
    }
    func test_reviveWindow_published_andApply_restoresStreak() {
        let today = saturday()
        let store = RescueTicketStore(defaults: UserDefaults(suiteName: "revive-\(UUID())")!)
        let vm = HomeViewModel(dateProvider: FixedDateProvider(date: today), calendar: cal, rescueTicketStore: store)
        let records = (2...9).map { rec($0, from: today) } // 昨日だけ空白
        vm.refresh(records: records, isPremium: false, referralFreezeBonus: 0)
        XCTAssertNotNil(vm.reviveWindow)
        XCTAssertEqual(vm.reviveWindow?.freezesNeeded, 1)
        XCTAssertTrue(vm.reviveWindow?.hasEnough == true) // 無料枠1で足りる
        let rank = vm.applyRevive()
        XCTAssertNotNil(rank)
        // 復活後 refresh で連続が伸びている
        vm.refresh(records: records, isPremium: false, referralFreezeBonus: 0)
        XCTAssertGreaterThan(vm.streak.currentStreak, 0)
        XCTAssertNil(vm.reviveWindow, "復活後は window 解消")
    }
    func test_noWindow_whenStreakIntact() {
        let today = saturday()
        let store = RescueTicketStore(defaults: UserDefaults(suiteName: "revive-\(UUID())")!)
        let vm = HomeViewModel(dateProvider: FixedDateProvider(date: today), calendar: cal, rescueTicketStore: store)
        let records = (1...9).map { rec($0, from: today) } // 昨日も達成
        vm.refresh(records: records)
        XCTAssertNil(vm.reviveWindow)
    }
}
```

- [ ] **Step 5: ビルド + swiftc(StreakFreezeWindow 再確認)+ コミット**

```bash
git add app/GOExercise/GOExercise/ViewModels/HomeViewModel.swift app/GOExercise/GOExerciseTests/HomeViewModelReviveTests.swift
git commit -m "feat(D): HomeViewModel に reviveWindow 公開 + applyRevive(連続復活)" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 2: `StreakRevivePopup` + HomeView 配線

### Task 4: `StreakRevivePopup` ビュー

**Files:** Create `app/GOExercise/GOExercise/Views/StreakRevivePopup.swift`

UIUX(skill 反映): 穏やかなコピー(損失を煽らない)、主 CTA 1つ、ディスミス明確、44pt タップ、reduceMotion 配慮。残枠で分岐。

```swift
// app/GOExercise/GOExercise/Views/StreakRevivePopup.swift
import SwiftUI

/// 連続が途切れた直後(4日グレース)に出す復活ポップ。穏やかなトーン。
struct StreakRevivePopup: View {
    let potentialStreak: Int     // 復活後に戻る連続日数
    let freezesNeeded: Int
    let remaining: Int
    let hasEnough: Bool
    let onUseFreeze: () -> Void   // 残枠十分: フリーズ適用
    let onSeePremium: () -> Void  // 残枠不足: paywall
    let onDismiss: () -> Void     // 今回はしない

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 36, height: 5).padding(.top, 8)
            Image(systemName: "snowflake")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color(red: 0.40, green: 0.70, blue: 0.95))
                .accessibilityHidden(true)
            Text("連続\(potentialStreak)日を守れます")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .multilineTextAlignment(.center)
            Text(hasEnough
                 ? "フリーズを使うと、お休みした日が埋まって連続記録が続きます(残り\(remaining)回)。"
                 : "連続を守るにはフリーズが\(freezesNeeded)回必要です(残り\(remaining)回)。GOプレミアムなら毎月4回使えます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if hasEnough {
                Button(action: onUseFreeze) {
                    Text("フリーズを使う(\(freezesNeeded)回)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: onSeePremium) {
                    Text("GOプレミアムでフリーズを増やす")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("今回はしない", action: onDismiss)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
    }
}
```

- [ ] **Step 1: 上記を作成、ビルド GREEN、コミット** `feat(D): StreakRevivePopup`

### Task 5: HomeView 配線(提示・復活演出・paywall・処理済み記録)

**Files:** Modify `app/GOExercise/GOExercise/Views/HomeView.swift`

- [ ] **Step 1: state 追加**(他 @State の近く)

```swift
    @State private var isShowingRevive = false
    @State private var isShowingFreezePaywall = false
    @State private var reviveShownThisLaunch = false
    @State private var reviveCelebration: CatRank?
    private let reviveDismissStore = ReviveDismissStore()
```

- [ ] **Step 2: 提示判定**(`evaluateRankCelebration()` を呼んでいる `.onAppear` 内、その直後に `maybePresentRevive()` を追加)

```swift
    /// 復活ポップを条件付きで提示(1起動1回・未処理 break のみ)。
    private func maybePresentRevive() {
        guard !reviveShownThisLaunch else { return }
        guard let window = viewModel.reviveWindow else { return }
        let today = calendar.startOfDay(for: store.today)
        let missed = StreakFreezeWindow.missedDates(forOffsets: window.missedOffsets, today: today, calendar: calendar)
        guard let key = ReviveDismissStore.breakKey(missedDates: missed, calendar: calendar) else { return }
        guard !reviveDismissStore.isHandled(key) else { return }
        reviveShownThisLaunch = true
        isShowingRevive = true
    }
```

`.onAppear` の `evaluateRankCelebration()` の次行に `maybePresentRevive()` を追加。

- [ ] **Step 3: sheet 修飾子を追加**(他 `.sheet` 群と同階層)

```swift
            .sheet(isPresented: $isShowingRevive) {
                let w = viewModel.reviveWindow
                StreakRevivePopup(
                    potentialStreak: viewModel.potentialReviveStreak,
                    freezesNeeded: w?.freezesNeeded ?? 0,
                    remaining: viewModel.reviveRemainingFreezes, // 下記 VM computed
                    hasEnough: w?.hasEnough ?? false,
                    onUseFreeze: { handleReviveUse() },
                    onSeePremium: {
                        markReviveHandled()
                        isShowingRevive = false
                        isShowingFreezePaywall = true
                    },
                    onDismiss: {
                        markReviveHandled()
                        isShowingRevive = false
                    }
                )
            }
            .sheet(isPresented: $isShowingFreezePaywall) {
                PremiumPaywallSheet(store: storeKit, context: .freeze)
            }
```

- [ ] **Step 4: ヘルパ + VM に remaining 公開**

VM に computed 追加(`HomeViewModel`):
```swift
    var reviveRemainingFreezes: Int {
        let today = calendar.startOfDay(for: dateProvider.currentDate())
        return rescueTicketStore.remainingTickets(today: today, allowance: rescueAllowance)
    }
```

HomeView ヘルパ:
```swift
    private func markReviveHandled() {
        let today = calendar.startOfDay(for: store.today)
        if let window = viewModel.reviveWindow {
            let missed = StreakFreezeWindow.missedDates(forOffsets: window.missedOffsets, today: today, calendar: calendar)
            if let key = ReviveDismissStore.breakKey(missedDates: missed, calendar: calendar) {
                reviveDismissStore.markHandled(key)
            }
        }
    }
    private func handleReviveUse() {
        markReviveHandled()
        let restored = viewModel.applyRevive()
        isShowingRevive = false
        // 連続/称号/背景を即時反映 + 復活演出(計画①の RankCelebrationOverlay 流用)。
        viewModel.refresh(records: store.records, weightLoss: currentWeightSnapshot(),
                          isPremium: storeKit.isPremiumActive, referralFreezeBonus: referralStore.summary.freezeBonusThisMonth)
        WidgetSnapshotPublisher.publish(from: store, today: Date(), rescuedDates: RescueTicketStore.shared.rescuedDates(), calendar: calendar)
        if let restored {
            reviveCelebration = restored
            CelebrationCenter.shared.fireLight()
        }
    }
```

- [ ] **Step 5: 復活演出オーバーレイ**(body の ZStack 末尾、`pendingRankEvent` オーバーレイの近く)

```swift
                if let rank = reviveCelebration {
                    RankCelebrationOverlay(
                        rank: rank,
                        message: "連続復活!",
                        onFinished: { reviveCelebration = nil }
                    )
                    .transition(.opacity)
                    .zIndex(11)
                }
```

- [ ] **Step 6: ビルド GREEN(simulator name=iPhone 17)。コミット**

```bash
git add app/GOExercise/GOExercise/Views/HomeView.swift app/GOExercise/GOExercise/Views/StreakRevivePopup.swift app/GOExercise/GOExercise/ViewModels/HomeViewModel.swift
git commit -m "feat(D): 復活ポップ提示+フリーズ適用+復活演出+paywall導線+処理済み抑止" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 3: 検証(D: checklist 15-19)

### Task 6: 純ロジック swiftc 最終確認 + 全テスト
- [ ] swiftc で `StreakFreezeWindow.Decision` ハーネス ALL PASS を再確認。
- [ ] `xcodebuild ... test`(hang したら `-only-testing:GOExerciseTests/StreakFreezeWindowTests` 等で個別)。`StreakFreezeWindowTests`/`HomeViewModelReviveTests`/既存 `HomeViewModelComebackTests` green を確認(comeback 回帰なし)。

### Task 7: simctl スクショ + 3LLM(D 復活ポップ)
- [ ] **撮影**: DemoDataSeeder に「昨日だけ欠けて streak が切れた」シナリオが無ければ、検証用に `--seed-scenario` の既存(streakBroken)を使うか、一時 DEBUG ハーネスで `StreakRevivePopup` を直接表示してスクショ。残枠あり/なし(=hasEnough true/false)の2状態。
- [ ] 3LLM 採点(checklist D15-19): 発火条件/無料枠復活/枠切れ→ペイウォール/節度(ディスミス可・煽らないコピー)。2点未満を改善。
- [ ] 検証ハーネスを削除、最終ビルド、`docs/superpowers/verification/2026-06-06-plan2/` に記録。

### Task 8: 後片付け + メモリ更新
- [ ] grep で残デバッグ無し、ビルド GREEN、Info.plist キー確認。
- [ ] メモリ `achievement_luxury_redesign.md` を「計画②完了・次は計画③(E)」に更新。

---

## Self-Review(spec D 突き合わせ)
- 4日グレース検出(StreakFreezeWindow・2層純ロジック)— Task1 ✅(境界4/5日・複数日・休息日混在・残枠0をテスト)
- 無料枠で復活 / 枠切れ→PremiumPaywallSheet(.freeze)— Task5 ✅
- 復活で連続/称号/背景 即時 + 復活演出(RankCelebrationOverlay 流用)— Task5 ✅
- 節度: ディスミス可・1起動1回(reviveShownThisLaunch)・4日失効(lookback)・処理済み break 再表示なし(ReviveDismissStore)— Task2/5 ✅
- フリーズ自体は既存 RescueTicketStore 流用・消耗型IAP復活なし — ✅(スコープ外)
- 既存 comeback と共存(別判定)— 調査5・Task6 で回帰確認 ✅

**型一貫性**: `StreakFreezeWindow.Result{revivable,missedOffsets,freezesNeeded,hasEnough}` / `.Decision.evaluate(statuses:remainingFreezes:lookback:)` / `.evaluate(records:today:rescuedDates:remainingFreezes:lookback:calendar:)` / `.missedDates(forOffsets:today:calendar:)` / `HomeViewModel.reviveWindow/.potentialReviveStreak/.applyRevive()->CatRank?/.reviveRemainingFreezes` / `ReviveDismissStore.breakKey(missedDates:calendar:)?/.isHandled/.markHandled` / `StreakRevivePopup(potentialStreak:freezesNeeded:remaining:hasEnough:onUseFreeze:onSeePremium:onDismiss:)` — 全タスクで一致。
</content>
