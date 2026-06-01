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

#### 1-C. CAPTCHA (Supabase 設定) — **クライアント対応とセットでのみ有効化**
- Authentication → 匿名サインインに **Cloudflare Turnstile(CAPTCHA)** を用意。
  ただし ON にするとサーバが captcha token を必須化するため、**先にアプリ側で Turnstile
  token を取得し `signInAnonymously` に渡す実装が必要**(未対応のまま ON にすると
  「友達とつながる」/deep link のサインインが実行時に失敗する, Codex P3)。
- `supabase/schema.sql` のセットアップ手順に「クライアント対応前は ON にしない」を明記済。
  → token plumbing(クライアント)は Phase 1 残タスク。それまで CAPTCHA は OFF 運用。

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

### Phase 2 (v1.1): Apple + Google identity linking

#### 2-A. クライアント連携 UI (`FriendsView` / 新 `FriendsBackupView`)
- 論点Bの条件で**消せる「バックアップ」カード**を表示。設定にも常設導線。
- ボタン: 「Apple でバックアップ」「Google でバックアップ」。
- 連携成功 → カードは恒久的に消え、ヘッダーに「✓ バックアップ済み」を小さく表示。

#### 2-B. linking 実装 (`SupabaseFriendsService`)
- `func linkIdentity(_ provider: .apple | .google) async throws` 追加。
  Supabase の `auth.linkIdentity` / Sign in with Apple のネイティブフロー(`signInWithIdToken` +
  link)を用い、**anonymous → permanent** に昇格(uid 不変)。
- 衝突時(論点C): `identity_already_exists` を捕捉し、UI に二択を提示する error を返す。
- `is_linked` をクライアントが知るための軽い getter(`session.user.isAnonymous`)を `FriendsStore`
  に公開(`var isBackedUp: Bool`)。

#### 2-C. Android 側(参考・別repo)
- 同じ Supabase プロジェクトで Google Sign-In による linking を実装(クロスプラットフォーム復旧)。
  本 spec は iOS が対象だが、schema/方針は共通である旨を明記。

#### 2-D. Sign in with Apple 設定
- Capabilities に Sign in with Apple を追加。Supabase の Apple provider 設定
  (Service ID / Key)。Secrets/Info.plist 経由は既存 SupabaseConfig 流儀に合わせる。

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
