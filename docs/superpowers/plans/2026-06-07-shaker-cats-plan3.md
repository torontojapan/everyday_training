# 計画③ シェイカー猫フレーバー(E)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 運動記録の**前後**で、ユーザーの猫種がプロテインシェイカーを持つ待機ポーズ(`cat_<breed>_waitingMorning_shaker`)を出す「補給」フレーバー。達成段階(CatRank)とは無関係に誰でも出る。コードは**画像欠落で破綻しない**(フォールバック)設計で先に出荷し、10猫種のアセット生成は別フェーズで best-effort。

**Architecture:** 純プロパティ `CatBreed.shakerAssetName` + 注入可能な存在チェックでフォールバックする `resolvedShakerAssetName(exists:)`。`BigCatView` に `useShaker` フラグを足し、`RecordCompletionView`(記録直後ヒーロー)と `HomeView` catTheater(今日未記録の待機文脈)で有効化。アセットは既存 `cat_orange_waitingMorning_shaker`(1024²・透過)を style 基準に、他10猫種を Codex 生成 → flood-fill 透過 → 3LLM トンマナ検証 → imageset 追加。

**Tech Stack:** Swift/SwiftUI/iOS17/XCTest。純ロジック=swiftc。アセット=Codex CLI 画像生成 + Python(PIL)flood-fill 透過 + 3LLM 検証。

**正本spec:** `docs/superpowers/specs/2026-06-06-achievement-luxury-design.md`(E節)。**検証**: チェックリスト E(20-23)。
**前提**: 計画①②完了(branch `feature/referral-rewards-v12`)。

---

## 調査で確定した事実

1. **既存アセット**: `cat_orange_waitingMorning_shaker.imageset`(1024×1024 PNG・透過・1x スロットのみ・743KB)。アート=オレンジトラが黒トラックスーツ+白ヘッドバンド+スニーカーで座り、肉球ロゴの白いプロテインシェイカーを持つチビ画風。**これが他10猫種の style 基準**。`cat_orange_waitingMorning_crown` は計画①で削除済、shaker は保持。
2. **CatBreed**(`Models/CatBreed.swift`): 11種(orange/black/white/gray/calico/silvertabby/browntabby/siamese/tuxedo/persian/scottish)。`assetName(for:)`=`cat_<raw>_<state>`、`avatarAssetName`=`cat_<raw>_waitingMorning`、`fallbackAvatarAssetName`=`cat_orange_waitingMorning`。全11種×7状態は Phase 6.7 で生成済(=各 breed の `waitingMorning` は存在する)。
3. **BigCatView**(`Views/HomeView.swift:619`): `let state: CatState`。body で `primary = state.assetName(breed:)`、`resolved = UIImage(named: primary) != nil ? primary : CatBreed.fallbackAssetName(for: state)`。光輪 Circle + breathing/float/sway + tap bounce。`decoration` 引数は計画①で撤去済。
4. **呼び出し**: catTheater `BigCatView(state: viewModel.catState)`(HomeView:273)、RecordCompletion `BigCatView(state: streakExtendedThisRun ? .streakExtended : .celebrating)`(RecordCompletionView:64)。
5. **`DailyStatus.countsAsAchieved`** あり(達成判定)。`viewModel.todayStatus` で今日の状態が取れる。
6. **画像生成パイプライン**([[codex_image_generation]]): `codex exec --sandbox workspace-write` で参照画像パスをプロンプトに含め同キャラ生成。**逐次実行+ファイル存在 verify**(並列は不安定)。デフォルト 1254² → `sips -z 1024 1024` でリサイズ。透過=Python+PIL flood-fill(外側白のみ・THRESHOLD=230・エッジ alpha graded)。token 枯渇時は Gemini CLI 画像生成。
7. **CatState**: waitingMorning/worriedNoon/beggingNight/celebrating/streakExtended/resting/encouraging。

### ファイル構成

| 区分 | パス | 役割 |
|---|---|---|
| 改 | `GOExercise/Models/CatBreed.swift` | `shakerAssetName`(純)+ `resolvedShakerAssetName(exists:)`(注入可フォールバック) |
| 改 | `GOExercise/Views/HomeView.swift` | BigCatView に `useShaker` 追加 + catTheater で今日未記録時に有効化 |
| 改 | `GOExercise/Views/RecordCompletionView.swift` | 記録直後ヒーローを shaker に |
| 新規テスト | `GOExerciseTests/CatBreedShakerTests.swift` | 全11種の asset 名規約 + フォールバック解決 |
| 新規アセット | `Resources/Assets.xcassets/CatCharacter/cat_<breed>_waitingMorning_shaker.imageset`×10 | 生成画像 |
| 一時 | `/tmp/transparentize_cats.py`, `/tmp/gen_shaker_*.txt` | 生成・透過の作業ファイル(コミットしない) |

### スコープ外(YAGNI)
- shaker 以外のポーズ追加、達成段階連動、アニメGIF。フォールバックで動くので**アセット未完でも出荷可**。

---

## Phase 0: コード(shaker 解決 + 表示配線)— アセット無しでも安全

### Task 1: `CatBreed.shakerAssetName` + `resolvedShakerAssetName`(TDD swiftc)

**Files:** Modify `Models/CatBreed.swift`、Create `GOExerciseTests/CatBreedShakerTests.swift`、一時 `/tmp/ShakerHarness.swift`

CatBreed は `import SwiftUI` を含む(tintColor が Color)→ swiftc native 不可。だが純文字列ロジックなので、harness では CatBreed を**最小スタブ無しで**検証できない。→ 方針: 純文字列部を **Foundation だけで完結する static 関数**にも出し、swiftc で検証。具体的には enum メソッドはそのまま、検証は XCTest を主とし、加えて文字列規約だけ swiftc で軽く確認(下記)。

- [ ] **Step 1: `CatBreed.swift` に追加**(`fallbackAvatarAssetName` の後):
```swift
    /// プロテインシェイカーを持つ待機ポーズの asset 名。例: cat_black_waitingMorning_shaker。
    /// 達成段階と無関係に「運動記録の前後」で出すフレーバー(spec E)。
    var shakerAssetName: String {
        "cat_\(rawValue)_waitingMorning_shaker"
    }

    /// shaker 画像の解決。存在チェック `exists` を注入してフォールバックする(テスト可能)。
    /// 1) 当該猫種の shaker → 2) 当該猫種の通常 waitingMorning → 3) orange shaker。
    /// 画像欠落でも必ず何か返るので破綻しない。
    func resolvedShakerAssetName(exists: (String) -> Bool) -> String {
        if exists(shakerAssetName) { return shakerAssetName }
        if exists(avatarAssetName) { return avatarAssetName }
        return "cat_orange_waitingMorning_shaker"
    }
```

- [ ] **Step 2: XCTest `CatBreedShakerTests.swift`**:
```swift
import XCTest
@testable import GOExercise

final class CatBreedShakerTests: XCTestCase {
    func test_shakerAssetName_convention_allBreeds() {
        for breed in CatBreed.allCases {
            XCTAssertEqual(breed.shakerAssetName, "cat_\(breed.rawValue)_waitingMorning_shaker")
        }
        XCTAssertEqual(CatBreed.orange.shakerAssetName, "cat_orange_waitingMorning_shaker")
        XCTAssertEqual(CatBreed.black.shakerAssetName, "cat_black_waitingMorning_shaker")
    }
    func test_resolvedShaker_usesBreedShaker_whenPresent() {
        let r = CatBreed.black.resolvedShakerAssetName { _ in true } // 全て存在
        XCTAssertEqual(r, "cat_black_waitingMorning_shaker")
    }
    func test_resolvedShaker_fallsBackToBreedWaiting_whenShakerMissing() {
        let r = CatBreed.black.resolvedShakerAssetName { name in name == "cat_black_waitingMorning" }
        XCTAssertEqual(r, "cat_black_waitingMorning")
    }
    func test_resolvedShaker_fallsBackToOrangeShaker_whenAllMissing() {
        let r = CatBreed.persian.resolvedShakerAssetName { _ in false }
        XCTAssertEqual(r, "cat_orange_waitingMorning_shaker")
    }
}
```

- [ ] **Step 3: swiftc 軽検証**(純文字列規約のみ。CatBreed は SwiftUI 依存のため、`/tmp/ShakerHarness.swift` に規約を直接書いて確認する代替として、XCTest を build-for-testing で担保。swiftc が難しければ Step 4 のビルドで代替)。実装者判断: `grep` で `shakerAssetName` 11種が `cat_<raw>_waitingMorning_shaker` を返すことをコードレビューで確認。

- [ ] **Step 4: ビルド GREEN** + コミット:
```bash
git add app/GOExercise/GOExercise/Models/CatBreed.swift app/GOExercise/GOExerciseTests/CatBreedShakerTests.swift
git commit -m "feat(E): CatBreed.shakerAssetName + フォールバック解決(純ロジック)" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task 2: BigCatView に `useShaker` + 表示配線

**Files:** Modify `Views/HomeView.swift`(BigCatView + catTheater)、`Views/RecordCompletionView.swift`

- [ ] **Step 1: BigCatView に `useShaker` を追加**。`Views/HomeView.swift:619` 付近の body 先頭を:
```swift
struct BigCatView: View {
    let state: CatState
    var useShaker: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @State private var floating = false
    @State private var swaying = false

    var body: some View {
        let breed = UserCatPreferences.shared.myCat
        let resolved: String = useShaker
            ? breed.resolvedShakerAssetName { UIImage(named: $0) != nil }
            : (UIImage(named: state.assetName(breed: breed)) != nil
               ? state.assetName(breed: breed)
               : CatBreed.fallbackAssetName(for: state))
        ZStack {
```
(以降の `resolved` 使用箇所はそのまま。`primary` ローカルは消えるので参照が無いか確認し、`resolved` に統一)

- [ ] **Step 2: RecordCompletion ヒーローを shaker に**。`RecordCompletionView.swift:64`:
```swift
                    BigCatView(state: streakExtendedThisRun ? .streakExtended : .celebrating, useShaker: true)
```

- [ ] **Step 3: Home catTheater で今日未記録時に shaker**。`HomeView.swift:273`:
```swift
            BigCatView(state: viewModel.catState, useShaker: !viewModel.todayStatus.countsAsAchieved)
```
(今日まだ達成していない=これから運動の文脈で「補給して頑張ろう」。達成済みなら通常猫)

- [ ] **Step 4: ビルド GREEN**(simulator name=iPhone 17)。この時点で orange 以外は shaker 画像が無いので `resolvedShakerAssetName` が breed の通常 waitingMorning にフォールバック=破綻しない。orange ユーザーだけ shaker が出る。コミット:
```bash
git add app/GOExercise/GOExercise/Views/HomeView.swift app/GOExercise/GOExercise/Views/RecordCompletionView.swift
git commit -m "feat(E): BigCatView useShaker + 記録前後(RecordCompletion/Home未記録)で表示" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 1: アセット生成(10猫種)— best-effort・フォールバックで安全

> **方針**: コードは Phase 0 で出荷済み。ここは画質が伴わなければ「orange のみ shaker・他はフォールバック」で確定して良い(spec の品質ガード=トンマナ不一致を出すくらいなら出さない)。各猫種を**逐次**生成し、**3LLM トンマナ検証で合格したものだけ**マージする。

### Task 3: 透過スクリプト用意 + 参照画像確認
- [ ] `/tmp/transparentize_cats.py` を再生成([[codex_image_generation]] のパターン: PIL flood-fill・外側白のみ・THRESHOLD=230・エッジ alpha graded `255*nonwhite/24`)。内部の白(シェイカー本体/ヘッドバンド/靴下)は connected-component で残す。
- [ ] 参照画像パス = `app/.../cat_orange_waitingMorning_shaker.imageset/cat_orange_waitingMorning_shaker.png`。各猫種の通常 waitingMorning(`cat_<breed>_waitingMorning.png`)も参照に使い、**その猫種の柄/色**を保ちつつシェイカー+トラックスーツ+ヘッドバンドを合成する。

### Task 4: 10猫種を逐次生成 → 透過 → 1024² 化
対象: black/white/gray/calico/silvertabby/browntabby/siamese/tuxedo/persian/scottish。
- [ ] 各猫種、Codex に「参照1=orange shaker(ポーズ/装備/画風), 参照2=該当 breed の waitingMorning(柄/色)。**該当 breed の毛色・柄でシェイカーを持つ同じポーズ**を生成。白背景・1024²・/tmp に保存して `file` で verify」と指示。**逐次**(並列は事故る)。token 枯渇で Gemini 画像生成に切替。
- [ ] 生成後 `sips -z 1024 1024` + `/tmp/transparentize_cats.py` で透過。`/tmp/shaker_<breed>.png` に保存。
- [ ] 各画像を Claude(自分の目)で確認: 柄が breed と一致・青滲み無し・装備が orange と統一。

### Task 5: 3LLM トンマナ検証 → 合格分だけ imageset 追加
- [ ] 全候補(orange + 生成10)を1枚のコンタクトシート(`sips`/montage 代替で並べる)にし、Codex + Gemini に「11匹の画風・線・塗り・装備が統一されているか。**青色滲み・スタイル不一致**(過去 variant 一掃の原因)を指摘」と採点させる。
- [ ] 合格した猫種のみ `cat_<breed>_waitingMorning_shaker.imageset/`(Contents.json は orange のと同形式・1x スロット)を作成し PNG を配置。不合格は**追加しない**(フォールバックで通常 waiting が出る=破綻しない)。
- [ ] iCloud 重複チェック後ビルド GREEN。コミット(合格猫種ぶん):
```bash
git add app/GOExercise/GOExercise/Resources/Assets.xcassets/CatCharacter/cat_*_waitingMorning_shaker.imageset
git commit -m "assets(E): シェイカー猫 N猫種(3LLMトンマナ合格分)を追加" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 2: 検証(E: checklist 20-23)

### Task 6: テスト + スクショ
- [ ] `CatBreedShakerTests` green(build-for-testing。sim runner hang 時は build-for-testing + コードレビューで担保)。
- [ ] simctl スクショ: RecordCompletion(記録直後ヒーロー=shaker)+ Home今日未記録(catTheater=shaker)。orange は確実、生成合格 breed があればそれも。`--seed-demo-data --seed-scenario basic` 等 + 猫種切替で撮影。
- [ ] 3LLM で E20(トンマナ)/E21(構図)/E22(表示タイミング)を採点。2点未満は再生成 or その breed を見送り。

### Task 7: 後片付け + メモリ更新
- [ ] 一時ファイル削除。ビルド GREEN。Info.plist キー確認。
- [ ] メモリ `achievement_luxury_redesign.md` を「計画③完了・装飾リデザインA〜F全完了」に更新。生成できた猫種数を記録。

---

## Self-Review(spec E 突き合わせ)
- アセット全11種 `cat_<breed>_waitingMorning_shaker`(orange 流用+10生成)— Task4/5(合格分のみ・フォールバックで安全)✅
- 品質ガード(flood-fill 透過・青滲み/不一致を 3LLM で排除)— Task3/5 ✅
- 表示=記録直後ヒーロー + ホーム未記録の待機 — Task2 ✅
- フォールバック(画像欠落で通常 waitingMorning / orange shaker)— Task1 `resolvedShakerAssetName` ✅
- 解決ロジック=`shakerAssetName` 純プロパティ + 存在チェック — Task1 ✅
- テスト=全11種 asset 名規約 / 欠落フォールバック — Task1 ✅
- 達成段階(CatRank)と無関係 — useShaker は todayStatus のみ依存 ✅

**型一貫性**: `CatBreed.shakerAssetName` / `.resolvedShakerAssetName(exists:)` / `BigCatView(state:useShaker:)` — 全タスク一致。
</content>
