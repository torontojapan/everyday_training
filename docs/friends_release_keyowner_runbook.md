# キー所有者ランブック: iOS 友達ループを閉じる (Supabase 設定 + 実機 E2E)

作成: 2026-06-03 / 対象: **キー所有者(あなた)が手作業で行う**設定・デプロイ・実機検証の手順書。
前提: クライアント実装は全て完了・gate OFF で未出荷(Apple/Google 連携・復元・切替・削除・`delete-account` wire-up)。
真実源: `docs/superpowers/specs/2026-06-01-friends-account-hardening-design.md`

> このランブックを上から順に実施すると「iOS 友達ループ(連携→削除→機種変復旧)」が実機で成立する。
> 完了 → iOS v1.0 審査承認 → その後 Android 着工(別計画書 `2026-06-02-android-implementation-plan.md`)。
> **gate を ON にするのは検証ビルドのみ**。本出荷の解禁は v1.0 審査承認後(§6)。

所要の目安: コンソール設定 30–60分 + 実機 E2E 30–60分。実機は **2 台(または 1 台 + 再インストール)** 推奨。

---

## 0. 用意するもの

- Supabase プロジェクト(iOS が使う本番プロジェクト)への管理者アクセス。
- Apple Developer(Sign in with Apple 用 Services ID / Key)。
- Google Cloud Console(OAuth 2.0 クライアント ID。iOS は web/PKCE 経路なので **Web application** 種別の client）。
- 実機 iPhone 2 台(または 1 台で削除→再インストール)。Apple ID と Google アカウントが各1。
- `supabase` CLI(ログイン済み, `supabase link` 済み)。

---

## 1. Supabase コンソール設定

### 1-A. Apple provider (Auth → Sign In / Providers → Apple)
- Enable。Services ID(例 `com.goexercise.app.signin`)、Apple の Team ID / Key ID / Private Key(.p8)を設定。
- iOS はネイティブ id_token 経路だが、Supabase 側で Apple provider が有効である必要がある。

### 1-B. Google provider (Auth → Providers → Google)
- Enable。**Authorized Client IDs** に Google Cloud の OAuth client ID を設定。
- iOS は **web/PKCE**(`signInWith(.google)` web)経路。Client secret も設定(web flow のため)。

### 1-C. Manual Linking を ON (Auth → Settings)
- **"Allow manual linking" / Manual Linking を有効化**。これが OFF だと `linkIdentity*` 系が
  `manual_linking_disabled` で失敗する(クライアントは「ただいまこの方法は利用できません」表示)。

### 1-D. Redirect URLs 許可 (Auth → URL Configuration → Redirect URLs)
- **`goexercise://auth-callback` を追加**。Google web/PKCE のコールバック先。
  - 補足: iOS 側の URL scheme `goexercise` は `Info.plist` 登録済み。Apple のネイティブ経路は redirect 不要。

### 1-E. CAPTCHA (任意 / 推奨, Auth → Settings → Bot and Abuse Protection)
- Cloudflare Turnstile を有効化し、**secret** を Supabase に、**site key** をクライアント(§3-C)に設定。
- Turnstile 側で許可ドメインに WKWebView の baseURL ホスト(既定 `goexercise.app`)を登録。
- **順序厳守**: 「Turnstile 許可ドメイン登録 → Supabase 側 CAPTCHA ON → クライアント site key 設定」を同時に
  揃える。揃わないと匿名サインインが実行時に失敗する(`schema.sql` 2-b 参照)。空のままなら CAPTCHA 無効=従来挙動。

### 1-F. スキーマ / RLS / cron が適用済みか確認
- `supabase/schema.sql`(`cheers_delete` RLS、`set_updated_at` トリガ等)と
  `supabase/cron/cleanup_orphans.sql`(孤児匿名の日次削除)が本番に適用済みであること。

---

## 2. Edge Function `delete-account` をデプロイ

```sh
supabase functions deploy delete-account
```
- `verify_jwt` は既定 ON のまま(本人 JWT 検証に必須)。
- `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` は Edge 環境に自動注入(手動設定不要)。
- デプロイ後、クライアントの `deleteAccount()` がこの関数を**正本**として呼ぶ(成功=auth ユーザーごと
  完全削除 + 全セッション失効)。未デプロイ時はクライアント側のデータ削除フォールバックで審査要件は満たすが、
  **完全削除(auth 行 + token 失効)には本デプロイが必須**。

---

## 3. iOS 検証ビルドの設定

### 3-A. Sign in with Apple capability を追加
- Xcode → Target `GOExercise` → Signing & Capabilities → **+ Capability → Sign in with Apple**。
  - これで `GOExercise.entitlements` に `com.apple.developer.applesignin` が入る(現状未付与)。
  - App ID(`com.goexercise.app`)側にも Sign in with Apple を有効化(Apple Developer)。
- Google は web 経路なので iOS 側 capability 追加は不要(Supabase の Google provider 設定のみ)。

### 3-B. 連携フラグを ON(検証ビルド限定)
- `app/GOExercise/GOExercise/Resources/Info.plist` に**検証中だけ**以下を追加(既定は未設定=false):
  ```xml
  <key>FriendsAppleLinkEnabled</key>  <true/>
  <key>FriendsGoogleLinkEnabled</key> <true/>
  ```
  - 読み取りは `SupabaseConfig.appleLinkEnabled` / `.googleLinkEnabled`(Bool)。
  - **検証後は false に戻す/キーを削除**(本出荷の解禁は §6 の v1.0 承認後)。

### 3-C. Secrets.xcconfig に接続情報(未設定なら)
- `app/GOExercise/Secrets.xcconfig`(gitignore 済)に:
  ```
  SUPABASE_HOST     = <ref>.supabase.co
  SUPABASE_ANON_KEY = <anon public key>
  TURNSTILE_SITE_KEY = <任意: Turnstile site key>
  ```

### 3-D. 公式 Google "G" アセットへ差し替え(ブランド準拠)
- `GoogleGMark`(`Views/GoogleSignInButton.swift`)は**近似描画のプレースホルダ**。出荷前に
  **公式 Google "G" ロゴアセット**へ差し替える(ブランドガイドライン準拠)。検証だけなら後回し可。

---

## 4. 実機 E2E テストマトリクス

各シナリオで「uid/friendCode/友達が保持/復元されるか」「データが消えるか」を確認。
端末A・端末B(または A→再インストール)。

| # | シナリオ | 手順 | 期待 |
|---|---|---|---|
| 1 | **Apple 連携(昇格)** | A で匿名→友達を1人追加→「Apple でバックアップ」 | uid/friendCode/友達 不変。`isBackedUp=true` |
| 2 | **Google 連携(昇格)** | 別アカウントで 1 と同様に「Google でバックアップ」(web/Custom 戻り) | 同上(provider=google) |
| 3 | **衝突→切替(Apple)** | 既に別データに紐づく Apple ID で連携 | 「既存に切替/中止」二択。切替で既存アカウントに入る |
| 4 | **衝突→切替(Google)** | 同上を Google で(web flow を再度通る) | 同上 |
| 5 | **復元(Apple, 新端末)** | アプリ削除→再インストール→welcome「Apple で復元」 | `restored`:友達/コードが戻る |
| 6 | **復元(Google, 新端末)** | 同上を「Google で復元」 | 同上 |
| 7 | **キャンセル無視** | 連携/復元の途中で Apple シート/Custom Tab を閉じる | エラーバナーを出さず welcome に留まる |
| 8 | **アカウント削除(完全)** | signedIn→「アカウントを削除」→確認 | welcome へ。Supabase で `profiles/friendships/...` と **auth.users 行**が消えている(Edge Function デプロイ済なら) |
| 9 | **削除後の復元不可** | 8 の後、同 Apple/Google で「復元」 | 既存データ無し=新規(`created`)。古い友達は戻らない |
| 10 | **gate OFF 回帰** | フラグを false に戻したビルド | カード/ボタン非表示・経路未実行=従来の匿名挙動と不変 |

検証メモ:
- 8 で **auth.users 行**まで消えるのは Edge Function デプロイ済みのとき(§2)。未デプロイだと
  データ行は消えるが auth 行は残る(後でデプロイ→次回削除で回収)。
- 5/6 の復元は「別端末/再インストールで新規匿名にならず既存に着地」が肝。

---

## 5. ロールバック / 無効化

- 連携を止める: `Info.plist` の `Friends{Apple,Google}LinkEnabled` を false/削除 → カード/ボタン非表示・
  経路未実行(バイト互換)。
- Supabase 側 provider を Disable すれば、誤って ON のビルドが出ても `provider_disabled` で安全側
  (クライアントは「ただいま利用できません」)。

---

## 6. 出荷ゲート(順序厳守)

1. 本ランブック完了(実機 E2E green)。
2. **iOS v1.0 審査承認**(友達版の本リリースはこれ以降)。承認後に `AppFeatureFlags.friendsEnabled` /
   連携フラグの解禁、App Privacy ラベル更新(友達解禁版)を行う。
3. その後 **Android 着工**(計画書 §15 の v1 スコープ A / 分析・push B を確定した上で)。

---

## 付録: クライアント側の対応関係(参照)
- 連携/復元/切替/削除: `SupabaseFriendsService`(Apple=native id_token / Google=web PKCE)。
- 衝突写像: `mapLinkError` / `mapPKCECallback`。削除: `deleteAccount`(Edge Function 正本 + フォールバック)。
- UI: `FriendsView`(バックアップカード / welcome 復元 / 衝突二択 / 削除確認)。
- 設定ゲート: `SupabaseConfig.{appleLinkEnabled,googleLinkEnabled,isAccountLinkingEnabled,googleRedirectURL}`。

---

## 7. Android 版 (#10) 追加手順 — キー所有者作業

> Android(`app-android/`)は **iOS と同一 Supabase プロジェクトを共有**(friend code 名前空間共有 =
> Apple↔Android 相互フレンド)。**§1 のコンソール設定は共用**。**Android は iOS の鏡像**:
> Google=native id_token(Credential Manager)/ Apple=web/PKCE(Custom Tabs)。
> dev はすべて Mock 経路で動作確認済み。下記を投入すると実経路へ自動で切り替わる。

### 7-A. 接続情報を `app-android/local.properties`(gitignore)へ
```
SUPABASE_HOST=<iOS と同じ host>.supabase.co
SUPABASE_ANON_KEY=<iOS と同じ anon key>
```
→ `SupabaseConfig.isConfigured=true` になり、friends は実 `SupabaseFriendsService`、連携 coordinator は
実 `RealAccountAuthCoordinator`(Credential Manager / Custom Tabs)に自動切替。

### 7-B. Google **Web** Client ID(Credential Manager 用)
```
GOOGLE_WEB_CLIENT_ID=<...>.apps.googleusercontent.com
```
- **Web アプリケーション型**の OAuth クライアント ID を使う(Android 型ではない)。Supabase の Google
  provider に登録したものと同一でよい。未設定だと Google 連携は `providerUnavailable` で安全側。
- Custom Tabs の Apple web callback `goexercise://auth-callback` は **§1-D の Redirect URLs に登録必須**
  (iOS と共用済みのはず。Android も同 URL)。

### 7-C. 連携フラグを ON(検証ビルド限定 / `local.properties`)
```
FRIENDS_APPLE_LINK_ENABLED=true
FRIENDS_GOOGLE_LINK_ENABLED=true
```
→ welcome の復元入口・バックアップカード・削除導線が表示される(既定 false = 非表示で不変)。

### 7-D. Play Billing(課金)
1. Play Console で **サブスク商品**を作成: `com.goexercise.app.premium_monthly` / `..._yearly`
   (iOS の `premium_monthly/yearly` に対応する **Play 上の別 productId**)。
2. base plan に **14 日無料トライアル offer** を追加(`trialOffer()` が priceAmountMicros==0 のフェーズを
   優先選択する前提)。
3. **内部テスト**トラックに署名済み AAB を配信(Billing は実機 + ストア商品が無いとテスト不可)。
4. `local.properties` に `PLAY_BILLING_ENABLED=true` → 実 `PlayBillingPremiumRepository` に切替。

### 7-E. リリース署名 + ビルド
- keystore を作成し `app-android/app/build.gradle.kts` に `signingConfigs` + release へ適用(本番鍵は
  リポジトリに入れない。`keystore.properties` は gitignore)。
- R8 縮小 / リソース shrink は**設定済み**(`isMinifyEnabled`/`isShrinkResources=true`、keep は
  `proguard-rules.pro` + `res/raw/keep.xml` で cat_* 保護)。`./gradlew :app:bundleRelease` で AAB。
- Room v1→v2 の実 Migration は**実装 + 計装テスト green 済み**(`MIGRATION_1_2` / `MigrationTest`)。

### 7-F. 審査 / ストア整備
- **アカウント削除 URL**: `docs/account-deletion.md`(公開先 URL を Play / App の該当欄に登録)。
- **Data safety フォーム**: 友達=共有プロフィール/連携(任意)。運動・体重はローカルのみ(クラウド送信なし)。
- ペイウォールのサブスク開示(価格/周期/自動更新/トライアル後課金/解約=Play 定期購入)は実装済み。

### 7-G. Android 実機 E2E マトリクス
| # | シナリオ | 期待 |
|---|---|---|
| 1 | Google でバックアップ(native) | Credential Manager → linked、再起動で復元可 |
| 2 | Apple でバックアップ(web/Custom Tabs) | callback 受領 → linked。**Tab を閉じる**と Cancelled で畳む(ハング無し) |
| 3 | 別端末で復元(Google/Apple) | restored で友達/コードが戻る |
| 4 | 衝突(既存 ID に別データ) | 「既存に切替/中止」二択 → 切替で identity 張り直し |
| 5 | アカウント削除 | EF 200=即時 / 404・ネット断=RLS フォールバック / 500=fail closed(再試行) |
| 6 | **Apple↔Android 友達** | iOS で生成した friend code を Android で追加(逆も)= 相互フレンド成立 |
| 7 | 課金 | 14日無料で購入 → isPremium → rescue 月4 / 体重タブ解錠 |
| 8 | v1→v2 アップグレード | v1 配信済み端末へ v2 を上書き → クラッシュ無し・既存運動記録保持 |

### 7-H. ロールバック(Android)
- `FRIENDS_*_LINK_ENABLED` / `PLAY_BILLING_ENABLED` を false → 各 UI 非表示・経路未実行。
- `SUPABASE_*` を空に戻せば全面 Mock 経路へ(コンソール障害時の安全退避)。
