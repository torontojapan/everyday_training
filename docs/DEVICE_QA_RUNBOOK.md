# GO エクササイズ 実機 QA 手順書 (🍎📱)

最終更新: 2026-05-29

横断監査(`docs/AUDIT_MATRIX_2026-06-13.md`)のうち **静的監査・自動テストでは検証できない** 項目
(実機 / StoreKit Sandbox / 権限 / Live Activity / ウィジェット / 通知配信) を、
**Apple Developer 加入後** に順番どおり実施するための手順書。

各項目: 🍎=Apple Developer 加入必須 / 📱=実機必須 / ⏱=想定時間。
チェックは「期待結果」を満たしたら ✅。満たさない場合は「FAIL 時メモ」に再現手順を記録。

---

## 0. 事前準備 (加入直後に一度だけ)

- [ ] 🍎 Apple Developer Program 加入完了 (有料・年額)
- [ ] 🍎 App Store Connect で App ID `com.goexercise.app` 登録
- [ ] 🍎 Capabilities 有効化: **App Groups** (`group.com.goexercise.app`) / **Live Activities** (Info.plist `NSSupportsLiveActivities=true` は設定済) / **iCloud (CloudKit)** — 友達機能で使用 (詳細はセクション I)。Push は v1 未使用
- [ ] 🍎 App Store Connect → サブスクリプション登録:
  - `com.goexercise.app.premium_monthly` … 月額 ¥500
  - `com.goexercise.app.premium_yearly` … 年額 ¥3,800
  - 両方とも **サブスクリプショングループ** に入れる (アップグレード/ダウングレード可)
  - **無料お試し 2 週間 (14日)** の Introductory Offer (paymentMode=free) を両方に設定
  - `Products.storekit` の内容と一致させる (productID / 価格 / グループ / トライアル)
- [ ] 🍎 Sandbox テスター Apple ID を 2 つ作成 (購入用 / ファミリー共有・2台目用)
- [ ] 📱 実機 2 台用意できると理想 (購入復元・ファミリー共有確認用)。最低 1 台。
- [ ] 📱 実機の「設定 → App Store → Sandbox アカウント」にテスターでサインイン

> メモ: 友達機能は **v1 で CloudKit 実装済み**だが、`AppFeatureFlags.friendsEnabled`
> はまだ Release=false (休眠) のまま。**セクション I の実機 2 アカウント疎通テストが
> 通ってから** フラグを true にして解禁する (検証前に出さない)。それまでは友達タブ等は
> 非表示で、セクション G の「友達が出ない」確認はフラグ false の現状ビルドに対して有効。

---

## A. ビルド・署名・App Group (土台) 📱🍎 ⏱15分

- [ ] 🍎 実機向け署名ビルドが通る (Capabilities が provisioning に反映)
- [ ] 📱 実機起動後、Xcode の Console で
  `App Group store を開けず local にフォールバック` の **警告が出ない** こと
  (出る = App Group entitlement 不備。アプリと widget がデータ分断する)
  - 補足: DEBUG ビルドなら App Group 不備時に `assertionFailure` で即クラッシュするため、
    実機 DEBUG で一度起動して落ちなければ App Group は正しく開けている。
- [ ] 📱 記録 → ウィジェット即反映、ウィジェット記録 → アプリ即反映 (= 同一ストア共有確認)

## B. 課金 (GOプレミアム) ★最重要 🍎📱 ⏱40分

> simctl 直起動では StoreKit Configuration が注入されず「商品情報読込中…」になる。
> **Xcode から実機実行 (Scheme の StoreKit Configuration = Products.storekit)** か、
> **TestFlight + Sandbox** で確認する。

- [ ] 🍎 ペイウォール (PremiumPaywallSheet) に月額 ¥500 / 年額 ¥3,800 が App Store Connect 価格で表示
- [ ] 🍎 **14日無料トライアル** 開始 → 即時課金されない / 「14日間無料」等の期間表示が出る
- [ ] 🍎 購入完了 → **体重タブが解放** & **フリーズが月4回** に増える
- [ ] 🍎 アプリ削除 → 再インストール → **購入復元** で Premium 復活 (起動時 `AppStore.sync`/`currentEntitlements`)
- [ ] 🍎 「購入を復元」ボタンからの明示復元も成功
- [ ] 🍎 Sandbox で解約 (またはトライアル解約) → 期限切れ後に **Premium ロック** (体重タブが再ゲート / フリーズ月1)
- [ ] 🍎 自動更新 (renewal) が走っても `purchase_complete` を **二重計上しない** (txn.id==originalID で除外済の実機確認)
- [ ] 🍎 Ask to Buy (保留購入) → 承認後に Premium 反映 (Transaction.updates)
- [ ] 🍎 「サブスクリプションを管理」リンク が設定/管理画面へ遷移
- [ ] 🍎 EULA・プライバシーポリシーリンクが開く
- [ ] 🍎 ファミリー共有: familyShareable=false なので **共有されない** ことを確認 (2台目では各自購入要)
- [ ] 📱 機内モード / ネットワーク断時に **誤って Premium がロックされない** (entitlement キャッシュ維持)

## C. データ全削除と各ストア即リフレッシュ 🍎📱 ⏱10分

- [ ] 📱 記録・体重・体調を数件入れ、ウィジェット/Live Activity に連続日数が出ている状態にする
- [ ] 📱 設定 → 全削除 (確認ダイアログ) 実行
- [ ] 📱 期待結果: 記録のみ消え、**ウィジェット/Live Activity も即座に 0 / 初期表示** に更新される
  (今回修正: 削除後に空スナップショット再 publish + Live Activity 終了)
- [ ] 🍎 期待結果: **購入 / サブスクは保持** (体重タブが解放のまま / フリーズ残数維持)
- [ ] 📱 クラッシュしない / 各画面 (ホーム/履歴/体重) が空状態で正しく描画

## D. 通知 📱 ⏱20分 (時刻待ちあり)

- [ ] 📱 通知許可ダイアログ (初回) で許可 → ローリング7日 one-shot がスケジュールされる
- [ ] 📱 通知時刻を直近に設定 → 実際に **届く**
- [ ] 📱 当日達成 → 当日分通知が **cancel** され届かない / 翌日以降は残る
- [ ] 📱 保険チケットで救済した日も「連続維持」前提の文面になる (rescuedDates 反映の実機確認)
- [ ] 📱 通知タップ → 該当画面へ deep link (goexercise://record など)
- [ ] 📱 通知 ON/OFF / 時刻変更が即反映

## E. ウィジェット 📱 ⏱15分

- [ ] 📱 Small / Medium をホーム画面に追加 → オレンジ猫 (状態連動) + グラデ + 「1分だけでも」表示
- [ ] 📱 「運動した！」1タップ記録 (AppIntent) → アプリ履歴に反映 / 連続日数更新
- [ ] 📱 タイムライン更新 (残り時間 / 週達成率) / タップでアプリ起動
- [ ] 📱 救済日が「未達成」表示にならない (rescuedDates 反映: 今回修正の実機確認)

## F. Live Activity / Dynamic Island 📱 (iPhone 14 Pro 以降) ⏱15分

- [ ] 📱 記録開始でロック画面常駐の猫 (オレンジ画像) 表示
- [ ] 📱 Dynamic Island の展開 / compact / minimal (肉球) 各表示
- [ ] 📱 「運動した！」ボタン / 達成で ✓ 表示
- [ ] 📱 連続日数が救済日込みで正しい (今回修正の実機確認)

## G. 表示・互換 (実機目視) 📱 ⏱20分

- [ ] 📱 5テーマ × ダーク/ライト 切替で破綻なし
- [ ] 📱 VoiceOver で主要ボタン (保存 / 記録 / タブ) に読み上げラベル
- [ ] 📱 Dynamic Type 特大 / reduceMotion で崩れ・はみ出しなし
- [ ] 📱 端末サイズ SE 〜 Pro Max / **iPad SplitView** (友達非表示で 4 セクション) で崩れなし
- [ ] 📱 友達タブ/ランキング/共有設定が **どこにも出ない** (v1 hide の実機最終確認)

## H. 分析・クラッシュ 🍎📱 ⏱10分

- [ ] 📱 TelemetryDeck App ID 未設定の現状: **送信ゼロ** (プライバシーラベルと整合)
- [ ] 🍎 (App ID 設定後) app_open / record / paywall / purchase 等が TelemetryDeck に届く
- [ ] 📱 Xcode Organizer にクラッシュが上がる運用確認 (第三者クラッシュ SDK なし)

---

## I. 友達 (CloudKit) ★v1新規 🍎📱 ⏱40分 (実機2台・iCloud2アカウント必須)

> 実装は `CloudKitFriendsService` (Public DB)。識別=iCloud アカウント (Sign in with
> Apple 不要)。**この章が通ってから** `AppFeatureFlags.friendsEnabled` の Release を
> true にして解禁する。体重・体調データは共有しない (FriendProfile に含まれない)。

### I-0. ポータル / CloudKit Console セットアップ 🍎
- [ ] 🍎 Developer ポータル → App ID `com.goexercise.app` → **iCloud capability を ON**、
      **CloudKit コンテナ `iCloud.com.goexercise.app` を作成**して紐付け
- [ ] 🍎 Xcode の Signing & Capabilities でも iCloud (CloudKit) コンテナが選択されているか確認
      (entitlements に `iCloud.com.goexercise.app` 記載済)
- [ ] 🍎 初回実機起動でアプリが書き込むと CloudKit が **Development 環境**にスキーマを自動生成する。
      その後 **CloudKit Console** (icloud.developer.apple.com) で確認:
  - レコード型 `Profile` / `FriendRequest` / `Friendship` / `Cheer` が出来ている
  - **クエリ対象フィールドの Index を QUERYABLE に**: `Profile.username` /
    `FriendRequest.fromCode` `FriendRequest.toCode` / `Friendship.ownerCode` `Friendship.friendCode` /
    `Cheer.toCode` (これが無いと検索/一覧クエリが失敗する)
  - `recordName` も Queryable (既定で可)
- [ ] 🍎 **Deploy Schema to Production** (Console) — これをやらないと本番ビルドで友達が動かない

### I-1. 実機 2 台疎通 📱 (DEBUG ビルドで先行検証)
> テスト用に DEBUG ビルドを起動引数 **`--enable-friends --cloudkit-friends`** で実行
> (Release フラグを上げずに CloudKit パスを検証できる)。端末 A / B は **別々の iCloud
> アカウント**でサインイン (設定 → Apple ID)。

- [ ] 📱 端末 A: 友達タブ → サインイン (表示名・ユーザー名入力) → friend code が表示される
- [ ] 📱 端末 B: 同様にサインイン → B の friend code を控える
- [ ] 📱 端末 A: B の friend code で **申請を送信** → エラーなく送信完了
- [ ] 📱 端末 B: 友達タブを開く/更新 → **申請が届いている** → **承認**
- [ ] 📱 端末 A: 更新 → B が **友達一覧に出る**。B 側も A が出る (相互。A の再 refresh で確定)
- [ ] 📱 両端末で運動を記録 → `publishMyProfile` 後、相手側の更新で **連続日数・今日の達成・猫**が反映
- [ ] 📱 詳細共有 ON の側のみ **今日の種目詳細**が相手に見える / OFF は見えない
- [ ] 📱 **チア送信**がエラーにならない (受信通知は v1.1。今は送信成功のみ確認)
- [ ] 📱 **ユーザー名で検索** (完全一致) して相手が出る
- [ ] 📱 **友達削除** → 自分側の一覧から消える (相手側は相手の更新まで残る = v1 既知)
- [ ] 📱 自分のコードを申請 → 「自分のコードは追加できません」、重複申請 → 「送信済み」
- [ ] 📱 iCloud 未ログイン端末で友達タブ → 「iCloud にサインインすると…」の案内が出る (クラッシュしない)

### I-2. 解禁 (検証 OK 後)
- [ ] `AppFeatureFlags.friendsEnabled` の **Release ブランチを `true` に**変更 → コミット
- [ ] Release ビルドで友達タブ/iPad sidebar/ディープリンク (`goexercise://friends`) が復帰
- [ ] App Store Connect スクショ/メタデータに友達導線を反映 (任意)
- [ ] (任意 v1.1) Push 通知 (CKQuerySubscription + aps-environment) で申請・チアを通知

---

## 自動化済み / 静的検証済み (実機で再確認不要)

- ロジック (連続記録・休養・フリーズ月1/4・週進捗・体重集計・周期) … 自動テスト
- Release で debug 起動引数が無効 (`--mock-premium`/`--seed-*`/`--mock-seed-friends` 他) … 静的監査 + Release ビルド確認済
- `--mock-premium` の DEBUG 限定 … 確認済
- 友達 v1 hide のロジック (タブ/ルート振替) … 単体テスト + Release ビルド確認済
- 全削除で購入保持 / rescuedDates の全集計伝播 / 保存失敗時に成功表示しない … 静的監査 + 自動テスト

## 完了基準

- [ ] B (課金) 全項目 ✅ … リリース必須
- [ ] A / C / D / E / F / G / H の 📱 項目 ✅
- [ ] FAIL ゼロ (FAIL があれば修正 → 該当セクション再実施)
