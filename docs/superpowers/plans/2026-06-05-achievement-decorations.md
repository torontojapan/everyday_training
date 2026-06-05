# 達成マイルストーン装飾 実装計画 (iOS / v1.1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `totalAchievedDays` に応じて、猫の「背景(多段ラダー)」と「装着アイテム(30日シェイカー/100日王冠)」を表示し、達成の育成を見える化する。

**Architecture:** 進行は純粋関数 `MilestoneStyle`(日数→背景tier/アイテム)で算出。背景は猫の後ろのレイヤー(ホーム大猫+アバター両方・breed共通画像)。アイテムは単一ポーズのアバターのみ(`cat_<breed>_waitingMorning_<suffix>`)に焼き込み。Supabase スキーマ変更ゼロ(friends は既存同期の `total_achieved_days` から同じ算出)。旧 `CatDecoration` チップは退役。

**Tech Stack:** Swift / SwiftUI / XCTest。アート生成は Codex(別途)。対象 `app/GOExercise`。ブランチ `feature/achievement-decorations`。

**前提:** スペック `docs/superpowers/specs/2026-06-05-achievement-decorations-design.md`。案A確定(アイテムはアバターのみ、背景は両方)。ビルド検証は `xcodebuild ... -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO`。

---

## ファイル構成
- 新規: `app/GOExercise/GOExercise/Models/MilestoneStyle.swift`(日数→背景tier/アイテムの純粋ロジック + asset名)
- 新規: `app/GOExercise/GOExercise/Views/Components/MilestoneBackgroundView.swift`(背景レイヤー)
- 新規テスト: `app/GOExercise/GOExerciseTests/MilestoneStyleTests.swift`
- 変更: `Models/CatBreed.swift`(アバターasset解決にアイテムsuffix+fallback)
- 変更: `Views/HomeView.swift`(`BigCatView` に背景レイヤー挿入)
- 変更: `Views/FriendAvatarView.swift` / `Views/Components/RewardCard.swift`(アバターをアイテム付きに、背景付与、旧チップ撤去)
- 変更: `ViewModels/HomeViewModel.swift` / `Models/FriendProfile.swift`(旧 `CatDecoration` 参照の置換)

---

## Task 1: MilestoneStyle モデル(純粋ロジック)

**Files:**
- Create: `app/GOExercise/GOExercise/Models/MilestoneStyle.swift`
- Test: `app/GOExercise/GOExerciseTests/MilestoneStyleTests.swift`

- [ ] **Step 1: 失敗するテストを書く**

```swift
// MilestoneStyleTests.swift
import XCTest
@testable import GOExercise

final class MilestoneStyleTests: XCTestCase {
    // アイテム: 30未満=none / 30..<100=shaker / 100以上=shakerCrown(累積)
    func test_item_boundaries() {
        XCTAssertEqual(MilestoneItem(totalAchievedDays: 0), .none)
        XCTAssertEqual(MilestoneItem(totalAchievedDays: 29), .none)
        XCTAssertEqual(MilestoneItem(totalAchievedDays: 30), .shaker)
        XCTAssertEqual(MilestoneItem(totalAchievedDays: 99), .shaker)
        XCTAssertEqual(MilestoneItem(totalAchievedDays: 100), .shakerCrown)
        XCTAssertEqual(MilestoneItem(totalAchievedDays: 9999), .shakerCrown)
    }

    func test_item_assetSuffix() {
        XCTAssertEqual(MilestoneItem.none.assetSuffix, "")
        XCTAssertEqual(MilestoneItem.shaker.assetSuffix, "_shaker")
        XCTAssertEqual(MilestoneItem.shakerCrown.assetSuffix, "_crown") // crownアートはシェイカーも内包
    }

    // 背景tier: しきい値 7,14,30,50,75,100,150,200,300,365,500
    func test_backgroundTier_boundaries() {
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 6).tier, 0)
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 7).tier, 1)
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 29).tier, 2)   // 14到達
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 30).tier, 3)
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 100).tier, 6)
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 500).tier, 11)
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 99999).tier, 11) // 最上段で頭打ち
    }

    func test_backgroundAssetName() {
        XCTAssertNil(MilestoneBackground(totalAchievedDays: 0).assetName)      // tier0は背景なし
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 7).assetName, "bg_milestone_01")
        XCTAssertEqual(MilestoneBackground(totalAchievedDays: 500).assetName, "bg_milestone_11")
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `cd app/GOExercise && xcodebuild test -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GOExerciseTests/MilestoneStyleTests 2>&1 | tail -20`
Expected: コンパイルエラー(`MilestoneItem` / `MilestoneBackground` 未定義)。

- [ ] **Step 3: 最小実装**

```swift
// MilestoneStyle.swift
import Foundation

/// 達成日数で決まる猫の装着アイテム(累積)。アバター(単一ポーズ)にのみ焼き込む。
enum MilestoneItem: Equatable {
    case none          // 0..<30
    case shaker        // 30..<100
    case shakerCrown   // 100+

    init(totalAchievedDays days: Int) {
        switch days {
        case ..<30: self = .none
        case 30..<100: self = .shaker
        default: self = .shakerCrown
        }
    }

    /// アバター asset 名に付与する接尾辞。crown アートはシェイカーも内包(累積)。
    var assetSuffix: String {
        switch self {
        case .none: return ""
        case .shaker: return "_shaker"
        case .shakerCrown: return "_crown"
        }
    }
}

/// 達成日数で決まる背景ランク。breed 非依存・猫の後ろのレイヤー。
struct MilestoneBackground: Equatable {
    /// しきい値(日数)。到達した最大段が tier。以降の追加はここに足す。
    static let thresholds = [7, 14, 30, 50, 75, 100, 150, 200, 300, 365, 500]

    let tier: Int   // 0 = 背景なし、1..thresholds.count

    init(totalAchievedDays days: Int) {
        var t = 0
        for (i, th) in Self.thresholds.enumerated() where days >= th { t = i + 1 }
        self.tier = t
    }

    /// 背景アセット名。tier0 は nil(背景なし)。
    var assetName: String? {
        tier == 0 ? nil : String(format: "bg_milestone_%02d", tier)
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `cd app/GOExercise && xcodebuild test -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GOExerciseTests/MilestoneStyleTests 2>&1 | tail -20`
Expected: PASS(`Test Suite 'MilestoneStyleTests' passed`)。

- [ ] **Step 5: コミット**

```bash
git add app/GOExercise/GOExercise/Models/MilestoneStyle.swift app/GOExercise/GOExerciseTests/MilestoneStyleTests.swift
git commit -m "feat(decorations): MilestoneStyle(日数→背景tier/アイテム)純粋ロジック+test"
```

---

## Task 2: アバター asset 解決にアイテム+fallback

**Files:**
- Modify: `app/GOExercise/GOExercise/Models/CatBreed.swift`(`assetName(for:)` 付近に新メソッド追加)
- Test: `app/GOExercise/GOExerciseTests/MilestoneStyleTests.swift`(追記)

- [ ] **Step 1: 失敗するテストを追記**

```swift
// MilestoneStyleTests.swift に追記
extension MilestoneStyleTests {
    func test_avatarAssetName_withItems() {
        // 0日: 素アバター
        XCTAssertEqual(CatBreed.orange.avatarAssetName(totalAchievedDays: 0), "cat_orange_waitingMorning")
        // 30日: シェイカー
        XCTAssertEqual(CatBreed.orange.avatarAssetName(totalAchievedDays: 30), "cat_orange_waitingMorning_shaker")
        // 100日: 王冠(+シェイカー内包)
        XCTAssertEqual(CatBreed.black.avatarAssetName(totalAchievedDays: 120), "cat_black_waitingMorning_crown")
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `cd app/GOExercise && xcodebuild test -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GOExerciseTests/MilestoneStyleTests 2>&1 | tail -20`
Expected: FAIL(`avatarAssetName(totalAchievedDays:)` 未定義)。

- [ ] **Step 3: 最小実装(CatBreed に追加)**

`CatBreed.swift` の `avatarAssetName`(`var avatarAssetName: String`)の直後に追記:

```swift
    /// 達成日数に応じたアイテム付きアバター asset 名。アイテムは単一ポーズ
    /// (waitingMorning)のアバターにのみ焼き込む(ホームの大猫には付けない=案A)。
    func avatarAssetName(totalAchievedDays days: Int) -> String {
        let suffix = MilestoneItem(totalAchievedDays: days).assetSuffix
        return "cat_\(rawValue)_waitingMorning\(suffix)"
    }
```

- [ ] **Step 4: テストが通ることを確認**

Run: 同上 `-only-testing:GOExerciseTests/MilestoneStyleTests`
Expected: PASS。

- [ ] **Step 5: コミット**

```bash
git add app/GOExercise/GOExercise/Models/CatBreed.swift app/GOExercise/GOExerciseTests/MilestoneStyleTests.swift
git commit -m "feat(decorations): アバターasset解決にアイテムsuffixを追加"
```

---

## Task 3: 背景レイヤー View + fallback 解決ヘルパ

**Files:**
- Create: `app/GOExercise/GOExercise/Views/Components/MilestoneBackgroundView.swift`

> アセット未生成でも落ちない: `UIImage(named:)` が nil の時は何も描かない(透明)。Task 8 で実画像を入れると自動で出る。

- [ ] **Step 1: 実装(Viewは純粋描画のためユニットテストせず、ビルド検証で代替)**

```swift
// MilestoneBackgroundView.swift
import SwiftUI

/// 猫の「後ろ」に敷く達成背景。overlay 不具合(顔の上に重ねる)を避けるため、
/// 必ず猫画像より下のレイヤーに置くこと。tier0 / 画像未存在なら透明(何も描かない)。
struct MilestoneBackgroundView: View {
    let totalAchievedDays: Int

    var body: some View {
        if let name = MilestoneBackground(totalAchievedDays: totalAchievedDays).assetName,
           UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFill()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
```

- [ ] **Step 2: ビルド確認**

Run: `cd app/GOExercise && xcodebuild build -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'`
Expected: BUILD SUCCEEDED。

- [ ] **Step 3: コミット**

```bash
git add app/GOExercise/GOExercise/Views/Components/MilestoneBackgroundView.swift
git commit -m "feat(decorations): MilestoneBackgroundView(背景レイヤー・画像未存在で透明)"
```

---

## Task 4: ホーム大猫(BigCatView)に背景を挿入

**Files:**
- Modify: `app/GOExercise/GOExercise/Views/HomeView.swift`(`BigCatView`, 既存の `ZStack { Circle ... }` の最背面に背景を追加)
- `BigCatView` に `totalAchievedDays` を渡すため、呼び出し元(HomeView 本体)も合わせて変更。

- [ ] **Step 1: BigCatView に引数追加 + 背景挿入**

`struct BigCatView: View {` の `let state: CatState` の下に追加:
```swift
    let totalAchievedDays: Int
```
`var body` の `ZStack {` 直後(光輪 Circle より前=最背面)に追加:
```swift
            MilestoneBackgroundView(totalAchievedDays: totalAchievedDays)
                .scaleEffect(1.0)
```
(光輪 Circle はそのまま残す。背景はその後ろに敷かれる。)

- [ ] **Step 2: 呼び出し元を更新**

`HomeView.swift` 内の `BigCatView(state: ...)` 生成箇所を grep:
Run: `grep -n 'BigCatView(' app/GOExercise/GOExercise/Views/HomeView.swift`
各箇所に `totalAchievedDays: viewModel.lifetimeStats.achievedDays` を追加(`viewModel` が参照可能なスコープであること。不可なら `UserCatPreferences` と同様に lifetime 値を引き回す)。

- [ ] **Step 3: ビルド確認**

Run: `cd app/GOExercise && xcodebuild build -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'`
Expected: BUILD SUCCEEDED。

- [ ] **Step 4: コミット**

```bash
git add app/GOExercise/GOExercise/Views/HomeView.swift
git commit -m "feat(decorations): ホーム大猫の最背面に達成背景を挿入"
```

---

## Task 5: アバター表示にアイテム+背景を反映

**Files:**
- Modify: `app/GOExercise/GOExercise/Views/FriendAvatarView.swift`(アバター画像解決を `avatarAssetName(totalAchievedDays:)` に、背面に `MilestoneBackgroundView`)

> 友達は `FriendProfile.totalAchievedDays`、自分は lifetime 値。アバターViewが受け取る profile から日数を取得する。

- [ ] **Step 1: 現状把握**

Run: `grep -n 'avatarAssetName\|totalAchievedDays\|struct FriendAvatarView\|let profile\|ZStack' app/GOExercise/GOExercise/Views/FriendAvatarView.swift | head`

- [ ] **Step 2: アバター画像解決をアイテム付きに差し替え + 背景**

`avatarAssetName`(引数なし)を使っている箇所を、その avatar の日数を使う版へ:
```swift
// 例: 既存
// let asset = breed.avatarAssetName
// ↓ 変更後(profile.totalAchievedDays を使用、未存在なら素アバター→orange にフォールバック)
let withItem = breed.avatarAssetName(totalAchievedDays: profile.totalAchievedDays)
let base = breed.avatarAssetName  // アイテム無し素アバター
let asset = UIImage(named: withItem) != nil ? withItem
          : (UIImage(named: base) != nil ? base : CatBreed.fallbackAvatarAssetName)
```
画像を描く `ZStack`(または最上位コンテナ)の**最背面**に追加:
```swift
MilestoneBackgroundView(totalAchievedDays: profile.totalAchievedDays)
```

- [ ] **Step 3: ビルド確認**

Run: `cd app/GOExercise && xcodebuild build -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'`
Expected: BUILD SUCCEEDED。

- [ ] **Step 4: コミット**

```bash
git add app/GOExercise/GOExercise/Views/FriendAvatarView.swift
git commit -m "feat(decorations): アバターにアイテム付き画像+達成背景を反映"
```

---

## Task 6: 旧 CatDecoration チップの退役(一本化)

**Files:**
- Modify: `app/GOExercise/GOExercise/Views/Components/RewardCard.swift`(チップ表示を撤去 or 新装飾の説明に置換)
- Modify: `app/GOExercise/GOExercise/ViewModels/HomeViewModel.swift`(`catDecoration` 廃止 or 未使用化)
- Modify: `app/GOExercise/GOExercise/Models/FriendProfile.swift`(`decoration`/`decorationTier` の参照を整理)

> 二重進行(チップ + 新背景/アイテム)を避けるため、見た目の進行は新システムに一本化。`CatDecoration` 型自体は当面残してよいが、UIチップの露出を外す。

- [ ] **Step 1: 参照棚卸し**

Run: `grep -rn 'catDecoration\|\.decoration\b\|CatDecoration\|RewardCard(' app/GOExercise/GOExercise/ | grep -v Tests`

- [ ] **Step 2: RewardCard からチップ撤去**

`RewardCard.swift` の `decoration` を使うチップ表示(emoji/accentColor 等)を削除し、必要なら「次の解放まであと N 日」等の文言に置換(露出を新システムに寄せる)。`RewardCard` の `decoration` 引数が他で未使用になれば削除。

- [ ] **Step 3: 呼び出し元の整合**

`HomeViewModel.catDecoration`(line 20/97)と `FriendProfile.decoration`(line 43-44)の参照が消えたら、未使用プロパティを削除。コンパイルを通す。

- [ ] **Step 4: 全テスト + ビルド**

Run: `cd app/GOExercise && xcodebuild test -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -25`
Expected: 全 PASS / BUILD SUCCEEDED(既存テストが CatDecoration に依存していれば併せて更新)。

- [ ] **Step 5: コミット**

```bash
git add -A
git commit -m "refactor(decorations): 旧CatDecorationチップを退役し新装飾に一本化"
```

---

## Task 7: アート生成(Codex)— 最小セット

> コードは Task 1-6 で完成。ここは**コンテンツ生成**(別作業・Codex)。最小セットだけ先に入れれば動作が見える。

**最小セット:**
- 背景: `bg_milestone_01` 〜 `bg_milestone_11`(breed 非依存・縦長・猫の後ろに敷ける淡め〜豪華の段階)
- オレンジのアイテム付きアバター: `cat_orange_waitingMorning_shaker` / `cat_orange_waitingMorning_crown`(crown は王冠+シェイカー両方)

> 他10 breed のアイテム画像は段階導入(未生成なら Task 2/5 の fallback で素アバター表示=落ちない)。[[codex_image_generation]] の透過/flood-fill パターンで生成し、`Assets.xcassets` に同名で追加。

- [ ] **Step 1:** Codex で背景11枚を生成 → `Assets.xcassets/Milestones/` に `bg_milestone_01..11` で追加。
- [ ] **Step 2:** Codex で `cat_orange_waitingMorning` をベースにシェイカー版・王冠版を生成 → `Assets.xcassets` に追加。
- [ ] **Step 3:** ビルド & 実機/シミュレータ確認(下記 Task 8)。
- [ ] **Step 4: コミット**(`git add app/GOExercise/GOExercise/Assets.xcassets && git commit -m "assets(decorations): 背景11段+オレンジのアイテム付きアバター"`)

---

## Task 8: 結合・目視検証

- [ ] **Step 1: 達成日数を変えて見た目確認**
  - シミュレータで起動引数 or デバッグ手段で lifetime 達成日を 0 / 30 / 100 / 365 に変え、ホーム背景の段階変化と、アバター(プロフィール/友達)のシェイカー→王冠を確認。
  - 既存のデモ seeder(`DemoDataSeeder` / `--seed-*`)を活用可。
- [ ] **Step 2:** 友達一覧で、各 friend の `totalAchievedDays` に応じた背景/アイテムが出ることを確認(Mockの 35/168/201/312 等)。
- [ ] **Step 3:** reduceMotion / ダーク・ライト / iPad で崩れない事を確認。
- [ ] **Step 4: 最終コミット**(必要な微調整があれば)。

---

## Self-Review メモ(計画作成時チェック済)
- スペック §3.1 背景ラダー → Task1(thresholds)+Task3/4/5(描画)。§3.2 アイテム → Task1(MilestoneItem)+Task2/5。§4 レンダリング順(背景→猫) → Task4/5 で最背面挿入。§3 旧tier退役 → Task6。§5 ソーシャル(スキーマ変更ゼロ) → Task5 が friend.totalAchievedDays から算出。§6 アート → Task7。
- 型整合: `MilestoneItem(totalAchievedDays:)` / `MilestoneBackground(totalAchievedDays:).tier/.assetName` / `CatBreed.avatarAssetName(totalAchievedDays:)` を Task間で一貫使用。
- 案A(アイテムはアバターのみ・背景は両方)を Task4(背景のみ)と Task5(背景+アイテム)で反映。
