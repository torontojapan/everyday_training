# Next Steps — GOエクササイズ

最終更新: 2026-05-25 (Phase 5.7 — バグ厳格回収 第二弾: validation / toast race / calendar / log)

このファイルは「次セッションで何から手をつけるか」をすぐ思い出すための作業メモです。完了済み機能の網羅的な一覧は `README.md` / `MEMORY.md` を参照。

---

## 直近の状態 (要約)

- **iOS アプリ本体**: 機能実装は完了 (Phase 5.6 まで)。Simulator で全画面動作確認済み。
- **テスト**: Unit **154** / UI 8 = **162 件 PASS**。
- **友達機能**: FriendDetailView + 週カレンダー + sort + 詳細から cheer / 削除まで完成。`FriendsStore` をアプリ root に注入済み。
- **音声演出**: 削除済み (Phase 5.5)。haptic のみ残存。
- **写真保存**: Info.plist 不備バグを修正 (NSPhotoLibraryAddUsageDescription 追加)。ImageSaver で完了 callback 経由のエラー処理。
- **Deep link**: cerealexercise://{home|record|history|settings|friends|notification-settings|streak-share} を `.onOpenURL` で処理 (Phase 5.6)。
- **通知タップ**: 記録画面に直接遷移するよう `AppDelegate + NotificationDelegate` を実装 (Phase 5.6)。
- **SettingsView**: アプリ情報セクションに privacy / terms / support 実リンクを追加 (Phase 5.6)。
- **未解決のバグ報告**: なし。
- **プライバシーポリシー / 利用規約 / メタデータ**: CloudKit + 友達機能用に更新済み。

---

## 残タスク (優先度順)

### 🔴 P0 — App Store 提出に必要

| # | タスク | 概要 | 前提 |
|---|---|---|---|
| 1 | **Apple Developer Program 加入** | 年 ¥12,800、code signing と CloudKit / Sign in with Apple に必須 | ユーザー作業 |
| 2 | ~~プライバシーポリシー / 利用規約~~ | ✅ 完了 (2026-05-25) — `docs/privacy.md` / `docs/terms.md` / submission 配下を CloudKit + 友達機能用に更新 | — |
| 3 | ~~App Privacy ラベル草案~~ | ✅ 完了 — `submission/app_store_metadata.md` の "プライバシー" セクションに転記用テーブル記載 | — |
| 4 | **アプリアイコン最終版差し替え** | 現状は仮アイコンの可能性。`AppIcon.appiconset` 確認 | デザイン |
| 5 | **App Store スクリーンショット作成 (本番版)** | iPhone 6.9" 必須 (1320×2868)。Phase 5.4 で開発用 5 枚を `submission/screenshots/phase5_4_friends/` に保存済み | 最終アイコンと配色 |
| 6 | ~~メタデータ準備~~ | ✅ 完了 — `submission/app_store_metadata.md` 全項目埋め済み | — |

### 🟡 P1 — CloudKit 実装 (Phase 5.0 / 5.4 を本実装に昇格)

現在の `FriendsService` は `MockFriendsService`。Mock で UI フロー (FriendsView / FriendDetailView / FriendAddView / Sign in) が完成しているので、`CloudKitFriendsService` に差し替えるだけで本番化できる状態。

| # | タスク | 概要 |
|---|---|---|
| 7 | iCloud Capability 有効化 | `CerealExercise.entitlements` に `com.apple.developer.icloud-container-identifiers = iCloud.com.serial.cerealexercise` |
| 8 | Sign in with Apple Capability 追加 | `AuthenticationServices` + entitlement |
| 9 | `CloudKitFriendsService` 実装 | Public DB に `UserProfile` / `FriendRequest` / `Cheer` レコードタイプ。`FriendsService` プロトコルに準拠 |
| 10 | `CerealExerciseApp` で本番/Mock 切替 | DEBUG=Mock, RELEASE=CloudKit |
| 11 | Push 通知 entitlement + Subscription | 友達からの cheer / 友達申請を受信 |
| 12 | 実機テスト | iCloud アカウント 2 つで相互承認・cheer 送受信 |
| 13 | 週カレンダー (`weeklyAchievements`) の同期 | 毎日 publish タイミングで最新 7 日分を更新 |

### 🟢 P2 — 将来 Phase (任意)

| # | タスク | フェーズ |
|---|---|---|
| 14 | 当日メニュー詳細共有 (回数・セットも opt-in で) | 5.5 |
| 15 | 週間ランキング (オプトイン) | 5.6 |
| 16 | 友達からの達成 push 通知 | 5.6 |
| 17 | Duolingo 風リーグ・昇格システム | 5.7 |
| 18 | 簡易チャット (CloudKit Shared DB) | 5.8 |
| 19 | Android 版検討 (CloudKit を破棄して Supabase 移行) | 6.0 |

### 🔵 P3 — メンテナンス

| # | タスク | 状態 |
|---|---|---|
| 20 | iOS 19 / Xcode 18 への対応確認 (リリース時) | pending |
| 21 | データ移行テスト (SwiftData migration) — 既存ユーザー想定 | 既存 SwiftDataMigrationTests あり |
| 22 | Instruments による Allocations / Time Profiler チェック (実機) | pending |
| 23 | アクセシビリティ監査 (VoiceOver / Dynamic Type) | ✅ Phase 5.4 で FriendsView / FriendDetailView を accessibility5 まで確認 |

---

## 「次セッションで最初にやること」候補

1. **Apple Developer 加入が済んだら** → P1 #7 から順に CloudKit 実装
2. **加入前にできること**:
   - P0 #4 アプリアイコン差し替え
   - P0 #5 App Store スクリーンショット撮影 (Simulator で可、launch arg `--mock-seed-friends --initial-route friends` で友達画面を直接撮れる)
   - 既存テストの UI test 拡充 (FriendsView / FriendDetailView の flow テスト)
3. **新機能要望が来た場合**: P2 タスクから優先度すり合わせ

---

## 開発時に便利な launch arguments

```bash
# 友達画面に直接遷移 (サインアウト状態)
--initial-route friends

# 友達画面 + Mock サインイン済み (友達 2 名・申請 1 件)
--initial-route friends --mock-seed-friends

# 友達画面 + 詳細シートを最初から開いた状態
--initial-route friends --mock-seed-friends --mock-open-friend-detail

# 友達追加画面を最初から開いた状態
--initial-route friends --mock-seed-friends --mock-open-friend-add

# 既存:
--no-notification-prompt    # 通知許可ダイアログをスキップ
--skip-milestones           # マイルストーン自動表示をスキップ
--seed-demo-data            # 12 日連続 + サンプル種目を投入
--seed-scenario {basic|long-streak|streak-broken|month-boundary|empty|edge-minute}
```

---

## 参照

- `README.md` — 機能一覧 + Phase 完了表
- `MEMORY.md` — Claude のメモリインデックス
- `submission/screenshots/phase5_4_friends/` — 友達機能 5 画面 + Dynamic Type 検証 2 枚
- 直近主要コミット:
  - (本コミット) Phase 5.4 友達体験完成: FriendDetailView + 週カレンダー + sort + FriendsStore 注入
  - `52eee5b` 友達ボタンをホーム toolbar に / バッジ削除 / 設定順最適化
  - `84c64ca` (歴史的: 効果音 + CoreHaptics。効果音は Phase 5.5 で削除)
  - `517028f` 4 段階祝祭演出 (CelebrationOverlay)
  - `1c4aa4b` 友達機能 MVP (Mock)
  - `fea1ffc` 5 テーマカラー
