# 設計: 友達 UI/UX「最高級」化 (スコープ=全6・中程度の洗練)

最終更新: 2026-05-31 / ブランチ: feature/friends-release

## 狙い
友達機能は front/back 動作・テスト・Codex 承認済みで、トンマナ(peach/cream・角丸・猫アバター・🔥連続・やさしい日本語)も踏襲できている good レベル。本設計は**トンマナを厳守しつつ premium 感**へ引き上げる中程度の洗練。大規模再設計はしない。`reduceMotion`・Dynamic Type を尊重。

## 対象と変更 (6項目)

### ① 自分ヘッダー整理 — 友達をファーストビューへ (`FriendsView.profileHeader` / `shareAppCard`)
- プロフィール card の縦余白・要素間隔を圧縮。
- 「このアプリを友達にシェア」を**大カード→スリム1行**(アイコン+1行ラベル+chevron)に。直下配置は維持し高さを削減。
- 結果: 友達グリッド/申請がファーストビューに入る。

### ② ランキング 自分ハイライト (`WeeklyRankingView`)
- ランク行リストで、自分の行に **peach 系背景 + 「あなた」バッジ**。上部サマリカードに加えリスト内でも即発見できる。
- 自分判定: `entry.friendCode == friendsStore.profile?.friendCode`(または既存の self 判定)。

### ③ チア delight (`FriendsView.sendCheer` / カード)
- 既存のトースト+触覚に加え、送信時に**絵文字が小さく「ポン」と出て上方向にフェード**するワンショット演出。
- `@Environment(\.accessibilityReduceMotion)` true 時はアニメ無効(トーストのみ)。
- 二重送信ガード(`cheeringCodes`)とは独立。

### ④ 友達カードの情報階層 (`FriendsView.friendCard`)
- **🔥連続数を主役**(より大きく・`Palette.primaryDeep`)。「今日達成」を目立つ pill、未達成は控えめ。@username はサイズ/色を一段下げる。
- 視線誘導: 名前 → 連続 → 今日の状態 の順に。

### ⑤ 空状態を温かく (`FriendsView` 友達0時 / `EmptyStateView` 利用箇所)
- テキストのみ → **待機ポーズの猫イラスト**(既存アセット。`UserCatPreferences.myCat` の待機/おねだり等)+ やさしいコピー。
- 申請も友達も0のときに表示。`isLoading` 中は出さない(既存)。

### ⑥ アバター個体差 (`FriendAvatarView`)
- `friendCode` 由来の**淡い色リング**(決定論的ハッシュ→色相)を追加し、同じ猫種が並んでも一目で区別。
- 既存の装飾ボーダー(tier)と両立。彩度・太さは控えめ(トンマナを壊さない)。
- 自分のアバターには適用しない or 適用は任意(一貫性優先で friend カード/グリッドに適用)。

## 非対象
- バックエンド・データモデル変更なし。
- 友達タブの大規模再設計(ホーム統合・公園演出刷新等)はしない。
- 新規画面の追加なし。

## テスト/検証
- 既存の友達ユニット(27)・UIテスト(5)を壊さない。
- 純粋ロジックを足す箇所(②自分判定ヘルパー、⑥色リングのハッシュ→色)は単体テスト追加。
- ビルド成功 + before/after スクショ(シミュレータ)で目視。
- Codex 改善ループで承認まで回す。

## 影響ファイル(想定)
`Views/FriendsView.swift`(ヘッダー/shareAppCard/friendCard/空状態/sendCheer)、`Views/WeeklyRankingView.swift`(自分ハイライト)、`Views/Components/FriendAvatarView.swift`(色リング)、必要なら小ヘルパー(色ハッシュ)。テスト各種。

## 完了基準
- 6項目すべて実装・トンマナ維持・`reduceMotion`/Dynamic Type 配慮。
- 全テスト green・ビルド成功・Codex 承認。
- before/after スクショで premium 化を確認。
