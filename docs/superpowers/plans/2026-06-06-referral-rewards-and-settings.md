# 紹介リワード(ホームスター+猫解放)& 設定リデザイン 実装計画 (iOS / v1.2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (推奨)。Steps は checkbox(`- [ ]`)で進捗管理。

**Goal:** ホーム上部に紹介スター行(0=枠星/1〜9=金星+10枠進捗/10=全点灯+お祝い/11+=「⭐N」、タップで招待共有)を出し、⭐10で猫種を無料解放する。あわせて設定画面を13→6グループに再編し、無料特典ガイド(折りたたみ)を追加する。

**Architecture:** 表示・解放判定は純関数(`ReferralStarsDisplay` / `ReferralReward` / `CatBreedAccess` 拡張)。星の元データは既存 `referralStore.summary.starBadges`(スキーマ変更ゼロ)。設定は機能・遷移を変えず `Section` のグルーピング/並び/折りたたみのみ再構成。

**Tech Stack:** Swift 6 / SwiftUI / XCTest(コンパイルゲート)+ swiftc ネイティブ実行(純ロジック)。対象 `app/GOExercise`。ブランチ `feature/referral-rewards-v12`(iOS v1.1 の上)。

**前提/環境:**
- スペック `docs/superpowers/specs/2026-06-06-referral-rewards-and-settings-design.md`。
- `referralStore`(`@Environment(ReferralStore.self)`)は HomeView / SettingsView / UserCatPickerView で注入済(v1.1)。`referralStore.summary.starBadges: Int`。
- **iOS シミュレータのテストランナーはハングするため `xcodebuild test` は不可**。純ロジック=新規 `.swift` を一時 main と `swiftc` でネイティブ実行、XCTest=`build-for-testing` でコンパイル、UI=`xcodebuild build`。
- **xcodegen の Info.plist 落ちは恒久修正済**([[gotcha-xcodegen-infoplist-drop]])。新ファイルはフォルダglobで取込。dev 検証中は local pbxproj 手当てでも可。
- 既存 `CatBreedAccess.isLocked(_:current:isPremium:)`、`UserCatPickerView`(`cell(_:)` と確定ボタンで `CatBreedAccess.isLocked` を使用、`referralStore` 注入済)、`HomeView` body の `VStack(spacing:12){ weeklyMini; topStatusBar }`(`HomeView.swift:51-54`)、`SettingsView` は `List{ Section... }`(`SettingsView.swift:38-`)。

**共通コマンド:**
```bash
cd app/GOExercise
# UI/サービス
xcodebuild build -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'
# XCTest コンパイル
xcodebuild build-for-testing -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|TEST BUILD SUCCEEDED|BUILD FAILED'
```

---

## ファイル構成

**作成:**
- `app/GOExercise/GOExercise/Models/ReferralStarsDisplay.swift` — 星表示モードの純ロジック + `ReferralReward`(閾値・解放判定)。
- `app/GOExercise/GOExercise/Views/Components/ReferralStarsRow.swift` — ホームのスター行 View(タップで招待共有)。
- `app/GOExercise/GOExercise/Views/Components/PerkGuide.swift` — 無料特典ガイドのデータ(`PerkGuideItem`)+ 折りたたみ View。
- `app/GOExercise/GOExerciseTests/ReferralRewardsTests.swift` — 純ロジック XCTest。

**変更:**
- `app/GOExercise/GOExercise/Models/CatBreedAccess.swift` — `isLocked` に `referralUnlocked` 追加。
- `app/GOExercise/GOExercise/Services/ReferralStore.swift` — 猫解放お祝いの未表示フラグ + `pendingBreedUnlock`。
- `app/GOExercise/GOExercise/Views/HomeView.swift` — スター行を `topStatusBar` の下に追加 + 解放お祝い提示。
- `app/GOExercise/GOExercise/Views/UserCatPickerView.swift` — `referralUnlocked` を `isLocked` に渡す。
- `app/GOExercise/GOExercise/Views/SettingsView.swift` — 6グループ再編 + 特典ガイド差し込み。

---

## Task 1: 純ロジック(星表示 + 報酬閾値 + ロック拡張)

**Files:**
- Create: `app/GOExercise/GOExercise/Models/ReferralStarsDisplay.swift`
- Modify: `app/GOExercise/GOExercise/Models/CatBreedAccess.swift`
- Test: `app/GOExercise/GOExerciseTests/ReferralRewardsTests.swift`

- [ ] **Step 1: 失敗するテストを書く**

`app/GOExercise/GOExerciseTests/ReferralRewardsTests.swift`:
```swift
import XCTest
@testable import GOExercise

final class ReferralRewardsTests: XCTestCase {
    // MARK: ReferralStarsDisplay
    func test_stars_zero_isGhost() {
        XCTAssertEqual(ReferralStarsDisplay.style(count: 0), .ghost)
    }
    func test_stars_oneToNine_isProgressToTen() {
        XCTAssertEqual(ReferralStarsDisplay.style(count: 1), .progress(filled: 1, total: 10))
        XCTAssertEqual(ReferralStarsDisplay.style(count: 9), .progress(filled: 9, total: 10))
    }
    func test_stars_ten_isComplete() {
        XCTAssertEqual(ReferralStarsDisplay.style(count: 10), .complete)
    }
    func test_stars_elevenPlus_isCollapsed() {
        XCTAssertEqual(ReferralStarsDisplay.style(count: 11), .collapsed(11))
        XCTAssertEqual(ReferralStarsDisplay.style(count: 25), .collapsed(25))
    }
    // MARK: ReferralReward
    func test_breedUnlock_threshold() {
        XCTAssertEqual(ReferralReward.breedUnlockThreshold, 10)
        XCTAssertFalse(ReferralReward.isBreedUnlocked(starBadges: 9))
        XCTAssertTrue(ReferralReward.isBreedUnlocked(starBadges: 10))
        XCTAssertTrue(ReferralReward.isBreedUnlocked(starBadges: 11))
    }
    // MARK: CatBreedAccess + referralUnlocked
    func test_catBreed_referralUnlock_unlocksAll() {
        // 非プレミアムでも referralUnlocked なら今の猫以外も解放
        XCTAssertFalse(CatBreedAccess.isLocked(.black, current: .orange, isPremium: false, referralUnlocked: true))
        // referralUnlocked=false は従来どおりロック
        XCTAssertTrue(CatBreedAccess.isLocked(.black, current: .orange, isPremium: false, referralUnlocked: false))
        // プレミアムは常に解放
        XCTAssertFalse(CatBreedAccess.isLocked(.black, current: .orange, isPremium: true, referralUnlocked: false))
        // 旧API(referralUnlocked省略)は従来挙動
        XCTAssertTrue(CatBreedAccess.isLocked(.black, current: .orange, isPremium: false))
    }
}
```

- [ ] **Step 2: 実装(星 + 報酬)**

`app/GOExercise/GOExercise/Models/ReferralStarsDisplay.swift`:
```swift
import Foundation

/// ホームの紹介スター行の表示モード(純ロジック)。iOS/Android 共通仕様。
enum ReferralStarsDisplay: Equatable {
    case ghost                              // 0個: 薄い枠星1個
    case progress(filled: Int, total: Int)  // 1〜9個: 金星 filled + 枠星 (total-filled)
    case complete                           // 10個: 全点灯
    case collapsed(Int)                     // 11個以上: 「⭐ N」

    static func style(count: Int) -> ReferralStarsDisplay {
        switch count {
        case ..<1:  return .ghost
        case 1...9: return .progress(filled: count, total: ReferralReward.breedUnlockThreshold)
        case 10:    return .complete
        default:    return .collapsed(count)
        }
    }
}

/// 紹介の報酬閾値と解放判定(純ロジック)。
enum ReferralReward {
    /// この数の紹介(⭐)で猫種が無料解放される。
    static let breedUnlockThreshold = 10
    static func isBreedUnlocked(starBadges: Int) -> Bool {
        starBadges >= breedUnlockThreshold
    }
}
```

- [ ] **Step 3: 実装(CatBreedAccess 拡張)**

`CatBreedAccess.swift` の `isLocked` を置換:
```swift
// CatBreedAccess.swift
import Foundation

/// 猫種選択のロック判定(課金解放)。
/// 無料(非プレミアム)は「今の猫」以外ロック=新規はオレンジ限定、解約後は今の猫維持・変更不可。
/// ただし紹介⭐10個達成(referralUnlocked)なら無料でも全種解放。
enum CatBreedAccess {
    static func isLocked(_ breed: CatBreed, current: CatBreed,
                         isPremium: Bool, referralUnlocked: Bool = false) -> Bool {
        !isPremium && !referralUnlocked && breed != current
    }
}
```

- [ ] **Step 4: ネイティブ実行(星+報酬の純ロジック実証)**

`/tmp/rewards_check.swift`(コミットしない):
```swift
import Foundation
enum ReferralReward { static let breedUnlockThreshold = 10
    static func isBreedUnlocked(starBadges: Int) -> Bool { starBadges >= breedUnlockThreshold } }
enum ReferralStarsDisplay: Equatable {
    case ghost; case progress(filled: Int, total: Int); case complete; case collapsed(Int)
    static func style(count: Int) -> ReferralStarsDisplay {
        switch count { case ..<1: return .ghost; case 1...9: return .progress(filled: count, total: 10)
        case 10: return .complete; default: return .collapsed(count) } } }
assert(ReferralStarsDisplay.style(count: 0) == .ghost)
assert(ReferralStarsDisplay.style(count: 1) == .progress(filled: 1, total: 10))
assert(ReferralStarsDisplay.style(count: 9) == .progress(filled: 9, total: 10))
assert(ReferralStarsDisplay.style(count: 10) == .complete)
assert(ReferralStarsDisplay.style(count: 11) == .collapsed(11))
assert(!ReferralReward.isBreedUnlocked(starBadges: 9))
assert(ReferralReward.isBreedUnlocked(starBadges: 10))
print("Rewards logic OK")
```
Run:
```bash
swiftc -Onone /tmp/rewards_check.swift -o /tmp/rewards_check && /tmp/rewards_check && rm -f /tmp/rewards_check /tmp/rewards_check.swift
```
Expected: `Rewards logic OK`。

- [ ] **Step 5: XCTest コンパイル**

Run: `xcodebuild build-for-testing ...`(共通コマンド)→ `TEST BUILD SUCCEEDED`(`error:` 無し)。

- [ ] **Step 6: commit**
```bash
cd /Users/jun/Documents/Business_Project_Management/serial_training
git add app/GOExercise/GOExercise/Models/ReferralStarsDisplay.swift app/GOExercise/GOExercise/Models/CatBreedAccess.swift app/GOExercise/GOExerciseTests/ReferralRewardsTests.swift
git commit -m "feat(v12): 星表示ロジックReferralStarsDisplay+報酬閾値+CatBreedAccess解放拡張(純ロジック)"
```

---

## Task 2: ホームのスター行 View + タップ招待共有

**Files:**
- Create: `app/GOExercise/GOExercise/Views/Components/ReferralStarsRow.swift`
- Modify: `app/GOExercise/GOExercise/Views/HomeView.swift`

- [ ] **Step 1: スター行 View を作成**

`app/GOExercise/GOExercise/Views/Components/ReferralStarsRow.swift`:
```swift
import SwiftUI

/// ホーム上部の紹介スター行。`referralStore.summary.starBadges` を
/// `ReferralStarsDisplay` で出し分け、タップで招待を共有する。
/// 表示は呼び出し側で「サインイン時 かつ AppFeatureFlags.isReferralActive」に限定する。
struct ReferralStarsRow: View {
    let count: Int
    let friendCode: String

    private var inviteText: String {
        "GOエクササイズで一緒に運動しよう!オンボーディングでこの招待コードを入れると、お互いにフリーズがもらえます → \(friendCode)\nhttps://apps.apple.com/jp/app/id6774551663"
    }

    var body: some View {
        ShareLink(item: inviteText) {
            HStack(spacing: 6) {
                content
                if case let .progress(filled, total) = ReferralStarsDisplay.style(count: count), filled < total {
                    Text("あと\(total - filled)人で猫が解放")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("紹介スター \(count)。タップで友達を招待")
        .accessibilityIdentifier("home-referral-stars")
    }

    @ViewBuilder
    private var content: some View {
        switch ReferralStarsDisplay.style(count: count) {
        case .ghost:
            star(filled: false)
        case let .progress(filled, total):
            // 横に入らなければ2行目へ折り返す。
            FlowStars(filledCount: filled, totalCount: total)
        case .complete:
            FlowStars(filledCount: 10, totalCount: 10)
        case let .collapsed(n):
            HStack(spacing: 4) {
                star(filled: true)
                Text("\(n)").font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
            }
        }
    }

    private func star(filled: Bool) -> some View {
        Image(systemName: filled ? "star.fill" : "star")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(filled ? Palette.primary : Palette.textSecondary.opacity(0.3))
    }
}

/// 星を横に並べ、幅に入らなければ折り返す簡易フロー(金 filled + 枠 total-filled)。
private struct FlowStars: View {
    let filledCount: Int
    let totalCount: Int
    var body: some View {
        // SwiftUI 標準の折り返しは LazyVGrid の adaptive で代用。星サイズに合わせ最小幅指定。
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 22), spacing: 4)], alignment: .leading, spacing: 4) {
            ForEach(0..<max(totalCount, filledCount), id: \.self) { i in
                Image(systemName: i < filledCount ? "star.fill" : "star")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(i < filledCount ? Palette.primary : Palette.textSecondary.opacity(0.3))
            }
        }
    }
}
```
注: `Palette.primary`(アクセント)が金/琥珀系でなければ、星の filled 色だけ `Palette` の暖色トークン(無ければ `Color.orange`)に差し替えてよい。ビルドして見た目で調整・報告。

- [ ] **Step 2: HomeView に行を差し込む**

`HomeView.swift:51-54` の `VStack(spacing: 12) { weeklyMini; topStatusBar }` を、`topStatusBar` の**下に**スター行を足す形に変更:
```swift
                    VStack(spacing: 12) {
                        weeklyMini
                        topStatusBar
                        if AppFeatureFlags.isReferralActive, let code = friendsStore.profile?.friendCode {
                            ReferralStarsRow(count: referralStore.summary.starBadges, friendCode: code)
                        }
                    }
```
(`friendsStore` / `referralStore` は HomeView に注入済。サインイン時=`profile?.friendCode` 非nil のときだけ表示=spec の方針。)

- [ ] **Step 3: ビルド**

`ReferralStarsRow.swift` を local pbxproj に追加(または無視して folder-glob 前提で `xcodebuild build`)。Run: `xcodebuild build ...` → `BUILD SUCCEEDED`。`Palette.primary` 等のトークンが無ければ近傍既存トークンに合わせて修正。

- [ ] **Step 4: commit**
```bash
git add app/GOExercise/GOExercise/Views/Components/ReferralStarsRow.swift app/GOExercise/GOExercise/Views/HomeView.swift
git commit -m "feat(v12): ホームに紹介スター行(進捗/省略/タップ招待共有)"
```

---

## Task 3: 猫種の無料解放配線 + 10到達お祝い

**Files:**
- Modify: `app/GOExercise/GOExercise/Views/UserCatPickerView.swift`
- Modify: `app/GOExercise/GOExercise/Services/ReferralStore.swift`
- Modify: `app/GOExercise/GOExercise/Views/HomeView.swift`

- [ ] **Step 1: UserCatPickerView で referralUnlocked を渡す**

`UserCatPickerView.swift` で `CatBreedAccess.isLocked(...)` を呼ぶ**2箇所**(`cell(_:)` 内 ~:110 と 確定ボタン ~:64)に `referralUnlocked:` を追加。まず computed を足す(`storeKit` 宣言付近):
```swift
    private var referralUnlocked: Bool {
        ReferralReward.isBreedUnlocked(starBadges: referralStore.summary.starBadges)
    }
```
そして両方の呼び出しを:
```swift
        CatBreedAccess.isLocked(breed, current: prefs.myCat, isPremium: storeKit.isPremiumActive, referralUnlocked: referralUnlocked)
```
(確定ボタン側は `selected` を渡している箇所も同様に `referralUnlocked: referralUnlocked` を付ける。)

- [ ] **Step 2: ReferralStore に解放お祝いフラグを追加**

`ReferralStore.swift` に、未表示フラグ(UserDefaults)+ 公開 state を追加。プロパティ群に:
```swift
    var pendingBreedUnlock = false
    private static let breedUnlockCelebratedKey = "referral.breedUnlockCelebrated.v1"
```
`refresh()` の `summary` 更新後に判定を足す(`_summary`/`summary` 更新の直後):
```swift
        // ⭐10 到達を初回だけ祝う。星は累計なので一度祝ったら二度と出さない。
        if ReferralReward.isBreedUnlocked(starBadges: summary.starBadges),
           !defaults.bool(forKey: Self.breedUnlockCelebratedKey) {
            defaults.set(true, forKey: Self.breedUnlockCelebratedKey)
            pendingBreedUnlock = true
        }
```
> 注: iOS の `ReferralStore` は `@Observable` クラスで `summary` は stored property、`defaults: UserDefaults` を保持している(v1.1 実装)。プロパティ名が異なる場合は読んで合わせる。`consumeBreedUnlock()` も足す:
```swift
    func consumeBreedUnlock() { pendingBreedUnlock = false }
```

- [ ] **Step 3: HomeView で解放お祝いを提示**

`HomeView.swift` の body 最外 View の modifier チェーン(既存の紹介ポップ `.sheet` 群の近く)に、解放お祝いの alert を追加:
```swift
        .alert("⭐10達成!", isPresented: Binding(
            get: { referralStore.pendingBreedUnlock },
            set: { if !$0 { referralStore.consumeBreedUnlock() } }
        )) {
            Button("やったね!", role: .cancel) { referralStore.consumeBreedUnlock() }
        } message: {
            Text("友達を10人紹介しました!設定や猫選びの画面から、好きな猫が無料で選べるようになりました。")
        }
```

- [ ] **Step 4: ビルド**

Run: `xcodebuild build ...` → `BUILD SUCCEEDED`。

- [ ] **Step 5: commit**
```bash
git add app/GOExercise/GOExercise/Views/UserCatPickerView.swift app/GOExercise/GOExercise/Services/ReferralStore.swift app/GOExercise/GOExercise/Views/HomeView.swift
git commit -m "feat(v12): ⭐10で猫種無料解放(CatBreedAccess配線)+到達お祝いalert"
```

---

## Task 4: 設定リデザイン(13→6グループ)

**Files:**
- Modify: `app/GOExercise/GOExercise/Views/SettingsView.swift`

**方針(重要):** 各設定項目の**機能・遷移先・Toggle のバインディング・accessibilityIdentifier は一切変えない**。`List` 内の `Section` の**グルーピング・並び順・見出し・折りたたみだけ**を再構成する。各項目の中身(ShareLink/NavigationLink/Button/Toggle のブロック)は現行から**verbatim で移動**する。

- [ ] **Step 1: 現行 body を読み、項目を把握**

`SettingsView.swift` の `body`(`List { ... }`)を読み、現行の各 Section の中身ブロックを特定する(アプリシェア / プレミアム / 通知 / 外観(テーマ・キャラ)/ 友達と共有する情報 / 友達を招待 / 演出(振動)/ 体調・周期 / ウィジェット / 自動休養日 / フィードバック / データ管理 / プライバシー / アプリ情報)。

- [ ] **Step 2: 6グループに再構成**

`body` の `List { ... }` を以下の順・グルーピングに置換する。**各 `/* 現行XXのブロックを verbatim */` には、現行 Section の中身(label/binding/destination 込み)をそのまま移す**:
```swift
        List {
            // ① プレミアム & 特典
            Section("プレミアム & 特典") {
                /* 現行プレミアムカード(加入中/アップグレード Button)を verbatim。footer は行内 Text に畳むか省略可 */
                PerkGuideSection()   // Task 5 で追加(折りたたみ・無料特典ガイド)
                /* 現行「友達を招待」セクションの中身(共有/⭐紹介数/後から入力)を verbatim。
                   AppFeatureFlags.isReferralActive のときだけ。元の Section ラッパは外し、この Section 内に置く */
            }

            // ② カスタマイズ
            Section("カスタマイズ") {
                /* 現行 外観の テーマカラー NavigationLink を verbatim */
                /* 現行 外観の 自分のキャラを変更 Button を verbatim */
                /* 現行 演出(振動)の 達成時の振動 Toggle を verbatim */
            }

            // ③ 記録 & 共有
            Section("記録 & 共有") {
                /* 現行 体調・周期 Toggle を verbatim */
                /* 現行 自動休養日 の行を verbatim */
                if AppFeatureFlags.friendsEnabled {
                    /* 現行「友達と共有する情報」の詳細共有 Toggle + 注記 を verbatim */
                }
            }

            // ④ 通知 & ウィジェット
            Section("通知 & ウィジェット") {
                /* 現行 通知設定 NavigationLink を verbatim */
                /* 現行 ホーム画面ウィジェット 追加方法 NavigationLink を verbatim */
            }

            // ⑤ データ & プライバシー
            Section("データ & プライバシー") {
                /* 現行 データを書き出す を verbatim */
                /* 現行 すべての記録を削除 を verbatim */
                /* 現行 利用状況の分析を共有 Toggle を verbatim */
            }

            // ⑥ 情報・サポート(折りたたみ既定閉)
            Section {
                DisclosureGroup("情報・サポート") {
                    /* 現行 フィードバック(ご意見/不具合)を verbatim */
                    /* 現行 サブスクリプションを管理 を verbatim */
                    /* 現行 プライバシーポリシー / 利用規約 / サポート を verbatim */
                }
            }
        }
```
- 最上部の「アプリを友達にシェア」(`AppSharingConfig.shareURL` の ShareLink)は **① の先頭 or ⑥ の中**に置く(招待=friend_code とは別物の「アプリ共有」なので、①プレミアム&特典の先頭が自然)。実装者判断で① 先頭に置く。
- footer の注記テキストは、対応する Section の `footer:` に残すか、長すぎる場合は省略してよい(情報量は特典ガイドへ集約)。
- 各ブロックを移す際、`Palette`/`Typography`/`accessibilityIdentifier`/binding を**変更しない**。

- [ ] **Step 3: ビルド**

Run: `xcodebuild build ...` → `BUILD SUCCEEDED`。`PerkGuideSection()` は Task 5 で作るので、Task 4 単体ビルドでは**一時的に** `EmptyView()` をその位置に置き、Task 5 で差し替える(または Task 4→5 を連続で実施し Task 5 のビルドで緑にする)。実装者はどちらでも良いが、コミット時点でビルドが緑であること。

- [ ] **Step 4: 目視確認(ビルドのみ・実行はXcode)**

セクション数が6、各項目の遷移/トグルが元のまま移っていることをコード上で確認(diff レビュー)。

- [ ] **Step 5: commit**
```bash
git add app/GOExercise/GOExercise/Views/SettingsView.swift
git commit -m "feat(v12): 設定を13→6グループに再編(機能・遷移は不変、グルーピングのみ)"
```

---

## Task 5: 無料特典・達成ガイド(折りたたみ)

**Files:**
- Create: `app/GOExercise/GOExercise/Views/Components/PerkGuide.swift`
- Modify: `app/GOExercise/GOExercise/Views/SettingsView.swift`(Task 4 の `PerkGuideSection()` を有効化)

- [ ] **Step 1: 特典ガイドのデータ + View を作成**

`app/GOExercise/GOExercise/Views/Components/PerkGuide.swift`:
```swift
import SwiftUI

/// 無料で得られる特典・達成イベント1項目。将来の特典追加はこの配列に足すだけ。
struct PerkGuideItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

enum PerkGuide {
    static let items: [PerkGuideItem] = [
        PerkGuideItem(icon: "snowflake", title: "連続記録フリーズ",
                      detail: "無料は月1 / プレミアムは月4。友達紹介で +1(上限5)。招待された人はウェルカム +1。"),
        PerkGuideItem(icon: "star.fill", title: "友達紹介",
                      detail: "1人紹介ごとに⭐とフリーズ。⭐10個で好きな猫が無料で選べるようになります。"),
        PerkGuideItem(icon: "sparkles", title: "達成装飾",
                      detail: "累計日数で背景が進化。30日でシェイカー、100日で王冠が付きます。"),
        PerkGuideItem(icon: "cat.fill", title: "猫種",
                      detail: "無料はオレンジ。プレミアム、または⭐10で全11種から選べます。"),
        PerkGuideItem(icon: "flame.fill", title: "連続記録の節目",
                      detail: "連続記録のマイルストーンでお祝い演出が出ます。"),
    ]
}

/// 設定の「無料特典・達成ガイド」折りたたみセクション(既定は閉)。
struct PerkGuideSection: View {
    var body: some View {
        DisclosureGroup {
            ForEach(PerkGuide.items) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: item.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.primary)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                        Text(item.detail)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .padding(.vertical, 2)
            }
        } label: {
            Label("無料でもらえる特典・達成", systemImage: "gift.fill")
                .foregroundStyle(Palette.textPrimary)
        }
        .accessibilityIdentifier("perk-guide-disclosure")
    }
}
```
注: `Typography.caption` が無ければ近傍既存トークンに置換。

- [ ] **Step 2: SettingsView で有効化**

Task 4 で① グループ内に置いた `PerkGuideSection()`(または一時 `EmptyView()`)を `PerkGuideSection()` にする(既に置いていればそのまま)。

- [ ] **Step 3: ビルド**

Run: `xcodebuild build ...` → `BUILD SUCCEEDED`(`PerkGuide.swift` を pbxproj/folder-glob で取込)。

- [ ] **Step 4: commit**
```bash
git add app/GOExercise/GOExercise/Views/Components/PerkGuide.swift app/GOExercise/GOExercise/Views/SettingsView.swift
git commit -m "feat(v12): 無料特典・達成ガイド(折りたたみ・配列駆動)を設定に追加"
```

---

## Task 6: 統合ビルド + 検証

**Files:** なし(検証)

- [ ] **Step 1: フルビルド** Run: `xcodebuild build ...` → `BUILD SUCCEEDED`。
- [ ] **Step 2: XCTest コンパイル** Run: `xcodebuild build-for-testing ...` → `TEST BUILD SUCCEEDED`。
- [ ] **Step 3: 純ロジック ネイティブ再実行**(Task 1 Step 4 の `/tmp/rewards_check.swift`)→ `Rewards logic OK`。
- [ ] **Step 4: キルスイッチ確認** `grep -rn "isReferralActive" app/GOExercise/GOExercise/Views/HomeView.swift` でスター行がゲートされていること。設定の特典ガイドは常時表示でよい(無害)。
- [ ] **Step 5: Info.plist 退行チェック** `git diff --stat app/GOExercise/GOExercise/Resources/Info.plist` → 差分なし(project.yml恒久修正済なので xcodegen 実行時も保持)。

---

## Self-Review

**スペック網羅:**
- Part1 §1.1 スター行(0=ghost/1-9=progress/10=complete/11+=collapsed・進捗テキスト・タップ共有・サインイン時のみ) → Task 1(ReferralStarsDisplay)+ Task 2(ReferralStarsRow + HomeView 配置 + ShareLink + `isReferralActive && profile.friendCode` ゲート)。✓
- Part1 §1.2 ⭐10で猫解放(CatBreedAccess referralUnlocked・恒久・到達お祝い・閾値10) → Task 1(CatBreedAccess拡張・ReferralReward)+ Task 3(UserCatPickerView配線・ReferralStore未表示フラグ・HomeView alert)。✓
- Part1 §1.3 データ=既存 starBadges・スキーマ変更ゼロ → 全Task で `referralStore.summary.starBadges` 参照のみ。✓
- Part2 §2.2 6グループ再編(機能・遷移不変) → Task 4。✓
- Part2 §2.3 特典ガイド(配列駆動・折りたたみ既定閉) → Task 5(PerkGuide.items + DisclosureGroup)。✓
- Part2 §2.4 スクロール削減(13→6・折りたたみ) → Task 4(6 Section)+ Task 5(DisclosureGroup既定閉)+ Task 4 ⑥(情報・サポート DisclosureGroup)。✓
- §3 コンポーネント分割(ReferralStarsDisplay/ReferralStarsRow/ReferralReward/CatBreedAccess拡張/PerkGuideItem/PerkGuideSection) → 各Taskで作成。✓
- §4 テスト(ネイティブ+XCTestコンパイル) → Task 1 Step 4/5、Task 6。✓

**型整合:**
- `ReferralStarsDisplay.style(count:) -> ReferralStarsDisplay`(.ghost/.progress(filled:total:)/.complete/.collapsed(_)) — Task1定義 → Task2(ReferralStarsRow)で switch。✓
- `ReferralReward.breedUnlockThreshold` / `isBreedUnlocked(starBadges:)` — Task1定義 → Task1(ReferralStarsDisplay.progress total)/ Task3(UserCatPickerView/ReferralStore)で参照。✓
- `CatBreedAccess.isLocked(_:current:isPremium:referralUnlocked:)`(default false) — Task1定義 → Task3(UserCatPickerView 2箇所)で使用。旧API互換維持。✓
- `ReferralStore.pendingBreedUnlock` / `consumeBreedUnlock()` — Task3定義 → Task3(HomeView alert)で参照。✓
- `PerkGuideSection()` — Task5定義 → Task4(① グループ)で配置。✓

**プレースホルダ走査:** 純ロジックは完全コード。UIは新規コンポーネント完全コード+配置指示。Task4の「現行ブロックを verbatim 移動」は**既存コードの移設**(新規記述ではない)ため許容=リファクタの性質上、全行再掲はせず移設対象を明示。デザイントークン不一致は「近傍に合わせ修正・報告」と明記。

**留意点(実装者向け):**
- 星の filled 色 `Palette.primary` が金/琥珀でなければ暖色に差し替え(見た目調整)。
- Task4→5 はビルド緑の都合上、連続実施推奨(`PerkGuideSection()` の前方参照を避ける)。
- スター行はサインイン時のみ表示(spec方針)。未サインインの大多数には出ない点は spec 既知の割り切り(将来 always-visible+tapでensureSignedIn は別途検討)。
