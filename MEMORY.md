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
- 画像生成 API キー未設定のため、猫キャラはひとまず emoji + SF Symbol で表情差分を表現
- App Group `group.com.serial.cerealexercise` は Apple Developer ポータルでの作成が実機テスト時に必要
