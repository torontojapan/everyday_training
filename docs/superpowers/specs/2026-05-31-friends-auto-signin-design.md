# 設計: 友達タブの自動サインイン化(サインインの壁カードを廃止)

最終更新: 2026-05-31 / ブランチ: feature/friends-release

## 背景・狙い
友達タブを開くと最初に「サインインして始める」の全面カード(`signedOutBody`)が壁として出る。
バックエンド(Supabase)は**匿名認証**で、メール/パスワード不要。よってこの壁は不要な摩擦。
ユーザー操作なしに**裏で匿名サインイン**し、即座に友達グリッド/空状態を見せる。

identity(他人に見える表示名)は社交機能に必要なので、
**初回だけ軽い表示名入力**を促し(スキップ可)、**いつでもヘッダーから変更**できるようにする。

## 変更点

### A. 裏で匿名サインイン (`FriendsStore` / `FriendsView`)
- `FriendsStore.ensureSignedIn()` 追加: `profile == nil` のときだけ、
  既定表示名 `autoDisplayName`("ねこの友")+ 自動生成 username で `signIn`。
  `signIn` は `upsert(onConflict: user_id)` で**冪等**。匿名 uid は永続するので
  再起動時も同じ friendCode/プロフィールを引き継ぐ。
- username 自動生成: `"neko" + UUID 先頭6桁(小文字)`。一意制約は無いが衝突しにくく検索可。
- `FriendsView.task`: 未サインインなら `ensureSignedIn()`(内部で `refresh`)、
  サインイン済みなら従来通り `refresh()`。
- 壁 `signedOutBody` を廃止し、`profile == nil` 分岐は
  **サインイン中=spinner / 失敗時のみ=やさしい再試行**(`friendsConnectingBody`)に置換。

### B. 初回のみ表示名入力 (`FriendsView`)
- `@AppStorage("friends.didDismissNamePrompt")` で一度きり。
- 表示条件: `!didDismissNamePrompt && profile.displayName == autoDisplayName`。
  → デモ/スクショの "ジュン" など既に名が付くプロフィールには出ない。
- インラインカード(`Palette.surface`)に TextField +「決定」「あとで」。
  決定 → `updateDisplayName` + フラグ立て。あとで → フラグ立てのみ。

### C. ヘッダーに表示名変更 (`FriendsView.profileHeader`)
- 表示名横に鉛筆ボタン → `.alert` で表示名のみ変更。
- `FriendsStore.updateDisplayName(_:)`: 現 `profile` の `displayName`/`lastUpdated` を更新し
  `publishMyProfile` で送信(username/friendCode は不変)。

### D. 不要コードの除去
- `FriendsSignInSheet` 構造体・`isShowingSignIn` state・対応 `.sheet`・`friends-signin-button` を削除。
- `handlePendingFriendCode` の未サインイン分岐を `Task { await ensureSignedIn(); tryPresentPendingAdd() }` に。
- `tryPresentPendingAdd` の `!isShowingSignIn` ガードを除去。

## 非対象
- バックエンド/データモデル変更なし(既存 signIn/publishMyProfile を利用)。
- username の変更 UI は出さない(検索補助。表示名のみ編集可能にする)。
- 友達タブの大規模再設計はしない。

## テスト/検証
- `FriendsFlowUITests.testFriendsSignedOutShowsSignInButton` を
  **自動サインイン検証**(force-signed-out で起動 → 友達追加ボタン/友達コードが出る)に書き換え。
- `FriendsStoreTests` に `ensureSignedIn`(冪等・既定名)/`updateDisplayName` のユニット追加。
- ビルド成功 + Codex 改善ループで承認まで。

## 完了基準
- 壁カードが消え、開くと自動で signed-in UI。初回のみ表示名入力が出てスキップ可。
- ヘッダーから表示名変更可能。username/friendCode は不変。
- 全テスト green・ビルド成功・Codex 承認。
