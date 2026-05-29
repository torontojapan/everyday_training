# Next Steps — GOエクササイズ

最終更新: 2026-05-29 (リリース前 QA: 2 ラウンドの 3LLM 監査 + Codex ダブルチェック / 友達を v1 非表示)

---

## リリース前 QA (2026-05-29)

`docs/QA_CHECKLIST.md` を起点に、3 LLM (Claude / Codex / Gemini) 監査 → 改修 →
Codex ダブルチェックを **2 ラウンド** 実施。全ラウンド Debug テスト PASS + Release ビルド成功。

**ラウンド1 (debug 安全性 + 集計整合)**
- Release で debug 起動引数を全て無効化 (`#if DEBUG`): `--seed-*` / `--mock-seed-friends` /
  `--mock-force-signed-out` / `--skip-onboarding` / `--no-notification-prompt` / `--initial-route` /
  `--initial-tab` / `--skip-milestones` / `--no-review-prompt` / `--mock-open-friend-*` (`--mock-premium` は既存)
- `rescuedDates` 未伝播を 4 箇所修正 (通知 / streakShare / ウィジェット / Live Activity) — 救済日が未達成表示になるのを解消

**ラウンド2 (広域監査 + 友達 v1 非表示)**
- **友達機能を v1 で非表示** (`AppFeatureFlags.friendsEnabled` = Release常にoff / DEBUGは`--enable-friends`)。詳細は下記
- 保存失敗時に「保存しました」と誤表示していた件を修正 (`RecordEntryViewModel` が失敗時 nil 返却・副作用停止)
- 全削除後にウィジェット/Live Activity が古い連続日数のままだった件を修正 (空スナップショット再 publish + Live Activity 終了)
- `MenstrualStore` の保存失敗握り潰し (`try?`) を `lastErrorMessage` で観測可能に
- `AppModelContainer` の App Group フォールバックに DEBUG/CI 用 `assertionFailure` (Release は graceful 維持)
- `CatMessageProvider.pickedMessage` の空配列クラッシュ landmine 修正 / ウィジェット書込失敗のログ追加

→ 実機 QA (🍎📱) は **`docs/DEVICE_QA_RUNBOOK.md`** に手順化済 (Apple Developer 加入後に実施)。

### 友達機能: v1 非表示 (決定)
- 理由: バックエンドが `MockFriendsService` (端末ローカルのみ) で本番では機能しないため。
- 実装: `AppFeatureFlags.friendsEnabled` を単一フラグに、タブ / iPad sidebar / ディープリンク振替 /
  プロフィール同期 / 設定の共有セクションを一括ゲート。`AppFeatureFlagsTests` で検証。
- 解禁: CloudKit 実装 (下記 P1) でフラグを true 固定 or 撤去すれば全導線が自動復帰。

---

## 直近の状態

- **iOS アプリ本体**: リリース運用基盤を追加 (レビュー依頼 / アプリ内フィードバック / データ書き出し+削除 / サブスク管理導線 / 行動分析の土台) + ウィジェット刷新 + 既存全機能維持
- **ウィジェット刷新 (2026-05-29)**: 絵文字 → ブランドのオレンジ猫画像 (状態連動) に差し替え。Dynamic Island の極小スロットは `pawprint.fill`。カード背景をグラデーションで派手化。文言を「1分だけでも」「1分だけでも運動しよう」に。widget 専用カタログ `CerealExerciseWidget/WidgetCatAssets.xcassets` (オレンジ7状態を384pxに縮小、1.1MB) を新設 (本体 Assets.xcassets は88MBで丸ごと同梱不可)。アセット欠落時は肉球記号にフォールバック。Codex 2R で収束。**注意: ウィジェット/Live Activity の実機レンダリングは CLI 検証不可** — 実機/シミュレータのホーム画面で要目視確認
- **テスト**: 全 unit PASS + UI **17/17**。新規 `DataManagementServiceTests` (6) + `ReviewRequestControllerTests` (4) を追加
- **Codex レビュー**: gpt-5.3-codex / xhigh で **5 ラウンド回し 0 findings / "patch is correct" に収束**。指摘して潰した内容: ①遅延購入の purchase_complete 取りこぼし → `handleVerified` で計測 ②レビュー Task の取り残し → cancellable `.task` ③削除後に Weight/Menstrual ストアがステイル → 3 ストアとも `.goDataDidReset` 購読 ④削除で救済使用履歴が残る → `RescueTicketStore.clear()` (購入残は保持) ⑤エクスポート名衝突 → 秒+UUID ⑥エクスポート一時ファイル残留 → 共有後に削除 ⑦保存失敗でも record_created 発火 → 成功時のみ計測
- **Codex CLI**: 2026-05-29 時点で `gpt-5.5` が利用可能 (本セッションの監査・ダブルチェックで使用)。background 実行時は `< /dev/null` で stdin を渡さないと "Reading additional input from stdin..." でハングするので注意
- **Apple Developer Program**: 注文 W1563167588、Welcome メール待ち
- **新規 SPM 依存**: TelemetryDeck 2.14.0 (`app/CerealExercise/project.yml`)

---

## アプリ開発チェックリスト対応 (2026-05-29 実装)

`~/Downloads/app_development_checklist.md` を、このアプリ (ローカルファースト /
バックエンドなし / 独自アカウントなし / 課金あり / 個人開発) の実態に合わせて
取捨選択して実装した。

### 実装済み

| 項目 | 実装 |
|---|---|
| レビュー依頼 | `ReviewRequestController` + `RecordCompletionView` で連続記録の節目 (7/30/100 日) の祝祭後に `requestReview`。最小間隔 90 日 + 同一節目は一度のみ。`--no-review-prompt` で抑止 |
| アプリ内フィードバック | `FeedbackComposer` (mailto + 端末/OS/版/言語の診断情報自動付与) → 設定「フィードバック」セクション (ご意見・不具合報告) |
| データ書き出し | `DataManagementService.writeExportFile()` → 運動/体重/体調を JSON 化し共有シート (設定「データ管理」) |
| データ全削除 | `DataManagementService.deleteAllRecords()` (記録のみ。購入/サブスク/無料体験状態は対象外)。削除後 `.goDataDidReset` 通知で `WorkoutStore` を再フェッチ |
| サブスク管理導線 | 設定に「サブスクリプションを管理」(`apps.apple.com/account/subscriptions`) |
| 行動分析の土台 | `Analytics` ファサード + `AnalyticsService` 抽象 + TelemetryDeck/Noop 実装。主要イベント計装済 (app_open / onboarding_complete / record_created / view_paywall / start_purchase / purchase_complete / data_exported / data_deleted) |
| クラッシュ監視 | **Apple 標準 (Xcode Organizer) のみ** を採用 (第三者 SDK なし)。実装コードは不要。運用は Organizer の Crashes で確認 |

### 該当しないと判断してスキップ

管理画面 / DB バックアップ / RLS / Rate Limit / CDN / 負荷テスト / Webhook /
独自認証・ログイン / AI 向け項目 → **サーバーがないため対象外**。
紹介リンク計測・リモート価格 A/B → バックエンド必須なので CloudKit 後に再検討。

### ⚠ TelemetryDeck 有効化の残作業 (App ID 設定までは送信ゼロ)

現状は `Info.plist` の `TelemetryDeckAppID` が空 = `Analytics` は Noop で **一切送信しない**
(プライバシーラベル「データ収集なし」を維持)。有効化する時の手順:

1. TelemetryDeck ダッシュボードで App ID (UUID) を取得
2. `project.yml` の `TelemetryDeckAppID` に設定 → `xcodegen generate`
3. **App Store Connect のプライバシーラベル**を「使用状況データ (Product Interaction) / 個人と紐付けない」に更新
4. プライバシーポリシーは既に TelemetryDeck を記載済 (`docs/privacy.md` / `submission/PrivacyPolicy.md` の第 4 章)
5. 計測は Release ビルドのみ有効 (DEBUG は送信しない)

---

## 課金再設計: GOプレミアム (2026-05-29)

¥1,000 保険チケット (消耗型) を含む旧課金を全面刷新し、統合サブスクに一本化した。

| 項目 | 内容 |
|---|---|
| 商品 | **GOプレミアム** 月額 ¥480 / 年額 ¥3,800 (同一 subscription group)、**14日間無料**トライアル |
| 解放内容 | 体重タブ全機能 + 連続記録フリーズ **月4回** (無料は月1回) + 将来テーマ等 |
| 廃止 | **¥1,000 保険チケット (消耗型 IAP) を完全廃止**。体重 Pro 単独サブ (¥500/月) も廃止 |
| 体重タブ | 独自30日トライアルを廃止し **Premium ゲート**化 (試用はサブの14日無料)。ホームの体重入力は無料のまま |
| クラッシュ/分析 | 変更なし (前セッションの方針を維持) |

**実装メモ**:
- `Products.storekit`: consumable 削除、premium_monthly/premium_yearly + P2W 無料トライアル
- `StoreKitManager`: `isWeightProActive`→`isPremiumActive`、消耗型インフラ(hook/queue)を撤去
- `WeightAccessGate` 削除 (体重タブは `storeKit.isPremiumActive` で直接ゲート)
- `RescueTicketStore`: purchasedRemaining 撤去、月次枠のみ。`RescueTicketAllowance.current(isPremium:)` = 4 / 1
- 新 `PremiumPaywallSheet` (月/年選択・年額推し・14日無料・復元・規約)。体重タブ/フリーズ枠/設定から起動
- App Store Connect 登録時の価格: 月¥480 / 年¥3,800 (Tier は加入後に設定)

⚠ **App Store Connect 作業 (Apple Developer 加入後)**: 新 productID 2 本 (`premium_monthly` / `premium_yearly`) を登録、14日無料トライアル設定、サブスクグループ作成。

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

### 🟡 P1 — 友達 (CloudKit) 本実装 = v1.1 で解禁 (Apple Developer 加入後)

> v1 は `AppFeatureFlags.friendsEnabled=false` で非表示。下記完了後にフラグを true 固定 or 撤去して解禁。

| # | タスク |
|---|---|
| 1 | iCloud Capability 有効化 |
| 2 | Sign in with Apple Capability |
| 3 | `CloudKitFriendsService` 実装 (Mock と差し替え) |
| 4 | `AppFeatureFlags.friendsEnabled` を true 固定 or 撤去 (全導線が自動復帰) |
| 5 | Push 通知 entitlement + CKQuerySubscription |
| 6 | iCloud 2 アカウントで実機相互テスト |
| 7 | `weeklyAchievements` / `monthlyTotalMinutes` / `myCatBreed` の daily publish |
| 8 | 週間ランキングをデンス順位 (1,1,2) 化 (現状は競争順位 1,1,3。Gemini 指摘) |

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

**Welcome メール (Apple Developer 加入) 届いていれば** → 最優先で:
1. `docs/DEVICE_QA_RUNBOOK.md` の手順0 (App ID / Capabilities / サブスク登録 / Sandbox テスター)
2. **B. 課金 Sandbox QA** (リリース最重要ブロッカー)
3. CloudKit / HealthKit ブロッカー解除に着手
4. アプリ共有 URL を実 App Store URL に差し替え (`AppSharingConfig.swift`)

**届いていなければ** → 加入不要の P2 独自色フェーズ (週次/月次レポート、-3/-5kg マイルストーン祝賀等) を推奨。

NEXT_STEPS.md と memory の pending_tasks.md は同期済。

---

## 参照

- `README.md` — 機能一覧 + Phase 完了表
- `docs/QA_CHECKLIST.md` — リリース QA チェックリスト / `docs/DEVICE_QA_RUNBOOK.md` — 実機 QA 手順書 (Apple Developer 加入後)
- `MEMORY.md` — Claude のメモリインデックス
- `submission/screenshots/iphone-6.9/` — App Store スクショ
- `docs/ux_review/uxrevamp_{claude,gemini,codex,prompt}.md` — Phase 7.0 UX 刷新提案 3 LLM 分
