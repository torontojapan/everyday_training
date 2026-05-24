# Phase 3.5 Execute — UI/UX 中優先項目改善

あなたは Execute エージェント (Codex) です。Phase 1-3 で完成したコードベースに UI/UX 改善を**加算**してください。

## 厳守事項

1. **作業ディレクトリ**: `/Users/jun/Documents/Business_Project_Management/serial_training`
2. **変更を許可するパス**: `app/` 配下のみ
3. **必読**:
   - `specs/requirements_v1.md` §5 §22 §6
   - `artifacts/phase3.5/plan.md` (本フェーズの設計書)
   - 既存実装すべて (Phase 1-3 累積)
4. **スコープ**:
   - ホーム余白の活用 (TodayAchievementSummaryCard + WeeklyHighlightCard)
   - iPad NavigationSplitView (RootSplitView)
   - 記録入力の保存後 ConfirmationDialog
   - DatePicker アフォーダンス + 通知未許可 warning banner
   - 空状態の追加 (サジェスト 0 件時)
   - ハプティクスフィードバック (PrimaryButton + 保存 + 達成)
   - Reduce Motion 対応 (CatStateView, ConfettiView, Motion)
5. **対象外**:
   - 国際化, ダークモード本格対応, Dynamic Type 上限調整 (将来 Phase で対応)
6. **技術スタック**: iOS 17+ / Swift 6 / SwiftUI / WidgetKit / UserNotifications / XCTest

## 必須実装

### Services
- `ExerciseTrendSummary.swift` (`today(records:today:calendar:)` + `week(records:week:calendar:)`)

### Components
- `Views/Components/TodayAchievementSummaryCard.swift`
- `Views/Components/WeeklyHighlightCard.swift`
- `Views/Components/HapticFeedback.swift` (protocol + default impl)

### Views (新規)
- `Views/RootSplitView.swift` (iPad 専用 NavigationSplitView, sidebar = ホーム/履歴/設定)

### Views (拡張)
- `HomeView.swift`: 2 カードを ScrollView 内に追加 (今日達成済みの時のみ Today カード、週データありの時のみ Weekly カード)
- `RecordEntryView.swift`: 保存後の `.confirmationDialog` で 3 択 (続けて記録 / 完了画面 / キャンセル)
- `RecordEntryView.swift`: カテゴリ選択時にサジェスト 0 件なら "履歴がたまると、ここによく使う種目が出ます" 表示
- `NotificationSettingsView.swift`: 通知許可が `.denied` or `.notDetermined` の場合に warning banner (UIApplication.openSettingsURLString リンク付き)
- `NotificationSettingsView.swift`: DatePicker に chevron Image
- `Components/PrimaryButton.swift`: tap 時 scale + haptic
- `Components/ConfettiView.swift`: `@Environment(\.accessibilityReduceMotion)` で動作を抑制
- `Views/CatStateView.swift`: 同上
- `Theme/Motion.swift`: Reduce Motion 検知ヘルパー
- `CerealExerciseApp.swift`: `UIDevice.current.userInterfaceIdiom == .pad` で RootSplitView, それ以外で HomeView

### Tests (新規)
- `CerealExerciseTests/ExerciseTrendSummaryTests.swift` (5 件以上)
  - today() の categoryCounts / exerciseCount / totalDurationSeconds
  - week() の usedCategories / totalDurationSeconds / topExerciseNames
- `CerealExerciseTests/HapticFeedbackTests.swift` (3 件以上)
  - protocol を spy で渡し、success / warning / tap が呼ばれることを検証

## 制約

- ファイル冒頭コメント禁止 (本プロジェクト規約)
- Force unwrap / try! 禁止 (テスト・プレビュー除く)
- @MainActor / Sendable を適切に
- 既存テスト (57 件) を壊さない
- 既存 §24 受け入れ条件にリグレッションを起こさない

## 終了時にやること

`artifacts/phase3.5/execute_log.md` を作成:

```markdown
# Phase 3.5 Execute Log

## 実行者
Codex via `codex exec`

## 新規ファイル
- ...

## 変更ファイル
- ...

## 既知の未対応
- ...

## テスト
- 新規 X件、合計 Y件 PASS (期待値: 65件以上)
```

最後に build + test の確認:
```bash
xcodebuild -project app/CerealExercise/CerealExercise.xcodeproj -scheme CerealExercise \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  test 2>&1 | grep -E 'error:|Executed|TEST SUCCEEDED|TEST FAILED' | tail -10
```

並列ツール呼び出しで効率化OK。
