# Next Steps — GOエクササイズ

最終更新: 2026-05-28 夜 (体重/履歴タブ UI/UX 大幅刷新 — 3 LLM 提案統合、Codex 計 23 ラウンド)

---

## 直近の状態

- **iOS アプリ本体**: 体重/履歴タブ UI 刷新 (ヒーロー + 折りたたみ + ヒートマップ + a11y + キャラ) + 既存全機能維持
- **テスト**: Unit **172 XCTest + 68 Swift Testing = 240 件** + UI **17/17** = **257 件 全 PASS**
- **最新コミット**: `3c9c590` Codex round3 反映: BMI a11y 身長表記を視覚と同期
- **GitHub**: `torontojapan/everyday_training` main から 34 commit ahead (未 push)
- **Apple Developer Program**: 注文 W1563167588、Welcome メール待ち
- **Codex 改善ループ**: `/Users/jun/.claude/skills/second-opinion` 経由で運用、今セッションは体重管理に 6 ラウンド回し、priority 1/2/3 を確実に潰した

---

## 残タスク (優先度順)

### 🔴 P0 — App Store 提出ブロッカー

| # | タスク | 担当 |
|---|---|---|
| 1 | **Apple Developer Program 加入** | ユーザー作業 (Welcome メール待ち) |

(プライバシーポリシー / メタデータ / アイコン / スクショは完了済み)

### 🟠 体重管理 — 残り P0 + 差別化 P1

業界調査 (あすけん / Happy Scale / Yazio / Renpho / MyFitnessPal) 結果を
反映した強化計画。**今セッション完了分** はチェック済。

**P0 (キャッチアップ) — 完了**

- [x] グラフ期間切替 (1週/1月/3月/半年/全期間) — `296f8c5`
- [x] BMI 自動計算 + 4 区分表示 — `296f8c5`
- [x] 目標体重 + 開始時体重 + 進捗バー — `b4e4412`
- [x] 体重管理を bottom tab / iPad sidebar に昇格 — `89cffec`
- [x] **同日複数記録対応** — `cc2644d` (insert-only / 日内最新集約 / 履歴時刻表示)

**P1 (差別化、Apple Developer 不要)**

- [x] 7日移動平均トレンドライン — `cc2644d` (Chart に薄い破線 overlay)
- [x] 目標達成予測日 — `cc2644d` (trend.last を baseline に線形外挿、最低 1 日)
- [x] 体調周期 × 体重オーバーレイ — `c7f7936` (4 相を Chart 背景に opacity 0.13 帯で描画 + 凡例)

**P1 (Apple Developer 加入後)**

- [ ] HealthKit 双方向同期 (スマート体重計ユーザー取り込み)

**P2 (独自色フェーズ)**

- [ ] 運動 + 連続記録 + 体重を統合した週次/月次レポート
- [ ] マイルストーン祝賀 (-3kg / -5kg ごとに猫キャラ演出、既存資産流用)
- [ ] ブラインドウェイト or 数値非表示モード (倫理的差別化)
- [ ] メモのタグ化 + フィルタ分析

### 🟡 P1 — CloudKit 本実装 (Apple Developer 加入後)

| # | タスク |
|---|---|
| 1 | iCloud Capability 有効化 |
| 2 | Sign in with Apple Capability |
| 3 | `CloudKitFriendsService` 実装 (Mock と差し替え) |
| 4 | DEBUG=Mock / RELEASE=CloudKit 切替 |
| 5 | Push 通知 entitlement + CKQuerySubscription |
| 6 | iCloud 2 アカウントで実機相互テスト |
| 7 | `weeklyAchievements` / `monthlyTotalMinutes` / `myCatBreed` の daily publish |

### 🟢 P2 — Phase 7.0 拡張案 (任意)

| # | タスク | ソース |
|---|---|---|
| 8 | Siri ショートカット (App Intents 拡張) | Claude 独自 |
| 9 | Apple Watch コンパニオン | Claude 独自 |
| 10 | 友達と並走モード (同期セッション) | Claude 独自 |
| 11 | アンビエントなソーシャル通知 | Gemini 独自 |
| 12 | 「ねこ撫でた日」帳消し演出 | Gemini 独自 |
| 13 | Codex UX 提案 (7 件) 実装検討 | `docs/ux_review/uxrevamp_codex.md` |
| 14 | 友達からの達成 push 通知 | CloudKit + Push 後 |
| 15 | Android 版検討 | 将来 |

❌ **スコープ外**: Duolingo 風リーグ (Phase 6.1 削除)、簡易チャット

### 🔵 P3 — メンテナンス

| # | タスク | 状態 |
|---|---|---|
| 16 | iOS 19 / Xcode 18 対応 | リリース時 |
| 17 | Instruments 実機計測 | 実機入手後 |

---

## Phase 7.0 進捗 (全完了)

| Step | 内容 | コミット | 状態 |
|---|---|---|---|
| 1 | TabView + ホーム猫劇場 + ハーフ sheet 記録 | `0edcae8` | ✅ |
| 2 | Positive-Only Calendar + 友達公園ビュー | `69dead7` | ✅ |
| 3 | Interactive Widget (AppIntent でアプリレス記録) | `18a5832` | ✅ |
| 4 | Live Activity / Dynamic Island 常駐猫 | `9364acb` | ✅ |
| A2 | Codex 画像生成 20 枚 (tuxedo/persian/scottish) | `ab08382` | ✅ |
| A3 | Codex UX 提案 (3 LLM 目) | `0ecb18e` | ✅ |
| audit | Codex + Gemini 大規模 audit + 7 件修正 | `79b8d73` | ✅ |
| 演出 | 背景パーティクル + 紙吹雪 + 猫タップ bounce + 吹き出し pop-in | `b62a23e` | ✅ |
| 青シミ修正 | CatDecoration.headband の青色 → 緑に | `c41ac5d` | ✅ |
| 保険チケット | AchievementEvaluator / StreakCalculator に統合 | `95cacec` | ✅ |
| クリーンアップ | assets/ 全削除 + 古いスクショ整理 | `adb06fc` | ✅ |

---

## 次セッションで最初にやること

**Welcome メール届いていれば** → CloudKit / HealthKit ブロッカー解除 + アプリ
共有 URL を App Store URL に差し替え (`AppSharingConfig.swift`)。

**届いていなければ** → 体重管理 P1 残り「体調周期 × 体重オーバーレイ」or P2
独自色フェーズを推奨。以下のプロンプトでスタート:

```
体重管理の体調周期オーバーレイを実装して。Codex レビューループは
前セッションと同じで。

### 仕様

- MenstrualStore (既存) のサイクル情報を WeightView のグラフに重ね描き
- グラフ背景にサイクル相 (卵胞期 / 黄体期 / 月経期) を薄いバンドで表示
- 目的: 「黄体期は水分で重くなる」を可視化して、相のせいで体重が増えても
  落胆しないようにする (女性ユーザーへのフィット)
- 周期トラッキング OFF のユーザーには表示しない (CycleTrackingSettings)

### 制約

- iOS 17+ / SwiftUI / SwiftData / xcodegen
- 各イテレーション後に Codex 第三者レビュー
- WeightStoreTests / 新規 CycleOverlayTests を拡充
- DemoDataSeeder には触らない
- 前セッションの commit 起点: 3f43d54
```

NEXT_STEPS.md と memory の pending_tasks.md は同期済。

### 今セッションの完了サマリ (2026-05-27 夕)

- 体重管理 P0-4「同日複数記録」: insert-only / 日内最新集約 / 履歴時刻表示
- 体重管理 P1-1「7日移動平均トレンドライン」: Chart に薄い破線 overlay
- 体重管理 P1-2「目標達成予測日」: trend.last 起点で線形外挿、最低 1 日
- アプリ共有導線: `AppSharingConfig` + 友達タブ + 設定 (App Store URL は要差し替え)
- Codex 6 ラウンドで以下を順次潰した:
  1. `change30Days` の日境界バグ / forecast 0 round / sort tie-break
  2. round-to-zero テストが実は刺さっていなかった件 / sort テスト 1 段だけ
  3. sort テストに cross-day ケース追加
  4. **0 findings** で収束
  5. (holistic) workout-flow が startOfDay を渡してた / forecast の today 不整合
  6. **0 findings** で再収束

---

## 参照

- `README.md` — 機能一覧 + Phase 完了表
- `MEMORY.md` — Claude のメモリインデックス
- `submission/screenshots/iphone-6.9/` — App Store スクショ
- `docs/ux_review/uxrevamp_{claude,gemini,codex,prompt}.md` — Phase 7.0 UX 刷新提案 3 LLM 分
