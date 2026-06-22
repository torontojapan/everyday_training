# セキュリティ堅牢化 計画 / 実装記録 — 2026-06-22

脆弱性評価（iOS / Android / Supabase）の所見に対する修正。branch `fix/security-hardening-2026-06-22`。
**push / 本番デプロイは行わない**（schema は適用手順を残すのみ）。検証は Codex 改善ループ + ビルド/テスト。

## デプロイ互換性の前提（重要）
- 配信済みクライアント（iOS 1.2 公開 / 1.3 審査中）は `profiles` を `friend_code`/`username` で
  **直接全列 SELECT** する。RLS で SELECT を封鎖すると現行ユーザーの友達機能が壊れる。
- → **V1 / V3 は後方互換**（不正な write のみ拒否、正規の accept/referral は通る）＝即適用可。
- → **V2（profiles 絞り込み）は段階移行**：schema に discovery 用 SECURITY DEFINER RPC を追加し、
  新クライアントは RPC 経由（RPC 不在時は旧 `eq()` にフォールバック）。本番の SELECT 封鎖ポリシーは
  **全クライアントが新版に上がってから**カットオーバー（schema にコメントで封鎖版を同梱）。

## 作業項目
### バックエンド（supabase/schema.sql）— 私が実装
- [V1] friendships BEFORE INSERT トリガ：`auth.uid()` 宛の friend_request か、`auth.uid()` が referee の
  referral が存在する時のみ INSERT 許可。クライアント直挿しの強制友達化を遮断。
- [V3] cheers / friend_requests に時間窓レート制限トリガ（直近1時間の自分発の件数上限）。
- [V2] `find_profile_by_code(text)` / `search_profiles_by_username(text)` を SECURITY DEFINER で追加し、
  **非機微列のみ**返す（today_exercise_details 等は除外）。封鎖版 profiles_select はコメントで同梱。
- 入力 DB CHECK：display_name / username に length 上限（防御多層）。

### iOS（app/GOExercise）— サブエージェントA
- [iOS-1] SwiftData ストアファイルに `.completeUnlessOpen` 保護を付与（widget 背景アクセスと両立）。
- [iOS-2] username 検索の LIKE メタ文字（`% _ \`）エスケープ。
- [iOS-4] friend_code の pasteboard コピーを localOnly + 60s expiry に。
- [iOS-5] display_name / username をクライアントで length clamp + 制御文字除去。

### Android（app-android）— サブエージェントB（小）/ C（暗号）
- [And-4] FriendCode 生成を `SecureRandom` に（iOS は CSPRNG でパリティ確保）。
- [And-5] OAuth `state` 生成 + callback 検証（PKCE に多層防御を追加）。
- [And-6] display_name / username の length clamp。
- [V3-And] signInAnonymously に captchaToken 経路を追加（iOS パリティ）。
- [And-1] Room を SQLCipher 化（平文→暗号の一回移行、鍵は Keystore 由来 passphrase）。
- [And-2] 生理 DataStore を暗号化（Keystore 鍵）。
- [And-3] supabase-kt セッションを暗号化 SessionManager に。

### 検証
- Codex（既定モデル gpt-5.5）で全差分を correct 収束までレビュー反映。
- Android: `:app:assembleDebug` + `:app:testDebugUnitTest`、可能なら emulator スモーク。
- iOS: 署名ビルドでコンパイル確認。
- V2/V3 の本番 RLS 動作は anon key 必要（owner 検証用スクリプトを supabase/ に用意）。

---

## 実施結果（2026-06-23 完了）

### 検証サマリ
- **V1/V3 トリガ**: ローカル Postgres 16 で回帰テスト `supabase/test_security_triggers.sql` = **10/10 PASS**
  （一方的友達化の遮断・accept/referral 正規経路の許容・レート制限・過去日時詐称バイパスの封鎖）。
- **schema.sql**: ローカル PG へ全適用クリーン。RPC の EXECUTE 権限 = `authenticated` のみ（anon/public は revoke 確認）。
- **Android**: `:app:assembleDebug` + `:app:testDebugUnitTest` = **BUILD SUCCESSFUL**（SQLCipher/暗号prefs/暗号Session 含む）。
- **iOS**: シミュレータ向け `xcodebuild build` = **BUILD SUCCEEDED**。

### Codex 改善ループ（gpt-5.5・correct 収束まで）
- Round1: 全差分レビュー → 5 件指摘。
  - F1[High] RPC が PUBLIC/anon 実行可能 → `revoke ... from public, anon` + `auth.uid() is not null` 多層防御。
  - F2[High] Android OAuth state/nonce 照合が GoTrue の正規 callback を誤拒否 → nonce 照合を撤去し
    in-flight 存在チェックのみに（state 検証は PKCE/SDK 委譲）。
  - F3[Med] 平文→暗号 DB 移行の失敗時にクラッシュループ/データ喪失リスク。
  - F4[Med] Android username 検索の LIKE エスケープ漏れ → `\ % _` エスケープ（iOS パリティ）。
  - F5[Med] iOS ファイル保護が後発 -wal/-shm を取りこぼし → 開く前にディレクトリ既定保護も設定。
- Round2–8（F3 のクラッシュ整合性を反復強化）:
  - 移行結果を enum 化し失敗時は平文で開く（SQLCipher で平文を開く起動不能ループを回避）。
  - 原本は **atomic rename 限定**で `.migrate-bak` 退避（部分コピーを排除）+ 失敗時復元。
  - passphrase は最終検証成功後に **commit()（同期・耐久）** 保存、その後にのみ backup 削除。
  - 起動時回復は passphrase を **先に durable clear** してから平文復元。
  - `getOrCreatePassphrase()` は耐久書き込み失敗時に throw（鍵を失った暗号 DB を作らない）。
  - 最終 Codex 判定: **「NO DATA-LOSS PATH」**（残存は劣化端末で commit 失敗時の一過性事象のみ・データは
    常に goexercise.db か .migrate-bak に保持）。

### 未デプロイ／owner 作業（このセッションでは push/deploy しない）
- `supabase/schema.sql` を本番へ適用（V1/V3/V2-RPC/長さ check）。V2 の profiles_select 封鎖は
  全クライアント更新後にコメント解除でカットオーバー。
- Turnstile 有効化（V3 の CAPTCHA 層）、Android の captchaToken 経路実装はフォローアップ。
- 実機/エミュで Android 暗号化（SQLCipher 移行・暗号セッション）と iOS ファイル保護の動作確認。
