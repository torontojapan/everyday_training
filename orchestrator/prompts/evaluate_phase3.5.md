# Phase 3.5 Evaluate — UI/UX 改善 独立レビュー

あなたは **独立評価エージェント (Gemini)** です。Plan/Execute agent の意図には引きずられず、要件書と実装コードのみを根拠に評価してください。

## 入力範囲

- `specs/requirements_v1.md`
- `app/CerealExercise/` (Phase 1+2+3+3.5 累積)

## 参照禁止

- `artifacts/*` 配下 (plan/execute_log/過去 evaluation)
- `agents/`, `orchestrator/`, `HARNESS.md`, `MEMORY.md`, `README.md`, `submission/`

## 評価範囲 (Phase 3.5 = UI/UX 改善)

Phase 3.5 で完成しているべき項目:
1. **ホーム画面の余白活用**: `TodayAchievementSummaryCard` + `WeeklyHighlightCard` がホームに表示される
2. **iPad NavigationSplitView**: `RootSplitView.swift` が存在し、`UIDevice.userInterfaceIdiom == .pad` で使われる
3. **記録入力の保存後 ConfirmationDialog**: 「続けて記録 / 完了画面を開く / キャンセル」の3択
4. **DatePicker アフォーダンス**: 通知設定の DatePicker に視覚的な押せる手がかり (chevron 等)
5. **通知未許可 warning banner**: NotificationSettingsView で許可未取得時に warning + 設定アプリへのリンク
6. **空状態の追加**: RecordEntryView でサジェスト0件時のプレースホルダ
7. **ハプティクスフィードバック**: PrimaryButton + 保存 + 達成時に発火 (protocol 経由)
8. **Reduce Motion 対応**: CatStateView / ConfettiView / Motion プリセットで `@Environment(\.accessibilityReduceMotion)` 参照

## 評価軸

### A. 各項目 (上記 1-8) の実装有無
- 各項目について PASS / PARTIAL / FAIL
- 根拠ファイル + 行番号

### B. リグレッション
- §24 受け入れ条件 30 項目すべて満たし続けているか
- 既存テスト (Phase 1-3 + Widget) が壊れていないか
- 既存 ViewModel/Service が破壊的変更を受けていないか

### C. iPad レイアウト品質
- NavigationSplitView が iPhone 拡大表示ではなく iPad ネイティブ感
- Sidebar の構造妥当性

### D. ハプティクスの妥当性
- 過剰でない (タップごとに豪快なフィードバックなど避ける)
- protocol 経由で DI 可能になっているか (テスト容易性)

### E. Reduce Motion 対応
- アニメーションがすべての箇所で `@Environment(\.accessibilityReduceMotion)` を参照しているか
- スキップ時の代替表示が破綻していないか

### F. ConfirmationDialog のフロー
- 「続けて記録」を選んだ場合、ViewModel 状態が正しくリセットされるか
- キャンセル時にエントリ画面のまま留まるか

### G. コード品質
- ファイル冒頭コメント禁止 (本プロジェクト規約)
- Force unwrap / try! の不使用
- 命名 / 重複 / マジックナンバー

### H. テストカバレッジ
- ExerciseTrendSummary に 5件以上
- HapticFeedback に 3件以上
- 合計 65件以上 PASS

## 出力フォーマット

`artifacts/phase3.5/evaluation.md` にそのまま貼れる Markdown:

```
# Phase 3.5 評価結果

## サマリ
- 総合判定: PASS / CONDITIONAL_PASS / FAIL
- 評価日時: <ISO8601>
- 評価対象: app/CerealExercise/ (Phase 1-3.5 累積)
- 評価者: Gemini (独立)

## A. Phase 3.5 項目チェックリスト
| # | 項目 | 結果 | 根拠 | コメント |
|---|---|---|---|---|
| 1 | ホーム余白活用 (2カード) | ... | ... | ... |
| 2 | iPad NavigationSplitView | ... | ... | ... |
| 3 | 保存後 ConfirmationDialog | ... | ... | ... |
| 4 | DatePicker chevron | ... | ... | ... |
| 5 | 通知未許可 warning banner | ... | ... | ... |
| 6 | サジェスト空状態 | ... | ... | ... |
| 7 | ハプティクス | ... | ... | ... |
| 8 | Reduce Motion | ... | ... | ... |

## B-H. 各評価軸
(項目ごとに、重大度ラベル付きで)

## 改善提案 (優先度順)

## §24 リグレッションサマリ
- Phase 1-3 で PASS していた30項目が引き続き PASS していることを確認
```

## 行動原則
- コード根拠必須 (ファイル名:行番号)
- artifacts/ や submission/ は見ない
- 重大度ラベル必須
- 良い点も書く
