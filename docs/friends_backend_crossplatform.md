# 友達バックエンド クロスプラットフォーム設計 (Apple ↔ Android)

最終更新: 2026-05-31

## 背景と決定

将来 **Android 版**を提供し、**Apple ユーザーと Android ユーザーが友達としてつながれる**ようにしたい(ユーザー要望 2026-05-31)。

現状の友達バックエンド `CloudKitFriendsService` は **CloudKit** 実装で、これは **Apple エコシステム専用**:

- CloudKit に **Android / 汎用ネイティブ SDK は存在しない**。
- 唯一の外部窓口「CloudKit Web Services (REST)」も **Apple ID 認証が前提**で、Apple ID を持たない Android ユーザーをアカウント化できない。
- → **Apple↔Android 友達共有と CloudKit は根本的に非互換。**

### 決定

- **友達機能の本番バックエンドは、プラットフォーム中立なサービスに置き換える。**
- 追い風:①`FriendsService` プロトコルで抽象化済み(`CloudKitFriendsService`/`MockFriendsService` が準拠)→ UI を触らず差し替え可能。②友達機能は**未リリース(v1 非表示・ユーザーゼロ)**→ 今切り替えても**データ移行コストはゼロ**。
- **CloudKit 固有の監査指摘(下記 H2/H3/N+1/ページング等)は深追いしない**(置き換えで捨て仕事になるため)。バックエンド非依存のフロント/コピー修正のみ実施する。

---

## 3 LLM コード監査の統合結果 (2026-05-31)

Claude(2観点)/ Codex / Gemini で友達コードを監査。新BE設計に「引き継ぐ仕様」と「避ける設計」を抽出。

### v1 非表示リーク (Release で友達が露出していないか)

- Claude・Gemini: 「リークなし」と判定。
- **Codex が 2 件の Critical リークを検出(他2LLMは見逃し)** → **修正済み(本コミット)**:
  - `NotificationSettingsView` / `NotificationPersonality`: 通知設定に「友達が動いた時だけ / 友達 push 中心」が露出 → `friendsEnabled=false` で `friendDriven` を選択肢・フッターから除外、保存値も voice にフォールバック。
  - `UserCatPickerView`: オンボーディングの「…友達一覧で使われます」→ 無効時は友達文言を出さない。
- ゲート機構自体(`resolvedRoute` 単一チョークポイント + タブ/サイドバー/設定の個別ゲート + 単体テスト)は3LLMとも堅牢と確認。

### 新BEに「引き継ぐべき」健全な仕様 (検証済み: OK)

- friend code は紛らわしい文字 (0/O/1/I) 除外・6桁で十分なエントロピー。`FriendCodeValidator` の入力補正。
- 自己申請・重複申請・既友達のガード(`sendRequest`)。
- 共有データは **カテゴリ名・種目名まで**。体重・体調は一切含めない(`FriendProfile` に存在しない)= プライバシー設計は維持。
- SwiftData は全 `ModelConfiguration` に `cloudKitDatabase: .none`(意図しない iCloud 同期を防止)。

### 新BEで「設計し直す/避ける」点 (CloudKit 固有の弱点)

| 指摘 | 内容 | 新BEでの対応方針 |
|---|---|---|
| H: エラーが UI に出ない | `FriendsStore.lastError` を `FriendsView` が読まず、iCloud未ログイン/ネット断が「空表示」になる | 新BEクライアント実装と同時に、エラーバナー+再試行を UI に追加(バックエンド非依存) |
| H: friend code 復元の握りつぶし | ネット断時に `try?` で新規発行→再生成回帰 | 新BEは **サーバ採番**(原子的)にして端末側の生成・衝突回避を不要化 |
| H/Medium: 友達解除が片側エッジのみ | 有向エッジで相手側に残る/再申請不整合 | 新BEは **双方向 friendship を単一行/ステータス(`active/removed/blocked`)** でモデル化 |
| Medium: N+1 フェッチ / ページング無し | 友達ごとに逐次取得・100件超欠落 | クエリ1発で friends を JOIN/IN 取得、ページング対応 |
| Medium: cheer の宛先未検証 | 任意コードに送信可能 | サーバ側ルール(RLS/security rules)で friendship 必須 |
| Low: 検索の大小文字・部分一致差 | Mock=部分一致 / CloudKit=完全一致 | username を正規化列で保存し前方一致 or 完全一致を統一 |
| Low: signedOut の旧説明文 | 「将来CloudKit実装予定/デモ用」が残る | 新BE導入時に正しい説明へ |

---

## バックエンド比較

要件: iOS + Android 両対応 / 友達グラフ(申請・承認・解除)/ 公開プロフィール検索(friend code・username)/ 応援(cheer)/ できれば push 通知 / プライバシー最優先・opt-in。

| 観点 | Firebase (Firestore + Auth + FCM) | Supabase (Postgres + Auth + Realtime) | 自前API (例: Cloudflare Workers + D1) |
|---|---|---|---|
| iOS/Android SDK | ◎ 両方ファースト級 | ○ supabase-swift / supabase-kt(やや新しめ) | △ 自作(REST を両OSから叩く) |
| 友達グラフのモデリング | △ NoSQL でグラフは手作り | ◎ リレーショナル(JOIN・制約)が自然 | ○ 自由(=全部自作) |
| 認証 | ◎ 匿名 / Apple / Google 一通り | ◎ Apple / Google OAuth・匿名 | △ 自作 |
| Push 通知 | ◎ FCM が iOS/Android 両対応(v1.1の友達pushを一発で解決) | △ 別途 FCM/APNs 連携が必要 | △ 自作 |
| プライバシー / 主権 | △ Google にデータ・ロックイン強 | ◎ OSS・セルフホスト可・EUリージョン選択可 | ◎ 完全自前 |
| 無料枠 / コスト | ○ 寛大だが読み取り課金が伸びやすい | ○ 無料枠あり(無活動でpause)・定額が読みやすい | ◎ 小規模は最安・運用は自分持ち |
| 実装/運用負荷 | ◎ 最小 | ○ 小〜中 | ✗ 大(認証・push・スケール・セキュリティ全部) |
| ベンダーロックイン | 強 | 中(OSS・移行容易) | 無 |

### 推奨

2案に絞る:

- **Supabase 推奨(本命)**: 友達グラフは**リレーショナルが圧倒的に素直**(`friendships`/`friend_requests` を制約・RLS で堅く守れる)。**OSS・セルフホスト可・EUリージョン**は本プロジェクトの**プライバシー最優先方針**と相性が良い。弱点の push は FCM/APNs を後付け(友達 push は v1.1 想定なので初期は無くても可)。
- **Firebase 対抗**: とにかく**最短**で両OS対応 + **FCM で push まで一気通貫**。NoSQL の友達グラフ手組みと Google 依存・読み取り課金が許容できるなら最速。

> 自前APIは、認証・push・スケール・セキュリティを全部背負うため**個人開発では非推奨**(将来トラフィックが読めてから検討)。

**結論の出し方**: 「プライバシー主権・関係モデルの素直さ」を取るなら **Supabase**、「初速と push 一体」を取るなら **Firebase**。次のアクションでどちらかを確定 → スキーマ/RLS と `<BE>FriendsService` の実装に入る。

---

## 移行設計 (`FriendsService` プロトコルの裏側を差し替え)

### アイデンティティ / 認証

現UXは「ログイン不要・friend code でつながる」。これを維持しつつ Android と共有するには:

- **方式A(低摩擦・推奨初期)**: 端末生成の安定 `userId`(UUID, Keychain 永続)+ **サーバ採番の friend code**。アカウント登録なしで両OS共通の名前空間。複数端末同期は将来 Sign in with Apple / Google でリンク。
- **方式B(アカウント制)**: 最初から Sign in with Apple + Google Sign-In。多端末・復元に強いが摩擦増。

→ 初期は **方式A**、必要に応じて B へ昇格できる設計にする。

### データモデル(Supabase 例 / Postgres)

- `profiles(user_id pk, friend_code unique, username unique-ish, display_name, current_streak, total_achieved_days, today_*..., decoration_tier, cat_breed, weekly_*..., updated_at)` — **体重・体調は持たない**。
- `friend_requests(id, from_user, to_user, status[pending/accepted/declined], created_at)`。
- `friendships(user_a, user_b, status[active/removed/blocked], created_at)` — **双方向を1行**で表現(CloudKit の片側エッジ問題を解消)。
- `cheers(id, from_user, to_user, kind, created_at)` — RLS で friendship 必須。
- **RLS**: 自分の行のみ書込可、プロフィールは friend code/username 検索のため限定的に読み取り可。

### クライアント実装

- 新規 `SupabaseFriendsService: FriendsService`(または `FirebaseFriendsService`)を追加。`MockFriendsService` はテスト用に残す。
- 既存 UI(`FriendsView`/`FriendAddView`/`FriendDetailView`/`FriendsStore`)は**ほぼそのまま**。同時にバックエンド非依存の改善(エラーバナー・ローディング・旧説明文)を入れる。
- Android はKotlinでKMPまたは個別実装。**同一スキーマ・同一 friend code 名前空間**で相互運用。

### Push(友達申請・cheer 通知, v1.1+)

- Firebase: FCM で iOS/Android 一括。
- Supabase: DB トリガ → Edge Function → FCM(Android)/APNs(iOS)。

### プライバシーラベル影響

- 友達を実際に出す版では **App Privacy が「収集なし」→「User Content / Identifiers を収集(App機能・トラッキングなし)」に変わる**。`submission/app_store_metadata.md`(友達版コピー)とプライバシーポリシー第2章を解禁時に有効化。opt-in 設計は維持。

---

## フェーズ計画

1. **現在**: 友達は v1 非表示で出荷(審査提出済み)。Release リーク(通知/オンボのコピー)修正済み。CloudKit 固有バグは**深追いしない**。
2. **BE 確定**: Supabase か Firebase を決定 → スキーマ/RLS(or security rules)+ 認証方式A 設計。
3. **iOS 実装**: `<BE>FriendsService` を実装し `FriendsService` に差し替え。UI のエラー/ローディング/コピーも同時改善。実機2台(iOS同士でよい)で疎通。
4. **解禁**: `friendsEnabled` を true、App Privacy ラベル更新、iOS 友達リリース。
5. **Android**: 同一BEで Kotlin 実装、friend code 名前空間共有で Apple↔Android 相互フレンド。

---

## CloudKit 実装の扱い

- `CloudKitFriendsService.swift` は **参考実装として一旦残す**(フロー設計の生きた仕様)。新BE実装が固まったら削除 or `#if` で除外。
- 監査で出た CloudKit 固有の修正(friend code 握りつぶし・片側エッジ・N+1・ページング・Console の権限/インデックス)は **対応しない**(置き換えで不要)。本判断を記録し、将来「なぜ直さなかったか」を明確化。
