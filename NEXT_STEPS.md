# Next Steps — GO エクササイズ

最終更新: 2026-05-30 (課金QAローカル完走 + 記録UX大改善 + 連絡先フォーム化を実施・push済。残りは Sandbox/ASCビジネス/友達CloudKit)

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
- **署名**: `project.yml` に `DEVELOPMENT_TEAM=29YX3L7B47` 設定済。実機ビルド・署名・起動 OK (runbook A 相当 ✅)。
- **課金QA (runbook B) — ローカル StoreKit で完走**: 価格表示/14日トライアル/購入→体重解放&フリーズ月4/
  解約→再ロック/二重計上なし(コード)/Ask to Buy 承認反映/規約・プライバシーリンク/機内モード非ロック ✅。
  審査用ペイウォールスクショ取得済 (`submission/screenshots/01_paywall_6.9.png` 1320×2868)。
  **B4 削除→復元 / B5 復元ボタンは Sandbox 必須**(ローカルは削除で購入消失するため検証不可) → TestFlight で要確認。
- **記録まわり UX 大改善 (commit `5ba0b68`, push済)**: 時間/回数/セットをプルダウン化 /
  種目ごとにカテゴリ選択 (1記録に複数カテゴリ可、候補も種目カテゴリ連動) / 入力済み種目をアコーディオン最小化 /
  カテゴリ並び 筋トレ→有酸素 / 保存→記録完了画面へ直行 (大きい猫+特大連続日数で達成感) /
  履歴タブ(StatsView)最下部に「運動履歴 合計N日」折りたたみ / 空状態の絵文字→SF Symbol /
  ウィジェット・Live Activity「運動した！」→「運動を記録」/ Live Activity 文字色ダーク固定 (視認性) → **実機検証済**。
- **連絡先のフォーム化 (commit `073ac19`, push済)**: privacy/terms/support と submission・アプリ内の個人 Gmail を
  Google フォーム (`forms.gle/Ljbaj4MvW2YPmyJ99`) に統一。GitHub Pages フッターの GitHub 名も撤去。公開ページ反映済み。
- **友達 (CloudKit)**: バックエンド **実装済み (休眠中)**。`CloudKitFriendsService` (Public DB)。
  `friendsEnabled` は Release=false のまま → 実機2アカウント疎通テスト (runbook I) 後に解禁。
  **2026-05-30 進捗**: ポータル/コンテナ設定 ✅・Development スキーマ生成 ✅ (じゅんでサインイン済) →
  **残るは「2台目 iCloud アカウントで申請/承認の疎通」だけ**で中断中 (詳細は下の 🟡 セクション)。
- **git**: `main` に全コミット・**push 済** (CloudKit / 連絡先フォーム化 / UX大改善まで `5ba0b68` 時点で remote 反映)。

> 環境注意: リポジトリが `~/Documents` (iCloud 同期下)。大量ファイル操作後は
> `find . -name "* [0-9].*"` で iCloud 重複ファイルが湧いていないか確認すること。

---

## 残タスク (優先度順)

### 🔴 P0 — リリースブロッカー (ほぼ実機作業)

`docs/DEVICE_QA_RUNBOOK.md` に手順あり。実機 + Sandbox/iCloud アカウントが必要。

| # | タスク | 状態 / 参照 |
|---|---|---|
| 1 | A. 実機ビルド・署名・App Group | ✅ 実機起動OK |
| 2 | **B. 課金 (GOプレミアム) QA ★最重要** | ✅ ローカル完走。**B4/B5 のみ Sandbox 残** (runbook B) |
| 3 | **B4/B5 を TestFlight + Sandbox で確認** (削除→復元 / 復元ボタン) | ビルド番号↑→Archive→アップロード必要 |
| 4 | C. 全削除→各ストア即リフレッシュ / D. 通知 | ⬜ 実機 (runbook C/D) |
| 5 | E. ウィジェット / F. Live Activity 実機目視 | ✅ 文言・視認性は実機確認済 (残: 1タップ記録/Dynamic Island 細部) |
| 6 | **I. 友達 (CloudKit) 実機2アカウント疎通** → OK なら `friendsEnabled` Release=true | ⏳ 2台目アカウント待ち (runbook I) |
| 7 | 審査用ペイウォールスクショを **ASC にアップロード** | 取得済 `submission/screenshots/01_paywall_6.9.png`、アップロードのみ |
| 8 | 銀行口座・納税フォーム入力 (有料App契約を「有効」に) | ⬜ ASC ビジネス |
| 9 | EU トレーダーステータス提出 (or EU を配信対象から除外) | ⬜ ASC ビジネス |
| 10 | アプリ共有 URL を実 App Store URL に差し替え | ⬜ 数値ID入手後 `AppSharingConfig.swift` |

### 🟡 友達 CloudKit 解禁の具体手順 (runbook I) — ⏳ ステップ3で中断中 (2026-05-30)

1. ✅ **完了** Developer ポータル: CloudKit コンテナ `iCloud.com.goexercise.app` 作成 +
   App ID `com.goexercise.app` の **iCloud capability ON** + コンテナ紐付け (Enabled iCloud Containers = 1)
2. ✅ **ほぼ完了** スキーマ生成 + Index:
   - 実機 (じゅんの iPhone) で DEBUG ビルドを `--enable-friends --cloudkit-friends` 起動 → 友達サインイン成功
     (表示名「じゅん」/ friend code 例 `ZQOLYC`) → `Profile` + `MyAccount` が **Development** に書き込まれスキーマ自動生成
   - 判明: **Development 環境では CloudKit が各フィールドに QUERYABLE/SEARCHABLE/SORTABLE を自動作成**する
     (`Profile.username` も Queryable 確認済)。→ **Development では手動 Index 設定は不要**。
   - 残りのレコード型 `FriendRequest` / `Friendship` / `Cheer` はステップ3の申請/承認/チアで初めて生成される
     (= まだ未生成)。生成時に Index も自動で付く想定。
3. ⛔ **ここで中断 (要・2台目 iCloud アカウント)** 実機2台 (別 iCloud) で `--enable-friends --cloudkit-friends`
   起動 → 申請/承認/表示/検索/削除/チア疎通。
   - **ブロッカー**: 2台目の iCloud アカウントが無い。**シミュレータでは新規 Apple ID を作成不可**
     (「作成できる新規アカウント数が上限」エラー)。→ 作成はブラウザ (account.apple.com) で行い、
     シミュレータには**ログインのみ**する方針 (ログインは制限なし)。
   - メール案: Gmail のドット無し版 `cojjjuuunnnco@gmail.com` (ドットを無視する Gmail 仕様で
     同一受信箱に届くが Apple は別アドレスとして受理) を使う予定だったが、フォームを突破できず保留。
   - 代替: ①別の予備 Apple ID があればそれをシミュレータにログイン ②家族の実機を借りる (実機2台)。
4. ⬜ 検証 OK → **CloudKit Console で Deploy Schema Changes (本番へ反映)** →
   `AppFeatureFlags.friendsEnabled` の Release を `true` に → コミット → 友達導線が自動復帰

> 📌 **再開時のいちばん簡単な道**: 2台目の iCloud アカウント (新規でも予備でもOK) を1つ用意 →
> 2台目のシミュレータ/実機にログイン → アプリを `--enable-friends --cloudkit-friends` で起動 →
> じゅん側と申請/承認 → 一通り疎通したら本番 Deploy → フラグ ON。Xcode スキームには起動引数
> 2つを設定済み。Developer ポータル/コンテナ/Development スキーマは設定済みなので、残りは「2人目」だけ。

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
