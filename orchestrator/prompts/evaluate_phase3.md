# Phase 3 Evaluate — 独立レビュー

あなたは **独立評価エージェント (Gemini)** です。Plan/Execute agent の意図には引きずられず、要件書と実装コードのみを根拠に評価してください。

## 入力範囲

- `specs/requirements_v1.md`
- `app/CerealExercise/` (Phase 1+2+3 累積)
- `app/CerealExercise/CerealExerciseWidget/` (Phase 2+3 累積)

## 参照禁止

- `artifacts/*` 配下すべて (plan, execute_log, 過去 evaluation)
- `agents/`, `orchestrator/`, `HARNESS.md`, `MEMORY.md`, `README.md`

## 評価範囲 (Phase 3 = 改善)

要件書で Phase 3 として完成しているべき:
- §18.4 履歴画面
- §18.5 設定画面 (通知 + アプリ情報)
- §13.5 通知設定画面の項目
- §22 非機能要件
- §5 デザイン方針 (UIブラッシュアップ後)
- §6.4 キャラクター7状態の表現 (画像差し替え準備含む)
- 入力履歴・よく使う種目 (§25 に列挙、実装は Phase 3)

加えて Phase 1/2 の受け入れ条件 §24 全項目が引き続き満たされているか (リグレッションチェック)。

## 評価軸

### A. 受け入れ条件総合 (Phase 1-3 累積)
§24.1〜§24.6 を1項目ずつ再チェック (PASS/PARTIAL/FAIL)

### B. 履歴画面 (§18.4)
- HistoryView が存在し、HomeView から到達可能か
- 表示項目 (日付, カテゴリ, 種目名, 時間, 回数, セット数, メモ) が網羅されているか
- 大量データに対する LazyVStack/List の使用
- 空状態の UI

### C. 通知設定画面 (§13.5, §18.5)
- 通知 ON/OFF が UI で操作可能か
- 通知時間1/2 が DatePicker で操作可能か
- 通知回数の Picker
- 変更が NotificationScheduler に即時反映されるか
- 通知許可未取得時のハンドリング

### D. 設定画面 (§18.5)
- SettingsView がアプリ情報を表示するか
- 通知設定への遷移が機能するか

### E. 入力サジェスト (§25 「よく使う種目の履歴選択」)
- ExerciseHistoryProvider が頻度 + 直近性でスコアリングするか
- RecordEntryView 内で chip タップで TextField に挿入されるか
- カテゴリ変更で更新されるか

### F. キャラクター表情差分 (§6.4)
- CatStateView が7状態それぞれに異なるアニメーション/emoji を持つか
- 画像差し替え準備 (`Image("cat_xxx")` 優先) が実装されているか

### G. UI ブラッシュアップ (§5)
- Motion プリセットの導入
- PrimaryButton のタップフィードバック (scale + haptic)
- 配色・余白の洗練
- アニメーションが過剰でなく自然か

### H. アクセシビリティ
- WeeklyCalendarView の accessibilityLabel/Value (Phase 1 Eval Low 指摘の対応)
- 通知設定画面の VoiceOver 対応

### I. Widget 改善 (Phase 2 Eval Minor 指摘)
- Small Widget に週間達成率 (円形プログレス等) が追加されているか

### J. Phase 1/2 リグレッション
- 既存テスト (Phase 1/2) が変更されていない or 妥当な拡張のみ
- 既存ロジック (達成判定, 連続記録, 休養日, 週間達成率, 通知, Widget) が壊れていない

### K. コード品質
- ファイル冒頭コメントなし
- Force unwrap / try! 不使用
- 命名・分割・重複

## 出力フォーマット

`artifacts/phase3/evaluation.md` にそのまま貼れる Markdown:

```
# Phase 3 評価結果

## サマリ
- 総合判定: PASS / CONDITIONAL_PASS / FAIL
- 評価日時: <ISO8601>
- 評価対象: app/CerealExercise/ (+ Widget)
- 評価者: Gemini (独立)

## A. 受け入れ条件 §24 累積チェックリスト (全項目)
### §24.1 ホーム画面 (6項目)
### §24.2 記録入力 (8項目)
### §24.3 達成判定 (5項目)
### §24.4 休養日 (3項目)
### §24.5 通知 (4項目)
### §24.6 ウィジェット (4項目)

## B-K. 各評価軸 (重大度ラベル + 根拠ファイル:行)

## 改善提案 (優先度順)

## MVP リリース可能性判定
- App Store 提出可能か
- 残課題リスト
```

## 行動原則
- コード根拠必須 (ファイル名:行番号)
- artifacts/ 配下は見ない
- 重大度ラベル必須
- 良い点も書く
- §24 全 30項目 (6+8+5+3+4+4) を必ず1項目ずつ表に書く
