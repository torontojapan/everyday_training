# 達成背景の作り替え 実装計画 (iOS)

> 実装は visual iteration(build→seed→自前スクショ→調整)+ Codex改善ループで進める。純ロジックは TDD。

**Goal:** 画像カード `bg_milestone` を廃し、達成日数で**ホーム全面背景**が段階的に豪華になる `MilestoneBackdrop`(テーマ連動グラデ+tierで増える控えめ粒子/グロー+最上位のみ微動)に作り替える。

**前提:** spec `docs/superpowers/specs/2026-06-06-milestone-backdrop-design.md`。HomeView body は `NavigationStack{ ZStack{ backgroundGradient.ignoresSafeArea(); AmbientParticlesView(...); VStack{...} } }`(`HomeView.swift:32-`)。BigCatView は `MilestoneBackgroundView(totalAchievedDays:)`(`HomeView.swift:505`)。FriendAvatarView は `showsMilestoneBackground` で `MilestoneBackgroundView`(`FriendAvatarView.swift:20-25`)。`Palette.background`=テーマ背景、`Palette.primary`=テーマ主色。既存 `MilestoneBackground.thresholds`=[7,14,30,50,75,100,150,200,300,365,500]。ブランチ `feature/referral-rewards-v12`。

**検証:** iOS sim テストランナーはハングのため純ロジックは swiftc ネイティブ + XCTest コンパイル。UI は **simctl で seed 起動 → 自前スクショ**(App Group 回避: `SIMCTL_CHILD_XCTestConfigurationFilePath=/tmp/x`、起動引数 `--seed-demo-data --seed-scenario <yearly|monthly> --skip-onboarding --skip-milestones`)。

## Task 1: 純ロジック `MilestoneBackdropStyle`(TDD)
- Create `Models/MilestoneBackdropStyle.swift`、Test 追記 `GOExerciseTests/MilestoneBackdropStyleTests.swift`。
- `struct MilestoneBackdropStyle { let tier:Int; let richness:Double; let glowOpacity:Double; let sparkleCount:Int; let animated:Bool; init(totalAchievedDays:) }`。
  - tier = `MilestoneBackground(totalAchievedDays:).tier`。
  - richness = `min(1, Double(tier)/11)`、glowOpacity = `richness*0.45`、sparkleCount = `tier==0 ?0: min(4+tier*2,24)`、animated = `tier>=10`。
- テスト: 0→(0,0,0,0,false)/7→tier1/100→tier6/365→tier10 animated/500→tier11 sparkle24。

## Task 2: `MilestoneBackdrop` View
- Create `Views/Components/MilestoneBackdrop.swift`。全面 ZStack(`ignoresSafeArea`):
  1. ベースグラデ: `Palette.background` → golden を richness で blend。
  2. 中心グロー: RadialGradient(golden, glowOpacity)。
  3. 粒子: sparkleCount 個、決定的配置(index seed)+ ゆっくり opacity twinkle。
  4. animated 時のみ: 斜めの淡い光帯(ゆっくり)。
- golden トーンは実装で調整(暖琥珀)。可読性のため全体 opacity 抑制。

## Task 3: HomeView 差し替え + BigCatView カード削除
- HomeView の `backgroundGradient.ignoresSafeArea()` を `MilestoneBackdrop(totalAchievedDays: viewModel.lifetimeStats.achievedDays).ignoresSafeArea()` に差し替え(AmbientParticlesView は残す)。
- BigCatView の ZStack 内 `MilestoneBackgroundView(totalAchievedDays:)`(:505)を削除。

## Task 4: FriendAvatarView 置換
- `MilestoneBackgroundView` 使用を、tier に応じた控えめ tint/グロー(小円内)に置換 or 削除。

## Task 5: visual iteration + Codex
- ビルド → seed(yearly / monthly / 0日)で自前スクショ → 見た目調整(richness/色/粒子)を納得まで反復。
- Codex で diff レビュー → 修正 → "patch is correct" まで。

## Self-Review
- spec 各節 → Task 対応。型: MilestoneBackdropStyle(tier/richness/glowOpacity/sparkleCount/animated) を Task1 定義 → Task2 で使用。HomeView/BigCatView/FriendAvatarView の差し替え点は上記行番号で特定済。
