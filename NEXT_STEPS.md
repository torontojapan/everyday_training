# Next Steps — GOエクササイズ

最終更新: 2026-05-26 (Phase 7.0 Step 1-3 完了 — 大規模 UI/UX 刷新)

---

## 直近の状態

- **iOS アプリ本体**: Phase 7.0 で大規模 UI/UX 刷新完了 (Step 3 まで)
- **テスト**: Unit **172** / UI **14** = **186 件 全 PASS**
- **最新コミット**: `453d7db` Phase 7.0 Step 1-2 スクショ更新
- **Codex usage limit**: 18:11 まで生成不可 (画像 19 枚 + UX 提案 3 つ目)
- **Apple Developer Program**: 注文 W1563167588、Welcome メール待ち

---

## 残タスク (優先度順)

### 🔴 P0 — Apple Developer 加入待ち中の即時タスク

| # | タスク | 工数 | 状態 |
|---|---|---:|---|
| A1 | Phase 7.0 Step 4: Live Activity / Dynamic Island 常駐猫 | 2-3h | pending |
| A2 | tuxedo / persian / scottish 残 19 画像生成 (Codex 18:11 復帰後) | 20-30m | Codex 待ち |
| A3 | Codex UX 刷新提案 (3 LLM 目)、Antigravity はユーザー側 | 5m | Codex 待ち |

### 🔴 P0 — App Store 提出ブロッカー (Apple Developer 必須)

| # | タスク | 担当 |
|---|---|---|
| 1 | **Apple Developer Program 加入** | ユーザー作業 (Welcome メール待ち) |

(プライバシーポリシー / メタデータ / アイコン / スクショは完了済み)

### 🟡 P1 — CloudKit 本実装 (Apple Developer 加入後)

| # | タスク |
|---|---|
| 7 | iCloud Capability 有効化 |
| 8 | Sign in with Apple Capability |
| 9 | `CloudKitFriendsService` 実装 (Mock と差し替え) |
| 10 | DEBUG=Mock / RELEASE=CloudKit 切替 |
| 11 | Push 通知 entitlement + CKQuerySubscription |
| 12 | iCloud 2 アカウントで実機相互テスト |
| 13 | `weeklyAchievements` / `monthlyTotalMinutes` / `myCatBreed` の daily publish |

### 🟢 P2 — 将来 Phase (任意)

| # | タスク | 状態 |
|---|---|---|
| 14 | 当日メニュー詳細共有 (Phase 5.8 完了, Mock) | ✅ |
| 15 | 週間ランキング (Phase 5.9 完了) | ✅ |
| 16 | 友達からの達成 push 通知 | CloudKit + Push 後 |
| 17 | Duolingo 風リーグ | ❌ Phase 6.1 でスコープ外決定 |
| 18 | 簡易チャット | ❌ スコープ外 |
| 19 | Android 版検討 | 6.0 (将来) |

### 🟢 P2 — Phase 7.0 拡張案 (Claude/Gemini 提案より)

| # | タスク | ソース |
|---|---|---|
| 20 | Siri ショートカット (App Intents 拡張) | Claude 独自 |
| 21 | Apple Watch コンパニオン | Claude 独自 |
| 22 | 友達と並走モード (同期セッション) | Claude 独自 |
| 23 | アンビエントなソーシャル通知 | Gemini 独自 |
| 24 | 「ねこ撫でた日」帳消し演出 | Gemini 独自 |

### 🔵 P3 — メンテナンス

| # | タスク | 状態 |
|---|---|---|
| 25 | iOS 19 / Xcode 18 対応 | リリース時 |
| 26 | Instruments 実機計測 | 実機入手後 |

---

## Phase 7.0 進捗

| Step | 内容 | コミット | 状態 |
|---|---|---|---|
| 1 | TabView + ホーム猫劇場 + ハーフ sheet 記録 | `0edcae8` | ✅ |
| 2 | Positive-Only Calendar + 友達公園ビュー | `69dead7` | ✅ |
| 3 | Interactive Widget (AppIntent でアプリレス記録) | `18a5832` | ✅ |
| 4 | Live Activity / Dynamic Island 常駐猫 | — | pending |

---

## 次セッションで最初にやること

1. **Codex 復帰確認** (18:11 以降):
   - 残 19 画像 (tuxedo×5 + persian×7 + scottish×7) 生成 → 透過化 → install
   - UX 刷新提案 (3 LLM 目) 取得
2. **Phase 7.0 Step 4 (Live Activity)** を実装するか判断
3. **Welcome メール届いていれば** P1 CloudKit 実装へ

---

## 参照

- `README.md` — 機能一覧 + Phase 完了表
- `MEMORY.md` — Claude のメモリインデックス
- `submission/screenshots/iphone-6.9/` — App Store スクショ (Phase 7.0 反映済み)
- `docs/ux_review/uxrevamp_claude.md` / `uxrevamp_gemini.md` — UX 刷新提案
- 直近主要コミット:
  - `453d7db` Phase 7.0 Step 1-2 スクショ更新
  - `18a5832` Phase 7.0 Step 3: Interactive Widget
  - `69dead7` Phase 7.0 Step 2: Positive Calendar + 公園
  - `0edcae8` Phase 7.0 Step 1: TabView + 猫劇場
  - `96c653e` Phase 6.7 + 6.8: 自分のキャラ選択 + 月間ランキング
  - `1b2121a` Phase 6.6: 10 種類の猫アバター
