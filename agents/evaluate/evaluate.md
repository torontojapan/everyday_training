# Evaluate Agent (Gemini CLI) — INDEPENDENT REVIEWER

## 役割

**独立性最優先**。Plan agent の意図には影響されず、要件書と実装コードのみを根拠に評価する。

## 呼び出し方

```bash
gemini -p "$(cat orchestrator/prompts/evaluate_phase{N}.md)" \
  --approval-mode plan \
  --include-directories /Users/jun/Documents/Business_Project_Management/serial_training/app,/Users/jun/Documents/Business_Project_Management/serial_training/specs \
  --output-format text
```

- `--approval-mode plan`: read-only モードで実行。コード変更権限なし。
- `--include-directories`: 要件と実装ディレクトリのみ参照可。**`artifacts/` (Plan出力含む) は除外**

## 入力

- 要件定義書 (`specs/requirements_v1.md`)
- 実装コード (`app/` 配下)

## **入力に含めない**

- `artifacts/phase{N}/plan.md` (Plan agent の意図に引きずられないため)
- `artifacts/phase{N}/execute_log.md` (Execute の自己申告ではなく実物を見るため)

## 評価軸

各フェーズの該当範囲で以下を評価:

### A. 要件適合性 (最重要)
- 要件書 §24 「受け入れ条件」 を1項目ずつチェック (合格/部分合格/未達成)
- 該当する画面・機能が実装されているか
- データモデルが §19 の定義と整合しているか
- ロジック(達成判定 §20, 連続記録 §10, 休養日 §11) が要件通りか

### B. iOS / SwiftUI ベストプラクティス
- SwiftData / Observation / @MainActor の使い方
- View 分割の粒度、状態管理 (@State / @Bindable / @Environment)
- ナビゲーション (NavigationStack の正しい利用)
- アクセシビリティ (Dynamic Type, VoiceOver labels)
- パフォーマンス (List 仮想化、不要な再描画)

### C. UX / デザイン方針 (§5)
- 「ポップ・柔らかい・女性も使いやすい」方向性に沿っているか
- 黒基調のハードなジムアプリ風になっていないか
- 入力負荷 (ホームから2タップ以内で記録 §22.1)
- 猫キャラクターの状態別表現 (§6.4)

### D. コード品質
- Force unwrap / try! の不適切な使用
- 命名規則 (Swift API Design Guidelines)
- 重複コード / マジックナンバー
- エラー処理の妥当性

## 出力

`artifacts/phase{N}/evaluation.md` に以下:

```markdown
# Phase {N} 評価結果

## サマリ
- 総合判定: PASS / CONDITIONAL_PASS / FAIL
- 評価日時: {iso8601}
- 評価対象: app/ 配下 (commit/snapshot)

## A. 要件適合性チェックリスト
| 受け入れ条件 | 結果 | 根拠 (ファイル:行) | コメント |
|---|---|---|---|
| ... | ✅/⚠️/❌ | ... | ... |

## B. iOS/SwiftUI ベストプラクティス
- (重大度 High/Medium/Low ごとの指摘)

## C. UX / デザイン方針
- ...

## D. コード品質
- ...

## 改善提案 (優先度順)
1. [High] ...
2. [Medium] ...

## 次フェーズへの引き継ぎ事項
- ...
```

## 行動原則

- 推測ではなく**コード根拠** (ファイル名 + 行番号) を必ず示す
- 良かった点も書く (改善の方向性を示唆する)
- 「Plan ではこう書かれていた」という参照はしない (Plan を見ていない前提)
- 重大度ラベルを必ず付ける (High / Medium / Low)
