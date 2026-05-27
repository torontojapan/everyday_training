# Next Steps — GOエクササイズ

最終更新: 2026-05-27 PM (体重管理 P0 完了 + bottom tab 昇格 + Codex 改善ループ運用開始)

---

## 直近の状態

- **iOS アプリ本体**: Phase 7.0 完全完了 + 体重管理 P0 (3/4 機能完了、同日複数記録のみ未着手)
- **テスト**: Unit **180/180** + UI **14/14** = **194 件 全 PASS**
- **最新コミット**: `89cffec` 体重管理を一級市民に昇格 (bottom tab / iPad sidebar)
- **GitHub**: `torontojapan/everyday_training` main から 5 commit ahead (未 push)
- **Apple Developer Program**: 注文 W1563167588、Welcome メール待ち
- **Codex 改善ループ**: `/Users/jun/.claude/skills/second-opinion` 経由で運用、各イテレーションで priority 1 correctness バグを安定検出

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

**P0 (キャッチアップ)**

- [x] グラフ期間切替 (1週/1月/3月/半年/全期間) — `296f8c5`
- [x] BMI 自動計算 + 4 区分表示 — `296f8c5`
- [x] 目標体重 + 開始時体重 + 進捗バー — `b4e4412`
- [x] 体重管理を bottom tab / iPad sidebar に昇格 — `89cffec`
- [ ] **同日複数記録対応** (現状は上書き、`addSameDay_overwritesExisting`
      テストで挙動を locking 中)

**P1 (差別化、Apple Developer 不要)**

- [ ] 7日移動平均トレンドライン (Happy Scale 流、研究で継続率向上が
      実証されているキラー機能)
- [ ] 目標達成予測日 (移動平均の傾きから線形外挿)
- [ ] 体調周期 × 体重オーバーレイ (GO 独自、既存 MenstrualStore と連携)

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

**Welcome メール届いていれば** → CloudKit / HealthKit ブロッカー解除タスクへ。

**届いていなければ** → 体重管理 P0 残り + P1 トレンドラインを推奨。
以下のプロンプトでスタート:

```
体重管理機能の P0 残り + P1 トレンドラインを進めて。Codex レビュー
で改善ループを回す方式は前セッションと同じで。

### 着手順

1. P0-4「同日複数記録対応」
   - 現状: WeightStore.add() が同日エントリを上書き (テスト
     addSameDay_overwritesExisting で挙動を locking 中)
   - 仕様: 朝/晩で別々に記録できるよう insert 化、履歴は時刻付き表示、
     グラフは「日内最新」に集約 (Happy Scale = 全点表示 / あすけん =
     日内最新、シンプルさで後者推奨)

2. P1-1「7日移動平均トレンドライン」
   - Happy Scale の killer feature、研究文献でも継続率向上が実証
   - WeightStore に movingAverage 計算関数を追加
   - Chart に薄い LineMark を catmullRom で重ね描き
   - 「日々の水分変動で一喜一憂しない」UX 効果

3. P1-2「目標達成予測日」
   - 移動平均の傾きから線形外挿
   - 目標体重カードに「あと約 18 日で達成」を追加

### 制約

- iOS 17+ / SwiftUI / SwiftData / xcodegen
- 各イテレーション後に Codex 第三者レビュー
  (codex exec, gpt-5.3-codex, /Users/jun/.claude/skills/second-opinion/
   references/codex-review-schema.json)
- WeightStoreTests を必ず拡充
- DemoDataSeeder には触らない
- HealthKit / CloudKit は Apple Developer 加入待ち、スコープ外
- 前セッションの commit 起点: 89cffec
```

NEXT_STEPS.md と memory の pending_tasks.md は同期済。

---

## 参照

- `README.md` — 機能一覧 + Phase 完了表
- `MEMORY.md` — Claude のメモリインデックス
- `submission/screenshots/iphone-6.9/` — App Store スクショ
- `docs/ux_review/uxrevamp_{claude,gemini,codex,prompt}.md` — Phase 7.0 UX 刷新提案 3 LLM 分
