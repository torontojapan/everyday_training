# 設計: 友達アカウント堅牢化(匿名ファースト維持 + lazy化 + 任意のApple/Google連携)

最終更新: 2026-06-01 / ブランチ: feature/friends-release

## 背景・狙い
直近の変更(`9fba749`)で友達タブは「壁を出さず裏で匿名サインイン」になった。これにより
摩擦は消えたが、匿名認証を自動化したことで**運用上の懸念が3点**生まれている。
本設計はこの3点を **匿名ファーストの気軽さを壊さずに** 全て払拭する。壁は復活させない。

### 払拭すべき懸念
1. **①識別子の喪失(復旧不可)** — 匿名セッションは端末ローカル(Keychain)のみ。機種変・
   再インストール・別プラットフォームへ移ると uid が変わり、friendCode も友達も失う。
   メール/パスワードが無く復旧手段ゼロ。相手側の `friendships` 行は死んだ uid を指したまま残る。
2. **②孤児アカウントの蓄積** — タブを開いた瞬間に匿名ユーザー+`profiles` 行が生成され、
   未使用/アンインストールで幽霊行が永久に残る。Supabase の MAU/上限を圧迫し、匿名サインインの
   スクリプト量産(濫用)も可能。
3. **③プライバシー(opt-in)との緊張** — ユーザー操作なしにタブ表示だけでクラウドへ profile を
   upsert する。プライバシー最優先・opt-in 志向の方針と厳密にはズレる。プライバシーラベル整合も必要。

## 基本方針(ターゲット像)
- **匿名ファーストは維持**。アカウントを最初から強制しない(気軽さ)。
- **発火を lazy 化** — クラウドが要る能動操作の瞬間に初めて匿名サインイン(②③を根治)。
- **復旧は Apple/Google 連携を「任意・後追いで促す」形で被せる**(①を根治)。壁ではない。
- **運用ガード** — CAPTCHA + 孤児削除 cron + 既存 RLS。

「設計は全部入り、出す順番は分ける」。①の連携が最も重いので v1 を人質にしない。

| 段階 | 入れるもの | 効果 |
|---|---|---|
| **v1 (アーカイブ前)** | lazy化 / CAPTCHA / 孤児削除cron / プライバシーラベル整合 | **②③を完全に潰す**。①は対象母数を最小化してリスク低減 |
| **v1.1 (ファストフォロー)** | Apple+Google identity linking(任意・促し) | **①を根治** |

lazy化を先に入れることで、連携が来るまでの間に識別子を持つのは「実際に友達を使った engaged な人」
だけになり、母数が小さいうちに v1.1 が間に合う。

---

## 確定した論点(自己判断)

### 論点A: 「能動操作」の線引き
**サインインを発火させる操作 = クラウド上の identity が必須なものに限定:**
- 自分の friendCode / QR を**表示**しようとした時(他人が引けるよう profile 行が要る)
- 友達を**追加**(コード入力 / 検索 / QR読取)しようとした時
- ディープリンクの友達コードを**承認**しようとした時

**発火させない(ローカルのみで完結):**
- 友達タブを開く / 空状態・オンボ文言・猫パークの閲覧
- アプリ共有カード(`shareAppCard`)= `AppSharingConfig.shareURL` の静的 install URL。identity 不要。

### 論点B: 連携の促し発火条件
- 条件: `(friends.count >= 1 || profile.currentStreak >= 7)` かつ **未連携** かつ **直近で dismiss していない**。
  - 友達1人以上 = 社交的に失うものがある瞬間。ストリーク7日 = 努力的に失うものがある瞬間。
- 頻度: **消せるカードを1回**。dismiss したら `@AppStorage` のタイムスタンプで**30日**沈黙し、その後
  条件を満たせば再掲。**設定画面からはいつでも**「友達を機種変でも引き継ぐ」導線を出す。
- 文言は「サインインして」ではなく「**Apple / Google でバックアップ(機種変でも引き継ぐ)**」。

### 論点C: link 衝突処理(マージしない)
- Supabase の identity linking で対象 Apple/Google ID が**既に別アカウントに紐付く**場合
  (`identity_already_exists`)、**友達グラフのマージは行わない**(2グラフ統合は破壊的で危険)。
- ユーザーに二択を提示:
  - (a) **既存アカウントに切替** — 「この Apple ID は既存データに紐付いています。現在の端末の
    匿名データ(友達/コード)は失われます」と**明示警告**の上、既存アカウントでサインイン。
  - (b) **中止** — 匿名のまま継続。
- 成功時(未紐付け): anonymous→permanent に**昇格**。uid 不変・friendCode 不変・友達不変。

---

## 変更点

### Phase 1 (v1): lazy化 + 運用ガード

#### 1-A. 発火の lazy 化 (`FriendsView` / `FriendsStore`)
- `FriendsView.task` から `ensureSignedIn()` の**無条件呼び出しを削除**。サインイン済みなら
  `refresh()` のみ。未サインインなら**何もクラウドに書かず**ローカル UI を描画。
- 未サインインの `body` 分岐: `isSigningIn` 中だけ `friendsConnectingBody`(spinner のみ)、
  それ以外の idle は**常に `friendsWelcomeBody`**(猫 + 「友達とつながる」CTA + `shareAppCard`)。
  ここに居る限りクラウドアクセスはゼロ。
- **サインイン失敗の扱い (Codex)**: 全画面 retry にせず welcome 内にやさしい固定文を**インライン表示**し、
  「友達とつながる」CTA が `clearError()`→再試行を兼ねる。stale な `lastError` で welcome に
  戻れなくなる(retry に閉じ込められる)不具合を回避。
- 能動操作の各エントリ(自分のコード表示 / 友達追加 / QR表示 / deep link 承認)を
  **`ensureSignedInThen { … }`** でラップ。中身:
  ```
  func ensureSignedInThen(_ action: () -> Void) async {
      if !isSignedIn { await ensureSignedIn() }   // 既存: profile==nil の時だけ signIn(冪等)
      guard isSignedIn else { return }             // 失敗時は lastError 表示、action は実行しない
      action()
  }
  ```
- 「初回のみ表示名入力」(`namePromptCard`)は**サインイン直後**に出す(従来はタブ表示時)。
  `didDismissNamePrompt` ロジックは流用。
- `friendsWelcomeBody` の CTA タップ → `ensureSignedInThen { isShowingAdd = true }` 等。

#### 1-B. Mock も lazy を反映 (`MockFriendsService` / DEBUG)
- スクショ/デモ用の `--mock-*` 自動オープン経路は、開く前に `ensureSignedIn()` を通す(従来は
  タブ表示で signed-in だった前提が崩れるため)。デモのリッチ表示は維持。

#### 1-C. CAPTCHA (Cloudflare Turnstile) — **クライアント実装済 (config-gated)**
- `CaptchaTokenProviding` 抽象 + `NoCaptchaTokenProvider`(no-op) + `TurnstileCaptchaTokenProvider`
  (WKWebView でチャレンジ実行)。`SupabaseFriendsService.ensureUID()` が新規匿名サインイン時のみ
  `obtainTokenIfNeeded()` → `signInAnonymously(captchaToken:)` に渡す。
- **config-gated**: `SupabaseConfig.turnstileSiteKey`(Secrets.xcconfig `TURNSTILE_SITE_KEY` →
  Info.plist)が空なら CAPTCHA 無効 = `captchaToken: nil`(従来挙動と**バイト互換**)。
- 有効化手順(site key 設定 + Turnstile 許可ドメイン登録 + Supabase 側 ON を同時に)は
  `supabase/schema.sql` 2-b に明記。ユニット検証済(gating/no-op/エラー文言)。
  ※ 実 Turnstile webview 経路は実機 + 実キーでの手動確認が残(CI/シミュレータ未到達)。

#### 1-D. 孤児削除 cron (Supabase pg_cron + SQL)
- `supabase/cron/cleanup_orphans.sql`: **friendship 0件 かつ friend_requests 0件(送受信)
  かつ `coalesce(profiles.updated_at, auth.users.created_at)` が30日以上前** の匿名ユーザーを削除。
  `auth.users.is_anonymous = true` のみ対象。permanent(連携済み)は除外。
- **権限封じ込め (Codex P1)**: `SECURITY DEFINER` 関数の `EXECUTE` を public/anon/authenticated
  から revoke。PostgREST RPC 経由でクライアントが `inactive_days=0` 等で即時削除を強制できないようにする。
- **活動シグナルの担保 (Codex P2)**: クライアント upsert は `updated_at` を送らないため、
  `profiles` に **BEFORE UPDATE トリガ `set_updated_at`** を追加し更新時に `now()` を打つ。
  これで inactive 判定が「アカウント年齢」でなく実際の最終 publish で効く(`schema.sql`)。
- `friendships`/`friend_requests`/`cheers` は `on delete cascade` 済みなので auth.users 削除で連鎖。日次実行。

#### 1-E. プライバシーラベル整合 (`submission/`)
- App Store プライバシー栄養ラベルを「**友達を追加するとアカウントが作成され、表示名・運動サマリ
  (連続記録/カテゴリ/種目名)が送信される**」に更新。「タブ表示だけでは送信しない」を反映。
- `docs` のプライバシー方針にも lazy 化を明記。体重・体調は送らない(既存)を再確認。

### Phase 2: Apple identity linking — **実装済 (config-gated)**。Google/復元入口は follow-up

壁打ち(Codex)で確定した最適解で実装。Apple=ネイティブ id_token、Google=web/PKCE(後追い)。

#### 2-A. linking 実装 (`SupabaseFriendsService` / `AccountLinking.swift`)
- **Apple (本実装)**: `AppleSignInCoordinator`(ASAuthorization + SHA256 nonce、Swift6 nonisolated
  デリゲート→MainActor)で id_token 取得 → `linkIdentityWithIdToken(provider:.apple)` で
  **anonymous→permanent 昇格(uid 不変)**。`linkApple(idToken:nonce:)`。
- **衝突 (論点C)**: `AuthError.errorCode == .identityAlreadyExists` を `AccountLinkError.
  alreadyLinkedToAnotherAccount` に写像 → `FriendsStore.AppleLinkResult.collision` → UI で
  「既存アカウントに切替/中止」の二択。切替 = `switchToAppleAccount`(`signInWithIdToken` +
  `signIn` で切替先 profile をロード)。孤児化した匿名 uid は孤児 cron で回収。
- `isBackedUp` (= `session.user.isAnonymous == false`) を `FriendsStore.backupStatus` に公開。
- 連携時の落とし穴対応: rawNonce/SHA256 取り違え無し、RNG 失敗は throw(決定的フォールバック禁止)、
  signOut は**匿名のみクラウド削除・連携済みは保持**(バックアップを壊さない)、連打/継続の再入ガード。

#### 2-B. クライアント UI (`FriendsView`)
- 論点Bの条件(`friends>=1 || streak>=7`、未バックアップ、30日未dismiss、連携有効)で
  **消せる「バックアップ」カード** → 「Apple でバックアップ」。成功でトースト、衝突で二択ダイアログ。

#### 2-C. config-gating
- `SupabaseConfig.appleLinkEnabled`/`googleLinkEnabled`(Info.plist `FriendsAppleLinkEnabled`/
  `FriendsGoogleLinkEnabled`、既定 false)。未設定なら `isAccountLinkingEnabled=false` で
  カード非表示・coordinator 不実行 = **現匿名挙動と不変**。ユニット検証済(gating/衝突/成功/失敗写像)。

#### 2-D. 残 follow-up (Phase 2 完了に必要)
- **復元入口**: 新端末/再インストール時に welcome から「Apple でサインイン(復元)」。
  これが無いと連携済みでも新端末で新規匿名になる。`signInWithIdToken(.apple)` で復元。
- **Google 連携**: `linkIdentity(provider:.google)` の web/PKCE + `goexercise://` コールバック。
- **設定 (キー所有者)**: Sign in with Apple capability 追加 / Supabase Apple(+Google) provider 設定 /
  Manual Linking ON / redirect URL 許可。その後 `Friends*LinkEnabled=true`。実機手動検証。

---

## 非対象
- 友達グラフのマージ(論点C で明示的に除外)。
- username 変更 UI(従来通り表示名のみ編集)。
- 体重・体調などセンシティブデータの共有(従来通り持たない)。
- 友達タブの大規模 UI 再設計。

## テスト/検証
### Phase 1
- `FriendsStoreTests`: `ensureSignedInThen`(未サインイン→action前にsignIn / 失敗時はaction不実行 /
  既サインインは即action)。lazy: タブ相当の初期化で `signIn` が**呼ばれない**ことを Mock spy で検証。
- `FriendsFlowUITests`: 起動直後はコード/追加が出るが**クラウド書込なし**(welcome 表示)→ CTA タップで
  サインインしコードが出る、を検証。
- 孤児 cron: SQL を Supabase ローカル(`supabase db reset`)で実行し、30日超・friendshipゼロの匿名のみ
  削除されることを確認。
### Phase 2
- linking ユニット: 未紐付け→昇格で uid/friendCode 不変。衝突→二択 error。
- 手動: 実機で Apple 連携 → アプリ削除 → 再インストール → 同 Apple で復元 → 友達/コードが戻る。
- 各 Phase でビルド成功 + Codex 改善ループで承認まで(既存ワークフロー)。

## 完了基準
### Phase 1 (v1)
- タブ表示・閲覧では**クラウドアクセスゼロ**。能動操作で初めてサインイン。
- 匿名サインインに CAPTCHA 有効。孤児削除 cron 稼働。
- プライバシーラベルが lazy 挙動と一致。全テスト green・Codex 承認。
### Phase 2 (v1.1)
- 任意の Apple/Google 連携で機種変・再インストール復旧が成立(uid/friendCode/友達 保持)。
- 連携は壁にならず dismiss 可。衝突はマージせず二択で安全に処理。全テスト green・Codex 承認。

---

## 復元入口: ✅ 完了 (commit `f28b6e4`, 2026-06-02)

Phase 2 Apple 連携 (commit `e1fc98c`) の **残り半分 = 復元入口**を実装済み。
appleLinkEnabled(既定 false)ゲート、全 211 ユニット + 5 FriendsFlow UI テスト緑、
**Codex(xhigh) 改善ループ 9 周で `patch is correct` 収束**。

### 実装サマリ (実際の落とし所)
- 既存バグ修正: `switchToAppleAccount` の fallback 名上書き → 空文字 + `signInWithApple` 共用ヘルパー。
- 公開 API 分離: `linkApple` / `restoreWithApple`(restored/created/failed)/ `switchToAppleAccount`。
- welcome 2CTA(「この端末で始める」/ 公式 `ASAuthorizationAppleIDButton` ラッパー `AppleIDButton`)。
- 残存匿名データありは確認ダイアログ(`anonymousSessionHasData`, fail-closed + 保留申請も対象)。
- **Codex 9 周で潰した追加バグ**(下記いずれも gated OFF で未出荷だったが backend 稼働で顕在化する潜在バグ):
  - 部分 `select("col")` の decode throw(`ProfileRow`/`FriendshipRow` の必須カラム)→ 全カラム select に是正。
    復元 probe に加え既存 5 箇所(`generateUniqueCode`/`acceptRequest`/`removeFriend`/`sendCheer`)も修正。
  - `signIn`: 非匿名(連携済み)セッションは既存プロフィールを保持(自動既定名で上書きしない)。gate OFF は不変。
  - identity 切替の stale 競合 → 世代トークン(`identityGeneration`)で in-flight refresh を無効化 + 切替後再ロード。
  - post-auth 失敗 → `signOut(scope:.local)` で巻き戻し(全端末失効を回避)、identity 変化時のみ境界クリア。

### ⚠️ まだ未対応(出荷前に必須)
- **連携済み(永続)アカウントの削除導線** (審査 Guideline 5.1.1(v))。現状 signOut は匿名のみクラウド削除。
- **Google 連携**(`linkIdentity(provider:.google)` web/PKCE + `goexercise://` コールバック)。
- ユーザー作業: Supabase の Apple provider 設定 / Manual Linking ON / Sign in with Apple capability →
  `FriendsAppleLinkEnabled=true` で実機手動検証(機種変復旧 E2E)。

---

## 次セッション計画 (順序確定: 2026-06-02)

iOS 友達リリース面を**完全に閉じてから** Android へ。各ステップ独立セッション推奨
(削除はデータ消去を伴うため Codex ループ前提でしっかり)。

### ① 連携アカウント削除導線: ✅ 実装済 (2026-06-02)
- 審査 **Guideline 5.1.1(v)**: アカウント作成(Apple/Google 連携)を提供するなら**アプリ内削除導線が必須**。
- 現状 `signOut` は**匿名のみ**クラウド削除。**永続(連携済み)アカウントの削除**が無かった。

#### 実装サマリ
- `FriendsService.deleteAccount()` を protocol に追加 (extension 既定は安全側で throw)。
- `SupabaseFriendsService.deleteAccount()`: 本人 uid の `cheers`/`friend_requests`/
  `friendships`/`profiles` を削除 → `signOut(scope:.global)` で**全端末の refresh token を失効**。
  匿名/連携済みを問わず消す (`signOut` の「匿名のみ削除」とは別物)。各 delete は冪等、
  途中失敗 (セッション取得 / delete / signOut) は throw 伝播でサインアウトせず再試行可能。
  無セッションは `notSignedIn` で throw (誤った成功報告を避ける)。
- **Codex 改善ループ (xhigh) で潰したバグ**:
  - round1: 無セッションを「成功」と早期 return → サーバ行が残るのに削除完了と誤報告 +
    サインアウトで再試行不能。→ throw に是正。`signOut` の `try?` で失敗握り潰し → セッション
    残存で再作成リスク。→ `try` 伝播に是正。
  - round2: `.local` サインアウトでは別端末が生きたセッションでデータを再作成しうる
    (account resurrection)。→ 意図的削除なので `.global` 失効に是正 (rollback 経路は失敗操作
    なので `.local` のまま)。残る access token 窓 (~1h) と `auth.users` 行削除は Edge Function 担当。
- `FriendsStore.deleteAccount() -> Bool`: 連打ガード (`isDeletingAccount`)、成功で
  profile/friends/requests/backupStatus クリア + `bumpIdentity()`、失敗は lastError。
- `FriendsView`: サインアウト下に **`SupabaseConfig.isAccountLinkingEnabled` ゲートで**
  「アカウントを削除」(赤) → 確認ダイアログ (完全削除・復元不可を明示) → 成功トースト。
  gate OFF は導線非表示 = 現挙動と不変。
- **schema 修正**: `cheers` に `cheers_delete` RLS ポリシーを追加 (当事者削除を許可)。
  これが無いと RLS で client の cheers 削除が **0 行へ静かにフィルタ**される潜在バグだった。
- `MockFriendsService.deleteAccount()` (in-memory 全消去) + ユニット3本
  (成功でクリア / 失敗で保持・lastError / 連打ガード)。

#### `auth.users` 行削除の方針 (要設計判断 → 確定: Edge Function 採用)
- anon key では `auth.users` 行**自体**は削除不可 (service_role 必須)。クライアントは
  データ消去 + ローカルサインアウトまで。残る auth 行に PII は無く、行削除時に各表は
  `on delete cascade` で連鎖削除される。
- **採用**: Edge Function `supabase/functions/delete-account/index.ts` (スキャフォルド済)。
  呼び出し元 JWT で本人 uid を検証 → service_role の `auth.admin.deleteUser(uid)`。
  - cron 拡張を**不採用**の理由: 連携済みを cron で掃除するには「削除予約」状態が要り、
    その行自体が PII/複雑性を増やす。Edge Function は無状態で即時・単純。
  - 孤児 cron (`cleanup_orphans.sql`) は引き続き**匿名の未使用のみ**を対象 (役割分担)。
- **残作業 (キー所有者)**: `supabase functions deploy delete-account` → デプロイ後に
  クライアントを best-effort 呼び出し (`functions.invoke`) へ更新する follow-up。
  本セッションのクライアントは**データ削除 + ローカルサインアウトまで**で審査要件を満たす。

### ② Google 連携 (iOS): ✅ 実装済 (2026-06-02)
- `linkIdentity(provider:.google)` web/PKCE + `goexercise://` コールバック。Apple と同等の連携/復元/切替/削除。
- `googleLinkEnabled` ゲート。Supabase の Google provider + redirect URL 設定(ユーザー作業)。
- `googleLinkEnabled`(既定 false)ゲート、全 224 ユニット緑、**Codex(gpt-5.5, xhigh)改善ループ 2 周で
  `patch is correct` 収束**(round1 で access_denied 写像漏れを是正)。

#### 実装サマリ (実際の落とし所)
- **経路差**: Apple=ネイティブ id_token、Google=**web/PKCE**。`GoogleSignInCoordinator`
  (`ASWebAuthenticationSession`, callbackURLScheme=`goexercise`, 再入ガード/`.canceledLogin`→`.cancelled`)が
  認可 URL を提示しコールバック URL を返すだけ。認可 URL 生成 + PKCE code 交換は Service が担う:
  - 連携(昇格): `getLinkIdentityURL(.google)` → flow → `session(from:)`。uid/friendCode/友達 不変。
  - 復元/切替: `getOAuthSignInURL(.google)` → flow → `session(from:)` → `signInWithGoogle` ヘルパで
    profile ロード(空文字 signIn で既存保持)+ post-auth 失敗時 `signOut(scope:.local)` 巻き戻し(Apple と同型)。
- **衝突 (論点C)**: web/PKCE では `identity_already_exists` はコールバック URL の error_code に載って
  `AuthError.pkceGrantCodeExchange(error:code:)` で throw される(`errorCode` は `.unknown`)。
  `mapPKCECallback(code:error:)` で `alreadyLinkedToAnotherAccount` に写像 → UI で二択。
  切替は creds を再利用できないため web flow を再度通す(`isConfirmingGoogleSwitch`)。
- **provider-neutral 化**: `AppleRestoreOutcome→RestoreOutcome`、`FriendsStore.AppleLinkResult→LinkResult`、
  `AppleRestoreResult→RestoreResult`(case 名は不変 = Apple 挙動不変)。`.cancelled` を追加し、web flow 内
  キャンセルをエラーバナーなしで welcome に留める。`performSwitch`/`performRestore` で Apple/Google を DRY 化。
- **削除導線**: `deleteAccount()` は provider 非依存。`isAccountLinkingEnabled` ゲートでそのまま効く(確認済)。
- **gate-OFF バイト互換**: `FriendsGoogleLinkEnabled` は Info.plist 未追加(既定 false)。カード/ボタン非表示・
  coordinator 不実行。`connectButtonLabel` は `isAccountLinkingEnabled` 判定に変更(Apple/Google 共通)。
- **Codex round1 修正**: `access_denied`(error_code 不在)で SDK が `code="unspecified_code"` を入れるため
  `code ?? error` だと `.failed` になっていた。両フィールドを見つつプレースホルダを無視するよう是正。
- **ビルド統合**: 新規 `.swift` 2 本(coordinator/button)は `project.pbxproj` に手動登録
  (このプロジェクトは file-synchronized group でないため)。

#### ⚠️ 残作業 (出荷前 / キー所有者)
- Supabase の Google provider 設定 + **Manual Linking ON** + redirect URL `goexercise://auth-callback` 許可。
- `FriendsGoogleLinkEnabled=true` で実機手動検証(連携→削除→再インストール→Google で復元 の E2E)。
- **公式 Google "G" ブランドアセット**へ差し替え([[GoogleGMark]] は近似描画のプレースホルダ)。

### ③ Android 実装計画書 (タスク#7) — 新セッションで集中
- Android アプリ(全機能ゼロから / Kotlin + Compose)の**実装計画書を作成** → Codex レビュー →
  **着工の号砲はユーザー承認後**(数ヶ月規模の新規開発)。
- Supabase backend は中立設計済み(`docs/friends_backend_crossplatform.md`)= Android も同じ
  匿名認証 + PostgREST + Apple/Google 連携を再利用する前提。

---

## 旧: 次セッション計画 (復元入口) — 実装済みのため参考

Codex 壁打ち(計画段階)で判定「要修正」。以下を反映して実装した(上記サマリ参照)。

### ⚠️ 先に直す既存バグ (commit `e1fc98c` 内, gated OFF で未出荷)
- `SupabaseFriendsService.switchToAppleAccount` が `signIn(displayName: fallback, username: fallback)`
  を呼ぶが、`signIn` は**非空入力を優先**するため、復元/切替時に既存アカウントの
  `display_name`/`username` を「ねこの友」等の fallback で**上書きしてしまう**(Codex#1)。
  → 復元/切替の profile ロードは **空文字を渡す**(`signIn(displayName:"", username:"")`)。
  `signIn` の `displayName.isEmpty ? existing : displayName` 分岐で**既存を保持**、無い時のみ既定。

### 実装方針 (修正版)
1. **公開 API は統合しない**(Codex#B): `link`(昇格) / `restore`(復元) / `switch`(衝突切替) は副作用が
   違うので分離。内部ヘルパー(`signInWithApple(idToken:nonce:loadProfileOnly:)`)は共用可。
   - `restoreWithApple` は結果を明示: `restored`(既存ありロード) / `created`(新規) / `failed`。
     `profiles` を uid で引いて既存有無を判定し返す。
2. **welcome UI**: appleLinkEnabled 時のみ 2 CTA。
   - 主: 「この端末で始める」(= 現「友達とつながる」匿名)
   - 副: 「Apple で復元（以前連携した方）」→ AppleSignInCoordinator → restoreWithApple
   - **公式 Sign in with Apple ボタン**(`ASAuthorizationAppleIDButton` 相当)を使う(独自装飾不可, Codex#F)。
   - isLinkingAccount 連打ガード。.cancelled 無視・失敗 lastError。成功で signedInBody 着地。
3. **匿名残存セッションにデータがある状態で復元/切替する場合は確認ダイアログ必須**(Codex#3/A-ii)。
   welcome は store.profile==nil だが Keychain に旧匿名セッションが残る不整合あり得る。
   復元前に「現在の端末のデータが失われる可能性」を提示するか、匿名側に friends があれば警告。
4. **gate OFF をテストで固定**(Codex#E): appleLinkEnabled=false 時にボタン非表示 + 経路未実行。
5. ユニット: 復元 success(restored)/新規(created)/失敗/ゲートOFF。既存上書きしないことの検証。
6. ビルド+全ユニット緑 → Codex 改善ループで correct → コミット&プッシュ。

### 審査メモ (Codex#F)
- Guideline **5.1.1(v)**: アカウント作成を提供するなら**アプリ内アカウント削除導線**が必要。
  現状 signOut は匿名のみクラウド削除。**連携済み(永続)アカウントの削除導線**を別途用意すること。
- Guideline 4.8: 将来 Google を足すなら同等の第三者ログイン要件を満たす。

### この後 (別タスク)
- Google 連携(`linkIdentity(provider:.google)` web/PKCE + `goexercise://` コールバック)。
- **Android アプリ(全機能ゼロから / Kotlin+Compose)** = 実装計画書を作成しCodexレビューしてから着工。
