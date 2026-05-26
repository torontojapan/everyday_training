# Next Steps — GOエクササイズ

最終更新: 2026-05-27 (Phase 7.0 完全完了 + 大規模 audit + 演出強化 + リポジトリ整理)

---

## 直近の状態

- **iOS アプリ本体**: Phase 7.0 完全完了 (Step 1-4 + 全 audit + 演出強化 + 保険チケット連携)
- **テスト**: Unit **172/172** + UI **14/14** = **186 件 全 PASS**
- **最新コミット**: `adb06fc` リポジトリ整理 (142 ファイル削除)
- **GitHub**: `torontojapan/everyday_training` main に push 済
- **Apple Developer Program**: 注文 W1563167588、Welcome メール待ち

---

## 残タスク (優先度順)

### 🔴 P0 — App Store 提出ブロッカー

| # | タスク | 担当 |
|---|---|---|
| 1 | **Apple Developer Program 加入** | ユーザー作業 (Welcome メール待ち) |

(プライバシーポリシー / メタデータ / アイコン / スクショは完了済み)

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

1. **Welcome メール届いていれば** → P1 CloudKit 実装に着手
2. **届いていなければ** → P2 拡張案から好きなもの (Siri / Apple Watch / 並走モード / Codex 提案 7 件)
3. NEXT_STEPS.md と memory の pending_tasks.md は同期済

---

## 参照

- `README.md` — 機能一覧 + Phase 完了表
- `MEMORY.md` — Claude のメモリインデックス
- `submission/screenshots/iphone-6.9/` — App Store スクショ
- `docs/ux_review/uxrevamp_{claude,gemini,codex,prompt}.md` — Phase 7.0 UX 刷新提案 3 LLM 分
