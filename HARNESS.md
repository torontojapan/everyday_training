# シリアルエクササイズ 開発ハーネス設計

## 0. 目的

要件定義書 `specs/requirements_v1.md` を基に、SwiftUI iOSアプリ「シリアルエクササイズ」を **Plan → Execute → Evaluate** の三段サイクルで自律的に構築するためのマルチエージェント・ハーネス。

評価の独立性を最優先する設計とし、評価エージェントは Plan/Execute と必ず別ベンダー(別CLI)で動かす。

---

## 1. 役割分担

| 役割 | エージェント | CLI | 主担当 |
|------|--------------|-----|--------|
| **Orchestrator / Plan** | Claude (Opus 4.7) | Claude Code (本セッション) | 要件分解・タスク設計・統合判断・成果物統括 |
| **Execute** | Codex | `codex exec` | Swift/SwiftUI コード生成、ファイル作成、リファクタ |
| **Evaluate** | Gemini | `gemini -p` (非対話) | 独立コードレビュー、要件適合性検証、UX/iOSベストプラクティス監査 |
| **画像生成** | OpenAI画像API → Nanobanana fallback | カスタムスクリプト | 猫キャラ7状態、アプリアイコン、UIモック |

### 1.1 評価独立性の担保

- Evaluate は **Gemini に固定** (別ベンダー = 別バイアス)
- Plan が出力した期待仕様を、Evaluate には**実装物だけ渡し**、Plan文書は最小限提示することで「設計者の意図に引きずられない」第三者視点を確保
- Evaluate の入力: 要件書 (specs/requirements_v1.md) + 実装コード (app/)
- Evaluate の出力: `artifacts/phase{N}/evaluation.md` (合格/不合格 + 指摘事項 + 重大度)

### 1.2 Evaluate結果のフィードバックループ

```
Evaluate結果が「不合格」または「重大度High指摘あり」
  → Orchestratorが指摘内容を要件として Execute に再投入
  → 再Execute → 再Evaluate
  → 上限3周。それでも収束しない場合のみユーザーに報告
```

---

## 2. ディレクトリ構造

```
serial_training/
├── HARNESS.md                # 本ファイル
├── README.md                 # プロジェクト概要・進行ガイド
├── MEMORY.md                 # ハーネス進捗・知見ログ
├── specs/
│   └── requirements_v1.md    # 要件定義書 (原本)
├── agents/                   # 各エージェントのロール定義
│   ├── plan/plan.md          # Plan agent のシステムプロンプト
│   ├── execute/execute.md    # Execute agent のシステムプロンプト
│   └── evaluate/evaluate.md  # Evaluate agent のシステムプロンプト
├── orchestrator/             # CLI呼び出しラッパー
│   ├── run_codex.sh          # Codex 非対話実行
│   ├── run_gemini_eval.sh    # Gemini 評価実行
│   ├── gen_image.sh          # 画像生成 (OpenAI → Nanobanana)
│   └── phase_runner.sh       # Phase 1サイクル実行
├── artifacts/                # フェーズ別の成果物
│   ├── phase1/
│   │   ├── plan.md           # Plan agent の出力
│   │   ├── execute_log.md    # Execute agent の出力ログ
│   │   └── evaluation.md     # Evaluate agent の出力
│   ├── phase2/
│   └── phase3/
├── assets/                   # 画像・モック
│   ├── cat_character/        # 猫キャラ7状態
│   ├── icons/                # アプリアイコン
│   └── mockups/              # UIモック
├── app/                      # SwiftUIプロジェクト本体 (Codexが生成)
│   └── CerealExercise/
└── logs/                     # 各CLI実行ログ
```

---

## 3. フェーズ進行

### Phase 1: MVPコア
1. ホーム画面（連続記録、週間達成率、週間カレンダー、記録ボタン、猫メッセージ）
2. 運動記録入力（カテゴリ、種目、時間、回数、セット数、メモ、複数種目）
3. 記録完了画面
4. データモデル + 永続化（SwiftData推奨）
5. 連続記録・週間達成率・休養日自動判定ロジック

### Phase 2: 習慣化体験
1. ローカル通知 (UserNotifications, デフォルト1日2回)
2. ホーム画面ウィジェット (WidgetKit, 残り時間/達成率/猫メッセージ)
3. 猫キャラクター7状態の状態遷移と表示
4. 達成演出 / 状態別メッセージ
5. アプリグループ + Widget用データ共有

### Phase 3: 改善
1. 履歴画面
2. 通知設定画面
3. UIブラッシュアップ（タイポグラフィ、余白、配色、アニメーション）
4. キャラクター表情差分組み込み
5. よく使う種目の履歴サジェスト

各フェーズで:
1. Orchestrator が Plan を起こす → `artifacts/phase{N}/plan.md`
2. Plan を Codex に渡して Execute → `app/` を更新, `artifacts/phase{N}/execute_log.md`
3. 実装物を Gemini に渡して Evaluate → `artifacts/phase{N}/evaluation.md`
4. 結果に応じて再修正 (最大3周)
5. ユーザーに進捗報告

---

## 4. CLIラッパー仕様

### 4.1 `orchestrator/run_codex.sh`
- 役割: Codex を非対話で呼び出し、結果をログファイルに保存
- 入力: `--prompt-file <path>` または stdin
- 出力: `logs/codex_<timestamp>.log` + 実ファイル変更 (`app/` 配下)
- 内部: `codex exec --skip-git-repo-check --cd <repo_root> < prompt`
- ファイル書き込み権限: `--full-auto` (sandbox内で自動)

### 4.2 `orchestrator/run_gemini_eval.sh`
- 役割: Gemini を非対話で呼び出し、評価結果を保存
- 入力: 要件書 + 実装コードのコンテキスト
- 出力: `artifacts/phase{N}/evaluation.md`
- 内部: `gemini -p "<eval prompt>" --approval-mode plan` (read-only)
- 重要: Plan agent の出力は **渡さない** (独立性確保)

### 4.3 `orchestrator/gen_image.sh`
- 役割: 画像を生成し `assets/` に保存
- 入力: `--prompt "<text>" --out <path> --size <WxH>`
- 1次: OpenAI Image API (`gpt-image-1`) via curl + `OPENAI_API_KEY`
- 2次 (fallback): Nanobanana (Gemini 2.5 Flash Image) via `GOOGLE_API_KEY` / Gemini CLI
- 失敗時: `assets/<path>.MISSING` を作成しログに記録、人間に通知

### 4.4 `orchestrator/phase_runner.sh`
- 役割: Phase N の Plan→Execute→Evaluate を順次実行
- 引数: フェーズ番号 (1/2/3)
- 動作:
  1. `artifacts/phase{N}/plan.md` を Orchestrator (Claude) が事前に置く前提
  2. Codex を Plan ベースで起動 → 実装
  3. Gemini を要件+実装で起動 → 評価
  4. 結果次第で再Executeループ

---

## 5. 安全策

- すべての CLI 実行ログを `logs/` に残し、後追い可能にする
- Codex 変更は `app/` 配下に限定し、ハーネス自体を改変させない
- Evaluate の独立性: Plan文書は渡さない / 要件原本 + 実装 のみで判断させる
- API キー未設定時は明示的にフォールバック/エラー、暗黙の失敗を許さない
- Xcode 未インストール環境ではビルド検証フェーズをスキップし、人間に通知

---

## 6. 自律進行ポリシー

ユーザー指示: 「なるべく人間承認を求めず自律的に最適進行」

実装ポリシー:
- 設計判断は Orchestrator が即決し、議事録は `MEMORY.md` に残す
- 評価で High 重大度の指摘が出ても、3周以内は自動で修正ループ
- ブロッカー(環境問題・API未設定・要件と矛盾する制約)のみユーザーに報告
- 進捗は Phase 完了時に簡潔にサマリ報告
