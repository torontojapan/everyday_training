# 達成マイルストーン背景の作り替え(画像カード → 画面全体の豪華背景)設計

- 作成日: 2026-06-06
- 対象: GOエクササイズ(iOS 先行)
- 背景: 実機スクショで現状の `bg_milestone_NN` が「猫の後ろの四角い画像カード」=チープと判明([[growth-feature-specs-v11]] の①装飾)。
- 方針(ユーザー承認 2026-06-06): **B-refined**(全面グラデ + tierで増える控えめな粒子/グロー、最上位のみ微動)。

## 1. ゴール / 非ゴール
- ゴール: 達成日数に応じて**ホーム画面全体の最背面**が段階的に豪華になる。テーマ色連動・全部コード・画像アセット不要。毎日見ても疲れない落ち着きを保ちつつ達成のご褒美感を出す。
- 非ゴール: 既存マイルストーン演出(`MilestoneCelebrationSheet`)の変更。アバターの王冠/アイテム画像網羅(別件)。Android(後追い)。

## 2. アーキテクチャ
### 2.1 純ロジック `MilestoneBackdropStyle`
`init(totalAchievedDays: Int)` → 既存 `MilestoneBackground.thresholds`([7,14,30,50,75,100,150,200,300,365,500])で tier 0..11 を算出し、以下を導出(すべてテスト可能):
- `tier: Int`(0=装飾なし)
- `richness: Double` = `min(1, Double(tier) / 11)`(グラデの深さ 0..1)
- `glowOpacity: Double` = `richness * 0.45`(中心グローの濃さ)
- `sparkleCount: Int` = `tier == 0 ? 0 : min(4 + tier * 2, 24)`(粒子数。最大24で頭打ち)
- `animated: Bool` = `tier >= 10`(365日〜のみ最上位の微動を有効化)

### 2.2 View `MilestoneBackdrop`
`MilestoneBackdrop(totalAchievedDays: Int)`。最背面・全面(`ignoresSafeArea`)。`@Environment(ThemeStore.self)`(または `ThemeStore.shared`)からテーマ色を読む。レイヤー(下→上):
1. **ベースグラデ**: テーマ背景色 → 暖golden(`achievementTint`)を `richness` で blend した LinearGradient(topLeading→bottomTrailing)。tier0 は実質テーマ背景のまま。
2. **中心グロー**: 画面中央やや上の RadialGradient(golden, `glowOpacity`)。猫の後ろを優しく光らせる。
3. **粒子(きらめき)**: `sparkleCount` 個の小さな星/光点を**決定的な疑似乱数配置**(index ベース。`Math.random` 不使用=再描画でちらつかせない)。各粒子は**ゆっくり opacity twinkle**(2〜4秒、位相を index でずらす)。常時はほぼ静止=軽量。
4. **最上位の微動(animated 時のみ)**: 画面を斜めにゆっくり横切る淡い光の帯(1本、20〜30秒周期、低opacity)。tier<10 では描かない=常時負荷ゼロ。

**可読性**: 背景は全体に低コントラスト・低彩度寄りに抑え、猫とテキスト/カードが常にくっきり見えること。グロー/粒子は前面コンテンツの邪魔をしない opacity に。

**テーマ連動**: `achievementTint` は暖golden 基調。テーマ非暖色(sky/midnight/forest)でも golden を控えめに blend して調和させる(全テーマで破綻しない範囲)。

### 2.3 配置(HomeView)
- `HomeView` のルート背景を `Palette.background` 単色から `MilestoneBackdrop(totalAchievedDays:)` に差し替え(最背面、`ignoresSafeArea`)。コンテンツ(週カレ/猫/CTA等)はその上。
- `BigCatView` の ZStack 内にある `MilestoneBackgroundView(totalAchievedDays:)`(猫の後ろの四角い画像カード)を**削除**。猫の背後の光輪(Circle のグラデ)は残してよい。

### 2.4 既存資産の退役
- `MilestoneBackgroundView`(画像カード)と `bg_milestone_*` アセットは**ホームから外す**。`FriendAvatarView` も `MilestoneBackgroundView` を使っているため、友達アバターは **tier に応じた控えめな単色 tint かグロー**(小さい円内)に置換、または背景なしにする(小さい文脈なので簡素化)。`MilestoneBackgroundView.swift` 自体はアセット未存在で透明を返す安全実装なので、参照を消せば無害。アセット削除は任意(残しても未参照で無害)。
- `MilestoneBackground`(tier 算出の純ロジック)は `MilestoneBackdropStyle` から流用するため**残す**。

## 3. コンポーネント分割
- `Models/MilestoneBackdropStyle.swift`: 純ロジック(tier/richness/glow/sparkleCount/animated)。
- `Views/Components/MilestoneBackdrop.swift`: 全面背景 View(グラデ+グロー+粒子+最上位微動)。
- `Views/Components/SparkleField.swift`(任意・内部 private でも可): 粒子レイヤー。
- 変更: `HomeView`(ルート背景差し替え)、`BigCatView`(画像カード削除)、`FriendAvatarView`(MilestoneBackgroundView 置換)。

## 4. テスト
- 純ロジック `MilestoneBackdropStyle`: ネイティブ swiftc 実行 + XCTest コンパイル。
  - 0日→tier0/richness0/sparkle0/animated=false。
  - 7日→tier1。100日→tier6。365日→tier10/animated=true。500日→tier11/sparkle頭打ち24。
- View はビルド + **実機/シミュレータ スクショで目視**(本件はスクショ確認を必須とする)。

## 5. 実装順
1. 純ロジック `MilestoneBackdropStyle` + テスト。
2. `MilestoneBackdrop` View(グラデ+グロー+粒子+最上位微動)。
3. HomeView ルート背景差し替え + BigCatView の画像カード削除。
4. FriendAvatarView の背景置換。
5. ビルド + シード(yearly)で**スクショ目視** + Codex改善ループ。

## 6. オープン事項(実装で詰める)
- `achievementTint`(golden)の正確なトーンと各テーマでの blend 量。
- 粒子のアニメ実装(`TimelineView`/`Canvas` か `withAnimation` 繰り返し)— 軽さ優先で選択。
- 中間 tier の見え方差(段階が「効く」最小限の差)はスクショで調整。
