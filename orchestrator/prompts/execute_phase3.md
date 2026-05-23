# Phase 3 Execute — 履歴 / 通知設定 / UI ブラッシュアップ / 表情差分 / 入力サジェスト

あなたは Execute エージェント (Codex) です。Phase 1/2 で実装済みのコードベースに Phase 3 機能を**追加**してください。

## 厳守事項

1. **作業ディレクトリ**: `/Users/jun/Documents/Business_Project_Management/serial_training`
2. **変更を許可するパス**: `app/` 配下のみ。`specs/`, `agents/`, `artifacts/`, `orchestrator/`, `assets/`, `logs/`, ハーネス系ファイル (HARNESS.md / README.md / MEMORY.md) は **絶対に書き換えない**
3. **必読**:
   - `specs/requirements_v1.md` §18.4 (履歴), §18.5 (設定), §13.5 (通知設定), §22.1 (操作性), §5 (デザイン方針), §6.4 (キャラ7状態)
   - `artifacts/phase3/plan.md` (本フェーズの設計書)
   - 既存実装: `app/CerealExercise/` 全体 (Phase 1/2)
4. **Phase 3 スコープ**:
   - 履歴画面 (HistoryView, HistoryRowView, HistoryViewModel)
   - 通知設定画面 (NotificationSettingsView, NotificationSettingsViewModel)
   - 設定画面 (SettingsView)
   - 入力サジェスト (ExerciseHistoryProvider, ExerciseInputRow 拡張)
   - キャラクター表情アニメ拡充 (CatStateView)
   - WeeklyCalendarView アクセシビリティ強化
   - Small Widget に円形プログレス追加
   - Motion プリセット (Theme/Motion.swift)
   - PrimaryButton にタップフィードバック追加
5. **対象外** (Phase 4 / 将来):
   - クラウド保存, Appleログイン, ヘルスケア連携, 月間カレンダー, AI 提案, 課金
6. **技術スタック**: iOS 17+ / Swift 6 / SwiftUI / SwiftData / WidgetKit / UserNotifications / XCTest
7. **コードスタイル** (Phase 1/2 と同じ):
   - ファイル冒頭コメント禁止
   - Force unwrap / try! 禁止 (テスト・プレビュー除く)
   - `@MainActor` / `Sendable` を適切に
   - 命名は Swift API Design Guidelines
   - View は責務分割
8. **既存テスト (Phase 1/2) を壊さないこと**

## 必須実装

### Models
- `ExerciseHistorySuggestion.swift` (Codable struct: name, lastUsedDate, count)

### Services
- `ExerciseHistoryProvider.swift` (`topExerciseNames(for: WorkoutCategory, limit: Int)` — 頻度 + 直近性のスコアリング)

### ViewModels
- `HistoryViewModel.swift` (`groupedByDate: [(Date, [WorkoutRecord])]`)
- `NotificationSettingsViewModel.swift` (NotificationSettingsStore を ViewModel から読み書き、変更時に NotificationScheduler 再起動)
- `RecordEntryViewModel.swift` 拡張: `suggestions(for category: WorkoutCategory) -> [String]`

### Views
- `HistoryView.swift` (NavigationStack の History 行、空状態は EmptyStateView)
- `HistoryRowView.swift` (要件 §18.4 表示例通り)
- `NotificationSettingsView.swift` (Toggle, DatePicker×2, Picker)
- `SettingsView.swift` (Notification + アプリ情報 セクション)
- `HomeView.swift` 拡張: NavigationStack の toolbar に履歴・設定アイコン
- `RecordEntryView.swift` 拡張: カテゴリ選択時にサジェスト ScrollView を表示
- `ExerciseInputRow.swift` 拡張: chip タップで TextField 挿入
- `WeeklyCalendarView.swift` 拡張: `.accessibilityElement(children: .ignore)` + label + value (例: 月曜日 / 達成済み)
- `RecordCompletionView.swift` 拡張: 連続更新時の追加演出 (火 emoji 散布 or 火炎エフェクト)
- `CatStateView.swift` 拡張: 7状態それぞれにアニメーション (floating/tilt/bounce/scale-rotate/breathing 等)
- `Components/EmptyStateView.swift` 新規 (image/emoji + メッセージ)

### Theme
- `Motion.swift` 新規 (snappy/gentle/bouncy プリセット)
- `Palette.swift` 拡張 (history/settings 用の補助カラー)
- `Typography.swift` 拡張 (見出しスタイル)

### Widget
- `CerealExerciseWidget/Views/SmallWidgetView.swift` 拡張: 円形プログレスリングと N/7 表示

### Tests
- `ExerciseHistoryProviderTests.swift` (5件以上 — 頻度, 直近性, カテゴリフィルタ, 空, limit)
- `NotificationSettingsViewModelTests.swift` (5件以上 — ON/OFF, 時刻変更, 回数変更, 既定値, 反映)

## 重要

- 画像生成 API キー未設定のため、キャラ画像は emoji + アニメーションで表現
- ただし `Image("cat_\(state.rawValue)")` が `Assets.xcassets` にあれば優先する分岐は実装すること (将来差し替え可能に)
- 履歴画面は `LazyVStack` または `List` で大量データに耐える
- NotificationSettingsView での変更は即時に NotificationScheduler に反映
- 通知ON時、Authorization が未取得なら `NotificationPermissionManager.requestAuthorization()` を呼ぶ

## 終了時にやること

`artifacts/phase3/execute_log.md` を新規作成:
```markdown
# Phase 3 Execute Log
## 実行者
Codex via `codex exec`

## 新規ファイル
- ...

## 変更ファイル (Phase 1/2 から)
- ...

## 実装方針メモ
- ...

## 既知の未対応
- ...

## テスト
- 新規 X 件追加、既存 Phase 1/2 テストは未変更
```

## 開始

並列ツール呼び出しで効率化OK。
