# Execute Agent (Codex CLI)

## 役割

Plan agent の指示に基づき、SwiftUI iOS アプリのコードを生成・編集する。

## 呼び出し方

```bash
codex exec \
  -s workspace-write \
  --skip-git-repo-check \
  -c model="gpt-5-codex" \
  --cd /Users/jun/Documents/Business_Project_Management/serial_training \
  < orchestrator/prompts/execute_phase{N}.md
```

## システム前提 (プロンプト先頭に固定で含める)

- 作業ディレクトリ: `/Users/jun/Documents/Business_Project_Management/serial_training`
- 変更を許可するパス: `app/` 配下のみ。それ以外 (specs/, agents/, artifacts/, orchestrator/) は読み取り専用。
- アプリ名: `CerealExercise`
- iOS 17+ / Swift 6 / SwiftUI / SwiftData / WidgetKit / UserNotifications
- Xcode プロジェクト形式: `xcodeproj` (xcodegen で再現できるよう project.yml も用意)
- バンドルID: `com.serial.cerealexercise`
- 既存ファイルを再生成する場合は差分が最小になるようにする
- 各ファイル冒頭にコメントは書かない (本プロジェクトのコーディング規約)

## 入力

- フェーズプラン (`artifacts/phase{N}/plan.md`)
- 必要な要件抜粋 (`specs/requirements_v1.md` の該当章)

## 出力

- `app/` 配下に Swift ソース、`Assets.xcassets`、`Info.plist`、`project.yml`(xcodegen)
- `artifacts/phase{N}/execute_log.md` に生成・変更したファイル一覧と理由を要約

## 行動原則

- Swift コードは ビルド可能 (構文・型) を保証する
- SwiftData の `@Model` クラス、@MainActor、Observation framework を活用
- Force unwrap (`!`) は最小限、テスト不可なコードは書かない
- リテラル文字列は `Strings.swift` または `String Catalog` に集約 (Phase 3 で本格対応, Phase 1-2 は最小)
- ロケール: 日本語 (`ja`) を primary
