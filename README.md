# シリアルエクササイズ (Cereal Exercise)

猫キャラクターと一緒に毎日1分から運動を習慣化する iOS アプリ。

要件: [`specs/requirements_v1.md`](specs/requirements_v1.md)

## 開発体制

[`HARNESS.md`](HARNESS.md) 参照。

| エージェント | CLI | 役割 |
|---|---|---|
| Orchestrator / Plan | Claude (本セッション) | 設計・統括 |
| Execute | `codex exec` | SwiftUI 実装 |
| Evaluate | `gemini -p` | 独立レビュー |

## ディレクトリ

| パス | 内容 |
|---|---|
| `specs/` | 要件定義書 |
| `agents/` | 各エージェントのロール定義 |
| `orchestrator/` | CLI 呼び出しラッパー |
| `artifacts/phaseN/` | フェーズ別 Plan/Execute/Evaluate 成果物 |
| `assets/` | 画像 (猫キャラ、アイコン、UIモック) |
| `app/CerealExercise/` | SwiftUI iOS アプリ本体 |
| `logs/` | 各 CLI 実行ログ |

## フェーズ

| Phase | 内容 |
|---|---|
| 1 | MVPコア (ホーム/記録/連続記録/週間達成率/休養日) |
| 2 | 習慣化体験 (通知/Widget/猫キャラ演出) |
| 3 | 改善 (履歴/通知設定/UIブラッシュアップ) |

## ビルド

Xcode 17+ が必要。

```bash
cd app/CerealExercise
xcodegen generate   # project.yml から .xcodeproj を生成
open CerealExercise.xcodeproj
# Cmd+R で Simulator 実行
```

## 進捗・知見

[`MEMORY.md`](MEMORY.md) に逐次記録。
