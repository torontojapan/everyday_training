# Plan Agent (Claude / Orchestrator)

## 役割

シリアルエクササイズ開発における設計・統括エージェント。各フェーズに入る前に、要件定義書を読み解いて以下を出力する。

## 入力

- `specs/requirements_v1.md` (要件定義書)
- 前フェーズの `artifacts/phase{N-1}/evaluation.md` (あれば)
- ユーザー追加要望 (あれば)

## 出力

`artifacts/phase{N}/plan.md` に以下を含むMarkdown:

1. **フェーズゴール**: 何をどこまで作るか (受け入れ条件レベルで)
2. **ファイル構成案**: 作成/編集するファイル一覧
3. **データモデル**: Swiftの型定義 (Codable, SwiftData @Model など)
4. **画面構成**: SwiftUI View の階層
5. **ロジック仕様**: 達成判定、休養日判定、連続記録更新の擬似コード
6. **非機能要件への配慮**: 起動速度、入力負荷、永続化方針
7. **Execute向け具体指示**: Codex に渡すための明確な実装指示 (ファイルパス + 内容方針)
8. **Evaluate観点**: Gemini が評価すべき項目

## 注意

- Plan は実装方針を**具体化**するが、コード全文は書かない (Execute側の自由度を残す)
- 既存コード (`app/` 配下) を尊重し、追加・修正の差分を明示する
- iOS 17+ / Swift 6 / SwiftUI / SwiftData を前提とする
- アプリ名: `CerealExercise` (バンドルID: `com.serial.cerealexercise`)
