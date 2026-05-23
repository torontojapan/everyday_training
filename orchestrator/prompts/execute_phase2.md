# Phase 2 Execute — 通知 / Widget / 猫キャラ7状態 / 達成演出

あなたは Execute エージェント (Codex) です。Phase 1 で実装済みのコードベースに Phase 2 機能を**追加**してください。

## 厳守事項

1. **作業ディレクトリ**: `/Users/jun/Documents/Business_Project_Management/serial_training`
2. **変更を許可するパス**: `app/` 配下のみ。`specs/`, `agents/`, `artifacts/`, `orchestrator/`, `assets/`, `logs/`, ハーネス系ファイル (HARNESS.md / README.md / MEMORY.md) は **絶対に書き換えない**
3. **必読**:
   - `specs/requirements_v1.md` §13 §14 §6 §21 §24.5 §24.6
   - `artifacts/phase2/plan.md` (本フェーズの設計書)
   - 既存実装: `app/CerealExercise/` 全体 (Phase 1 を破壊しないため把握必須)
4. **Phase 2 スコープ**:
   - ローカル通知 (UserNotifications, デフォルト1日2回)
   - WidgetKit (small + medium)
   - 猫キャラ7状態 (CatState enum + CatStateResolver + CatStateView)
   - 達成演出 (RecordCompletionView にアニメ + ConfettiView)
   - App Group 経由のホスト⇔Widget データ共有
5. **対象外** (Phase 3 で扱う):
   - 通知設定画面 (NotificationSettingsView)
   - 履歴画面
   - UI 全体のブラッシュアップ
6. **技術スタック**: iOS 17+ / Swift 6 / SwiftUI / SwiftData / WidgetKit / UserNotifications / XCTest
7. **コードスタイル** (Phase 1 と同じ):
   - ファイル冒頭コメント禁止
   - Force unwrap / try! 禁止 (テスト・プレビュー除く)
   - `@MainActor` / `Sendable` を適切に
   - 命名は Swift API Design Guidelines
   - View は責務分割
8. **既存テスト (Phase 1) を壊さないこと**

## 必須実装

### Models
- `CatState.swift` (enum, rawValue は plan §4.1)
- `WidgetSnapshot.swift` (Codable struct, plan §3.2)

### Services
- `NotificationPermissionManager.swift` (UNUserNotificationCenter 許可リクエスト + 状態取得)
- `NotificationScheduler.swift` (`scheduleDaily(...)`, `cancelToday()`, `rescheduleAfterAchievement()`)
- `NotificationMessageProvider.swift` (時間帯 + 状態 → 文言)
- `SharedSnapshotStore.swift` (App Group UserDefaults 経由の WidgetSnapshot 読み書き、Suite name: `group.com.serial.cerealexercise`)
- `WidgetSnapshotPublisher.swift` (`publish(from: WorkoutStore, today: Date)` で SharedSnapshotStore 更新 + WidgetCenter.reload)
- `CatStateResolver.swift` (plan §4.2 の優先度ルール)

### ViewModels
- `HomeViewModel.swift` を拡張: catState 計算, RecordCompletionView 用に streakExtendedThisRun フラグ

### Views
- `CatStateView.swift` (CatState を受け取り emoji + 状態別装飾)
- `CatMessageView.swift` (既存) を CatStateView を内包する形にリファクタ
- `RecordCompletionView.swift` (既存) に達成演出追加 (spring + scale + ConfettiView)
- `Components/ConfettiView.swift` (SwiftUI ベース、軽量)

### App / Resources
- `CerealExerciseApp.swift` を拡張:
  - 起動時に通知許可をリクエスト (初回のみ)
  - 起動時 / シーン active 時に WidgetSnapshotPublisher.publish
  - 起動時 / 記録保存時に NotificationScheduler.rescheduleAfterAchievement
- `CerealExercise.entitlements` 新規 (App Groups: `group.com.serial.cerealexercise`)
- `Info.plist` に通知関連は iOS 13+ では不要だが、必要なキーがあれば追加 (`NSUserTrackingUsageDescription` は不要)

### Widget Extension
- `CerealExerciseWidget/` ディレクトリ新規
- `CerealExerciseWidget.swift` (@main WidgetBundle)
- `WidgetEntry.swift` (TimelineEntry)
- `WidgetProvider.swift` (TimelineProvider, SharedSnapshotStore から読む)
- `Views/SmallWidgetView.swift`
- `Views/MediumWidgetView.swift`
- `Views/WidgetCatView.swift`
- `Info.plist`
- `CerealExerciseWidget.entitlements` (App Groups: 同上)

### project.yml 拡張
- Widget extension target を追加 (`type: app-extension`, `platform: iOS`)
- 両ターゲットに entitlements 適用
- ホストアプリの dependencies に Widget extension を追加

### Tests
- `NotificationSchedulerTests.swift` (5件以上)
- `CatStateResolverTests.swift` (5件以上、7状態を網羅)
- `SharedSnapshotStoreTests.swift` (5件以上、シリアライズ/デシリアライズ)

## 注意

- 通知トーン: 要件 §13.4 §21 の文言を引用 (例: 「🐱 今日の運動、そろそろ一緒にやろ？」)
- WidgetSnapshot の `nightDeadlineHoursLeft` は `23:59 - 現在時刻` の時間 (整数)
- WidgetCenter.reloadAllTimelines() は **ホスト側のみ** 呼ぶ (Widget からは呼ばない)
- UserNotifications の許可リクエストは `Task { @MainActor in ... }` で非同期に
- SwiftUI Preview を実害なく動かすため、PreviewProvider 内ではダミーデータを使う
- App Group は実機テスト時に Apple Developer ポータルで作成が必要 (コード/entitlements で記述するだけでOK)

## 終了時にやること

`artifacts/phase2/execute_log.md` を新規作成:
```markdown
# Phase 2 Execute Log
## 実行者
Codex via `codex exec`

## 新規ファイル
- ...

## 変更ファイル (Phase 1 から)
- ...

## 実装方針メモ
- ...

## 既知の未対応
- 通知設定画面 (Phase 3)
- 履歴画面 (Phase 3)
- 猫画像差分 (画像生成APIキー設定後にアセット追加)

## テスト
- 新規 X 件追加、既存 Phase 1 テストは未変更
```

## 開始

開始してください。並列ツール呼び出しで効率化OK。
