# Next Steps — GO エクササイズ

最終更新: 2026-05-29 (リブランド + ASC セットアップ + 友達 CloudKit 実装)

---

## 現在地

- **アプリ名 / 識別子**: ユーザー向け表示名 **「GO エクササイズ」** / 内部・コードは **GOExercise** /
  Bundle ID **`com.goexercise.app`** / App Group **`group.com.goexercise.app`** /
  URL スキーム **`goexercise://`** (旧 CerealExercise・com.serial は全廃)。
- **テスト**: ユニット **175** + UI **17** = 全 PASS。Debug / Release ビルド成功。
- **Apple Developer**: 加入完了 (注文 W1563167588)。
- **App Store Connect セットアップ完了**:
  - App ID `com.goexercise.app` 登録 / App Group 紐付け
  - アプリレコード「GO エクササイズ」作成 (SKU `goexercise001`)
  - 有料App契約に同意済 (※銀行口座・納税フォームは未入力 = 販売開始前に要完了)
  - サブスク2本登録: `…premium_monthly` **¥500** / `…premium_yearly` **¥3,800**、
    グループ `GO Premium`、両方 **14日無料**、全世界配信、ファミリー共有OFF
  - Sandbox テスター ×2 (日本)
- **署名**: `project.yml` に `DEVELOPMENT_TEAM=29YX3L7B47` 設定済 (実機ビルド用)。
- **友達 (CloudKit)**: バックエンド **実装済み (休眠中)**。`CloudKitFriendsService` (Public DB)。
  `friendsEnabled` は Release=false のまま → 実機2アカウント疎通テスト (runbook I) 後に解禁。
- **git**: `main` に全コミット済。CloudKit 2 コミットは **未 push** (`! git push origin main` はユーザー操作)。

> 環境注意: リポジトリが `~/Documents` (iCloud 同期下)。大量ファイル操作後は
> `find . -name "* [0-9].*"` で iCloud 重複ファイルが湧いていないか確認すること。

---

## 残タスク (優先度順)

### 🔴 P0 — リリースブロッカー (ほぼ実機作業)

`docs/DEVICE_QA_RUNBOOK.md` に手順あり。実機 + Sandbox/iCloud アカウントが必要。

| # | タスク | 参照 |
|---|---|---|
| 1 | A. 実機ビルド・署名・App Group 確認 | runbook A |
| 2 | **B. 課金 (GOプレミアム) Sandbox QA ★最重要** | runbook B |
| 3 | C. 全削除→各ストア即リフレッシュ / D. 通知 | runbook C/D |
| 4 | E. ウィジェット / F. Live Activity の実機目視 (CLI 検証不可) | runbook E/F |
| 5 | **I. 友達 (CloudKit) 実機2アカウント疎通** → OK なら `friendsEnabled` Release=true | runbook I |
| 6 | サブスク審査用スクショ (ペイウォール) を ASC にアップロード | B 実施時に撮影 |
| 7 | 銀行口座・納税フォーム入力 (有料App契約を「有効」に) | ASC ビジネス |
| 8 | EU トレーダーステータス提出 (or EU を配信対象から除外) | ASC ビジネス |
| 9 | アプリ共有 URL を実 App Store URL に差し替え | `AppSharingConfig.swift` |

### 🟡 友達 CloudKit 解禁の具体手順 (runbook I)

1. Developer ポータル: App ID に **iCloud capability ON** + CloudKit コンテナ `iCloud.com.goexercise.app` 作成
2. CloudKit Console: 実機初回起動でスキーマ自動生成 → クエリ用 Index を **QUERYABLE** に → **本番へ Deploy**
3. 実機2台 (別 iCloud) で DEBUG ビルドを `--enable-friends --cloudkit-friends` 起動 → 申請/承認/表示/検索/削除/チア疎通
4. OK → `AppFeatureFlags.friendsEnabled` の Release を `true` に → コミット → 友達導線が自動復帰

### 🟢 P2 — 任意 (リリース後でも可)

- HealthKit 双方向同期 (スマート体重計取り込み)
- 運動+連続記録+体重の週次/月次レポート
- 体重マイルストーン祝賀 (-3kg/-5kg で猫演出)
- ブラインドウェイト (数値非表示モード)
- Siri ショートカット (App Intents) / Apple Watch コンパニオン
- Codex UX 提案 7 件の実装検討 (`docs/ux_review/uxrevamp_codex.md`)

❌ スコープ外: Duolingo 風リーグ、簡易チャット、Android 版 (将来)

### 🔵 P3 — メンテナンス

- iOS 19 / Xcode 18 対応 (リリース時)
- Instruments 実機計測

---

## 課題 / 既知の制限

- **友達 CloudKit は実機未検証**: 純粋なリネームでなく新規ネットワーク実装のため、
  実機2アカウントテストでバグ修正の反復が出る前提。検証前に `friendsEnabled` を上げない。
- **`removeFriend` の v1 制限**: 自分側の有向エッジのみ削除。相手側は相手が refresh する
  まで残る (相手にしばらく自分が表示される)。機能的な害はなし。CKShare 移行で解消可。
- **Push 通知は v1.1**: 友達申請・チアの通知は未実装 (refresh ポーリングで成立)。
  実装時は `aps-environment` entitlement + App ID の Push capability + CKQuerySubscription。
- **SwiftData × CloudKit**: iCloud entitlement があると SwiftData が CloudKit 自動同期を
  試みるため、**全 `ModelConfiguration` に `cloudKitDatabase: .none` 必須** (本体+テスト)。
  新規にコンテナを作る箇所を足すときは必ず付けること。
- **週間ランキング**: 競争順位 (1,1,3)。Gemini はデンス順位 (1,1,2) を要望 (未対応)。
- **TelemetryDeck 未有効化**: 下記参照 (現状は送信ゼロ = プライバシーラベル「収集なし」維持)。

### TelemetryDeck 有効化手順 (任意・App ID 設定までは送信ゼロ)

1. TelemetryDeck ダッシュボードで App ID (UUID) を取得
2. `project.yml` の `TelemetryDeckAppID` に設定 → `xcodegen generate`
3. App Store Connect のプライバシーラベルを「使用状況データ / 個人と紐付けない」に更新
4. プライバシーポリシーは TelemetryDeck 記載済 (`docs/privacy.md` / `submission/PrivacyPolicy.md` 第4章)
5. 計測は Release ビルドのみ有効

---

## 参照

- `docs/DEVICE_QA_RUNBOOK.md` — 実機 QA 手順 (0 事前準備 / A〜I)。**次の作業はここ**
- `docs/QA_CHECKLIST.md` — リリース QA チェックリスト全体
- `README.md` — 機能一覧 + ビルド/テストコマンド
- `MEMORY.md` — Claude のメモリインデックス
- `submission/` — App Store メタデータ / スクショ / 規約・プライバシー
