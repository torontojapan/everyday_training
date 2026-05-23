# Phase 1 Execute — SwiftUI MVPコア実装

あなたは Execute エージェント (Codex) です。Orchestrator (Claude) が作成した Plan に基づき、`/Users/jun/Documents/Business_Project_Management/serial_training/app/CerealExercise/` 配下に SwiftUI iOS アプリの Phase 1 実装を **コード生成のみで** 完了させてください。

## 厳守事項

1. **作業ディレクトリ**: `/Users/jun/Documents/Business_Project_Management/serial_training`
2. **変更を許可するパス**: `app/` 配下のみ。`specs/`, `agents/`, `artifacts/`, `orchestrator/`, `assets/`, `logs/`, ハーネス系ファイル (HARNESS.md / README.md / MEMORY.md) は **絶対に書き換えない**。読み取りはOK。
3. **要件と仕様の読み込み (必須)**:
   - `specs/requirements_v1.md` の §1〜§24
   - `artifacts/phase1/plan.md` (本フェーズの設計書)
4. **Phase 1 スコープ**: MVPコア (ホーム / 記録入力 / 記録完了 / データモデル / 達成判定 / 連続記録 / 週間達成率 / 休養日自動判定)
   - 通知, Widget, 履歴画面, 通知設定画面, キャラ画像差分は **Phase 1 では実装しない**
5. **技術スタック**: iOS 17+ / Swift 6 / SwiftUI / SwiftData / XCTest
6. **アプリ名**: `CerealExercise` / バンドルID: `com.serial.cerealexercise` / ロケール primary: ja
7. **コードスタイル**:
   - ファイル冒頭にコメントを書かない
   - Force unwrap (`!`), `try!` は禁止 (テスト・プレビュー除く)
   - 命名は Swift API Design Guidelines に従う
   - View は責務ごとに分割
   - SwiftUI の `@Observable` / `@Bindable` / `@Environment` を活用
   - `@MainActor` / `Sendable` 注釈は適切に付与
8. **テスト**: `CerealExerciseTests/` に各ロジック(達成判定/休養日/連続記録/週間達成率)の XCTest を各5件以上
9. **XcodeGen 対応**: `app/CerealExercise/project.yml` を作り、`xcodegen generate` で `CerealExercise.xcodeproj` を再生成可能にする
10. **ビルド検証はしない** (Xcode未インストール環境のため)。あなたは生成のみ担当。

## 期待するディレクトリ構造

```
app/CerealExercise/
├── project.yml                            # XcodeGen
├── CerealExercise/
│   ├── App/CerealExerciseApp.swift
│   ├── Models/
│   │   ├── WorkoutCategory.swift
│   │   ├── ExerciseItem.swift
│   │   ├── WorkoutRecord.swift
│   │   └── DailyStatus.swift
│   ├── Services/
│   │   ├── WorkoutStore.swift
│   │   ├── DateProvider.swift
│   │   ├── AchievementEvaluator.swift
│   │   ├── RestDayResolver.swift
│   │   ├── StreakCalculator.swift
│   │   ├── WeeklyProgressCalculator.swift
│   │   └── CatMessageProvider.swift
│   ├── ViewModels/
│   │   ├── HomeViewModel.swift
│   │   └── RecordEntryViewModel.swift
│   ├── Views/
│   │   ├── HomeView.swift
│   │   ├── RecordEntryView.swift
│   │   ├── ExerciseInputRow.swift
│   │   ├── RecordCompletionView.swift
│   │   ├── WeeklyCalendarView.swift
│   │   ├── StreakBadgeView.swift
│   │   ├── CatMessageView.swift
│   │   └── Components/
│   │       ├── PrimaryButton.swift
│   │       └── CategoryChip.swift
│   ├── Theme/
│   │   ├── Palette.swift
│   │   └── Typography.swift
│   └── Resources/
│       ├── Assets.xcassets/
│       │   ├── Contents.json
│       │   ├── AccentColor.colorset/
│       │   └── AppIcon.appiconset/
│       └── Info.plist
└── CerealExerciseTests/
    ├── AchievementEvaluatorTests.swift
    ├── RestDayResolverTests.swift
    ├── StreakCalculatorTests.swift
    └── WeeklyProgressCalculatorTests.swift
```

## 実装ガイド (Plan の補足)

### WorkoutRecord (@Model)
- `exercises` は `[ExerciseItem]` を JSON `Data` として `exercisesData: Data` に保存し、computed property `exercises` で getter/setter
- `category` も同様に `categoryRaw: String` (rawValue) + computed `category: WorkoutCategory`
- `date` は `Calendar.current.startOfDay(for:)` で正規化して保存

### AchievementEvaluator
```swift
static func isAchieved(record: WorkoutRecord) -> Bool {
  let hasExercise = !record.exercises.isEmpty
  let totalSeconds = record.exercises.reduce(0) { $0 + ($1.durationSeconds ?? 0) }
  return hasExercise || totalSeconds >= 60
}
```

### RestDayResolver
- 当週 (月曜開始) の未記録日リスト
- 最大2日まで休養日扱い、3日目以降は未達成

### StreakCalculator
- 今日から過去に向かって連続している (達成 or 休養) 日数を返す
- 未達成日に当たったら停止

### WeeklyProgressCalculator
- 月〜日 (Calendar 設定で月曜始まり) の DailyStatus 配列
- 達成数 = achieved + rest + todayAchieved

### CatMessageProvider
- 入力: DailyStatus + 時間帯 (morning/noon/evening/night)
- 出力: 文言 (要件 §21 から決定論的に1つ選ぶか、種を date で固定)

### View 実装ポイント
- HomeView は `NavigationStack` で RecordEntryView を `.navigationDestination` または `.sheet`
- RecordEntryView は Form ベース、種目は `ForEach` + `Add` ボタン
- WeeklyCalendarView は 7セル横並び (HStack)、今日セルはアクセント色
- CatMessageView は emoji 🐱 + 角丸カード + 吹き出し風

### Theme/Palette (ポップで柔らかい)
- 黒基調は禁止。クリーム背景 + コーラル/ピーチ アクセント
- 角丸 16〜24pt
- SF Rounded フォント (`.system(.body, design: .rounded)`)

### project.yml (XcodeGen)
```yaml
name: CerealExercise
options:
  bundleIdPrefix: com.serial
  deploymentTarget:
    iOS: "17.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
    DEVELOPMENT_TEAM: ""
    CODE_SIGN_STYLE: Automatic
targets:
  CerealExercise:
    type: application
    platform: iOS
    sources:
      - path: CerealExercise
        excludes: ["Resources/Info.plist"]
    resources:
      - path: CerealExercise/Resources/Assets.xcassets
    info:
      path: CerealExercise/Resources/Info.plist
      properties:
        CFBundleDisplayName: シリアルエクササイズ
        UILaunchScreen: {}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.serial.cerealexercise
        TARGETED_DEVICE_FAMILY: "1"
  CerealExerciseTests:
    type: bundle.unit-test
    platform: iOS
    sources: CerealExerciseTests
    dependencies:
      - target: CerealExercise
```

### Info.plist (最低限)
- CFBundleName, CFBundleDisplayName, CFBundleVersion, CFBundleShortVersionString
- UILaunchScreen
- 通知/Widget は Phase 2 で追加

## 終了時にやること

`artifacts/phase1/execute_log.md` を新規作成し、以下を記載:

```markdown
# Phase 1 Execute Log

## 実行者
Codex (`gpt-5-codex` 等) via `codex exec`

## 生成・変更したファイル
- app/CerealExercise/project.yml (新規)
- app/CerealExercise/CerealExercise/App/CerealExerciseApp.swift (新規)
- ...

## 実装方針メモ
- (Plan に対して採用した解釈や、Plan から逸脱した点があれば理由とともに記載)

## ビルド/テスト確認
- Xcode 未インストールのため未実施
- 静的に見て構文OKを期待

## 既知の未対応
- (もしあれば)
```

## 開始

それでは Phase 1 の実装を開始してください。
- 既存ファイルは現時点では存在しないはずです (新規プロジェクト)
- 並列ツール呼び出しで効率化してOK
- 完成後、`artifacts/phase1/execute_log.md` を必ず作成
