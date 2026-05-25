# Next Steps — GOエクササイズ

最終更新: 2026-05-25 (commit `52eee5b`)

このファイルは「次セッションで何から手をつけるか」をすぐ思い出すための作業メモです。完了済み機能の網羅的な一覧は `README.md` / `MEMORY.md` を参照。

---

## 直近の状態 (要約)

- **iOS アプリ本体**: 機能実装は完了。Simulator で全画面動作確認済み。
- **テスト**: Unit 121 / UI 8 = **129 件すべて PASS**。
- **未コミット作業**: なし (working tree clean)。
- **未解決のバグ報告**: なし。

---

## 残タスク (優先度順)

### 🔴 P0 — App Store 提出に必要

| # | タスク | 概要 | 前提 |
|---|---|---|---|
| 1 | **Apple Developer Program 加入** | 年 ¥12,800、code signing と CloudKit / Sign in with Apple に必須 | ユーザー作業 |
| 2 | **プライバシーポリシー / 利用規約 作成** | 現状 `SettingsView` の "アプリ情報" 内に「今後追加します」と仮置き済み。友達機能が入ったので CloudKit 利用時はデータ収集明記必須 | テンプレ流用可 |
| 3 | **App Privacy ラベル更新** | 現在 "データを収集しない"。友達機能 ON 時は Identifiers / Friend list を申告 | プライバシーポリシー先 |
| 4 | **アプリアイコン最終版差し替え** | 現状は仮アイコンの可能性。`AppIcon.appiconset` 確認 | デザイン |
| 5 | **App Store スクリーンショット作成** | iPhone 6.9" (必須) / iPad (任意) | 実機 or Simulator |
| 6 | **メタデータ準備** | サブタイトル / 説明文 / キーワード / サポート URL | 文章作成 |

### 🟡 P1 — CloudKit 実装 (Phase 5.0 を本実装に昇格)

現在の `FriendsService` は `MockFriendsService` (UserDefaults + デモプール)。Mock で UI フローが完成しているので、`CloudKitFriendsService` に差し替えるだけで本番化できる状態。

| # | タスク | 概要 |
|---|---|---|
| 7 | iCloud Capability 有効化 | `CerealExercise.entitlements` に `com.apple.developer.icloud-container-identifiers = iCloud.com.serial.cerealexercise` |
| 8 | Sign in with Apple Capability 追加 | `AuthenticationServices` + entitlement |
| 9 | `CloudKitFriendsService` 実装 | Public DB に `UserProfile` / `FriendRequest` / `Cheer` レコードタイプ。`FriendsService` プロトコルに準拠 |
| 10 | `CerealExerciseApp` で本番/Mock 切替 | DEBUG=Mock, RELEASE=CloudKit |
| 11 | Push 通知 entitlement + Subscription | 友達からの cheer / 友達申請を受信 |
| 12 | 実機テスト | iCloud アカウント 2 つで相互承認・cheer 送受信 |

### 🟢 P2 — 将来 Phase (任意)

| # | タスク | フェーズ |
|---|---|---|
| 13 | 当日メニュー詳細共有 (回数・セットも opt-in で) | 5.1 |
| 14 | 週間ランキング (オプトイン) | 5.2 |
| 15 | 友達からの達成 push 通知 | 5.2 |
| 16 | Duolingo 風リーグ・昇格システム | 5.3 |
| 17 | 簡易チャット (CloudKit Shared DB) | 5.4 |
| 18 | Android 版検討 (CloudKit を破棄して Supabase 移行) | 6.0 |

### 🔵 P3 — メンテナンス

| # | タスク |
|---|---|
| 19 | iOS 19 / Xcode 18 への対応確認 (リリース時) |
| 20 | データ移行テスト (SwiftData migration) — 既存ユーザー想定 |
| 21 | Instruments による Allocations / Time Profiler チェック (実機) |
| 22 | Accessibility 監査 (VoiceOver / Dynamic Type 全画面) |

---

## 「次セッションで最初にやること」候補

1. **Apple Developer 加入が済んだら** → P1 #7 から順に CloudKit 実装
2. **加入前にできること**:
   - P0 #2 プライバシーポリシー文面ドラフト
   - P0 #4 アプリアイコン差し替え
   - P0 #5 App Store スクリーンショット撮影 (Simulator で可)
   - P3 #22 アクセシビリティ監査
3. **新機能要望が来た場合**: P2 タスクから優先度すり合わせ

---

## 参照

- `README.md` — 機能一覧 + Phase 完了表
- `MEMORY.md` — Claude のメモリインデックス
- `submission/screenshots/` — フェーズ別 Simulator スクリーンショット
- 直近主要コミット:
  - `52eee5b` 友達ボタンをホーム toolbar に / バッジ削除 / 設定順最適化
  - `84c64ca` 効果音 + CoreHaptics
  - `517028f` 4 段階祝祭演出 (CelebrationOverlay)
  - `1c4aa4b` 友達機能 MVP (Mock)
  - `fea1ffc` 5 テーマカラー
