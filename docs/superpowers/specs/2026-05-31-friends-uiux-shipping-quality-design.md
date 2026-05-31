# 設計: 友達 UI/UX 出荷品質向上 (スコープC)

最終更新: 2026-05-31

## 背景・狙い
友達バックエンドは Supabase へ移行・疎通検証済み(front UIテスト5/5、back REST全合格、iOS実コード書込成功)。本設計は **3LLM監査で判明したフロントの課題を全て潰し、解禁前の出荷品質に上げる**(+空状態/サインアウト文言の磨き込み)。見た目の世界観(猫キャラ・peach系)は維持。バックエンド非依存で、Supabase/将来のAndroidにも共通。

非対象: バックエンド変更、`friendsEnabled` の解禁(別タスク)、QRアプリ内スキャナ(標準カメラ運用とする)。

## 対象課題(監査由来)
1. `FriendsStore.lastError` をUIが表示しない → ネット断/失敗が無言の空表示になる (High)
2. ローディング状態なし → 初回に「友達がいません」がチラつく (Medium)
3. サインアウト文言が旧仕様(「将来CloudKitで実装予定/デモ用」)= 解禁時に虚偽 (High)
4. `refresh()` 二重実行ガードなし → 並行実行で結果上書きの可能性 (Medium)
5. クイックチア連打で多重送信 (Low)
6. QRは生成のみ・読み取り手段なし → 「QRで追加できる」誤解 (High)

## ① 状態層 — `FriendsStore` (`Services/FriendsService.swift`)
- 追加: `private(set) var isLoading = false`(初回ロード)/ `private var isRefreshing = false`(再入ガード)/ `private(set) var cheeringCodes: Set<String> = []`
- `refresh()`:
  - `guard !isRefreshing else { return }` で再入防止。`isRefreshing` を defer で false 復帰
  - 初回(friends空)のみ `isLoading=true`、完了で false
  - 成功で `lastError=nil`、throw で `lastError=error.localizedDescription`(既存挙動維持)
- 追加: `func clearError() { lastError = nil }` / `func retry() async { await refresh() }`
- `cheer(_:to:)`: 送信中 `cheeringCodes` に friendCode を入れ、defer で除去(UI のガードに使う)

## ② 表示層 — `FriendsView` (`Views/FriendsView.swift`)
- **エラーバナー**(新規・再利用可能な小subview): signedIn/signedOut 両bodyの上部。`lastError != nil` のとき表示。peach系カード+`exclamationmark.triangle`(赤警告にしない=世界観維持)、本文=`lastError`、「再試行」(→`retry()`)+「閉じる」(→`clearError()`)。アクセシビリティ識別子付与
- **ローディング**: `isLoading && friends.isEmpty && requests.isEmpty && lastError == nil` のとき、空状態の代わりに `ProgressView`(猫トーンの軽い文言可)。チラつき解消
- **空状態磨き込み**: 既存 `EmptyStateView` の文言を猫トーンに更新(技術用語なし・絵文字は使わず記号/文)
- **サインアウト文言刷新**: 旧「将来CloudKit…/デモ用」を撤去 → 正確で温かいコピー(iCloud等の技術語なし)
- **cheer連打ガード**: クイックチアボタンを `friendsStore.cheeringCodes.contains(friendCode)` で `disabled`。FriendDetailView の既存ガードと整合

## ③ QR ディープリンク化(スキャナ不要・標準カメラ運用)
- QR encode 内容: `profile.friendCode` → `goexercise://friends?code=<friendCode>`(`FriendsView.qrImage` 呼び出し箇所を変更)
- `DeepLinkRouter` (`Services/DeepLinkRouter.swift`):
  - `route(from:)` を拡張し、`URLComponents` で `code` クエリを抽出
  - 既存 `pendingRoute: AppRoute?` に加え `pendingFriendCode: String?` を追加。`code` があれば保持
  - host 解釈は従来通り(`friends` → `.friends`)
- 受け側(`GOExerciseApp`): `onOpenURL`/`pendingRoute` 転送時に `pendingFriendCode` も `RouteState` 経由で渡す(`RouteState.pendingFriendCode` を追加)
- `FriendsView`: 表示時に `pendingFriendCode` があり、かつサインイン済みなら **FriendAddView をコード入力済みで自動 present**。サインアウト中はサインイン誘導→完了後に継続。コード消費後は nil クリア
- `FriendAddView`: `initialCode: String?` を受け、コード欄プリフィル
- **v1ゲート厳守**: `friendsEnabled=false` のとき `AppFeatureFlags.resolvedRoute` が `.friends`→`.home` に振替。`pendingFriendCode` も無視(FriendsView に到達しないため自然に未消費)。リークなし

## ④ エラーハンドリング/エッジ
- refresh/accept/cheer/search の失敗 → `lastError` → バナー表示+再試行
- `backendUnavailable`(Supabase未設定/ネット断)→ バナー
- ディープリンクの code が自分 → 既存 `cannotAddSelf` メッセージ
- ディープリンク中にサインアウト → サインイン後に code を消費して追加画面へ
- 二重 present 防止: code 消費は1回(消したら nil)

## ⑤ テスト
- Unit (`FriendsStoreTests`): refresh 再入ガード(同時2回呼び→裏の service は1回)/ `isLoading` 遷移 / throw時 `lastError` セット・成功で nil / cheer中 `cheeringCodes` に入る
- Unit (`DeepLinkRouterTests` 追加 or 既存に追記): `goexercise://friends?code=ABC123` → route `.friends` + pendingFriendCode `ABC123` / code無しは nil / `friendsEnabled=false` で `.home` 振替
- UI (`FriendsFlowUITests` 維持+追記可): 失敗Mock注入でエラーバナー表示・再試行ボタン存在。既存5本は維持
- 既存の友達ユニット(`FriendCodeValidatorTests`/`FriendSharingTests`/`WeeklyRankingCalculatorTests`/`AppFeatureFlagsTests`)を壊さない

## 影響ファイル(想定)
`Services/FriendsService.swift`(Store)/ `Services/DeepLinkRouter.swift` / `App/GOExerciseApp.swift`(RouteState 連携)/ `Views/FriendsView.swift` / `Views/FriendAddView.swift` / 必要なら `Views/Components`(エラーバナー)/ テスト各種。

## 完了基準
- 監査課題1〜6が解消(エラー表示・ローディング・文言・refresh再入・cheer連打・QR読み取り経路)
- v1非表示リークが無いこと(`friendsEnabled=false` で友達露出ゼロ)を維持
- 全テスト green・ビルド成功
