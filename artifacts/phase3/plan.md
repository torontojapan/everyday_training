# Phase 3 Plan — 改善 (履歴 / 通知設定 / UIブラッシュアップ / 表情差分 / 入力履歴)

## 0. フェーズゴール

要件書 §23 Phase 3 に対応する改善を完了し、MVP として App Store 提出可能なレベルに引き上げる。

スコープ:
1. **履歴画面** (§18.4): 過去の運動記録一覧
2. **通知設定画面** (§18.5, §13.5): ON/OFF, 通知時間1/2, 通知回数
3. **UIブラッシュアップ**: アニメーション・トランジション・配色微調整・余白・タップフィードバック
4. **キャラクター表情差分**: emoji + SF Symbol + 状態別アニメーションでの表情表現拡充 (画像差し替えは画像生成 API キー設定後)
5. **入力履歴・よく使う種目**: 過去の種目名サジェスト
6. **Phase 1/2 からの繰越**:
   - WeeklyCalendarView の accessibilityLabel/Value 強化 (Phase 1 Eval Low 指摘)
   - 達成時 UI のさらなるアニメーション洗練 (Phase 1 Eval Low 指摘)
   - Small Widget での週間達成率表現 (Phase 2 Eval Minor 指摘)

---

## 1. 追加・変更ファイル構成

```
app/CerealExercise/
├── CerealExercise/
│   ├── Models/
│   │   └── ExerciseHistorySuggestion.swift     # 新規: 過去種目名 + 直近使用日
│   ├── Services/
│   │   ├── ExerciseHistoryProvider.swift       # 新規: WorkoutStore から頻出種目名を抽出
│   │   └── ProgressRing.swift (Theme/)         # 新規: Small Widget 用円形プログレス
│   ├── ViewModels/
│   │   ├── HistoryViewModel.swift              # 新規: 履歴画面の状態
│   │   ├── NotificationSettingsViewModel.swift # 新規: 通知設定の状態
│   │   └── RecordEntryViewModel.swift          # 拡張: suggestions プロパティ追加
│   ├── Views/
│   │   ├── HistoryView.swift                   # 新規: 履歴一覧
│   │   ├── HistoryRowView.swift                # 新規: 履歴1行
│   │   ├── NotificationSettingsView.swift      # 新規: 通知設定 UI
│   │   ├── SettingsView.swift                  # 新規: 設定画面 (通知設定 + アプリ情報)
│   │   ├── HomeView.swift                      # 拡張: 履歴・設定への遷移ボタン (ツールバー)
│   │   ├── RecordEntryView.swift               # 拡張: 種目名サジェスト UI
│   │   ├── ExerciseInputRow.swift              # 拡張: サジェスト表示対応
│   │   ├── WeeklyCalendarView.swift            # 拡張: accessibility 強化
│   │   ├── RecordCompletionView.swift          # 拡張: 連続更新時の追加演出
│   │   ├── CatStateView.swift                  # 拡張: 状態別アニメーション (rotation, bounce, breathing)
│   │   └── Components/
│   │       └── EmptyStateView.swift            # 新規: 履歴ゼロ時など用の共通空状態
│   └── Theme/
│       ├── Palette.swift                       # 拡張: 状態別カラー追加 (history, settings)
│       ├── Typography.swift                    # 拡張: 見出し用フォント追加
│       └── Motion.swift                        # 新規: アニメーションプリセット (spring, easeOut, durations)
├── CerealExerciseWidget/
│   └── Views/
│       └── SmallWidgetView.swift               # 拡張: 円形プログレス + 達成率
└── CerealExerciseTests/
    ├── ExerciseHistoryProviderTests.swift      # 新規 (5件以上)
    └── NotificationSettingsViewModelTests.swift # 新規 (5件以上)
```

---

## 2. 履歴画面 (§18.4)

### 2.1 画面構成
- NavigationStack の `HomeView` から `Toolbar` のアイコンボタンで遷移 (ツールバー右上に履歴アイコン)
- セクション: 日付ごとにグループ化 (新しい日が上)
- 各セル: 日付, カテゴリアイコン+色, 種目名一覧, 合計時間/回数, メモ抜粋

### 2.2 HistoryViewModel
- `WorkoutStore.records` から日付降順で全件
- `[Date: [WorkoutRecord]]` にグループ化
- 検索/フィルタ機能は今期は不要 (MVP)

### 2.3 表示例 (要件 §18.4 通り)
```
2026/05/23
🏋️ 筋トレ
腕立て伏せ 10回
スクワット 20回
合計 8分
```

### 2.4 空状態
- 履歴ゼロのとき: `EmptyStateView` で 🐱 + 「まだ記録がないよ。今日から始めよう」

---

## 3. 通知設定画面 (§18.5, §13.5)

### 3.1 UI 要素
- 通知 ON/OFF: `Toggle`
- 通知時間1: `DatePicker` (時刻のみ)
- 通知時間2: `DatePicker` (時刻のみ)
- 通知回数: `Picker` (1日1回 / 1日2回 / OFF) — OFF は ON/OFF Toggle と連動

### 3.2 NotificationSettingsViewModel
- `NotificationSettingsStore` (Phase 2 で実装済み) を読み書き
- 変更時に `NotificationScheduler.scheduleDaily(...)` を再呼び出し
- 通知許可未取得なら、ON 操作時に許可リクエスト

### 3.3 SettingsView
- セクション: 通知 (→ NotificationSettingsView), アプリ情報 (バージョン, 利用規約 - 静的テキストで可)

---

## 4. UIブラッシュアップ

### 4.1 Motion プリセット
```swift
enum Motion {
  static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.75)
  static let gentle = Animation.easeInOut(duration: 0.4)
  static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
}
```

### 4.2 ボタンタップフィードバック
- すべての PrimaryButton にプレス時 scale 0.96 + haptic feedback (`.impactOccurred(intensity: 0.5)`)

### 4.3 ホーム画面の遷移演出
- 記録完了 → ホーム戻りで連続記録バッジが pop アニメーション
- WeeklyCalendarView の今日セルが breathing アニメーション (1.0 ↔ 1.05)

### 4.4 カラー微調整
- Palette を見直し、各画面のヒエラルキー (タイトル/本文/補助テキスト) を明確化

---

## 5. キャラクター表情差分

画像生成 API キー未設定のため emoji ベース + アニメーションで表現する。

### 5.1 状態別 emoji + アニメーション
| CatState | emoji | アニメーション |
|---|---|---|
| waitingMorning | 😺 | gentle 上下 floating |
| worriedNoon | 🐱 | わずかな左右 tilt |
| beggingNight | 🙀 | bouncy bounce (お願いする動き) |
| celebrating | 😻 | snappy scale + rotation (祝うジャンプ) |
| streakExtended | 😻🔥 | confetti と同時に大ジャンプ + 火 emoji |
| resting | 😴 | breathing scale (寝息) |
| encouraging | 🐱💪 | 拳を上げる動き (rotation 揺れ) |

### 5.2 アセット差し替えポイント
- `CatStateView` 内で `Image("cat_\(state.rawValue)")` が存在すれば優先表示、なければ emoji
- → 画像生成完了後、`Assets.xcassets/CatCharacter/` 配下に追加するだけで切り替わる構造に

---

## 6. 入力履歴・よく使う種目

### 6.1 ExerciseHistoryProvider
```swift
@MainActor
final class ExerciseHistoryProvider {
  func topExerciseNames(for category: WorkoutCategory, limit: Int = 8) -> [String]
  // WorkoutStore.records から、該当カテゴリの種目名を頻度+直近性でスコア化
}
```

スコアリング:
- 頻度: 出現回数 (記録された種目名カウント)
- 直近性: 最終使用日からの経過日数で重み減衰 (e.g., exp(-days/30))
- 合計スコア降順で limit 件返す

### 6.2 ExerciseInputRow の拡張
- 種目名入力フィールドの下に横スクロール chip 群でサジェスト
- chip タップで TextField に挿入
- カテゴリ変更時にサジェスト更新

---

## 7. WeeklyCalendarView アクセシビリティ (Phase 1 Eval 繰越)

- 各曜日セルに `.accessibilityLabel("月曜日")` + `.accessibilityValue("達成済み" / "休養日" / "未達成" / "未来" / "今日")`
- VoiceOver で「月曜日、達成済み」と読み上げ

---

## 8. Small Widget 週間達成率 (Phase 2 Eval 繰越)

- `ProgressRing` (円形プログレス) を Small Widget の右下に小さく配置
- リング内に "4/7" などの数字
- 既存の「あとX時間」+ 猫を圧迫しないレイアウト

---

## 9. Execute 向け指示

`orchestrator/prompts/execute_phase3.md` で詳細プロンプト:
1. Phase 1/2 既存ファイルを尊重 (壊さない)
2. 履歴画面 / 通知設定画面 / 設定画面 / 種目サジェストを新規実装
3. アニメーションプリセットを `Theme/Motion.swift` に集約
4. キャラクター表情アニメを CatStateView に組み込み
5. WeeklyCalendarView accessibility 強化
6. Small Widget に円形プログレス追加
7. 既存テストは壊さない / 新規テスト2ファイル追加 (各5件以上)

## 10. Evaluate 観点

- §24.1〜§24.6 全項目 (Phase 1/2 から繰越含む) 再チェック
- §18.4 履歴画面の表示要素
- §18.5 設定画面の設定項目
- §13.5 通知設定画面の項目
- §22.1 操作性 (2タップ以内)
- §5.1/§5.2 デザイン方針 (ポップ・柔らかい・黒基調回避)
- Phase 1/2 のリグレッションなし
- 表情差分が `CatStateResolver` の7状態すべてに対応

---

## 11. 受け入れ条件マッピング

| 受け入れ条件 / 要件 | 実装ファイル |
|---|---|
| §24.5 通知ON/OFF/時間 UI 提供 | NotificationSettingsView |
| §18.4 履歴画面 | HistoryView, HistoryRowView |
| §18.5 設定画面 | SettingsView, NotificationSettingsView |
| §6.4 キャラクター7状態の表現拡充 | CatStateView (アニメ + emoji + 画像差し替え対応) |
| §22.1 2タップ以内 (ホーム → 記録) | 維持 (HomeView 構造保つ) |
| Phase 1/2 Eval 改善提案 | WeeklyCalendarView accessibility, RecordCompletionView 演出, Small Widget 達成率 |

---

## 12. リスク

- 画像差分は emoji + アニメーションでカバー。実画像は画像生成 API キー設定後にアセット追加すれば自動切替
- 設定変更時の通知再スケジュールで Authorization 未取得なら無音失敗の可能性 → UI でステータスを明示
- 履歴件数が増えると Lazy 描画が必須 → `LazyVStack` または `List` を使用
