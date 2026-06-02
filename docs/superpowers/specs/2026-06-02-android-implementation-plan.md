# 実装計画書: Android 版 GO エクササイズ (Kotlin + Jetpack Compose / 全機能ゼロから)

作成: 2026-06-02 / 状態: **計画(レビュー用)。着工の号砲はユーザー承認後**(数ヶ月規模の新規開発)
真実源の上流: [[friends_backend_crossplatform.md]] / iOS 実装 = `app/GOExercise`

> この文書は「何を・どの順で・どの技術で作るか」の合意形成用。**承認まで実装コードは書かない**。
> 工数は個人開発(1人)前提の粗い相対見積り。確定スケジュールではない。

---

## 1. 目的・前提・非対象

### 目的
- iOS 版 GO エクササイズ (`com.goexercise.app`) と**機能パリティ**の Android 版を新規開発する。
- 最重要要件: **Apple ユーザーと Android ユーザーが友達としてつながれる**(2026-05-31 ユーザー要望)。
  これは中立BE = **Supabase を iOS と共有**することで満たす(friend code 名前空間を共有)。

### 確定済みの前提(上流仕様より)
- バックエンドは **Supabase**(Postgres + Auth + RLS)で確定済み・**iOS で本番稼働する同一プロジェクト/スキーマを Android も使う**(`profiles`/`friend_requests`/`friendships`/`cheers`、双方向 friendship 単一行、サーバ採番 friend code、cheer は RLS で friendship 必須)。
- 認証は **匿名ファースト**(端末ローカル匿名 uid)+ **任意の Apple/Google 連携で機種変/再インストール復旧**(iOS Phase2 と同一思想)。lazy 化(能動操作で初めて匿名サインイン)・孤児削除 cron・CAPTCHA(Turnstile)・アカウント削除導線(審査要件)も同一BEの上で再利用。
- 共有データは **表示名・連続記録・今日のカテゴリ/種目名まで**。体重・体調は持たない(プライバシー設計を厳守)。
- プライバシー最優先・opt-in 志向 ([[feedback_release_ops_decisions]])。
- 友達版の**本リリースは iOS v1.0 審査承認後**([[friends_v1_hidden]] / [[release_identifiers]])。Android もこの順序に従う。

### 非対象(この計画では作らない)
- KMP(Kotlin Multiplatform)による iOS とのコード共有 — iOS は完成済み Swift/SwiftUI のため**割に合わない**。Android は**純ネイティブ Kotlin/Compose** で実装する(§2)。
- Supabase スキーマ/RLS の再設計(iOS 用に確定済みをそのまま使う。Android 固有のサーバ変更は friends push の FCM 連携のみ・後追い)。
- iOS 側の変更(本計画は Android 専用)。

---

## 2. 全体方針(ターゲット像)

| 論点 | 決定 | 理由 |
|---|---|---|
| 言語/UI | Kotlin + **Jetpack Compose** + Material 3 | iOS の SwiftUI と対応。宣言的 UI で移植が素直。 |
| コード共有 | **純ネイティブ Android**(KMP 不採用) | iOS は既存 Swift。共有対象が無いので KMP はコスト過多。共有は **BE(Supabase)層のみ**。 |
| アーキ | 単一モジュール起点 → 機能成長で multi-module。MVVM + UDF(単方向データフロー) | iOS の `@Observable` Store/ViewModel + 純粋関数ロジックを Kotlin の `ViewModel`+`StateFlow` に対応。 |
| 最小SDK/対象 | **minSdk 26 (Android 8)** / 端末はスマホ先行(タブレットは後) | Glance/Compose/Credential Manager が安定動作。市場カバレッジ十分。 |
| 言語ロケール | **日本語のみ**(iOS と同じ)。ただし文字列は `strings.xml` に集約し将来 i18n 可能に | iOS はハードコード。Android は最初から resources 化が低コストで将来有利。 |
| 配信 | Google Play(日本のみ、iOS と同じ配信方針) | [[release_identifiers]] |

### レイヤリング(iOS との対応)
```
UI (Compose screens)              ← SwiftUI Views
ViewModel (StateFlow, events)     ← @Observable Store/ViewModel
Domain (pure Kotlin: streak/achievement/cycle 計算, use-cases)  ← StreakCalculator 等 純粋関数
Data (Room, DataStore, Supabase repos)  ← WorkoutStore/Supabase*Service
Platform (notifications, billing, widgets, auth coordinators)   ← Services
```
- DI: **Hilt**(または手動 DI)。iOS の `@Environment` 注入に対応。
- 純粋関数ロジック(streak/rescue/achievement/cycle/ranking)は **iOS と1:1 で移植**し、**同じテストケースを Kotlin で再現**(iOS のユニットが仕様書代わり)。

---

## 3. 技術選定(iOS → Android 依存対応表)

| 領域 | iOS | Android(採用) | 備考 |
|---|---|---|---|
| UI | SwiftUI | Jetpack Compose + Material 3 | |
| ローカルDB | SwiftData (`WorkoutRecord`/`WeightEntry`/`MenstrualEntry`) | **Room** | エンティティ1:1移植 |
| 設定/小データ | UserDefaults | **Jetpack DataStore (Preferences)** | theme/猫/通知設定/rescue使用日/milestone既読 |
| 機密(セッション) | Keychain | **supabase-kt のセッション永続 + AndroidKeyStore 由来鍵で暗号化**(`EncryptedSharedPreferences` は Security-Crypto 1.1.0 で deprecated のため不採用)。自動バックアップから token を除外(`fullBackupContent`/`dataExtractionRules`) | |
| BE クライアント | supabase-swift 2.46 | **supabase-kt**(Auth/Postgrest/Functions、必要なら Realtime) | 同一プロジェクト/スキーマ |
| 匿名/連携認証 | 匿名 + Apple(native id_token) + Google(web/PKCE) | 匿名 + **Google(native id_token)** + **Apple(web/PKCE)** | **iOS と鏡像**(§6) |
| Apple/Google ボタン | ASAuthorizationAppleIDButton / 自前 G | Google: Credential Manager / Apple: ブランド準拠ボタン | |
| Web OAuth | ASWebAuthenticationSession | **Custom Tabs (androidx.browser)** + deep link コールバック | |
| 課金 | StoreKit 2 | **着工時点で最新の Play Billing**(2026-06 現在 9。PBL7 は新規/更新が 2026-08-31 まで=数ヶ月スコープでは不可) | サブスク base plan/offer。`ProductDetails`/`offerToken` |
| 分析 | TelemetryDeck 2.14 | **TelemetryDeck Kotlin SDK** | opt-in・同一 App ID 体系 |
| クラッシュ | Apple 標準(ASC) | **Google Play Console: Android vitals**(SDK不要) | Apple 標準と同等思想。Crashlytics は不採用既定(§9) |
| ローカル通知 | UNUserNotificationCenter(rolling 7日) | **WorkManager / 非正確 AlarmManager(window) + NotificationCompat**(既定)。exact alarm は習慣リマインダーでは Play ポリシー的に不可寄り | 定時2回・達成後再スケジュール |
| ウィジェット | WidgetKit | **Jetpack Glance** | small/medium 相当 |
| Live Activity | ActivityKit | (v1非対象) ongoing notification / Android16 Live Updates | §10 |
| クイック記録 | App Intents / Lock screen | **App Shortcuts + Glance ボタン + Quick Settings タイル** | |
| 共有 | ShareLink | Android Sharesheet (`Intent.ACTION_SEND`) | |
| QR | CoreImage | **ZXing / ML Kit**(生成+読取) | 友達コード QR |
| 画像 | Asset Catalog(77猫画像) | drawable/WebP + Coil | §12 |
| Bot対策 | Turnstile(WKWebView) | Turnstile(WebView)or Play Integrity | 既定は iOS と同じ Turnstile を流用 |

---

## 4. データモデル & 永続化(Room)

iOS の SwiftData/値オブジェクトを Room + Kotlin data class に移植。

- `WorkoutRecord`(Room entity): id(UUID/String pk), date(epochDay), category(enum), exercises(JSON or 子テーブル), memo, createdAt, updatedAt。
  - `ExerciseItem` は JSON カラム(iOS と同じ)か 1:N 子テーブル。iOS は JSON 格納 → 同方式で移植容易。
- `WeightEntry`(premium): id, timestamp, weightKg, memo, createdAt, updatedAt(同日複数可)。
- `MenstrualEntry`(premium): id, date(startOfDay), createdAt。
- 値オブジェクト(永続化しない): `WorkoutCategory`/`DailyStatus`/`StreakState`/`WeeklyProgress`/`StreakLevel`/`CatState`/`CatBreed`/`CatDecoration`/`CyclePhase`/`Milestone` → Kotlin enum/data class に1:1移植。
- 友達系 DTO(`FriendProfile`/`SharedExerciseDetail`/`FriendRequest`): Supabase の行を kotlinx.serialization でデコード(iOS の Codable Row と同一カラム)。
- DataStore: 選択猫種・テーマ・通知設定・通知パーソナリティ・rescue 使用日 Set・milestone 既読・onboarding 完了・友達共有 opt-in・backupPromptDismissedAt。
- ウィジェット連携: iOS の App Group 相当は Android では**同一プロセスから Room/DataStore を直接読む**(Glance)。別途 `WidgetSnapshot` を DataStore に publish しても良い。

---

## 5. 機能パリティ表(フェーズ割当て付き)

凡例: P1=Android v1, P1.x=ファストフォロー, P2=後続。複雑度は相対(L/M/H)。

| 機能 | iOS | フェーズ | 複雑度 | Android 留意点 |
|---|---|---|---|---|
| コア運動記録(6カテゴリ/種目/メモ/時間reps sets) | ✅ | **P1** | M | RecordEntry の動的リスト=Compose `LazyColumn` |
| ストリーク計算(週2休/rescue) | ✅ | **P1** | M | 純粋関数移植 + 同テスト |
| 達成判定/カレンダー(月/週、DayDetail) | ✅ | **P1** | M | |
| ホーム(猫シアター/週ミニカレンダー/記録CTA) | ✅ | **P1** | M | アニメは Compose で簡略化可 |
| 猫11種×7状態 + 装飾tier | ✅ | **P1** | M | 77画像(WebP化) |
| テーマ5種 | ✅ | **P1** | L | Material 3 テーマトークン |
| オンボーディング(猫選択) | ✅ | **P1** | L | |
| ローカル通知(定時2回/パーソナリティ3種) | ✅ | **P1** | M | `POST_NOTIFICATIONS` + WorkManager / 非正確 AlarmManager(exact は不採用, §8) |
| 友達(コード/QR/申請/承認/解除/cheer/週間ランキング/公園) | ✅ | **P1** | H | supabase-kt、**iOS とコード相互運用** |
| アカウント連携(Google native / Apple web)+復元+切替+削除 | ✅ | **P1** | H | §6。審査(アカウント削除)必須 |
| 課金(サブスク2本/14日無料)+ペイウォール | ✅ | **P1** | M | 最新 Play Billing(現状9, §7) |
| ディープリンク(goexercise:// 7ルート) | ✅ | **P1** | M | App Links/scheme |
| 分析(TelemetryDeck 8イベント, opt-in) | ✅ | **P1** | L | |
| クラッシュ(Play vitals) | ✅(Apple) | **P1** | L | SDK不要 |
| データエクスポート/全削除 | ✅ | **P1** | M | 審査(削除)整合 |
| 体重トラッキング(premium, 7日移動平均グラフ) | ✅ | **P1.x** | M | グラフ(Vico 等) |
| 生理周期オーバーレイ(premium, 4フェーズ) | ✅ | **P1.x** | L | |
| ホームウィジェット(small/medium) | ✅ | **P1.x** | H | Glance |
| マイルストーン祝祭/シェア画像 | ✅ | **P1.x** | M | |
| クイック記録(ショートカット/タイル) | ✅ | **P1.x** | M | |
| Live Activity 相当 | ✅(iOS16.1+) | **P2** | H | Android は直接等価なし |
| 友達 push 通知(申請/cheer) | iOS 将来 | **P2** | M | Supabase→FCM(iOS も未) |
| レビュー促し | ✅ | **P1.x** | L | In-App Review API |

> **採用スコープ(既定)**: 段階的。**P1 で「相互フレンド + 課金 + 審査要件」を満たすコア**を出し、体重/生理/ウィジェット等は P1.x。これは「最短で Apple↔Android 友達を成立させ、機能差は後追いで詰める」方針(要ユーザー判断 §15-A)。

---

## 6. 友達 / アカウント連携の設計(iOS と鏡像)

### 基本
- **同一 Supabase プロジェクト**(URL/anon key を `local.properties`/BuildConfig 経由で注入。iOS の `Secrets.xcconfig` 相当)。
- 匿名サインインは **lazy**(コード表示/友達追加/承認の能動操作時のみ)。タブ閲覧ではクラウド書込ゼロ。
- friend code は**サーバ採番を信頼**(端末生成しない)。`FriendCodeValidator` 相当(O/0/I/1 除外, 6桁)を入力補正に移植。
- cheer は RLS で friendship 必須(サーバ側既存)。

### 連携(機種変復旧)の経路 — **iOS とちょうど鏡像**
| プロバイダ | iOS | Android |
|---|---|---|
| 自プラットフォーム | Apple = **native id_token**(ASAuthorization) | Google = **native id_token**(Credential Manager / Google ID) → `signInWith(IDToken)` / `linkIdentityWithIdToken` |
| 他プラットフォーム | Google = **web/PKCE**(ASWebAuthenticationSession) | Apple = **web/PKCE**(Custom Tabs)→ supabase-kt `linkIdentity(Apple)` / `signInWith(Apple)`(必要なら `getOAuthUrl`)→ `goexercise://auth-callback` → `exchangeCodeForSession` |

- 連携(昇格): 匿名 uid を保持したまま identity 連結(uid/friendCode/友達 不変)。
- 衝突(論点C, `identity_already_exists`): マージせず「既存に切替/中止」の二択。Android でも同一方針。web 経路の衝突は callback の error_code を写像(iOS の `mapPKCECallback` と同型)。
- 復元入口: welcome から「Google で復元」(native)/「Apple で復元」(web)。restored/created/failed を区別。
- 削除導線(審査): `deleteAccount()` 相当(本人 uid のデータ全削除 → global サインアウト)。**Google Play も近年アカウント削除導線を要求**するため必須。`auth.users` 行削除は Edge Function `delete-account`(iOS と共用、service_role)を呼ぶ。
- 再入ガード/.cancelled 無視/post-auth 失敗時 local サインアウト巻き戻し を iOS と同じ堅牢度で。
- **redirect URL** `goexercise://auth-callback` を Supabase 許可リストに追加(iOS で登録済みなら共用)。

### supabase-kt の確認ポイント(着工初期に PoC)
- 匿名サインイン + `captchaToken`(Turnstile)対応の API 形。
- `linkIdentityWithIdToken`(Google native)/ OAuth web(`linkIdentity` / `signInWith(Apple)`、必要なら `getOAuthUrl`)+ Custom Tabs コールバックで `exchangeCodeForSession`(PKCE)。※ Kotlin SDK の正確な API 名は着工時に supabase-kt 当該バージョンで確定する。
- Manual Linking 設定が iOS と共用で効くこと。

---

## 7. 課金(Google Play Billing)

- ライブラリ: **着工時点で最新の Play Billing**(`BillingClient`。2026-06 現在は 9。PBL7 は 2026-08-31 で新規/更新の受付終了 = 数ヶ月スコープでは古すぎる)。`ProductDetails` + `offerToken` で無料トライアル offer を扱う。
- 商品: サブスク(月/年)= iOS の `premium_monthly`/`premium_yearly` に対応する **Play 上の別 productId**(ストア間で課金は別管理。エンタイトルメントはBEで紐づけない=各ストア独立で良い)。14日無料は base plan の **free trial offer**。
- エンタイトルメント: `queryPurchasesAsync` + `acknowledgePurchase`。`isPremiumActive` を iOS と同じ意味で公開。
- gate 対象(P1.x の体重/生理 + rescue 月4枚 vs 1枚)を iOS と同一に。
- 審査: 価格/周期/自動更新の明示・復元(Play は購入復元が自動だが UI 導線)・解約導線(Play の定期購入管理)・法務リンク。

---

## 8. 通知(ローカル)

- 定時2回(朝8:30/夜20:00 既定)+ パーソナリティ3種(voice/quiet/friendDriven)を移植。
- スケジューラ(既定): **WorkManager** か **非正確 AlarmManager**(`setWindow`/`setInexactRepeating`)。習慣リマインダーは Play の exact-alarm ポリシー上「正確な時刻が本質」と見なされにくく、`USE_EXACT_ALARM` は時計/カレンダー系向け。分単位のズレ許容で十分なので exact は使わない(必要が出たら `SCHEDULE_EXACT_ALARM` のユーザー許可フローで限定採用)。**Android 13+ は `POST_NOTIFICATIONS` 実行時権限**が必要。
- iOS の「rolling 7日 one-shot」制約は Android には無い(64件制限が無い)ので、毎日再スケジュール方式に簡素化。
- 達成後/ rescue 後に再計算 → 再スケジュール + ウィジェット更新(iOS と同じトリガ)。
- タップ → deep link ルーティング。

---

## 9. 分析・クラッシュ・push(既定方針)

- **分析: TelemetryDeck Kotlin SDK**。iOS と同じ 8 イベント(appOpen/onboardingCompleted/recordCreated(category)/paywallViewed/purchaseStarted/purchaseCompleted/dataExported/dataDeleted)。opt-in・PII なし。App ID 設定時 + Release のみ有効(iOS と同じゲート)。
- **クラッシュ: Google Play Console の Android vitals**(ANR/クラッシュ)。SDK 不要 = Apple 標準と同等思想で**追加のデータ収集 SDK を入れない**([[feedback_release_ops_decisions]] のプライバシー最優先に合致)。
- **friends push(P2)**: Supabase DB トリガ → Edge Function → **FCM**(Android)/ APNs(iOS)。FCM はこの push のためだけに後追い導入(Firebase Analytics/Crashlytics は入れない)。
- 代替案(Firebase 一式)は §15-B に明記(push 即解決と引き換えに Google 依存増)。

---

## 10. ウィジェット / Live Activity 相当(P1.x〜P2)

- **Glance** で small/medium 相当(連続日数 + 週ミニカレンダー + 猫メッセージ)。データは Room/DataStore を直接読む。
- タップ → `goexercise://home`。記録ボタン → クイック記録。
- Live Activity(iOS ActivityKit)は Android に直接等価なし。**P2** で ongoing notification か Android 16 「Live Updates(promoted notifications)」を評価。v1 は非対象。

---

## 11. ディープリンク

- scheme `goexercise://` を Manifest の intent-filter に登録。7ルート(home/record/history/settings/notification-settings/friends?code=/weekly-ranking/streak-share)を `DeepLinkRouter` 相当へ。
- 友達 OAuth コールバック `goexercise://auth-callback` は **Custom Tabs / Credential Manager が捕捉**(通常の deep link ルーティングには流さない)= iOS と同じ衝突回避。
- 将来 QR 招待を Web から開けるよう **App Links(https 検証)** も検討(P1.x)。

---

## 12. アセット

- 猫 77 画像(11種×7状態)+ orange フォールバック。**WebP** 変換でサイズ削減、`drawable-nodpi` か density 別。Coil で表示。
- 命名は iOS `cat_<breed>_<state>` を踏襲(移植・突合が楽)。
- iOS の Asset Catalog からの書き出し → WebP 一括変換スクリプトを着工時に用意。

---

## 13. フェーズ計画(粗い相対見積り・1人開発)

> 数字は順序と相対規模の目安。確定スケジュールではない。

- **P0 基盤(〜2週)**: プロジェクト雛形(Compose/Hilt/Room/DataStore/CI)、テーマ5種、ナビゲーション、オンボーディング、デザインシステム(Palette/Typography 移植)。
- **P1a コア(2〜4週)**: 記録/カテゴリ/種目、ストリーク・達成・休息・rescue(純粋関数+テスト)、ホーム、カレンダー/履歴、猫11種×7状態+装飾、通知。
- **P1b 友達+連携(3〜5週)**: supabase-kt 疎通 PoC → 匿名 lazy・friend code・申請/承認/解除・cheer・週間ランキング・公園・QR。Google native + Apple web 連携・復元・切替・**削除導線**。エラーバナー/ローディング。
- **P1c 課金+審査整備(2〜3週)**: Play Billing、ペイウォール、データエクスポート/削除、Data safety フォーム、ストア掲載、内部テスト配信。
- **→ P1 リリース判定**(iOS v1.0 審査承認後、`friendsEnabled` 解禁条件と整合)。
- **P1.x(逐次)**: 体重+生理(premium)、ウィジェット(Glance)、マイルストーン祝祭/シェア、クイック記録、In-App Review。
- **P2**: friends push(FCM)、Live Activity 相当、タブレット最適化。

並行作業の山場: 友達連携(P1b)はデータ整合に関わるため **Codex 改善ループ前提**でしっかり([[feedback_verification_workflow]])。

---

## 14. テスト戦略

- **純粋ロジックは iOS のユニットを移植**(StreakCalculator/AchievementEvaluator/RestDayResolver/WeeklyProgress/WeeklyRanking/LifetimeStats/CyclePhase/CatStateResolver/FriendCodeValidator)。同入力同出力を JUnit で固定 = iOS と Android の**仕様一致を機械検証**。
- リポジトリ/ViewModel: フェイク Supabase(MockFriendsService 相当)で UDF を検証。連携の写像(collision/cancelled/failed/restore)を iOS の AccountLinkingTests と対応させる。
- UI: Compose UI test(主要フロー = 記録→ストリーク反映、友達 welcome→サインイン、ペイウォール)。
- 連携系・課金・削除は実機/実プロジェクトで手動 E2E(キー所有者作業)。

---

## 15. 要ユーザー判断(既定案 + 確認ポイント)

> 以下は計画の前提として**既定案を採用**して書いてある。覆すならここを指定。

- **A. v1 スコープ(既定: 段階的)** — P1=コア+友達+連携+課金+審査、体重/生理/ウィジェット等は P1.x。
  - 代替: 完全パリティ(v1 で 1:1、出荷最遅)/ コア最小 MVP(友達・課金を後回し=本来目的が遅れる)。
- **B. 分析/クラッシュ/push(既定: iOS 方針踏襲)** — TelemetryDeck + Play vitals、push は後追い FCM。
  - 代替: Firebase 一式(Analytics+Crashlytics+FCM、push 即解決だが Google 依存・収集増)。
- **C. 課金の地域/価格** — iOS と同額帯か Play の日本価格に合わせるか(ストア独立)。
- **D. minSdk / 端末** — 既定 minSdk 26・スマホ先行。タブレット/折りたたみは P2。
- **E. ロケール** — 既定 日本語のみ(strings.xml 化で将来拡張可)。
- **F. 通知スケジューラ(既定: 非 exact)** — WorkManager / 非正確 AlarmManager の分単位許容。`USE_EXACT_ALARM` は習慣リマインダーでは Play ポリシー上不可寄りなので使わない。どうしても秒精度が要るなら `SCHEDULE_EXACT_ALARM` のユーザー許可フローで限定。
- **G. KMP** — 既定 不採用(純ネイティブ)。将来 iOS 側も巻き込む再設計をするなら別議論。

---

## 16. 審査・ストア(Google Play)

- **Data safety フォーム**(Codex round1 で是正): 友達解禁版が Supabase / TelemetryDeck へ送る全データを Google の分類で正確に申告する。狭すぎる申告は審査ブロック要因。**SDK 経由送信も申告対象**。
  - **Health and fitness(Fitness info)**: 友達に共有する**運動カテゴリ名・種目名・連続記録・達成サマリ**。← 「User content」だけでは不足。
  - **App activity / analytics**: TelemetryDeck のアプリ操作イベント(opt-in でも申告)。
  - **Identifiers / User content**: 表示名・friend code・端末匿名 uid・cheer。
  - 用途は「アプリ機能」中心、**トラッキングなし・第三者広告なし**。**体重・体調(menstrual)はクラウドへ送らない**(端末ローカルのみ)を明記。
  - iOS の App Privacy 更新と意味を一致させる([[friends_backend_crossplatform.md]] のラベル方針)。
  - 出典: Google Play Data safety (support.google.com/googleplay/android-developer/answer/10787469)。
- **アカウント削除要件**: アカウント作成(連携)を提供するアプリは**アプリ内 + ウェブの削除導線**が要求される。`deleteAccount()` 導線 + (必要なら)ウェブ削除ページ。
- **サブスク開示**: 価格/周期/自動更新/解約方法/復元/法務リンク。
- 日本のみ配信([[release_identifiers]])。

---

## 17. リスクと対策

| リスク | 影響 | 対策 |
|---|---|---|
| supabase-kt の OAuth/匿名/Manual Linking が iOS と挙動差 | 連携が動かない | **P1b 冒頭で疎通 PoC**(匿名→Google native→Apple web→衝突→削除)を最優先で検証 |
| Apple web ログインの Android UX(Custom Tabs 戻り) | 復元が不安定 | redirect/コールバック・再入ガード・cancelled を iOS と同じ堅牢度で。実機検証 |
| friend code 名前空間の取り違え | 相互フレンド不成立 | **同一 Supabase プロジェクト**を BuildConfig で固定。iOS と同コードで疎通テスト |
| exact alarm / 通知権限ポリシー | 通知が出ない/審査弾かれ | Android 13/14 の権限フロー設計、代替 WorkManager |
| 課金エンタイトルメントの食い違い | 有料機能の不整合 | Play 購入を単一の真実源に、acknowledge 必須 |
| アセット77画像の重量 | APK 肥大 | WebP + density 整理、App Bundle(動的配信) |
| 個人開発の工数 | 長期化 | 段階出荷(§13)。P1 を相互フレンド成立に絞る |

---

## 18. 着工条件(明示)

- 本計画書を **Codex でレビュー → 反映**(次タスク)。
- **着工の号砲はユーザー承認後**。承認時に §15 の判断(特に A/B)を確定してから P0 に入る。
- 友達版の本リリースは **iOS v1.0 審査承認後**(順序厳守)。

---

## 付録: 直近の次アクション(承認後の最初の1歩)
1. Android Studio プロジェクト作成(Compose/Hilt/Room/DataStore、minSdk 26、パッケージ `com.goexercise.app` で Play 別アプリ)。
2. **supabase-kt 疎通 PoC**(匿名サインイン + `profiles` upsert + friend code 採番)を iOS と同一プロジェクトに対して通す。
3. 純粋ロジック(StreakCalculator 群)移植 + iOS テスト移植で仕様一致を固定。
