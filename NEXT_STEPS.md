# Next Steps — GO エクササイズ

最終更新: 2026-05-31 (**🚀 App Store 審査提出完了!** v1.0 build 1 + サブスク2本を審査へ提出 = ステータス「審査待ち」。スクショ全面再撮影・絵文字/無効文字対応・EU除外・GitHubメール除去まで完了。残りは 審査結果待ち / 共有URL差し替え(ID判明) / 友達CloudKit)

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
  - **有料App契約「有効」** ✅ (W-8BEN + Certificate of Foreign Status の税フォーム提出済、
    楽天銀行口座登録済。これで Sandbox/本番の IAP が動作)
  - サブスク2本登録: `…premium_monthly` **¥500** / `…premium_yearly` **¥3,800**、
    グループ `GO Premium`、両方 **14日無料**、全世界配信、ファミリー共有OFF。
    **メタデータ完備=「送信準備完了」** ✅ (グループ表示名「GO プレミアム」+ 各サブスクの表示名/説明/審査用スクショ設定済)
  - Sandbox テスター ×2 (日本)
- **TestFlight 配信済** ✅: ビルド **1.0 (1)** をアップロード → 処理完了 → 内部テストグループ「自分」で
  実機 (iPhone 15 Pro) にインストール済。輸出コンプライアンス(暗号化=標準のみ・該当外)回答済。
- **署名**: `project.yml` に `DEVELOPMENT_TEAM=29YX3L7B47` 設定済。実機ビルド・署名・起動 OK (runbook A 相当 ✅)。
- **課金QA (runbook B) — 完全制覇** ✅: 価格表示/14日トライアル/購入→体重解放&フリーズ月4/
  解約→再ロック/二重計上なし(コード)/Ask to Buy 承認反映/規約・プライバシーリンク/機内モード非ロック。
  審査用ペイウォールスクショ (`submission/screenshots/01_paywall_6.9.png` 1320×2868) は ASC のサブスク審査情報にも設定済。
  **B4 削除→再インストール→自動復元 ✅ / B5 復元ボタン(同一の `restorePurchases()` 経路)✅** を
  TestFlight + Sandbox(日本)で本確認済み。
- **Privacy Manifest 追加済** ✅: `PrivacyInfo.xcprivacy` を app+widget に同梱
  (UserDefaults=CA92.1 / 追跡なし / 収集なし)。Apple 必須 (ITMS-91053) 対応。
- **画面の向き指定済** ✅: universal アプリのため `UISupportedInterfaceOrientations`
  (iPhone=縦 / iPad=4方向) を Info.plist に設定 (アップロード検証 90474 解消)。
- **バージョン一元管理** ✅: `project.yml` の `MARKETING_VERSION=1.0` / `CURRENT_PROJECT_VERSION=1`
  (app+widget 継承)。**再アップロードのたびに `CURRENT_PROJECT_VERSION` を +1 する**。
- **通知/ウィジェット/Live Activity のタップ遷移をホームに統一** ✅。通知設定に「保存して戻る」追加。
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
- **git**: `main` に全コミット済。`f254ef2` まで push 済。**画面向き修正 `3fe4c9c` 以降は未 push の可能性** →
  `! git push origin main` で確定すること。アップロード済みビルドはローカル Archive 由来。

> 環境注意: リポジトリが `~/Documents` (iCloud 同期下)。大量ファイル操作後は
> `find . -name "* [0-9].*"` で iCloud 重複ファイルが湧いていないか確認すること。

---

## 残タスク (優先度順)

> **📍 今オープンな残タスク (2026-05-31 時点)** — P0 はほぼ完了、審査提出済み。
> 1. ⏳ **審査結果待ち** (Waiting for Review)。承認なら手動リリース / リジェクトなら Resolution Center 対応。
> 2. 🟢🟢 **友達BE = Supabase 疎通検証済** (#12) — front(UIテスト5/5)+back(REST全合格・RLS含む)+iOSアプリ実コードからの書込まで実証(2台目Apple ID不要)。**解禁の残**: テストデータ掃除 / 監査指摘UI改善(エラー表示等) / `friendsEnabled`=true / App Privacy更新 / 新ビルド提出。設計: `docs/friends_backend_crossplatform.md`。
> 3. ⬜ **任意 UX 詰め** (#11 / P2 / Codex UX 提案 `docs/ux_review/`) — リリース後で可。友達UI/UXの出荷品質改善は完了済(#12参照)。
> ※ メタデータ提出・審査提出・EU除外・共有URL差替・GitHubメール除去 は **完了**。

### 🔴 P0 — リリースブロッカー (ほぼ実機作業)

`docs/DEVICE_QA_RUNBOOK.md` に手順あり。実機 + Sandbox/iCloud アカウントが必要。

| # | タスク | 状態 / 参照 |
|---|---|---|
| 1 | A. 実機ビルド・署名・App Group | ✅ 完了 |
| 2 | **B. 課金 (GOプレミアム) QA ★最重要** | ✅ **完全制覇**(ローカル + Sandbox B4/B5 まで) |
| 3 | C. 全削除→ウィジェット/Live Activity リセット / D. 通知 | ✅ 実機確認済 (C: リセット+購入保持 / D: 届く+タップ→home) |
| 4 | 銀行口座・納税フォーム (有料App契約「有効」化) | ✅ 完了 (契約=有効) |
| 5 | TestFlight アップロード + Sandbox 課金確認 | ✅ 完了 (1.0 build 1 配信・B4/B5 確認済) |
| 6 | サブスク審査用スクショ/メタデータを ASC に設定 | ✅ 完了 (送信準備完了) |
| 7 | **App Store メタデータ提出** | ✅ **完了**(2026-05-31)。正本=`submission/app_store_metadata_v1.md`。説明/KW/プロモは**絵文字・罫線──・矢印→・¥を排除**(ASCが無効文字拒否)。スクショは現行ブランドで再撮影し提出(iphone-6.9×6 / ipad-13×5。旧版はリポジトリ清掃で削除=git履歴に残存) |
| 8 | **審査提出**(アプリ + サブスク2本一緒) | ✅ **完了=審査待ち(Waiting for Review)**。リリース方法=手動。年齢4+/カテゴリ=ヘルスケア&フィットネス+ライフスタイル/価格無料/日本のみ(EU除外)/App Privacy=収集なし/コンテンツ配信権=サードパーティなし/使用許諾=Apple標準。**審査結果メール待ち** |
| 9 | EU トレーダーステータス | ✅ **EU除外で確定**(配信=日本のみ)。個人連絡先公開を回避 |
| 10 | アプリ共有 URL を実 App Store URL に差し替え | ✅ **完了**(2026-05-31)。`AppSharingConfig.swift` を `https://apps.apple.com/jp/app/id6774551663` に更新。※反映は次ビルド(審査中の 1.0(1) は凍結)。[[release-identifiers]] |
| 11 | E. ウィジェット1タップ記録 / F. Dynamic Island 細部 / G. テーマ×ダークライト / H. 分析 | ⬜ 任意・実機目視 (文言/視認性は確認済) |
| 12 | **I. 友達バックエンド=Supabase。疎通検証済→解禁準備** | 🟢🟢 **疎通検証済み (2026-05-31)**: Supabaseプロジェクト作成+schema実行+Secrets記入 完了。**バックエンドREST疎通(2匿名ユーザーで申請→承認→双方向表示→チア+RLS負荷)全合格 / iOSアプリ実コード(supabase-swift)からも書込成功**(2台目Apple ID不要で実証)。フロントUIテスト5/5 pass・3LLM監査リーク2件是正済。**解禁の残作業**: ①テストデータ掃除(SQL)✅ ②監査指摘のUI改善 ✅**完了**(エラーバナー/初回ローディング/旧説明文刷新/cheer連打ガード/QRディープリンク化。設計=`docs/superpowers/specs/2026-05-31-friends-uiux-shipping-quality-design.md`、Codex監査ループで承認・ビルド成功・UIテスト5/5。※ユニットは当環境でApp Group署名hang=Xcodeで要実行) ③`friendsEnabled` Release=true ④App Privacyラベル更新(収集なし→User Content) ⑤新ビルド提出。BE設計=`docs/friends_backend_crossplatform.md` |

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
   - **2026-05-31 再挑戦も失敗**: ブラウザ作成で**電話番号認証がループ**(正しいコード入力でも
     再要求→エラー)。原因=本アカウントに紐付く番号での新規作成を Apple が制限。
     突破には**本アカウント未使用の別電話番号**が必要 → 入手できず保留継続。
   - 代替: ①本アカウント未使用の電話番号で再作成 ②別の予備 Apple ID ③家族の実機を借りる (実機2台)。
   - **判断: 友達は v1 では非表示のまま出荷し、解禁は 2台目アカウント入手時 or v1.1 に後ろ倒し。**
4. ⬜ 検証 OK → **CloudKit Console で Deploy Schema Changes (本番へ反映)** →
   `AppFeatureFlags.friendsEnabled` の Release を `true` に → コミット → 友達導線が自動復帰

> 📌 **再開時のいちばん簡単な道**: 2台目の iCloud アカウント (新規でも予備でもOK) を1つ用意 →
> 2台目のシミュレータ/実機にログイン → アプリを `--enable-friends --cloudkit-friends` で起動 →
> じゅん側と申請/承認 → 一通り疎通したら本番 Deploy → フラグ ON。**Xcode スキームに起動引数
> `--enable-friends` / `--cloudkit-friends` を「無効状態」で登録済み (commit `94f5c4f`)** →
> Edit Scheme でチェックを入れるだけで有効化できる (既定は従来どおり Mock)。
> Developer ポータル/コンテナ/Development スキーマは設定済みなので、残りは「2人目」だけ。

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
- (任意) `.git` 履歴ダイエット: 過去の画像blob蓄積で `.git`≈336M。`git filter-repo --strip-blobs-bigger-than` 等で圧縮可だが、全SHA書換+force-push+削除済み履歴は復元不可になるトレードオフあり。急がない。

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
