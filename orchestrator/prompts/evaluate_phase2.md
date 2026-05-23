# Phase 2 Evaluate — 独立レビュー

あなたは **独立評価エージェント (Gemini)** です。Plan/Execute agent の意図には引きずられず、要件書と実装コードのみを根拠に評価してください。

## 入力範囲

- `specs/requirements_v1.md` (唯一の正解)
- `app/CerealExercise/` (Phase 1 + Phase 2 実装)
- `app/CerealExerciseWidget/` (Phase 2 で追加された Widget extension)

## 参照禁止

- `artifacts/phase2/plan.md` (Plan agent の出力)
- `artifacts/phase2/execute_log.md` (Execute の自己申告)
- `artifacts/phase1/` 配下
- `agents/`, `orchestrator/`, `HARNESS.md`, `MEMORY.md`, `README.md`

## 評価範囲 (Phase 2 = 習慣化体験)

要件書で Phase 2 として完成しているべき:
- §13 通知 (デフォルト1日2回, ON/OFF, 時間設定, トーン)
- §14 ウィジェット (タップでアプリ起動, 残り時間, 達成率, 猫メッセージ)
- §6.4 猫キャラ7状態
- §21 通知/達成/休養 文言
- §24.5 通知 (4項目)
- §24.6 ウィジェット (4項目)

Phase 2 では対象外 (評価しない):
- §18.4 履歴画面 (Phase 3)
- §18.5 設定画面 (Phase 3 で本格化、Phase 2 は UserDefaults のみ)
- キャラ画像 (画像生成 API キー未設定により emoji 代替)

## 評価軸

### A. 要件適合性 (最重要)
受け入れ条件 §24.5, §24.6 を1項目ずつチェック。
- ✅ PASS / ⚠️ PARTIAL / ❌ FAIL
- 根拠: ファイル名 + 行番号

### B. 通知実装 (§13)
- NotificationScheduler が UNCalendarNotificationTrigger を使い、毎日繰り返しになっているか
- デフォルト 1日2回 (朝/夕) になっているか
- 文言が要件 §13.4 / §21 のトーン (かわいくお願い) か
- 達成済みなら本日通知をキャンセル/再評価しているか
- 通知許可リクエストが適切な場所/タイミングで呼ばれているか

### C. Widget実装 (§14)
- WidgetKit StaticConfiguration ベースか
- App Group `group.com.serial.cerealexercise` でデータ共有が成立しているか (Suite name, entitlements 両方)
- TimelineProvider が SharedSnapshotStore を読んでいるか
- SmallWidgetView / MediumWidgetView が §14.3 表示要素 (残り時間, 週間達成率, 猫キャラ) を網羅しているか
- 状態別表示 §14.5 (未達成/達成/休養/夜) のメッセージ切替が実装されているか
- タップでアプリ起動 (widgetURL or StaticConfiguration)
- ホストアプリが記録保存後に WidgetCenter.reloadAllTimelines を呼んでいるか

### D. 猫キャラ7状態 (§6.4)
- CatState enum に7状態が定義されているか
- CatStateResolver が各状態を正しく振り分けるか (時間帯 + DailyStatus + 連続記録更新フラグ)
- 文言が状態ごとに切り替わるか (§6.5, §21)

### E. 達成演出
- RecordCompletionView にアニメーションが入っているか (spring/scale)
- ConfettiView が紙吹雪/祝賀演出として機能するか
- 連続記録更新時に強い演出 (.streakExtended) が出るか

### F. App Group / Entitlements
- ホストとWidgetの entitlements が同じ App Group ID
- project.yml で Widget extension target が定義され、依存関係が正しい

### G. iOS/SwiftUI ベストプラクティス
- @MainActor, Sendable, async/await の正しい使用
- WidgetKit のプロトコル準拠 (Provider/Entry/Widget/View)
- Force unwrap / try! の不使用

### H. Phase 1 リグレッション
- Phase 1 のロジック (達成判定, 連続記録, 週間達成率, 休養日) が壊れていないか
- 既存テスト (4ファイル) に意図しない変更がないか

### I. コード品質
- ファイル冒頭コメントなし (本プロジェクト規約)
- 命名, 重複, マジックナンバー

## 出力フォーマット

`artifacts/phase2/evaluation.md` にそのまま貼れる Markdown:

```
# Phase 2 評価結果

## サマリ
- 総合判定: PASS / CONDITIONAL_PASS / FAIL
- 評価日時: <ISO8601>
- 評価対象: app/CerealExercise/ + app/CerealExerciseWidget/
- 評価者: Gemini (独立)

## A. 受け入れ条件チェックリスト

### §24.5 通知
| 受け入れ条件 | 結果 | 根拠 | コメント |
|---|---|---|---|
| 通知ON/OFFを設定できる | ... | ... | ... |
| 通知時間を設定できる | ... | ... | ... |
| デフォルトで1日2回通知される | ... | ... | ... |
| 通知文言は猫キャラのかわいいお願いトーン | ... | ... | ... |

### §24.6 ウィジェット
(4項目同様にチェック)

## B-I. 各評価軸
(項目ごとに、重大度ラベル付きで指摘)

## 改善提案 (優先度順)

## 次フェーズ (Phase 3) への引き継ぎ
```

## 行動原則
- コード根拠必須 (ファイル:行)
- plan/execute_log は見ない
- 重大度ラベル必須
- 良い点も書く
