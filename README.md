# GOエクササイズ (GO Exercise)

猫キャラクターと一緒に毎日1分から運動を習慣化する iOS アプリ。

App: SwiftUI / SwiftData / WidgetKit / Swift Charts (iOS 17+)
Pages: [https://torontojapan.github.io/everyday_training/](https://torontojapan.github.io/everyday_training/)
要件: [`specs/requirements_v1.md`](specs/requirements_v1.md)

## 主要機能

- 運動記録 (6 カテゴリ: 有酸素 / 筋トレ / ヨガ / ストレッチ / 筋膜リリース / その他)
- 連続記録 (休養日スキップ、達成日のみカウント) + 週間 / 月間カレンダー
- 累計運動日数 / 利用日数
- 通知 (1日2回ローカル通知) + ホーム画面ウィジェット (Small / Medium)
- 7 状態の猫キャラ + 累計達成日数に応じた装飾 (バンダナ→王冠)
- 連続記録シェア画面 (SNS / 写真保存)
- 月次レビュー (前月サマリーカード + シェア)
- 記念日演出 (1周年 / 100日連続等)
- アチーブメントバッジ 15 種
- 保険チケット (月1回、忙しい日を救う)
- 体重管理 (記録 + 推移グラフ)
- 体調・周期記録 (オプトイン、生理日に履歴カレンダーで ★)

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
| `artifacts/verification/` | 受け入れ検証 / エッジケース / パフォーマンス |
| `assets/` | 画像 (猫キャラ 7 状態、アイコン)、スクショ |
| `app/CerealExercise/` | SwiftUI iOS アプリ本体 |
| `submission/` | App Store 提出パッケージ (メタデータ、各サイズスクショ) |
| `docs/` | GitHub Pages (privacy / terms / support) |
| `logs/` | 各 CLI 実行ログ |

## フェーズ

| Phase | 内容 |
|---|---|
| 1 | MVPコア (ホーム/記録/連続記録/週間達成率/休養日) |
| 2 | 習慣化体験 (通知/Widget/猫キャラ演出) |
| 3 | 改善 (履歴/通知設定/UIブラッシュアップ) |
| 3.5 | UI/UX 中優先項目 (ホーム余白、iPad、ハプティクス、Reduce Motion) |
| 3.6 | 細かい改善 (種目候補/秒削除/保存後 bug/曜日タップ) |
| 3.7 | 連続記録ロジック改修 + シェア画面 |
| 3.8 | アプリ名「GOエクササイズ」改名 + Widget 促進 |
| 3.9 | 累計カード/ヘッダー左揃え/月間カレンダー |
| 4.0 | 保険チケット / 装飾 / バッジ / 月次レビュー / 記念日 |
| 4.1 | UX 整理 + 完了画面「もう一種目」 |
| 4.2 | 筋膜リリース + 体重管理 + 体調・周期 |
| 4.3 | テーマカラー 5 種 / 保険チケットカレンダー UI / 体調 ON で +1 枚 |
| 5.0 | 友達機能 MVP (Mock + UI 完成) |
| 5.1 | 4 段階祝祭演出 (CelebrationOverlay + ShimmerText) |
| 5.2 | 効果音 + CoreHaptics + 自動休養日ルール明記 |
| 5.3 | 友達ボタンをホーム toolbar に移動、バッジ削除、設定順最適化 |

## ビルド

Xcode 17+ が必要。

```bash
cd app/CerealExercise
xcodegen generate   # project.yml から .xcodeproj を生成
open CerealExercise.xcodeproj
# Cmd+R で Simulator 実行
```

## テスト実行

```bash
cd app/CerealExercise
xcodebuild \
  -project CerealExercise.xcodeproj \
  -scheme CerealExercise \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  test
```

現状: ユニット 121 + UI 8 = **129 件全 PASS**。CI も green (`.github/workflows/ios-ci.yml`)。

## 進捗・残タスク

- 完了履歴: [`MEMORY.md`](MEMORY.md)
- これからやること: [`NEXT_STEPS.md`](NEXT_STEPS.md)
