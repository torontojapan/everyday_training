# CLAUDE.md — このリポでの作業規約 / 再発防止チェックリスト

このファイルは Claude Code が毎セッション読み込む。過去セッションで実際に起きたミスを
繰り返さないための具体ルール。**着工前と提出前に該当項目を照合すること。**

## 0. ツール呼び出しの出力(最優先・2026-06-18 大量空転の教訓)
- **ツール呼び出しは正規の関数呼び出しブロックだけで行う。** 本文(散文)に「invoke」「parameter」等の
  タグ風テキストや、`court` / `call` のような断片トークンを書かない。harness はそれをパースできず
  **実行されずに空転**し、ユーザーには「止まった」ように見える(Tokens が進まない)。
- 散文は最小限に。**迷ったら 1 メッセージ 1 ツール。** ツール呼び出しの直後に余計な文字を続けない。
- 参照: memory `feedback_tool_call_format`。

## 1. 視覚成果物は必ず実画面/実描画で自己検証(memory `feedback_visual_selfcheck`)
- 「○○のように見える」と主張する前に、スクショ/レンダ画像を切り出し拡大して**主張どおりか自分の目で確認**。
- iOS: `--initial-route <route>` `--no-notification-prompt` `--seed-demo-data` 等で直接起動 →
  署名ビルド必須(無署名は App Group entitlement 欠落で AppModelContainer.make() クラッシュ)。
- Android: Canvas 描画は instrumented test で render → PNG を MediaStore 保存し `adb pull`(アンインストールで
  app 内ファイルは消える)。画面は assembleDebug→install→`adb exec-out screencap -p`。
- Android にデモ記録(records)シードは無い(iOS の `--seed-demo-data` 相当なし)→ content は UI から作成。

## 2. LLM/サブエージェントの所見は鵜呑みにせず裏取り
- 監査エージェントは**過大申告・「未確認」**が多い。所見は該当コードを直接読んで確定してから報告/修正する。
- 実例(2026-06-18 パリティ監査): 「Weekly カードKPI相違」「英字バッジ残存」はデッドコード由来の**誤検知**だった。
- 検証ワークフロー: 実装 → 2LLM(Claude 並列 + Codex)監査 → **Codex で correct 収束まで**再検証して報告
  (memory `feedback_verification_workflow`)。codex は ChatGPT アカウントだと `gpt-5.x-codex` 不可 → 既定モデルで実行。

## 3. リリース(iOS)前チェック
- `xcodegen generate` は Info.plist の手動キー(FriendsAppleLinkEnabled / FriendsGoogleLinkEnabled /
  TelemetryDeckAppID / NSCameraUsageDescription / ITSAppUsesNonExemptEncryption)を**落とす**。Archive 前に必ず再確認
  (memory `gotcha_xcodegen_infoplist_drop`)。
- ASC は同一バージョン内の**ビルド番号の重複/降順を拒否**。差し替え時は CURRENT_PROJECT_VERSION を +1。
- 署名ありビルドで Release コンパイルが通ることを Archive 前に確認。

## 4. バックエンド(Supabase)スキーマ変更は「DB を先に」
- 新カラムを送る publish を出す前に、本番 DB に `alter table ... add column if not exists` を適用。
  未適用だと PostgREST が unknown column で **upsert 全失敗**(例: `weekly_statuses`)。schema.sql に冪等 alter を同梱。

## 5. 再発バグの型カタログ(着工前後で grep 照合)
memory `gotcha_recurring_bug_classes` を参照。要点:
- 口座スコープ漏れ / 月境界 UTC↔ローカル / シート dismiss 未処理 / rescuedDates 渡し忘れ /
  連続=「昨日まで」×自動休養の相互作用 / UUID 大小 / state-machine 列は RLS でなく trigger+INSERT WITH CHECK /
  演出は記録後だけ / protocol 拡張の既定実装が override を隠す(静的ディスパッチ) /
  **順序不定・非均質コレクションから `.first` で1件取り状態と断定**(複数連携プロバイダ表示の誤りが実例)。

## 6. 環境メモ
- repo 実体 = `~/Developer/serial_training`(iCloud 圏外)。必ずここから開く。
- iOS build/test: Xcode。Android build: `JAVA_HOME=/Applications/Android Studio.app/Contents/jbr/Contents/Home`、
  `./gradlew :app:testDebugUnitTest`。emulator AVD `go_test` は `-no-window -gpu swiftshader_indirect` で起動。
- 既定ブランチ(main)直編集を避け、feature ブランチを切ってから着工。
- 現況の正本は memory `remaining_tasks_inventory`(冒頭「★★★最新ハンドオフ」)。
