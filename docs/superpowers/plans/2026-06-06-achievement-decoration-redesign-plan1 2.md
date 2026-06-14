# 達成の豪華演出リデザイン 計画① (装飾リデザイン: 撤去 + A背景 + B瞬間演出 + C称号 + F友達称号) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 猫に乗せる装飾(頭上バッジ/王冠/シェイカーアイテム)を全廃し、**連続日数ベースの統一ランク `CatRank`** を背骨に、A=背景進化 / B=小節目の瞬間演出 / C=メタリック称号バッジ / F=友達の称号表示 を実装する。

**Architecture:** `CatRank`(純ロジック・Foundation のみ)を単一ソースとし、現在の連続日数(`StreakCalculator.currentStreak`)から rank(0..11)/称号/メタル種別/richness を導出。SwiftUI 依存の色(`MetalStyle`)は別ファイルに分離して swiftc ネイティブ検証を可能にする。既存の `MilestoneBackground`/`MilestoneItem`/`CatDecoration`/`CatDecorationEmblem` は撤去し、消費元を `CatRank` に移行する。B は `RankUpDetector`(純ロジック)+ `CelebrationCenter.fireLight()` + 称号トーストオーバーレイ。F はバックエンド変更なしで `FriendProfile.rank`(currentStreak から computed)を `RankBadge` で表示。

**Tech Stack:** Swift 5.9 / SwiftUI / iOS 17 / xcodegen(`app/GOExercise/project.yml`)/ XCTest。純ロジック検証は swiftc ネイティブ実行、UI は `xcodebuild build` + `simctl` スクショ + 3LLM(Codex gpt-5-codex + Gemini)採点。

**正本spec:** `docs/superpowers/specs/2026-06-06-achievement-luxury-design.md`
**検証チェックリスト:** `docs/superpowers/specs/2026-06-06-decoration-verification-checklist.md`(A/B/C/F 軸)

---

## 重要な前提・調査結果(着工前に必読)

実コードを精査済み。以下は計画の根拠となる事実:

1. **既存 `StreakLevel`(7段・streak ベース)は別用途**(StreakShareSheet 用)。**触らない**。`CatRank` は新規の11段ランクで独立。
2. **`MilestoneBackdropStyle` は現在 `totalAchievedDays`(累計)駆動**(`MilestoneBackground.tier` 経由)。spec で背骨を**現在の連続(currentStreak)駆動**に変える。閾値 `[7,14,30,50,75,100,150,200,300,365,500]` は同じなので `CatRank.rank`(0..11)が `MilestoneBackground.tier` を置換するが、入力が累計→連続に変わる**意味変更**である点に注意。
3. **Widget(`GOExerciseWidget`)は `MilestoneStyle.swift` を共有ソースに含むが、その型(`MilestoneItem`/`MilestoneBackground`)を一切使っていない**(widget の猫 View は `CatState`/`CatBreed` だけ使用)。→ `MilestoneStyle.swift` を削除する際は `project.yml`(line 98)から共有ソース参照も外す。`CatRank` は widget に共有しない(本体のみ)。
4. **`CatDecorationEmblem` の唯一の配線は `HomeView.swift:528-533`(BigCatView の `.overlay(alignment: .top)`)**。`BigCatView.decoration` パラメータ(`HomeView.swift:497`)も撤去対象。call site は `HomeView.swift:214` と `RecordCompletionView.swift:73-74`。
5. **`CatDecoration` の消費元**: `FriendProfile.swift:43`(computed `decoration`)、`HomeView.swift:215/440`、`RecordCompletionView.swift:74`、`FriendDetailView.swift:94-97`、`FriendsStoreTests.swift:460-470`。`RewardCard.swift:4` はコメントのみ(型未使用)。
6. **`FriendProfile.decorationTier`(0..4)はバックエンド payload フィールド**(`SupabaseFriendsService.swift:742/760/822` で read/write、`MockFriendsService`/各テストで使用)。spec F の決定: **フィールドは温存し publish 値を `CatRank.rank`(0..11)に変える**。表示は currentStreak から computed する `FriendProfile.rank` を使う(decorationTier には依存しない)。
7. **テスト**: `MilestoneStyleTests.swift`(MilestoneItem/MilestoneBackground)は削除。`MilestoneBackdropStyleTests.swift` は `init(streak:)` へ書き換え。`FriendsStoreTests.swift:455-471` の `decoration` マッピングテストは `rank` へ。`StreakLevelTests` は不変。
8. **環境 gotcha**: `xcodegen generate` は Info.plist 手動キー(`FriendsAppleLinkEnabled`/`TelemetryDeckAppID`)を落とす場合あり(本計画は Info.plist 変更なしだが、generate 後に検証)。iCloud 重複ファイルはビルド前に `find app/GOExercise/build -name "* [0-9].*" -delete`。

### ファイル構成(このプランで触る範囲)

| 区分 | パス | 役割 |
|---|---|---|
| 新規 | `GOExercise/Models/CatRank.swift` | 連続ベース11段ランク(純・Foundation のみ): rank/title/metalKind/richness/thresholds/iconSymbol |
| 新規 | `GOExercise/Models/MetalStyle.swift` | `MetalKind` → SwiftUI 色/グラデ(bronze/silver/gold/platinum/rainbow と ±) |
| 新規 | `GOExercise/Views/Components/RankBadge.swift` | C: メタリック称号カプセル + 昇格 shimmer/pop |
| 新規 | `GOExercise/Services/RankUpDetector.swift` | B: 前回 rank/週次を UserDefaults 保持し小節目イベントを返す(純) |
| 新規 | `GOExercise/Views/Components/RankCelebrationOverlay.swift` | B: 光のさざ波 + 称号トースト(軽量・割り込まない) |
| 改 | `GOExercise/Models/MilestoneBackdropStyle.swift` | `init(streak:)` 化、`metalKind` 追加(A) |
| 改 | `GOExercise/Views/Components/MilestoneBackdrop.swift` | streak/rank 駆動の色帯・粒子・時間帯トーン・最上位光(A) |
| 改 | `GOExercise/Services/CelebrationCenter.swift` | `fireLight()` 追加(シート無しの軽量演出)(B) |
| 改 | `GOExercise/Models/FriendProfile.swift` | `decoration: CatDecoration` → `rank: CatRank`(currentStreak computed)(F) |
| 改 | `GOExercise/Views/Components/FriendAvatarView.swift` | リング色を `rank.metalKind` へ(F) |
| 改 | `GOExercise/Views/FriendDetailView.swift` | decoration チップ → `RankBadge`(F) |
| 改 | `GOExercise/Views/HomeView.swift` | backdrop=streak、RankBadge 配置、emblem 撤去、publish rank、RankUp 評価+演出(A/B/C/F) |
| 改 | `GOExercise/Views/RecordCompletionView.swift` | BigCatView の decoration 引数撤去 |
| 改 | `GOExercise/Models/CatBreed.swift` | `avatarAssetName(totalAchievedDays:)` 撤去(dead) |
| 改 | `GOExercise/Services/MockFriendsService.swift` | F スクショ用に mock 友達の currentStreak を多様化 |
| 改 | `app/GOExercise/project.yml` | widget 共有から `MilestoneStyle.swift` を除去 |
| 削除 | `GOExercise/Models/CatDecoration.swift` | → `CatRank` 統合 |
| 削除 | `GOExercise/Models/MilestoneStyle.swift` | `MilestoneItem`+`MilestoneBackground`(thresholds は CatRank へ) |
| 削除 | `GOExercise/Views/Components/CatDecorationEmblem.swift` | 頭上バッジ撤廃 |
| 削除 | `GOExercise/Views/Components/MilestoneBackgroundView.swift` | 画像背景 View(未使用) |
| 削除 | アセット `Milestones/bg_milestone_01..11.imageset` | 画像背景 |
| 削除 | アセット `CatCharacter/cat_orange_waitingMorning_crown.imageset` | 王冠アイテム(shaker は保持=計画③の種) |
| 削除 | テスト `GOExerciseTests/MilestoneStyleTests.swift` | 撤去型のテスト |

### 検証方式の使い分け

- **純ロジック(`CatRank`/`RankUpDetector`/`MilestoneBackdropStyle`)**: swiftc ネイティブで小ハーネスをコンパイル&実行(simテストランナーは hang するため使わない)。`CatRank.swift` と `RankUpDetector.swift` は **Foundation のみ**に保ち、SwiftUI 色は `MetalStyle.swift` に分離 → swiftc 単体コンパイル可能。
- **UI(`RankBadge`/`MilestoneBackdrop`/`RankCelebrationOverlay`/友達カード)**: `xcodegen generate` → `xcodebuild build` → `simctl` スクショ → 検証チェックリスト A/B/C/F を 3LLM 採点(各項目0-3点・全項目2点以上で合格)。

### CatRank 定義表(spec 正本より)

| rank | 連続閾値(≧) | title | metalKind |
|---|---|---|---|
| 0 | 0 | (なし) | — |
| 1 | 7 | みならいネコ | bronze |
| 2 | 14 | かけだしネコ | bronzePlus |
| 3 | 30 | がんばりネコ | silver |
| 4 | 50 | まいにちネコ | silverPlus |
| 5 | 75 | きたえネコ | goldMinus |
| 6 | 100 | つわものネコ | gold |
| 7 | 150 | ベテランネコ | gold |
| 8 | 200 | 達人ネコ | goldPlus |
| 9 | 300 | 仙人ネコ | goldPlus |
| 10 | 365 | レジェンドネコ | platinum |
| 11 | 500 | ぬしネコ | rainbow |

`richness = Double(rank)/11`。`thresholds = [7,14,30,50,75,100,150,200,300,365,500]`、`rank = thresholds.filter { streak >= $0 }.count`。

---

## Phase 0: `CatRank` 背骨(純ロジック)+ `MetalStyle`

### Task 1: `CatRank` 純ロジックモデル(TDD・swiftc 検証)

**Files:**
- Create: `app/GOExercise/GOExercise/Models/CatRank.swift`
- Create (一時ハーネス): `/tmp/CatRankHarness.swift`

- [ ] **Step 1: swiftc 用の失敗するハーネステストを書く**

`MetalKind` は Foundation だけで表現(色は次タスクの `MetalStyle.swift`)。まずハーネスに期待を書く:

```swift
// /tmp/CatRankHarness.swift  — `swiftc CatRank.swift /tmp/CatRankHarness.swift -o /tmp/catrank && /tmp/catrank`
import Foundation

func expect(_ cond: Bool, _ msg: String) {
    if !cond { print("FAIL: \(msg)"); exit(1) }
}

// rank 境界
expect(CatRank(currentStreak: 0).rank == 0, "0->0")
expect(CatRank(currentStreak: 6).rank == 0, "6->0")
expect(CatRank(currentStreak: 7).rank == 1, "7->1")
expect(CatRank(currentStreak: 13).rank == 1, "13->1")
expect(CatRank(currentStreak: 14).rank == 2, "14->2")
expect(CatRank(currentStreak: 29).rank == 2, "29->2")
expect(CatRank(currentStreak: 30).rank == 3, "30->3")
expect(CatRank(currentStreak: 49).rank == 3, "49->3")
expect(CatRank(currentStreak: 50).rank == 4, "50->4")
expect(CatRank(currentStreak: 75).rank == 5, "75->5")
expect(CatRank(currentStreak: 100).rank == 6, "100->6")
expect(CatRank(currentStreak: 150).rank == 7, "150->7")
expect(CatRank(currentStreak: 200).rank == 8, "200->8")
expect(CatRank(currentStreak: 300).rank == 9, "300->9")
expect(CatRank(currentStreak: 365).rank == 10, "365->10")
expect(CatRank(currentStreak: 499).rank == 10, "499->10")
expect(CatRank(currentStreak: 500).rank == 11, "500->11")
expect(CatRank(currentStreak: 99999).rank == 11, "max->11")
// reset(連続0→rank0)
expect(CatRank(currentStreak: 0).title == nil, "rank0 no title")
expect(CatRank(currentStreak: 0).metalKind == nil, "rank0 no metal")
// title / metal
expect(CatRank(currentStreak: 7).title == "みならいネコ", "title 7")
expect(CatRank(currentStreak: 14).title == "かけだしネコ", "title 14")
expect(CatRank(currentStreak: 500).title == "ぬしネコ", "title 500")
expect(CatRank(currentStreak: 7).metalKind == .bronze, "metal 7")
expect(CatRank(currentStreak: 30).metalKind == .silver, "metal 30")
expect(CatRank(currentStreak: 100).metalKind == .gold, "metal 100")
expect(CatRank(currentStreak: 365).metalKind == .platinum, "metal 365")
expect(CatRank(currentStreak: 500).metalKind == .rainbow, "metal 500")
// richness
expect(abs(CatRank(currentStreak: 0).richness - 0.0) < 0.0001, "richness 0")
expect(abs(CatRank(currentStreak: 500).richness - 1.0) < 0.0001, "richness 1")
// negative guard
expect(CatRank(currentStreak: -5).rank == 0, "negative->0")
print("ALL PASS")
```

- [ ] **Step 2: 実行して失敗(コンパイルエラー)を確認**

Run: `cd app/GOExercise/GOExercise/Models && swiftc CatRank.swift /tmp/CatRankHarness.swift -o /tmp/catrank 2>&1 | head` (CatRank.swift がまだ無いので「no such file / cannot find 'CatRank'」で失敗)
Expected: コンパイル失敗。

- [ ] **Step 3: `CatRank.swift` を実装(Foundation のみ)**

```swift
// app/GOExercise/GOExercise/Models/CatRank.swift
import Foundation

/// メタルの種別。色(SwiftUI)は `MetalStyle.swift` が担う。
/// `+`/`-` は同系統 ±8% 明度のバリアント。`rainbow` は AngularGradient。
enum MetalKind: Equatable, Sendable {
    case bronze, bronzePlus
    case silver, silverPlus
    case goldMinus, gold, goldPlus
    case platinum
    case rainbow
}

/// 達成の豪華演出の背骨。**現在の連続日数**で決まる統一11段ランク。
/// 連続が途切れたら rank も落ちる(降格)= 守る動機。フリーズで連続が保たれれば rank も保たれる。
/// A背景の濃さ・C称号名・Cメタル色・B昇格判定の唯一の入力。
struct CatRank: Equatable, Sendable {
    /// 連続閾値(昇順)。rank = この配列のうち streak 以下の要素数。
    static let thresholds = [7, 14, 30, 50, 75, 100, 150, 200, 300, 365, 500]

    /// 0..11。0 = 称号なし(連続7日未満)。
    let rank: Int

    init(currentStreak: Int) {
        let s = max(0, currentStreak)
        self.rank = Self.thresholds.filter { s >= $0 }.count
    }

    /// 0..1。背景 richness 等の連続的な濃さ。
    var richness: Double { Double(rank) / Double(Self.thresholds.count) }

    /// 称号(案B「ねこ仕立て」)。rank0 は nil。
    var title: String? {
        switch rank {
        case 1: return "みならいネコ"
        case 2: return "かけだしネコ"
        case 3: return "がんばりネコ"
        case 4: return "まいにちネコ"
        case 5: return "きたえネコ"
        case 6: return "つわものネコ"
        case 7: return "ベテランネコ"
        case 8: return "達人ネコ"
        case 9: return "仙人ネコ"
        case 10: return "レジェンドネコ"
        case 11: return "ぬしネコ"
        default: return nil
        }
    }

    /// メタル種別。rank0 は nil。
    var metalKind: MetalKind? {
        switch rank {
        case 1: return .bronze
        case 2: return .bronzePlus
        case 3: return .silver
        case 4: return .silverPlus
        case 5: return .goldMinus
        case 6, 7: return .gold
        case 8, 9: return .goldPlus
        case 10: return .platinum
        case 11: return .rainbow
        default: return nil
        }
    }

    /// 称号バッジの小アイコン(SF Symbol)。ブランド一貫性のため全 rank 共通の肉球。
    var iconSymbol: String { "pawprint.fill" }
}
```

- [ ] **Step 4: swiftc で実行し PASS を確認**

Run: `cd app/GOExercise/GOExercise/Models && swiftc CatRank.swift /tmp/CatRankHarness.swift -o /tmp/catrank && /tmp/catrank`
Expected: `ALL PASS`

- [ ] **Step 5: XCTest にも移植(sim ビルド用の正式テスト)**

Create `app/GOExercise/GOExerciseTests/CatRankTests.swift`:

```swift
import XCTest
@testable import GOExercise

final class CatRankTests: XCTestCase {
    func test_rankBoundaries() {
        let cases: [(Int, Int)] = [
            (0,0),(6,0),(7,1),(13,1),(14,2),(29,2),(30,3),(49,3),(50,4),
            (74,4),(75,5),(99,5),(100,6),(149,6),(150,7),(199,7),(200,8),
            (299,8),(300,9),(364,9),(365,10),(499,10),(500,11),(99999,11)
        ]
        for (streak, rank) in cases {
            XCTAssertEqual(CatRank(currentStreak: streak).rank, rank, "streak \(streak)")
        }
    }
    func test_reset_isRank0() {
        XCTAssertEqual(CatRank(currentStreak: 0).rank, 0)
        XCTAssertNil(CatRank(currentStreak: 0).title)
        XCTAssertNil(CatRank(currentStreak: 0).metalKind)
        XCTAssertEqual(CatRank(currentStreak: -3).rank, 0)
    }
    func test_titleAndMetal() {
        XCTAssertEqual(CatRank(currentStreak: 7).title, "みならいネコ")
        XCTAssertEqual(CatRank(currentStreak: 7).metalKind, .bronze)
        XCTAssertEqual(CatRank(currentStreak: 30).metalKind, .silver)
        XCTAssertEqual(CatRank(currentStreak: 100).metalKind, .gold)
        XCTAssertEqual(CatRank(currentStreak: 365).metalKind, .platinum)
        XCTAssertEqual(CatRank(currentStreak: 500).title, "ぬしネコ")
        XCTAssertEqual(CatRank(currentStreak: 500).metalKind, .rainbow)
    }
    func test_richness() {
        XCTAssertEqual(CatRank(currentStreak: 0).richness, 0, accuracy: 0.0001)
        XCTAssertEqual(CatRank(currentStreak: 500).richness, 1, accuracy: 0.0001)
    }
}
```

- [ ] **Step 6: コミット**

```bash
git add app/GOExercise/GOExercise/Models/CatRank.swift app/GOExercise/GOExerciseTests/CatRankTests.swift
git commit -m "feat(rank): CatRank 連続ベース11段ランク(純ロジック)を追加"
```

---

### Task 2: `MetalStyle`(SwiftUI 色/グラデ)

**Files:**
- Create: `app/GOExercise/GOExercise/Models/MetalStyle.swift`

- [ ] **Step 1: `MetalStyle.swift` を実装**

spec の RGB を正本にする。bronze=(0.80,0.52,0.25) / silver=(0.74,0.76,0.80) / gold=(1.00,0.80,0.42)(既存 backdrop と一致)/ platinum=(0.88,0.90,0.96)。`+`/`-` は明度 ±8%。rainbow は AngularGradient(reduceMotion で静止は呼び出し側で対応)。

```swift
// app/GOExercise/GOExercise/Models/MetalStyle.swift
import SwiftUI

/// `MetalKind` を SwiftUI の色・グラデーションに変換する。
/// spec の RGB を正本にし、`+`/`-` は明度 ±8% で表現。
enum MetalStyle {
    /// 代表色(チップ枠・アイコン色など単色が要る箇所)。
    static func baseColor(_ kind: MetalKind) -> Color {
        let (r, g, b, lum) = components(kind)
        return adjust(r: r, g: g, b: b, brightness: lum)
    }

    /// カプセル塗り用の金属グラデ(明→暗で立体感)。rainbow は別途 `isRainbow` で分岐。
    static func fillGradient(_ kind: MetalKind) -> LinearGradient {
        let (r, g, b, lum) = components(kind)
        let hi = adjust(r: r, g: g, b: b, brightness: lum + 0.10)
        let lo = adjust(r: r, g: g, b: b, brightness: lum - 0.10)
        return LinearGradient(colors: [hi, lo], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// rank11 の虹。角度グラデ(アニメは呼び出し側、reduceMotion で静止)。
    static let rainbowColors: [Color] = [
        Color(red: 1.00, green: 0.42, blue: 0.42),
        Color(red: 1.00, green: 0.80, blue: 0.42),
        Color(red: 0.55, green: 0.85, blue: 0.45),
        Color(red: 0.40, green: 0.78, blue: 0.95),
        Color(red: 0.62, green: 0.48, blue: 0.95),
        Color(red: 1.00, green: 0.42, blue: 0.42)
    ]

    static func isRainbow(_ kind: MetalKind) -> Bool { kind == .rainbow }

    /// (base R,G,B, 明度補正) — `+`/`-` は最後の値で ±0.08。
    private static func components(_ kind: MetalKind) -> (Double, Double, Double, Double) {
        switch kind {
        case .bronze:     return (0.80, 0.52, 0.25,  0.0)
        case .bronzePlus: return (0.80, 0.52, 0.25,  0.08)
        case .silver:     return (0.74, 0.76, 0.80,  0.0)
        case .silverPlus: return (0.74, 0.76, 0.80,  0.08)
        case .goldMinus:  return (1.00, 0.80, 0.42, -0.08)
        case .gold:       return (1.00, 0.80, 0.42,  0.0)
        case .goldPlus:   return (1.00, 0.80, 0.42,  0.08)
        case .platinum:   return (0.88, 0.90, 0.96,  0.0)
        case .rainbow:    return (1.00, 0.80, 0.42,  0.0) // baseColor フォールバック(通常は rainbow 分岐)
        }
    }

    /// 明度を ±delta して clamp。
    private static func adjust(r: Double, g: Double, b: Double, brightness delta: Double) -> Color {
        func c(_ v: Double) -> Double { min(1, max(0, v + delta)) }
        return Color(red: c(r), green: c(g), blue: c(b))
    }
}
```

- [ ] **Step 2: ビルド検証(本体)**

Run: `cd app/GOExercise && xcodegen generate >/dev/null && xcodebuild -project GOExercise.xcodeproj -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`(まだ消費元なしでもコンパイルは通る)

- [ ] **Step 3: コミット**

```bash
git add app/GOExercise/GOExercise/Models/MetalStyle.swift
git commit -m "feat(rank): MetalStyle で MetalKind→SwiftUI 色/グラデを追加"
```

---

## Phase 1: A 背景を `CatRank`(連続)駆動に作り替え

### Task 3: `MilestoneBackdropStyle` を `init(streak:)` 化(TDD・swiftc)

**Files:**
- Modify: `app/GOExercise/GOExercise/Models/MilestoneBackdropStyle.swift`
- Modify: `app/GOExercise/GOExerciseTests/MilestoneBackdropStyleTests.swift`
- Create (一時): `/tmp/BackdropHarness.swift`

- [ ] **Step 1: ハーネスで新仕様(streak 駆動)を書く**

`MilestoneBackdropStyle` を `MilestoneBackground`(削除予定)から切り離し、`CatRank` 駆動にする。`metalKind` を持たせて View が色帯を引けるようにする。

```swift
// /tmp/BackdropHarness.swift
// swiftc CatRank.swift MilestoneBackdropStyle.swift /tmp/BackdropHarness.swift -o /tmp/bd && /tmp/bd
import Foundation
func expect(_ c: Bool, _ m: String){ if !c { print("FAIL: \(m)"); exit(1) } }

let z = MilestoneBackdropStyle(streak: 0)
expect(z.rank == 0, "rank0"); expect(z.richness == 0, "rich0")
expect(z.glowOpacity == 0, "glow0"); expect(z.sparkleCount == 0, "spark0")
expect(z.animated == false, "anim0"); expect(z.metalKind == nil, "metal0")

let s7 = MilestoneBackdropStyle(streak: 7)
expect(s7.rank == 1, "rank1"); expect(s7.sparkleCount == 6, "spark 4+1*2"); expect(s7.animated == false, "anim1")
expect(s7.metalKind == .bronze, "metal bronze")

expect(MilestoneBackdropStyle(streak: 100).rank == 6, "rank6")
let y = MilestoneBackdropStyle(streak: 365)
expect(y.rank == 10, "rank10"); expect(y.animated, "anim365"); expect(y.metalKind == .platinum, "platinum")
let m = MilestoneBackdropStyle(streak: 500)
expect(m.rank == 11, "rank11"); expect(m.sparkleCount == 24, "spark cap"); expect(abs(m.richness-1)<0.0001, "rich1")
expect(m.animated, "anim500"); expect(m.metalKind == .rainbow, "rainbow")
print("ALL PASS")
```

- [ ] **Step 2: 実行して失敗を確認**

Run: `cd app/GOExercise/GOExercise/Models && swiftc CatRank.swift MilestoneBackdropStyle.swift /tmp/BackdropHarness.swift -o /tmp/bd 2>&1 | head`
Expected: 失敗(`init(streak:)`/`rank`/`metalKind` 未定義)。

- [ ] **Step 3: `MilestoneBackdropStyle.swift` を全置換**

```swift
// app/GOExercise/GOExercise/Models/MilestoneBackdropStyle.swift
import Foundation

/// 画面全体の達成背景パラメータ(純ロジック)。**現在の連続日数**駆動。
/// `CatRank` の rank/richness/metalKind を流用し、グラデ深さ・グロー・粒子数・最上位の微動を導出する。
struct MilestoneBackdropStyle: Equatable {
    /// 0..11。0 = 装飾なし。
    let rank: Int
    /// グラデの深さ 0..1。
    let richness: Double
    /// 中心グローの濃さ 0..1。
    let glowOpacity: Double
    /// きらめき粒子の数(0..24)。
    let sparkleCount: Int
    /// 最上位(rank>=10)のみ淡い光の帯をゆっくり動かす。
    let animated: Bool
    /// 色帯のメタル種別。rank0 は nil。
    let metalKind: MetalKind?

    init(streak: Int) {
        let r = CatRank(currentStreak: streak)
        self.rank = r.rank
        self.richness = r.richness
        // 3LLM検証: 365/500 の黄色が眩しすぎる指摘を反映し控えめに。
        self.glowOpacity = r.richness * 0.42
        self.sparkleCount = r.rank == 0 ? 0 : min(4 + r.rank * 2, 24)
        self.animated = r.rank >= 10
        self.metalKind = r.metalKind
    }
}
```

- [ ] **Step 4: swiftc で PASS を確認**

Run: `cd app/GOExercise/GOExercise/Models && swiftc CatRank.swift MilestoneBackdropStyle.swift /tmp/BackdropHarness.swift -o /tmp/bd && /tmp/bd`
Expected: `ALL PASS`

- [ ] **Step 5: XCTest を書き換え**

`app/GOExercise/GOExerciseTests/MilestoneBackdropStyleTests.swift` を全置換:

```swift
import XCTest
@testable import GOExercise

final class MilestoneBackdropStyleTests: XCTestCase {
    func test_zeroStreak_isPlain() {
        let s = MilestoneBackdropStyle(streak: 0)
        XCTAssertEqual(s.rank, 0)
        XCTAssertEqual(s.richness, 0, accuracy: 0.0001)
        XCTAssertEqual(s.glowOpacity, 0, accuracy: 0.0001)
        XCTAssertEqual(s.sparkleCount, 0)
        XCTAssertFalse(s.animated)
        XCTAssertNil(s.metalKind)
    }
    func test_sevenStreak_rank1() {
        let s = MilestoneBackdropStyle(streak: 7)
        XCTAssertEqual(s.rank, 1)
        XCTAssertEqual(s.sparkleCount, 6) // 4 + 1*2
        XCTAssertFalse(s.animated)
        XCTAssertEqual(s.metalKind, .bronze)
    }
    func test_hundredStreak_rank6() {
        XCTAssertEqual(MilestoneBackdropStyle(streak: 100).rank, 6)
    }
    func test_yearStreak_animated() {
        let s = MilestoneBackdropStyle(streak: 365)
        XCTAssertEqual(s.rank, 10)
        XCTAssertTrue(s.animated)
        XCTAssertEqual(s.metalKind, .platinum)
    }
    func test_maxStreak_sparkleCapped() {
        let s = MilestoneBackdropStyle(streak: 500)
        XCTAssertEqual(s.rank, 11)
        XCTAssertEqual(s.sparkleCount, 24) // min(4+11*2, 24)
        XCTAssertEqual(s.richness, 1, accuracy: 0.0001)
        XCTAssertTrue(s.animated)
        XCTAssertEqual(s.metalKind, .rainbow)
    }
}
```

- [ ] **Step 6: コミット**(View は次タスクで合わせるのでまだビルド未確認 — このコミットは純ロジック+テストのみ)

```bash
git add app/GOExercise/GOExercise/Models/MilestoneBackdropStyle.swift app/GOExercise/GOExerciseTests/MilestoneBackdropStyleTests.swift
git commit -m "refactor(backdrop): MilestoneBackdropStyle を CatRank(連続)駆動に変更 + metalKind 追加"
```

---

### Task 4: `MilestoneBackdrop` View を streak/rank 駆動に作り替え(A)

**Files:**
- Modify: `app/GOExercise/GOExercise/Views/Components/MilestoneBackdrop.swift`
- Modify: `app/GOExercise/GOExercise/Views/HomeView.swift:35`(呼び出しを streak 引数へ)

設計(spec A): 色帯を `rank.metalKind` 系統に、richness で濃さ。粒子=`sparkleCount`。時間帯トーン(朝/昼/夜)を ~6% かぶせる。rank>=10 で光帯、rank==11 でゴッドレイ+虹の微反射。`allowsHitTesting(false)`/`accessibilityHidden(true)`、reduceMotion で粒子/光帯静止。

- [ ] **Step 1: `MilestoneBackdrop.swift` を全置換**

```swift
// app/GOExercise/GOExercise/Views/Components/MilestoneBackdrop.swift
import SwiftUI

/// 画像カード(旧 `MilestoneBackgroundView`)を廃し、**現在の連続日数**で段階的に
/// 豪華になるコード背景。色帯は rank のメタル系統、richness で濃さ。粒子・時間帯
/// トーン・最上位の光を重ねる。装飾専用なので hitTesting/VoiceOver から完全に外す。
struct MilestoneBackdrop: View {
    let streak: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var style: MilestoneBackdropStyle { MilestoneBackdropStyle(streak: streak) }

    /// 色帯の基準色。rank0 は背景テーマのみ。
    private var bandColor: Color {
        guard let kind = style.metalKind else { return .clear }
        if MetalStyle.isRainbow(kind) { return Color(red: 1.0, green: 0.80, blue: 0.42) }
        return MetalStyle.baseColor(kind)
    }

    /// 時間帯トーン(暖→昼白→紺)を ~6% かぶせる。
    private var timeTone: Color {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return Color(red: 1.0, green: 0.85, blue: 0.6)   // 朝 暖
        case 11..<17: return Color.white                                // 昼 白
        default:      return Color(red: 0.20, green: 0.24, blue: 0.45)  // 夜 紺
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Palette.background

                // 1. メタル色帯(richness で濃さ)
                if style.rank > 0 {
                    LinearGradient(
                        colors: [
                            bandColor.opacity(0.07 * style.richness),
                            bandColor.opacity(0.30 * style.richness)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                }

                // 2. 中心グロー
                if style.glowOpacity > 0 {
                    RadialGradient(
                        colors: [bandColor.opacity(style.glowOpacity), .clear],
                        center: UnitPoint(x: 0.5, y: 0.34),
                        startRadius: 0, endRadius: geo.size.width * 0.72
                    )
                }

                // 3. 時間帯トーン(全体に淡く)
                timeTone.opacity(0.06).blendMode(.plusLighter)

                // 4. 粒子(reduceMotion で静止)
                if style.sparkleCount > 0 {
                    if reduceMotion {
                        ForEach(0..<style.sparkleCount, id: \.self) { i in
                            staticSparkle(i, size: geo.size)
                        }
                    } else {
                        TimelineView(.animation(minimumInterval: 0.2, paused: false)) { ctx in
                            let t = ctx.date.timeIntervalSinceReferenceDate
                            ForEach(0..<style.sparkleCount, id: \.self) { i in
                                sparkle(i, t: t, size: geo.size)
                            }
                        }
                    }
                }

                // 5. 最上位の光帯(rank>=10)。reduceMotion で静止。
                if style.animated {
                    if reduceMotion {
                        movingBand(t: 0, size: geo.size)
                    } else {
                        TimelineView(.animation(minimumInterval: 0.2, paused: false)) { ctx in
                            movingBand(t: ctx.date.timeIntervalSinceReferenceDate, size: geo.size)
                        }
                    }
                }

                // 6. rank11 のゴッドレイ + 虹の微反射
                if style.rank >= 11 {
                    godRays(size: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // 決定論的な粒子位置(再描画でちらつかない)
    private func sparklePosition(_ i: Int, size: CGSize) -> CGPoint {
        let x = Double((i &* 2_654_435_761) % 997) / 997.0
        let y = Double((i &* 40_503 &+ 12_345) % 991) / 991.0
        return CGPoint(x: x * size.width, y: y * size.height)
    }
    private func sparkle(_ i: Int, t: TimeInterval, size: CGSize) -> some View {
        let pos = sparklePosition(i, size: size)
        let phase = Double(i) * 0.7
        let op = 0.28 + 0.42 * (0.5 + 0.5 * sin(t * 1.1 + phase))
        let s = CGFloat(6 + (i % 4) * 3)
        return Image(systemName: "sparkle")
            .font(.system(size: s)).foregroundStyle(bandColor.opacity(op)).position(pos)
    }
    private func staticSparkle(_ i: Int, size: CGSize) -> some View {
        let pos = sparklePosition(i, size: size)
        let s = CGFloat(6 + (i % 4) * 3)
        return Image(systemName: "sparkle")
            .font(.system(size: s)).foregroundStyle(bandColor.opacity(0.45)).position(pos)
    }
    private func movingBand(t: TimeInterval, size: CGSize) -> some View {
        let period = 26.0
        let p = (t.truncatingRemainder(dividingBy: period)) / period
        let travel = size.width * 1.8
        return RoundedRectangle(cornerRadius: 240)
            .fill(LinearGradient(colors: [.clear, bandColor.opacity(0.10), .clear],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: travel, height: size.height * 0.55)
            .rotationEffect(.degrees(-20))
            .position(x: -travel * 0.4 + travel * p, y: size.height * 0.34)
            .blendMode(.plusLighter)
    }
    // rank11: 中心から放射する淡いレイ + 虹の微反射(静止・上品に)
    private func godRays(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: 80)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.06), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: size.width * 0.10, height: size.height * 0.9)
                    .rotationEffect(.degrees(Double(i) * 45))
                    .position(x: size.width * 0.5, y: size.height * 0.34)
            }
            AngularGradient(colors: MetalStyle.rainbowColors, center: UnitPoint(x: 0.5, y: 0.34))
                .opacity(0.05).blendMode(.plusLighter)
        }
    }
}
```

- [ ] **Step 2: `HomeView.swift:35` の呼び出しを streak 引数に変更**

`HomeView.swift` の `MilestoneBackdrop(totalAchievedDays: viewModel.lifetimeStats.achievedDays)` を:

```swift
                MilestoneBackdrop(streak: viewModel.streak.currentStreak)
                    .ignoresSafeArea()
```

に置換(背骨が累計→連続に変わる意味変更)。

- [ ] **Step 3: ビルド検証**

Run: `cd app/GOExercise && xcodegen generate >/dev/null && xcodebuild -project GOExercise.xcodeproj -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: コミット**

```bash
git add app/GOExercise/GOExercise/Views/Components/MilestoneBackdrop.swift app/GOExercise/GOExercise/Views/HomeView.swift
git commit -m "feat(A): MilestoneBackdrop を連続ランク駆動に(色帯/時間帯/最上位光)"
```

---

## Phase 2: 撤去(emblem / MilestoneItem / MilestoneBackground / 画像背景 / CatDecoration)

> このフェーズは「`CatRank` 移行が済んだ消費元」から順に dead code を消す。各コミットでビルド green を保つ。

### Task 5: 頭上バッジ `CatDecorationEmblem` を撤去

**Files:**
- Modify: `app/GOExercise/GOExercise/Views/HomeView.swift`(BigCatView の overlay と `decoration` パラメータ)
- Modify: `app/GOExercise/GOExercise/Views/RecordCompletionView.swift:73-74`
- Delete: `app/GOExercise/GOExercise/Views/Components/CatDecorationEmblem.swift`

- [ ] **Step 1: `BigCatView` の emblem overlay を削除**

`HomeView.swift:528-533` の以下ブロックを削除:

```swift
        .overlay(alignment: .top) {
            // 達成段階エンブレムを頭上に浮かせる(猫の体/顔には描かない=焼き込み装飾と非干渉)。
            // 顔/手に被らないよう十分上へ(3LLMスクショ検証: 顔被り指摘を反映)。
            CatDecorationEmblem(decoration: decoration)
                .offset(y: -18)
        }
```

- [ ] **Step 2: `BigCatView` の `decoration` プロパティを削除**

`HomeView.swift:497` の `var decoration: CatDecoration = .none` を削除。

- [ ] **Step 3: `HomeView.swift:214-215` の call site を修正**

```swift
            BigCatView(state: viewModel.catState)
                .frame(width: 280, height: 280)
```

(`decoration:` 引数を除去)

- [ ] **Step 4: `RecordCompletionView.swift:73-74` の call site を修正**

```swift
            BigCatView(state: streakExtendedThisRun ? .streakExtended : .celebrating)
```

(`decoration:` 引数行を除去。`lifetimeAchievedDays` がこれで未使用になるなら、その computed プロパティも削除 — Step 5 で確認)

- [ ] **Step 5: 不要になった `lifetimeAchievedDays` を確認・削除**

Run: `grep -n "lifetimeAchievedDays" app/GOExercise/GOExercise/Views/RecordCompletionView.swift`
他に参照が無ければ `private var lifetimeAchievedDays: Int {...}` を削除。参照があれば残す。

- [ ] **Step 6: ファイル削除**

```bash
rm app/GOExercise/GOExercise/Views/Components/CatDecorationEmblem.swift
```

- [ ] **Step 7: ビルド検証**

Run: `cd app/GOExercise && xcodegen generate >/dev/null && xcodebuild -project GOExercise.xcodeproj -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: コミット**

```bash
git add -A
git commit -m "refactor(cleanup): 頭上バッジ CatDecorationEmblem と BigCatView.decoration を撤去"
```

---

### Task 6: `MilestoneBackgroundView`(未使用画像背景 View)と画像アセットを撤去

**Files:**
- Delete: `app/GOExercise/GOExercise/Views/Components/MilestoneBackgroundView.swift`
- Delete: `app/GOExercise/GOExercise/Resources/Assets.xcassets/Milestones/`(bg_milestone_01..11 + Milestones グループ)

- [ ] **Step 1: 参照が無いことを再確認**

Run: `grep -rn "MilestoneBackgroundView\|bg_milestone" $(find app/GOExercise -name '*.swift')`
Expected: マッチ無し(View 定義ファイル自身を除く)。

- [ ] **Step 2: 削除**

```bash
rm app/GOExercise/GOExercise/Views/Components/MilestoneBackgroundView.swift
rm -rf app/GOExercise/GOExercise/Resources/Assets.xcassets/Milestones
```

- [ ] **Step 3: ビルド検証 + iCloud 重複チェック**

Run: `cd app/GOExercise && find build -name "* [0-9].*" -delete 2>/dev/null; xcodegen generate >/dev/null && xcodebuild -project GOExercise.xcodeproj -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: コミット**

```bash
git add -A
git commit -m "refactor(cleanup): 未使用の MilestoneBackgroundView と bg_milestone 画像11枚を撤去"
```

---

### Task 7: `MilestoneItem`/`MilestoneBackground`(`MilestoneStyle.swift`)を撤去し widget 共有を外す

**Files:**
- Modify: `app/GOExercise/GOExercise/Models/CatBreed.swift`(`avatarAssetName(totalAchievedDays:)` 削除)
- Delete: `app/GOExercise/GOExercise/Models/MilestoneStyle.swift`
- Delete: `app/GOExercise/GOExerciseTests/MilestoneStyleTests.swift`
- Modify: `app/GOExercise/project.yml`(widget 共有から `MilestoneStyle.swift` 行を除去)
- Delete: アセット `CatCharacter/cat_orange_waitingMorning_crown.imageset`

- [ ] **Step 1: `CatBreed.avatarAssetName(totalAchievedDays:)` を削除**

`app/GOExercise/GOExercise/Models/CatBreed.swift:69-72` 付近の以下を削除(唯一の消費元はテストのみ):

```swift
    func avatarAssetName(totalAchievedDays days: Int) -> String {
        let suffix = MilestoneItem(totalAchievedDays: days).assetSuffix
        return "cat_\(rawValue)_waitingMorning\(suffix)"
    }
```

(プレーンな `var avatarAssetName: String` は計画③で使うので残す)

- [ ] **Step 2: `project.yml` から widget 共有の `MilestoneStyle.swift` を除去**

`app/GOExercise/project.yml:98` の行を削除:

```yaml
      - path: GOExercise/Models/MilestoneStyle.swift
```

(widget はこの型を使っていない。調査で確認済み)

- [ ] **Step 3: ファイル削除**

```bash
rm app/GOExercise/GOExercise/Models/MilestoneStyle.swift
rm app/GOExercise/GOExerciseTests/MilestoneStyleTests.swift
rm -rf app/GOExercise/GOExercise/Resources/Assets.xcassets/CatCharacter/cat_orange_waitingMorning_crown.imageset
```

> 注: `cat_orange_waitingMorning_shaker.imageset` は **削除しない**(計画③シェイカー猫の種)。

- [ ] **Step 4: 残参照が無いことを確認**

Run: `grep -rn "MilestoneItem\|MilestoneBackground\b\|waitingMorning_crown" $(find app/GOExercise -name '*.swift')`
Expected: マッチ無し。

- [ ] **Step 5: ビルド検証(本体 + widget)**

Run: `cd app/GOExercise && find build -name "* [0-9].*" -delete 2>/dev/null; xcodegen generate >/dev/null && xcodebuild -project GOExercise.xcodeproj -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`(widget ターゲットも本体ビルドに含まれる構成。念のため widget scheme があれば併せて build)

- [ ] **Step 6: Info.plist 手動キーが残っているか確認(xcodegen gotcha)**

Run: `/usr/libexec/PlistBuddy -c "Print :FriendsAppleLinkEnabled" app/GOExercise/GOExercise/Resources/Info.plist; /usr/libexec/PlistBuddy -c "Print :TelemetryDeckAppID" app/GOExercise/GOExercise/Resources/Info.plist`
Expected: 両キーが存在(project.yml 由来なので落ちないはずだが確認)。落ちていたら復元してから次へ。

- [ ] **Step 7: コミット**

```bash
git add -A
git commit -m "refactor(cleanup): MilestoneItem/MilestoneBackground 撤去(thresholds は CatRank へ)+ widget 共有解除 + crown アセット削除"
```

---

### Task 8: `CatDecoration` を撤去し残りの消費元を `CatRank` 化(F の足場)

> `FriendProfile.decoration`/`FriendDetailView`/`HomeView` publish/`FriendsStoreTests` が `CatDecoration` を使う。F(Task 12-14)で `RankBadge` 表示に置換するが、まず `CatDecoration` 型自体を消すために publish/computed を `CatRank` に移しておく。

**Files:**
- Modify: `app/GOExercise/GOExercise/Models/FriendProfile.swift`
- Modify: `app/GOExercise/GOExercise/Views/HomeView.swift:440,454,469`
- Delete: `app/GOExercise/GOExercise/Models/CatDecoration.swift`

- [ ] **Step 1: `FriendProfile.decoration` を `rank` に置換**

`FriendProfile.swift:43-52` の `var decoration: CatDecoration {...}` を以下に置換:

```swift
    /// 友達の称号 = 現在の連続から算出(バックエンド変更なし。spec F)。
    var rank: CatRank { CatRank(currentStreak: currentStreak) }
```

`decorationTier`(stored, 0..11 を publish)は温存(コメントを 0..11 に更新):

```swift
    var decorationTier: Int             // publish 値 = CatRank.rank (0..11)。表示は computed rank を使用。
```

- [ ] **Step 2: `HomeView` publish を `CatRank.rank` に変更**

`HomeView.swift:440`:

```swift
        let tier = CatRank(currentStreak: streak).rank
```

(`streak` は同関数内 line 435 の `viewModel.streak.currentStreak`。以後 `current.decorationTier == tier`(454)/`updated.decorationTier = tier`(469)はそのまま動作 — 値の意味が 0..4→0..11 に変わるだけ)

- [ ] **Step 3: ファイル削除**

```bash
rm app/GOExercise/GOExercise/Models/CatDecoration.swift
```

- [ ] **Step 4: コンパイルエラー箇所を一掃**

Run: `grep -rn "CatDecoration" $(find app/GOExercise -name '*.swift')`
残箇所:
- `FriendDetailView.swift:94-103`(decoration emoji/displayName チップ)→ Task 13 で `RankBadge` に置換するが、ビルドを通すため**一旦** `if friend.rank.rank > 0 { Text(friend.rank.title ?? "") ... }` の仮実装にする(Task 13 で本実装):

```swift
            if friend.rank.rank > 0, let title = friend.rank.title {
                HStack(spacing: 6) {
                    Image(systemName: friend.rank.iconSymbol)
                    Text(title)
                }
                .font(Typography.caption)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(tierColor.opacity(0.18), in: Capsule())
                .foregroundStyle(tierColor)
            }
```

- `FriendsStoreTests.swift:455-471` → Task 14 で書き換え。ビルド(本体)には影響しないが、**テストターゲットのコンパイル**には影響する。本タスクのビルド確認は本体 scheme のみ行い、テストは Task 14 完了後に通す。

- [ ] **Step 5: 本体ビルド検証**

Run: `cd app/GOExercise && xcodegen generate >/dev/null && xcodebuild -project GOExercise.xcodeproj -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: コミット**

```bash
git add -A
git commit -m "refactor(F足場): CatDecoration 撤去 → FriendProfile.rank(currentStreak)化・publish を CatRank.rank に"
```

---

## Phase 3: C メタリック称号バッジ `RankBadge`

### Task 9: `RankBadge` コンポーネント(昇格 shimmer/pop・VoiceOver)

**Files:**
- Create: `app/GOExercise/GOExercise/Views/Components/RankBadge.swift`

UIUX 指針(skill 反映): メタリックは Liquid-glass 風の上品なグラデ + 細フチ。チープ厳禁。micro-interaction(pop)150-300ms、shimmer 一度だけ斜めハイライト。VoiceOver「称号 ◯◯ネコ」。reduceMotion で shimmer/pop 静止。タップ要素ではない(表示専用)。

- [ ] **Step 1: `RankBadge.swift` を実装**

```swift
// app/GOExercise/GOExercise/Views/Components/RankBadge.swift
import SwiftUI

/// メタリックな称号カプセル。`CatRank` 駆動。rank0(連続7日未満)は何も描かない。
/// `animateShimmer` を true にすると、表示時に斜めハイライトが一度流れ + 軽い pop。
struct RankBadge: View {
    let rank: CatRank
    /// 昇格直後など、初表示で shimmer/pop を一度だけ流すか。
    var animateShimmer: Bool = false
    var compact: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerX: CGFloat = -1.0
    @State private var popped = false

    var body: some View {
        if rank.rank > 0, let title = rank.title, let metal = rank.metalKind {
            content(title: title, metal: metal)
                .scaleEffect(popped ? 1.0 : (animateShimmer && !reduceMotion ? 0.92 : 1.0))
                .onAppear { runEntranceIfNeeded() }
                .accessibilityElement()
                .accessibilityLabel("称号 \(title)")
        }
    }

    @ViewBuilder
    private func content(title: String, metal: MetalKind) -> some View {
        let fill: AnyShapeStyle = MetalStyle.isRainbow(metal)
            ? AnyShapeStyle(AngularGradient(colors: MetalStyle.rainbowColors, center: .center))
            : AnyShapeStyle(MetalStyle.fillGradient(metal))

        HStack(spacing: 5) {
            Image(systemName: rank.iconSymbol)
                .font(.system(size: compact ? 10 : 12, weight: .bold))
                .accessibilityHidden(true)
            Text(title)
                .font(.system(compact ? .caption2 : .footnote, design: .rounded, weight: .heavy))
        }
        .foregroundStyle(Color.black.opacity(0.78)) // メタル地に黒文字でコントラスト確保(WCAG)
        .padding(.horizontal, compact ? 8 : 11)
        .padding(.vertical, compact ? 4 : 6)
        .background {
            Capsule()
                .fill(fill)
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.55), lineWidth: 0.75) // 金属フチ
                )
                .overlay(shimmerOverlay) // 斜めハイライト
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { geo in
            Capsule()
                .fill(LinearGradient(
                    colors: [.clear, .white.opacity(0.65), .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: geo.size.width * 0.5)
                .offset(x: shimmerX * geo.size.width)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .clipShape(Capsule())
    }

    private func runEntranceIfNeeded() {
        guard animateShimmer, !reduceMotion else { popped = true; return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { popped = true } // pop ~280ms
        withAnimation(.easeInOut(duration: 0.55)) { shimmerX = 1.0 } // shimmer 一度流す
    }
}
```

- [ ] **Step 2: ビルド検証**

Run: `cd app/GOExercise && xcodegen generate >/dev/null && xcodebuild -project GOExercise.xcodeproj -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: コミット**

```bash
git add app/GOExercise/GOExercise/Views/Components/RankBadge.swift
git commit -m "feat(C): RankBadge メタリック称号カプセル(昇格 shimmer/pop・VoiceOver)"
```

---

### Task 10: `RankBadge` を Home の連続チップ隣に配置(C)

**Files:**
- Modify: `app/GOExercise/GOExercise/Views/HomeView.swift`(`topStatusBar`)

spec C: 「○日連続」チップの**隣**に称号バッジ。rank0 は非表示(RankBadge 内で自動)。

- [ ] **Step 1: `topStatusBar` に `RankBadge` を挿入**

`HomeView.swift:173-182` を:

```swift
    private var topStatusBar: some View {
        HStack(spacing: 8) {
            StreakBadgeView(streak: viewModel.streak.currentStreak) {
                guard viewModel.streak.currentStreak > 0 else { return }
                isShowingStreakShare = true
            }
            RankBadge(rank: CatRank(currentStreak: viewModel.streak.currentStreak))
            Spacer()
            statusChip
        }
    }
```

に置換(`StreakBadgeView` の右に `RankBadge`。`compact` 既定 false で連続チップと同高さ感)。

- [ ] **Step 2: ビルド検証**

Run: `cd app/GOExercise && xcodebuild -project GOExercise.xcodeproj -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: コミット**

```bash
git add app/GOExercise/GOExercise/Views/HomeView.swift
git commit -m "feat(C): ホーム topStatusBar に RankBadge を配置(連続チップ隣)"
```

---

## Phase 4: B 小節目の瞬間演出(`RankUpDetector` + `fireLight` + 称号トースト)

### Task 11: `RankUpDetector` 純ロジック(昇格/週次の検出・TDD swiftc)

**Files:**
- Create: `app/GOExercise/GOExercise/Services/RankUpDetector.swift`
- Create (一時): `/tmp/RankUpHarness.swift`
- Create: `app/GOExercise/GOExerciseTests/RankUpDetectorTests.swift`

設計(spec B 検出): 前回 rank と前回「週次マイルストーン(連続7の倍数)」を `UserDefaults` に保持。`evaluate(currentStreak:)` が、(a) rank が上がっていれば `.rankUp(to:)`、(b) 連続が新しい7の倍数に達していれば `.weekly(streak:)` を返す(両方該当も可)。**リセット後の再上昇でも再発火**(前回値を下回ったら追従して下げる)。純ロジック=`UserDefaults(suiteName:)` を注入可能にして swiftc 実行可能。

- [ ] **Step 1: ハーネスを書く**

```swift
// /tmp/RankUpHarness.swift
// swiftc ../Models/CatRank.swift RankUpDetector.swift /tmp/RankUpHarness.swift -o /tmp/ru && /tmp/ru
import Foundation
func expect(_ c: Bool, _ m: String){ if !c { print("FAIL: \(m)"); exit(1) } }

let suite = "ru.test.\(UUID().uuidString)"
let d = UserDefaults(suiteName: suite)!
let det = RankUpDetector(defaults: d)

// 初回 streak 7: rank 0->1 昇格 かつ 週次7
var ev = det.evaluate(currentStreak: 7)
expect(ev.contains(.rankUp(to: 1)), "first rankUp to 1")
expect(ev.contains(.weekly(streak: 7)), "weekly 7")

// 同じ 7 で再評価 → 何も出ない(消化済み)
ev = det.evaluate(currentStreak: 7)
expect(ev.isEmpty, "no refire on same streak")

// 8..13 → 変化なし
expect(det.evaluate(currentStreak: 10).isEmpty, "10 nothing")

// 14: 週次14 かつ rank 1->2
ev = det.evaluate(currentStreak: 14)
expect(ev.contains(.rankUp(to: 2)), "rankUp 2")
expect(ev.contains(.weekly(streak: 14)), "weekly 14")

// リセット: streak 0 → 演出は出さない(降格はサイレント)。内部状態は下がる。
expect(det.evaluate(currentStreak: 0).isEmpty, "reset silent")

// 再上昇 7 → 再び rankUp to 1 + weekly 7(再発火)
ev = det.evaluate(currentStreak: 7)
expect(ev.contains(.rankUp(to: 1)), "refire rankUp after reset")
expect(ev.contains(.weekly(streak: 7)), "refire weekly after reset")

// 週次のみ(rank 跨がない): 例 rank3=30..49 内の 35,42
_ = det.evaluate(currentStreak: 30) // rank3 + weekly? 30 は7の倍数でない
ev = det.evaluate(currentStreak: 35) // 35 = 7*5、rank 変わらず
expect(ev.contains(.weekly(streak: 35)), "weekly only 35")
expect(!ev.contains(where: { if case .rankUp = $0 { return true } else { return false } }), "no rankUp at 35")
print("ALL PASS")
```

- [ ] **Step 2: 失敗を確認**

Run: `cd app/GOExercise/GOExercise/Services && swiftc ../Models/CatRank.swift RankUpDetector.swift /tmp/RankUpHarness.swift -o /tmp/ru 2>&1 | head`
Expected: 失敗(未定義)。

- [ ] **Step 3: `RankUpDetector.swift` を実装(Foundation のみ)**

```swift
// app/GOExercise/GOExercise/Services/RankUpDetector.swift
import Foundation

/// 小節目(minor)イベント。割り込まない軽量演出のトリガ。
enum RankUpEvent: Equatable {
    case rankUp(to: Int)       // CatRank 閾値を跨いで上がった
    case weekly(streak: Int)   // 連続が新しい7の倍数に達した(大節目に未該当時)
}

/// 前回 rank と前回処理済み週次を `UserDefaults` に保持し、上昇分のみ返す純ロジック。
/// リセット(連続0)後の再上昇でも再発火する(保存値が現在値を上回ったら追従して下げる)。
struct RankUpDetector {
    private let defaults: UserDefaults
    private let rankKey = "rankup.lastRank"
    private let weeklyKey = "rankup.lastWeeklyMultiple" // 直近で発火した「7の倍数」値

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// 現在の連続日数を渡し、発火すべき小節目イベント群を返す。状態は副作用で更新。
    func evaluate(currentStreak: Int) -> [RankUpEvent] {
        var events: [RankUpEvent] = []
        let streak = max(0, currentStreak)
        let newRank = CatRank(currentStreak: streak).rank
        let lastRank = defaults.object(forKey: rankKey) as? Int ?? 0

        // rank 上昇(1段ずつでなく最終 rank を1イベントで通知。複数跨ぎは to=newRank)
        if newRank > lastRank {
            events.append(.rankUp(to: newRank))
        }
        if newRank != lastRank {
            defaults.set(newRank, forKey: rankKey) // 上昇・下降どちらも追従
        }

        // 週次(7の倍数)。直近発火値より大きい最新の倍数なら発火。リセットで下がったら追従。
        let currentMultiple = (streak / 7) * 7 // 7未満は0
        let lastMultiple = defaults.object(forKey: weeklyKey) as? Int ?? 0
        if currentMultiple >= 7, currentMultiple > lastMultiple {
            events.append(.weekly(streak: currentMultiple))
        }
        if currentMultiple != lastMultiple {
            defaults.set(currentMultiple, forKey: weeklyKey)
        }
        return events
    }

    /// テスト/ログアウト用リセット。
    func reset() {
        defaults.removeObject(forKey: rankKey)
        defaults.removeObject(forKey: weeklyKey)
    }
}
```

- [ ] **Step 4: swiftc で PASS を確認**

Run: `cd app/GOExercise/GOExercise/Services && swiftc ../Models/CatRank.swift RankUpDetector.swift /tmp/RankUpHarness.swift -o /tmp/ru && /tmp/ru`
Expected: `ALL PASS`

- [ ] **Step 5: XCTest を追加**

```swift
// app/GOExercise/GOExerciseTests/RankUpDetectorTests.swift
import XCTest
@testable import GOExercise

final class RankUpDetectorTests: XCTestCase {
    private func makeDetector() -> (RankUpDetector, UserDefaults) {
        let d = UserDefaults(suiteName: "rankup.test.\(UUID().uuidString)")!
        return (RankUpDetector(defaults: d), d)
    }
    func test_firstRankUpAndWeekly() {
        let (det, _) = makeDetector()
        let ev = det.evaluate(currentStreak: 7)
        XCTAssertTrue(ev.contains(.rankUp(to: 1)))
        XCTAssertTrue(ev.contains(.weekly(streak: 7)))
    }
    func test_noRefireOnSameStreak() {
        let (det, _) = makeDetector()
        _ = det.evaluate(currentStreak: 7)
        XCTAssertTrue(det.evaluate(currentStreak: 7).isEmpty)
    }
    func test_refireAfterReset() {
        let (det, _) = makeDetector()
        _ = det.evaluate(currentStreak: 14)
        XCTAssertTrue(det.evaluate(currentStreak: 0).isEmpty) // reset silent
        let ev = det.evaluate(currentStreak: 7)
        XCTAssertTrue(ev.contains(.rankUp(to: 1)))
        XCTAssertTrue(ev.contains(.weekly(streak: 7)))
    }
    func test_weeklyOnlyWhenRankUnchanged() {
        let (det, _) = makeDetector()
        _ = det.evaluate(currentStreak: 30) // rank3
        let ev = det.evaluate(currentStreak: 35) // weekly only
        XCTAssertTrue(ev.contains(.weekly(streak: 35)))
        XCTAssertFalse(ev.contains { if case .rankUp = $0 { return true } else { return false } })
    }
}
```

- [ ] **Step 6: コミット**

```bash
git add app/GOExercise/GOExercise/Services/RankUpDetector.swift app/GOExercise/GOExerciseTests/RankUpDetectorTests.swift
git commit -m "feat(B): RankUpDetector 小節目(昇格/週次)検出(純ロジック・リセット再発火)"
```

---

### Task 12: `CelebrationCenter.fireLight()` + 称号トーストオーバーレイ(B)

**Files:**
- Modify: `app/GOExercise/GOExercise/Services/CelebrationCenter.swift`(`fireLight()` 追加)
- Create: `app/GOExercise/GOExercise/Views/Components/RankCelebrationOverlay.swift`
- Modify: `app/GOExercise/GOExercise/Views/HomeView.swift`(RankUp 評価 + オーバーレイ提示 + 大節目との二重抑止)

spec B: 小節目 = フルシート無しの軽量オーバーレイ(光のさざ波 + ハプティクス + 称号 shimmer + 称号トースト。上から短く降りて自動で消える)。大節目シートが同日に出る時は小節目を抑止。

- [ ] **Step 1: `CelebrationCenter.fireLight()` を追加**

`CelebrationCenter.swift` の `final class` 内に追記(既存 `fire(_:)` はハプティクス。`fireLight` は軽量=subtle ハプティクスのみ):

```swift
    /// 小節目(minor)用。シート無しの軽量演出。ハプティクスのみ鳴らし、
    /// 視覚演出(さざ波/称号トースト)は呼び出し側の RankCelebrationOverlay が担う。
    func fireLight() {
        fire(.subtle)
    }
```

(`fire(_:)` の既存シグネチャに合わせる。`CelebrationLevel.subtle` は既存)

- [ ] **Step 2: `RankCelebrationOverlay.swift` を実装**

```swift
// app/GOExercise/GOExercise/Views/Components/RankCelebrationOverlay.swift
import SwiftUI

/// 小節目(minor)の軽量オーバーレイ。割り込まない(タップ透過)。
/// 上から称号トーストが短く降り、光のさざ波が一度走り、自動で消える。
struct RankCelebrationOverlay: View {
    /// 表示する称号ランク(昇格後 or 週次時点の現在ランク)。
    let rank: CatRank
    /// トーストの上書きコピー(週次など)。nil なら「称号 ◯◯ネコ 達成!」。
    var message: String?
    /// 演出完了時に呼ばれる(呼び出し側で表示フラグを下ろす)。
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dropIn = false
    @State private var rippleScale: CGFloat = 0.2
    @State private var rippleOpacity: Double = 0.0

    var body: some View {
        ZStack(alignment: .top) {
            // 光のさざ波(中央から淡く広がって消える)
            Circle()
                .stroke(rippleColor, lineWidth: 3)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
                .frame(width: 160, height: 160)
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height * 0.34)
                .allowsHitTesting(false)

            // 称号トースト(上から降りる)
            toast
                .offset(y: dropIn ? 8 : -80)
                .opacity(dropIn ? 1 : 0)
        }
        .allowsHitTesting(false)
        .onAppear { run() }
    }

    private var rippleColor: Color {
        guard let metal = rank.metalKind else { return .white }
        return MetalStyle.isRainbow(metal) ? Color(red: 1, green: 0.8, blue: 0.42) : MetalStyle.baseColor(metal)
    }

    private var toast: some View {
        HStack(spacing: 8) {
            RankBadge(rank: rank, animateShimmer: true)
            Text(message ?? "達成!")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("称号 \(rank.title ?? "") を達成")
    }

    private func run() {
        if reduceMotion {
            // 動きは出さず、短時間表示してから消す。
            dropIn = true; rippleOpacity = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { onFinished() }
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { dropIn = true }
        withAnimation(.easeOut(duration: 0.8)) { rippleScale = 1.6; rippleOpacity = 0.0 }
        // ripple は 0→可視→0 を手動で(opacity を一瞬上げる)
        withAnimation(.easeOut(duration: 0.1)) { rippleOpacity = 0.7 }
        withAnimation(.easeOut(duration: 0.8).delay(0.1)) { rippleOpacity = 0.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.3)) { dropIn = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { onFinished() }
    }
}
```

- [ ] **Step 3: `HomeView` に RankUp 評価 + オーバーレイ状態を追加**

`HomeView` 構造体の state に追加(他の `@State` 近く、例 line 27 付近):

```swift
    @State private var pendingRankEvent: RankUpEvent? = nil
    private let rankUpDetector = RankUpDetector()
```

ZStack の最前面(`AmbientParticlesView` より後ろでも前でも可だが、トーストは最前面が良い)に、`MilestoneCelebrationSheet` の sheet 修飾子と同階層でオーバーレイを追加。`body` の `ZStack { ... }` の末尾付近に:

```swift
                if let event = pendingRankEvent {
                    RankCelebrationOverlay(
                        rank: rankForEvent(event),
                        message: messageForEvent(event),
                        onFinished: { pendingRankEvent = nil }
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }
```

ヘルパを `HomeView` に追加:

```swift
    private func rankForEvent(_ event: RankUpEvent) -> CatRank {
        switch event {
        case .rankUp(let to): return CatRank(currentStreak: CatRank.thresholds[max(0, to - 1)])
        case .weekly(let streak): return CatRank(currentStreak: streak)
        }
    }
    private func messageForEvent(_ event: RankUpEvent) -> String {
        switch event {
        case .rankUp: return "称号アップ!"
        case .weekly(let streak): return "\(streak)日連続!"
        }
    }

    /// 起動/記録後に小節目を評価。大節目シート提示中は抑止(二重演出防止)。
    private func evaluateRankCelebration() {
        guard presentedMilestone == nil else { return } // 大節目優先
        let events = rankUpDetector.evaluate(currentStreak: viewModel.streak.currentStreak)
        // rankUp を優先、無ければ weekly。1度に1つだけ出す(割り込まない・節度)。
        if let up = events.first(where: { if case .rankUp = $0 { return true } else { return false } }) {
            withAnimation { pendingRankEvent = up }
            CelebrationCenter.shared.fireLight()
        } else if let wk = events.first {
            withAnimation { pendingRankEvent = wk }
            CelebrationCenter.shared.fireLight()
        }
    }
```

呼び出し: `handleAutoPresentations()` の**末尾**(大節目の `presentedMilestone` 設定後)に `evaluateRankCelebration()` を追加。これにより大節目が立っていれば guard で抑止される。

> 注: `handleAutoPresentations()` の正確な位置は `HomeView.swift:80-81` 付近。大節目決定ロジックの直後に1行 `evaluateRankCelebration()` を足す。`presentedMilestone` が同 run で set される場合は guard により小節目は出ない。

- [ ] **Step 4: ビルド検証**

Run: `cd app/GOExercise && xcodebuild -project GOExercise.xcodeproj -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: コミット**

```bash
git add app/GOExercise/GOExercise/Services/CelebrationCenter.swift app/GOExercise/GOExercise/Views/Components/RankCelebrationOverlay.swift app/GOExercise/GOExercise/Views/HomeView.swift
git commit -m "feat(B): 小節目オーバーレイ(称号トースト+さざ波)+ fireLight + 大節目二重抑止"
```

---

## Phase 5: F 称号の友達共有・表示

### Task 13: 友達カード/詳細を `RankBadge` 表示に(F)

**Files:**
- Modify: `app/GOExercise/GOExercise/Views/Components/FriendAvatarView.swift`(リング色を `rank.metalKind` へ)
- Modify: `app/GOExercise/GOExercise/Views/FriendDetailView.swift`(Task 8 の仮チップ → `RankBadge` 本実装、line 372 の tierColor)

- [ ] **Step 1: `FriendAvatarView.decorationBorderColor` を rank メタル化**

`FriendAvatarView.swift:32-46` の overlay 条件と `decorationBorderColor`(68-76)を置換。`friend.rank.rank > 0` の時メタル色リング、それ以外は識別リング:

```swift
        .overlay {
            if showsDecorationBorder {
                if friend.rank.rank > 0, let metal = friend.rank.metalKind {
                    Circle()
                        .strokeBorder(metalRingColor(metal), lineWidth: 2)
                        .frame(width: size, height: size)
                } else {
                    Circle()
                        .strokeBorder(Self.identityRingColor(for: friend.friendCode), lineWidth: 1.5)
                        .frame(width: size, height: size)
                }
            }
        }
```

`decorationBorderColor`(68-76)を削除し、代わりに:

```swift
    private func metalRingColor(_ kind: MetalKind) -> Color {
        MetalStyle.isRainbow(kind) ? Color(red: 1.0, green: 0.80, blue: 0.42) : MetalStyle.baseColor(kind)
    }
```

(`friend.decorationTier > 0` 判定 36行目は `friend.rank.rank > 0` に置換済み。コメントも rank に更新)

- [ ] **Step 2: `FriendDetailView` の仮チップを `RankBadge` に置換**

Task 8 Step 4 で仮実装した `if friend.rank.rank > 0 {...}`(94-103)を:

```swift
            if friend.rank.rank > 0 {
                RankBadge(rank: friend.rank)
            }
```

に置換。`FriendDetailView.swift:372` 付近の `tierColor`(decorationTier switch)が他で使われていなければ削除。使用箇所を確認:

Run: `grep -n "tierColor" app/GOExercise/GOExercise/Views/FriendDetailView.swift`
他参照が無ければ `tierColor` computed と `switch friend.decorationTier` ブロックを削除。

- [ ] **Step 3: 本体ビルド検証**

Run: `cd app/GOExercise && xcodebuild -project GOExercise.xcodeproj -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: コミット**

```bash
git add app/GOExercise/GOExercise/Views/Components/FriendAvatarView.swift app/GOExercise/GOExercise/Views/FriendDetailView.swift
git commit -m "feat(F): 友達アバターのリング/詳細チップを CatRank メタル(RankBadge)で表示"
```

---

### Task 14: `FriendsStoreTests` の decoration→rank 移行 + mock 友達の streak 多様化

**Files:**
- Modify: `app/GOExercise/GOExerciseTests/FriendsStoreTests.swift:455-471`
- Modify: `app/GOExercise/GOExercise/Services/MockFriendsService.swift`(F スクショ用に currentStreak 多様化)

- [ ] **Step 1: `FriendsStoreTests` の `decoration` マッピングテストを `rank` に**

`FriendsStoreTests.swift:455-471` 付近の `let tiers: [(Int, CatDecoration)] = [...]` と `XCTAssertEqual(p.decoration, expected, ...)` を、currentStreak→rank の検証に置換:

```swift
        // 称号は currentStreak から CatRank で算出される(spec F)。
        let cases: [(Int, Int)] = [(0, 0), (7, 1), (30, 3), (100, 6), (365, 10), (500, 11)]
        for (streak, expectedRank) in cases {
            let p = FriendProfile(
                id: "f", friendCode: "ABCDEF", username: "u", displayName: "d",
                currentStreak: streak, totalAchievedDays: streak, todayAchieved: false,
                todayCategoryName: nil, todayExerciseNames: [], decorationTier: expectedRank,
                lastUpdated: Date())
            XCTAssertEqual(p.rank.rank, expectedRank, "streak \(streak) -> rank \(expectedRank)")
        }
```

(`FriendProfile` のイニシャライザ引数順は既存テストの他箇所 line 363/408/448 を参照して合わせる。`decoration` 参照を全て除去)

- [ ] **Step 2: 他テストの `decorationTier` 値はそのままで可**(stored フィールドとして有効)。`p.decoration` 参照が残っていないか確認:

Run: `grep -rn "\.decoration\b\|CatDecoration" $(find app/GOExercise/GOExerciseTests -name '*.swift')`
Expected: マッチ無し(`decorationTier` は可)。

- [ ] **Step 3: `MockFriendsService` の mock 友達に多様な currentStreak を設定(F スクショ検証用)**

`MockFriendsService.swift` の各 mock `FriendProfile` 生成箇所(247/265/279/293/...)で、称号の違いが画面で見えるよう `currentStreak` を散らす(例: 5, 9, 35, 120, 400, 530 等)。最低でも代表数名が rank0/低/中/最上位になるよう設定。`decorationTier` は表示に使わないので任意(rank 値に合わせると一貫)。

> 具体値は実装者裁量。狙い: F のスクショで bronze/silver/gold/platinum/rainbow と rank0(バッジ無し)が1画面に複数並ぶこと。

- [ ] **Step 4: 全テスト(sim)を実行**

Run: `cd app/GOExercise && xcodebuild -project GOExercise.xcodeproj -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 16' test 2>&1 | tail -25`
Expected: `Test Suite 'All tests' passed`。特に `CatRankTests`/`RankUpDetectorTests`/`MilestoneBackdropStyleTests`/`FriendsStoreTests` が green。

> sim テストランナーが hang する場合(既知): 純ロジックは Task 1/3/11 の swiftc ハーネスで担保済み。UI/統合は次フェーズのビルド+スクショで担保。hang したら `-only-testing:GOExerciseTests/CatRankTests` 等で個別実行を試す。

- [ ] **Step 5: コミット**

```bash
git add app/GOExercise/GOExerciseTests/FriendsStoreTests.swift app/GOExercise/GOExercise/Services/MockFriendsService.swift
git commit -m "test(F): FriendsStoreTests を decoration→CatRank へ移行 + mock 友達 streak 多様化"
```

---

## Phase 6: 検証ループ(simctl スクショ + 3LLM 採点 A/B/C/F)

### Task 15: 撮影マトリクスでスクショを撮る

**Files:** なし(検証作業)。スクショは `docs/superpowers/verification/2026-06-06-plan1/` に保存。

検証チェックリストの撮影マトリクス(最小):

| 軸 | 画面 | 段階/状態 | モード |
|---|---|---|---|
| A/C | ホーム | 連続 0/7/30/100/365/500 | light + dark |
| B | ホーム | ランク昇格直後 / 週次 | light |
| F | 友達パーク/一覧・詳細 | 称号の異なる友達数名 | light |

- [ ] **Step 1: スクショ保存先を作る**

```bash
mkdir -p docs/superpowers/verification/2026-06-06-plan1
```

- [ ] **Step 2: 連続日数を変えた状態でホームを撮る**

各段階(0/7/30/100/365/500)を出すには、デバッグ用に records を仕込むか、`StreakCalculator` をプレビュー注入する手段が要る。**推奨**: SwiftUI プレビューを用意して `xcodebuild` の代わりに `simctl` で起動したアプリのオンボ→記録投入が大変なため、**専用のプレビュー Harness View** を一時的に追加し、`MilestoneBackdrop(streak:)` + `topStatusBar` 相当 + `RankBadge` を各 streak で並べた検証画面を撮る。

実務手順:
1. `app/GOExercise/GOExercise/Views/Components/_RankPreviewHarness.swift`(`#if DEBUG`)を一時作成。各 streak の `MilestoneBackdrop` + `RankBadge` + `RankCelebrationOverlay` を縦に並べる。
2. 起動して `xcrun simctl io booted screenshot docs/superpowers/verification/2026-06-06-plan1/A_C_light.png`。
3. ダーク: `xcrun simctl ui booted appearance dark` → 再撮影 `A_C_dark.png`。
4. B: ハーネスで `RankCelebrationOverlay(rank: CatRank(currentStreak: 7))` を常時表示し `B_minor.png`。
5. F: 友達タブ(`MockFriendsService` の多様 streak)を開き `F_friends.png` / 友達詳細 `F_detail.png`。

> ハーネスは検証後 Task 17 で必ず削除する(本番混入防止)。

- [ ] **Step 3: 撮れたファイルを確認**

Run: `ls -la docs/superpowers/verification/2026-06-06-plan1/`
Expected: `A_C_light.png` `A_C_dark.png` `B_minor.png` `F_friends.png` `F_detail.png` が存在。

---

### Task 16: 3LLM(Codex + Gemini)で採点 → 改善ループ

**Files:** 改善は該当 View ファイル(`MilestoneBackdrop`/`RankBadge`/`RankCelebrationOverlay`/`FriendAvatarView`)。

- [ ] **Step 1: 自分(Claude)の目でチェックリストを採点**

検証チェックリスト A(1-6)/C(11-14)/B(7-10)/F(24-25)を、撮ったスクショで各0-3点採点。特に:
- A2 上品さ(365/500 の黄色過多回避)、A4 猫が主役、A3 時間帯/ダーク両対応
- C11 メタリック質感の判別性・上品さ、C12 連続チップ隣で被らない、rank0 非表示
- B7 軽量で割り込まない、B8 称号トーストが読め自動で消える
- F24 友達一覧/パークに RankBadge

- [ ] **Step 2: Codex(gpt-5-codex)で独立採点**

`second-opinion` skill か直接 Codex CLI を使い、スクショ画像をワークスペース内パスで実読させて採点させる。プロンプトにチェックリスト該当項目を貼り、各0-3点 + 具体的改善指示を求める。

Run(例): `second-opinion` を起動し、対象 = `docs/superpowers/verification/2026-06-06-plan1/*.png` + チェックリスト A/B/C/F。

- [ ] **Step 3: Gemini で独立採点**(同様に画像実読 + 採点)

- [ ] **Step 4: 2点未満の項目を修正 → 再ビルド → 再撮影 → 再採点**

全項目2点以上になるまでループ。典型的修正候補(UIUX skill 反映):
- メタルが「チープ」: `MetalStyle.fillGradient` のハイ/ロー差を詰める・フチ opacity 調整・shadow を弱める
- 365/500 が眩しい: `MilestoneBackdrop` の `0.30 * richness` を下げる / godRays opacity を下げる
- トーストが見えにくい: `.ultraThinMaterial` → コントラスト確保、表示時間調整
- ダークでフチが消える: メタル色の明度 floor を上げる

- [ ] **Step 5: 採点結果を記録**

`docs/superpowers/verification/2026-06-06-plan1/scores.md` に Claude/Codex/Gemini の最終点と改善履歴を残す。

```bash
git add docs/superpowers/verification/2026-06-06-plan1/
git commit -m "docs(verify): 計画① A/B/C/F の3LLMスクショ採点と改善履歴"
```

---

### Task 17: 後片付け + 計画①完了

**Files:**
- Delete: `app/GOExercise/GOExercise/Views/Components/_RankPreviewHarness.swift`(検証用ハーネス)

- [ ] **Step 1: 検証ハーネスを削除**

```bash
rm -f app/GOExercise/GOExercise/Views/Components/_RankPreviewHarness.swift
```

- [ ] **Step 2: 最終ビルド + 残 dead 参照ゼロを確認**

Run: `cd app/GOExercise && grep -rn "CatDecoration\|MilestoneItem\|MilestoneBackground\b\|CatDecorationEmblem\|MilestoneBackgroundView\|bg_milestone\|waitingMorning_crown" $(find . -name '*.swift'); xcodegen generate >/dev/null && xcodebuild -project GOExercise.xcodeproj -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3`
Expected: grep マッチ無し、`** BUILD SUCCEEDED **`

- [ ] **Step 3: Info.plist 手動キー最終確認(Archive 前 gotcha)**

Run: `/usr/libexec/PlistBuddy -c "Print :FriendsAppleLinkEnabled" app/GOExercise/GOExercise/Resources/Info.plist; /usr/libexec/PlistBuddy -c "Print :TelemetryDeckAppID" app/GOExercise/GOExercise/Resources/Info.plist`
Expected: 両キー存在。

- [ ] **Step 4: コミット**

```bash
git add -A
git commit -m "chore(verify): 検証ハーネス削除・計画①(撤去+A/B/C/F)完了"
```

- [ ] **Step 5: メモリ更新**

`achievement_luxury_redesign.md` を「計画①完了・次は計画②(フリーズ復活D)」に更新。

---

## Self-Review(spec 突き合わせ)

- **撤去**: emblem(Task5)/MilestoneItem+背景model(Task7)/画像背景View+assets(Task6)/CatDecoration(Task8)/crown asset(Task7)/MilestoneStyleTests(Task7) — ✅ 全網羅。shaker は保持(Task7 注記)。
- **背骨 CatRank**: 連続ベース・閾値・称号案B・metal・richness・reset — Task1。SwiftUI 色分離(swiftc 可)— Task2。✅
- **A 背景**: 色帯=metal、richness、sparkleCount、時間帯トーン、rank>=10 光帯、rank11 godray+虹、reduceMotion 静止、hitTesting/a11y 除外、連続駆動 — Task3/4。✅
- **B 瞬間演出**: RankUpDetector(昇格/週次・リセット再発火)Task11、fireLight + 称号トースト + さざ波 Task12、大節目二重抑止(guard)Task12。✅
- **C 称号**: RankBadge メタル+shimmer/pop+VoiceOver Task9、連続チップ隣・rank0 非表示 Task10。✅
- **F 友達**: FriendProfile.rank(currentStreak computed・BE変更なし)Task8、RankBadge 表示 Task13、decorationTier に rank publish Task8、FriendsStoreTests 移行 Task14。✅
- **テスト方針**: CatRankTests/RankUpDetectorTests/MilestoneBackdropStyleTests(streak)・MilestoneDetectorTests 不変・swiftc 純ロジック+simスクショ3LLM — Phase0-6。✅
- **スコープ外**: D(計画②)/E(計画③)/StreakLevel 不変 — 本計画は触れない。✅

**型一貫性チェック**: `CatRank(currentStreak:)` / `.rank` / `.title` / `.metalKind` / `.richness` / `.iconSymbol` / `MetalKind`(bronze..rainbow)/ `MetalStyle.baseColor/fillGradient/rainbowColors/isRainbow` / `MilestoneBackdropStyle(streak:)` / `MilestoneBackdrop(streak:)` / `RankBadge(rank:animateShimmer:compact:)` / `RankUpDetector(defaults:).evaluate(currentStreak:)→[RankUpEvent]` / `RankUpEvent.rankUp(to:)|.weekly(streak:)` / `CelebrationCenter.shared.fireLight()` / `RankCelebrationOverlay(rank:message:onFinished:)` / `FriendProfile.rank` — 全タスクで命名一致。

**placeholder スキャン**: TBD/TODO/「適切に」等なし。各コード手順に実コードを記載。
</content>
</invoke>
