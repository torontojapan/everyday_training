# 猫種(breed)課金解放 実装計画 (iOS / v1.1)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development。Steps use checkbox syntax.

**Goal:** 無料=オレンジ限定 / プレミアム購読で11種から選び放題 / 解約後も今の猫は維持(変更だけ不可)。

**Architecture:** ロック判定は純関数 `CatBreedAccess.isLocked(breed, current, isPremium)`。`UserCatPickerView` で `StoreKitManager.isPremiumActive` を参照し、ロックされた猫セルは🔒表示+タップでペイウォール。確定ボタンは選択中(=常に非ロック)を保存。新規既定オレンジは既存挙動(変更不要)。

**Tech Stack:** Swift/SwiftUI/XCTest。対象 `app/GOExercise`。ブランチ `feature/achievement-decorations`(同branchに追加 or 新branch可。本計画は同branch継続を想定)。

**前提:** スペック `docs/superpowers/specs/2026-06-05-cat-breed-monetization-design.md`。`UserCatPickerView.swift`(11種グリッド・`prefs.myCat=selected`で確定・onboarding=GOExerciseApp:52 / 設定=SettingsView:294 で提示)。`StoreKitManager` は app root で `.environment` 注入済=ピッカーで `@Environment(StoreKitManager.self)` 取得可。`PremiumPaywallSheet(store:context:)` の context は `.weight`/`.general`。

**環境注意:** iOSシミュレータのテストランナーがハングするため `xcodebuild test` は実行しない。検証は `xcodebuild build`(UI)と controller 側のネイティブ確認(純ロジック)。

---

## Task 1: ロック判定の純関数 + テスト

**Files:**
- Create: `app/GOExercise/GOExercise/Models/CatBreedAccess.swift`
- Test: `app/GOExercise/GOExerciseTests/CatBreedAccessTests.swift`

- [ ] **Step 1: 失敗するテスト**
```swift
import XCTest
@testable import GOExercise

final class CatBreedAccessTests: XCTestCase {
    func test_premium_unlocksAll() {
        XCTAssertFalse(CatBreedAccess.isLocked(.black, current: .orange, isPremium: true))
        XCTAssertFalse(CatBreedAccess.isLocked(.orange, current: .orange, isPremium: true))
    }
    func test_nonPremium_lockedExceptCurrent() {
        // 新規(current=orange): orangeのみ解放
        XCTAssertFalse(CatBreedAccess.isLocked(.orange, current: .orange, isPremium: false))
        XCTAssertTrue(CatBreedAccess.isLocked(.black,  current: .orange, isPremium: false))
        // 解約後(current=tabby): 今の猫は維持・他はロック
        XCTAssertFalse(CatBreedAccess.isLocked(.browntabby, current: .browntabby, isPremium: false))
        XCTAssertTrue(CatBreedAccess.isLocked(.orange,      current: .browntabby, isPremium: false))
    }
}
```

- [ ] **Step 2: 失敗確認(compile)** `xcodebuild build-for-testing -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E 'error:|TEST BUILD SUCCEEDED'` → `CatBreedAccess` 未定義エラー。

- [ ] **Step 3: 実装**
```swift
// CatBreedAccess.swift
import Foundation

/// 猫種選択のロック判定(課金解放)。
/// 無料(非プレミアム)は「今の猫」以外ロック=新規はオレンジ限定、解約後は今の猫維持・変更不可。
enum CatBreedAccess {
    static func isLocked(_ breed: CatBreed, current: CatBreed, isPremium: Bool) -> Bool {
        !isPremium && breed != current
    }
}
```

- [ ] **Step 4: compile成功確認** 同コマンド → `TEST BUILD SUCCEEDED`。

- [ ] **Step 5: commit**
```bash
git add app/GOExercise/GOExercise/Models/CatBreedAccess.swift app/GOExercise/GOExerciseTests/CatBreedAccessTests.swift
git commit -m "feat(breed-iap): 猫種ロック判定の純関数CatBreedAccess+test"
```

---

## Task 2: ピッカーにロックUI+ペイウォールを差し込む

**Files:**
- Modify: `app/GOExercise/GOExercise/Views/UserCatPickerView.swift`

- [ ] **Step 1: StoreKit環境 + paywall state を追加**
`UserCatPickerView` の `@State private var selected: CatBreed` 付近に:
```swift
    @Environment(StoreKitManager.self) private var storeKit
    @State private var showPaywall = false
```

- [ ] **Step 2: cell をロック対応にする**
`private func cell(_ breed: CatBreed)` を、ロック時は🔒オーバーレイ+減光、タップでペイウォール、非ロック時は従来選択、に変更:
```swift
    private func cell(_ breed: CatBreed) -> some View {
        let isSelected = selected == breed
        let locked = CatBreedAccess.isLocked(breed, current: prefs.myCat, isPremium: storeKit.isPremiumActive)
        return Button {
            if locked { showPaywall = true } else { selected = breed }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(breed.tintColor.opacity(0.30))
                        .frame(width: 64, height: 64)
                    Image(breed.avatarAssetName)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(1.10)
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                        .opacity(locked ? 0.45 : 1)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(isSelected ? Palette.primaryDeep : .clear, lineWidth: 3)
                        .frame(width: 64, height: 64)
                }
                Text(breed.displayName)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Palette.primaryDeep : Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? "\(breed.displayName)(プレミアムで解放)" : breed.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("user-cat-\(breed.rawValue)")
    }
```

- [ ] **Step 3: ペイウォールシートを presentation に追加**
`body` の `NavigationStack { ScrollView { ... } ... }` の末尾(`.interactiveDismissDisabled(isOnboarding)` の後)に:
```swift
            .sheet(isPresented: $showPaywall) {
                PremiumPaywallSheet(store: storeKit, context: .general)
            }
```

- [ ] **Step 4: 確定ボタンの安全策**
`Button(isOnboarding ? "はじめる" : "決定")` の action 先頭で、選択中がロックなら現状維持にフォールバック(理論上ロックは選択不可だが防御的に):
```swift
                        if CatBreedAccess.isLocked(selected, current: prefs.myCat, isPremium: storeKit.isPremiumActive) {
                            selected = prefs.myCat
                        }
                        prefs.myCat = selected
```

- [ ] **Step 5: build** `xcodebuild build -scheme GOExercise -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'error:|BUILD SUCCEEDED|BUILD FAILED'` → `BUILD SUCCEEDED`。

- [ ] **Step 6: commit**
```bash
git add app/GOExercise/GOExercise/Views/UserCatPickerView.swift
git commit -m "feat(breed-iap): 猫種ピッカーを課金ゲート(非プレミアムは今の猫以外ロック+ペイウォール)"
```

---

## Self-Review
- スペック §2(無料=オレンジ/プレミアム選び放題/解約後維持・変更不可) → `isLocked = !premium && breed != current`(新規current=orange / 解約後current=保存済breed)で全成立。§3(isPremiumActiveゲート・既定オレンジ既存) → Task2 + 既存UserCatPreferences。§6 ストア規約=コスメ・既存IAP。
- 型整合: `CatBreedAccess.isLocked(_:current:isPremium:)` を Task1定義→Task2使用で一貫。
- 新規既定オレンジは `UserCatPreferences` 既存挙動につき変更不要(明記)。
- ペイウォール context は `.general`(猫向け訴求文の追加は任意フォローアップ)。
