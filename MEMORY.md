# 進捗・知見ログ

## 2026-05-23

### セットアップ

- ハーネス構築開始
- ユーザー方針確定:
  - 技術スタック: SwiftUI ネイティブ (Xcode)
  - スコープ: Phase 1〜3
  - Plan/統括: Claude (本セッション)
  - Execute: Codex CLI 単独 (Antigravity は CLI 未提供のため不採用)
  - Evaluate: Gemini CLI (独立性確保)
  - 画像生成: OpenAI画像API → Nanobanana fallback
  - 自律進行モード (人間承認は最小限)

### 環境状況

- Codex 0.132.0: ChatGPT ログイン済み ✅
- Gemini 0.41.2: ログイン済み ✅
- Xcode: 未インストール ❌ → ユーザーが並行インストール中
- OPENAI_API_KEY: 未設定 ⚠️
- GOOGLE_API_KEY / GEMINI_API_KEY / NANOBANANA_API_KEY: 未設定 ⚠️
- 画像生成は API キーが必要。Phase 1 完了時点でユーザーに依頼予定

### ハーネス構築

- ディレクトリ作成 ✅
- 設計書 HARNESS.md ✅
- エージェントロール agents/plan, agents/execute, agents/evaluate ✅
- ラッパー orchestrator/run_codex.sh, run_gemini_eval.sh, gen_image.sh, phase_runner.sh ✅

### Phase 1: MVPコア — 完了 (PASS)

- Plan (Claude): artifacts/phase1/plan.md
- Execute (Codex): 35ファイル生成 / artifacts/phase1/execute_log.md
- Evaluate (Gemini, 独立): PASS / artifacts/phase1/evaluation.md
  - §24.1〜§24.4 全項目 ✅
  - Low priority 指摘 2件 (アクセシビリティ補強・UIアニメ) → Phase 3 で対応

### Phase 2: 習慣化体験 — 完了 (PASS)

- Plan: artifacts/phase2/plan.md
- Execute: 21ファイル追加 (Widget extension 8 + Services 5 + Models 2 + Views 1 + Components 1 + entitlements 2 + Tests 3 等)
- Evaluate: PASS / artifacts/phase2/evaluation.md
  - §24.5 通知 PASS 2 + PARTIAL 2 (UI は Phase 3 設計通り)
  - §24.6 Widget PASS 3 + PARTIAL 1 (Small Widget の達成率は Phase 3 検討)
  - Phase 1 リグレッションなし

### Phase 3: 改善 — 完了 (PASS)

- Plan: artifacts/phase3/plan.md
- Execute: 12ファイル追加/更新 (HistoryView, NotificationSettingsView, SettingsView, ExerciseHistoryProvider, Motion, etc.)
- Evaluate: PASS / artifacts/phase3/evaluation.md
  - **§24 全 30 項目 (6+8+5+3+4+4) PASS**
  - Phase 1/2 リグレッションなし
  - **MVP リリース可能水準と判定**
  - 残課題: App Store Connect 提出用アセット (アイコン/スクリーンショット), プライバシーポリシー URL
- 累積ファイル数: 68

### 自律進行サマリ

人間承認を求めずに3フェーズ完走:
- 環境制約2件 (Xcode 未インストール, Antigravity GUI のみ) は事前確認で方針確定
- 各フェーズで Plan(Claude) → Execute(Codex) → Evaluate(Gemini独立) を回し、リワーク不要で全 PASS
- 画像生成 API キーは未設定のため猫キャラは emoji + アニメで実装、画像差し替えポイントは用意済み

### ビルド検証 — 完了 (Xcode 26.5, iPhone 17 Pro / iOS 26.5 Simulator)

- `xcodegen generate` ✅
- `xcodebuild build` ✅ BUILD SUCCEEDED
- `xcodebuild test` ✅ **51 passed, 0 failures**
- `simctl install` + `launch` ✅ ホーム画面表示 (スクショ: assets/screenshots/)

### Swift 6 strict concurrency 修正 (Codex生成時の見落とし)

- `NotificationScheduler.swift:33` `NotificationScheduling` プロトコルに `Sendable` 追加
- `NotificationSchedulerTests.swift:74` Spy クラスに `@unchecked Sendable`
- `NotificationSchedulerTests.swift:6` テストクラスに `@MainActor`

### 知見

- Xcode 26.5 のデフォルト Swift 6 では `async` メソッドを持つプロトコルは Sendable 必須
- `simctl privacy <udid> grant notifications <bundle>` は Simulator のセキュリティで Operation not permitted
- AppleScript で System Events 経由で Simulator UI を操作するには System Events に Accessibility Permission が必要 (未付与だと AppleEvent timeout)
- iOS Simulator のタップ自動化は Xcode UITest 経由が確実 (本プロジェクトでは未導入)

### 知見・判断

- Gemini CLI を `--approval-mode plan` で起動すると write_file ツールが plan ディレクトリ以外への書き込みを拒否する。run_gemini_eval.sh が tee で出力をファイル化しているので実害なし
- Codex は `gpt-5-codex` (?) を使用し、Phase 1 で 95K tokens 程度を消費
- WorkoutRecord.exercises の getter で毎回 JSON decode は性能リスク (将来必要ならキャッシュ)
- StreakCalculator.streakState は lookbackDays=365 で重い (使用箇所限定して呼ぶ)
- App Group `group.com.serial.cerealexercise` は Apple Developer ポータルでの作成が実機テスト時に必要
- Codex は実は `image_generation` を内蔵 (`codex features list` で stable) — ChatGPT 認証経由で画像生成可。8 枚を 1 コマンドで作成成功

## 2026-05-24 〜 2026-05-25 (継続セッション)

### Phase 3.5: UI/UX 改善 (中優先)

- ホーム余白活用 (TodayAchievementSummaryCard / WeeklyHighlightCard)
- iPad NavigationSplitView (RootSplitView)
- 保存後 ConfirmationDialog (続けて記録 / 完了画面 / キャンセル)
- DatePicker chevron + 通知未許可 warning banner
- サジェスト空状態
- ハプティクス (protocol DI 可)
- Reduce Motion 対応
- Gemini Evaluate: **PASS** (8 項目すべて ✅、改善提案なし)

### Phase 3.6: 細かい改善

- 王道筋トレ種目候補 12 種 (+ 全カテゴリで 8 種ずつ)
- 記録入力から「秒」欄を削除 (分単位のみ)
- 「続けて記録」後の保存ボタン bug 修正 (resetAfterSave で first id 保持)
- 週間カレンダー曜日タップで DayDetailSheet

### Phase 3.7: 連続記録ロジック + シェア画面

- 連続記録は **実際に運動した日のみカウント** (休養日はスキップ、破壊しない)
- StreakBadgeView 化 (タップで SNS 共有可能なシェア画面)
- StreakLevel 6 段階 (sprout / week / twoWeeks / month / century / legend)
- 日数別装飾 (見出し / 火 emoji 数 / sparkle / バッジ / グラデ)
- ImageRenderer + ShareLink で画像化共有

### Phase 3.8: ブランド改名 + Widget 促進

- 全テキストで「シリアルエクササイズ」→「**GOエクササイズ**」(英字も「GO Exercise」)
- Bundle ID, target 名 (CerealExercise) は維持 (TestFlight 互換性のため)
- 設定画面に「ホーム画面ウィジェット」セクション + 「追加方法を見る」ボタン → 5 ステップ案内 Sheet
- Widget テスト拡充 (WidgetSnapshotFactoryTests 6 + WidgetSnapshotPublisherTests 3)

### Phase 3.9: ホーム改善 + 履歴月間カレンダー

- 休養日 symbol 「休」維持 (一度「/」にしたが要望で revert)
- 累計 運動日数/利用日数 表示 (LifetimeStatsCard)
- ホームヘッダーのサービス名を左揃え (.large 表示)
- 履歴ページに月間カレンダー (MonthlyCalendarView、前後月ナビ、達成色、今日ハイライト)
- HistoryView/SettingsView に明示「< ホーム」back button

### Phase 4.0: 5 エンゲージメント機能

- **保険チケット** (月1回、未達成日を救う) — RescueTicketStore
- **猫の装飾** (累計達成日で豪華に) — CatDecoration (バンダナ→ヘッドバンド→メダル→王冠)
- **アチーブメントバッジ** (15 種) — AchievementCatalog + AchievementsListView (toolbar rosette)
- **月次レビュー** (前月サマリー + SNS シェア) — MonthlyReviewBuilder + Sheet
- **記念日演出** (1周年/累計100日/連続100日) — MilestoneDetector + 起動時 Sheet
- Cat decoration は CatStateView で自動オーバーレイ (猫の頭)

### Phase 4.1: UX 整理

- 猫メッセージをホーム最上部に (視覚アンカー)
- RewardCard 新設 → ユーザー要望で削除 (装飾は猫頭に自動表示で十分、保険チケットは設定へ)
- 月次レビュー自動表示 (MonthlyReviewTracker で月1回)
- 記録完了画面に「もう一種目を記録する」追加

### Phase 4.2: 体重 + 体調管理

- WorkoutCategory に **`fasciaRelease`** (筋膜リリース) 追加 + 種目候補 8 種
- **体重管理機能** (WeightEntry @Model + WeightStore + WeightView)
  - Swift Charts で推移グラフ
  - 30 日変化、減量は緑表示
  - 設定 + ホーム下部から到達 (NavigationLink)
- 記録入力画面に「**今日の体重 (任意)**」セクション → 同日保存でグラフ反映
- 種目メモ input bug 修正 (axis: .vertical → 単行 TextField + 背景 pill)
- **体調・周期記録** (オプトイン、Toggle のみ) — MenstrualEntry + 履歴カレンダーに ★

### CI / リリース基盤

- CI: GitHub Actions (macos-15) で xcodebuild build + test、ノートPC同等
- リポジトリ Public + GitHub Pages (privacy / terms / support 公開) — `https://torontojapan.github.io/everyday_training/`
- App Store 提出パッケージ (submission/) 完備、メタデータ・スクショ全サイズ・アイコン (Codex 生成画像) 揃い済み

### 最終状態 (2026-05-25)

| 項目 | 値 |
|---|---:|
| Swift files | 103 |
| ユニットテスト | 113 (全 PASS) |
| UI テスト | 8 (全 PASS) |
| 累計 commits | 39 |
| カテゴリ数 | 6 (有酸素 / 筋トレ / ヨガ / ストレッチ / 筋膜リリース / その他) |
| §24 受け入れ条件 | 30/30 ✅ |
| Release アプリサイズ | 8.3 MB (Assets.car 5.5 MB) |
| CI status | ✓ green |

### この後 (人間アクション待ち)

1. Apple Developer Program 加入 ($99/年)
2. App Store Connect でアプリ作成 + メタデータ・スクショ登録 (submission/ から)
3. TestFlight ベータ配信 + App Review 提出
