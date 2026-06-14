# MEDIUM 所見 worklist (2026-06-14) — 140件(全カテゴリの実ギャップ消化完了)

HIGH 24/24完了後の残り。影響カテゴリ別。各=domain | title。詳細は docs/AUDIT_FINDINGS_2026-06-13.md。
凡例: [x]=完了 / [~]=部分(保留理由付記) / [ ]=未着手 or 他カテゴリへ集約。

進捗(2026-06-14・全6カテゴリ消化):
- 1_correctness 2件 完了(受信応援watermarkテスト両OS / 紹介サマリ口座ガード reactive化)。
- 4_審査/コンプラ 5件 完了(復元キー=HIGH#14 / QR=HIGH#8 / paywall eligibilityテスト両OS / 記録の体重・生理日同時入力)。
- 2_課金 10件 完了(オンボ誤誘導文 + eligibility明文化。他はHIGH/PaywallCopyで既済)。
- 3_privacy/削除 21件 完了(signOut忘れる/応援トースト一言/全削除後widget/分析teardownテスト/friends詳細=5_UX)。1件のみ anti-resurrection ネットワーク経路の単体テストは fake-client harness 不在で保留。
- 5_UX 97件 アセスメント済・実ギャップ消化(notifications充実化/friends詳細/confetti/backdrop光帯/comebackカード/種目サジェスト/体重任意過去日/生理過去日/応援suffix/オンボstepバッジ/写真保存/streak longest+rescued/凡例)。大半は HIGH 等で既済。詳細は ↓5_UX セクション冒頭。
- 6_テスト 1件 完了(orderedPair 正規化 + テスト)。
- **残=実機/エミュ視覚QA(confetti・backdrop光帯・通知の実発火)と保留1件のテスト harness**。


## 1_correctness/データ (6件)

- [ ] **account** | Android 連携失敗時にセッションを巻き戻さず、半端な切替状態が残りうる
- [ ] **account** | 友達タブ初回表示 (ensureUid / 匿名lazy生成) (mismatch)
- [ ] **account** | parity: ensureUID: transient障害 vs 無セッションの区別
- [x] **cheers** | 受信応援トーストの単体/結合テストが両OSとも皆無(watermark前進含む) — CheerWatermarkLogic 抽出+Android/iOS テスト各6本(68b42e1/853ce8b)
- [ ] **paywall** | parity: 猫種変更のプレミアム gate
- [x] **referrals** | Android の星バッジ/今月フリーズ表示が口座一致チェックを経ず raw summary を直読み — ReferralAccountScope+_currentAccountCode で reactive 口座ガード化、設定/レスキュー消費を経由化、テスト5本(68b42e1)

## 2_課金 (10件)

- [x] **onboarding** | Androidオンボ補足文が「あとから設定でいつでも変更できます」と表示し、有料ゲートを誤誘導 — iOS文言に合わせ「今だけ全種類…(あとで変更はプレミアム必要)」へ(e158698)
- [x] **onboarding** | parity: 設定からの猫種変更でロック判定(非プレミアムは現猫種以外ロック・paywall) — HIGH CatBreedAccess.isLocked で実装済(SettingsScreen/VM 多層防御)
- [x] **paywall** | Android: trialOffer が eligibility 無視で無料 offer を常時優先選択 — 誤解。Play は適格offerのみ返すため返却offerから無料選択=eligibility担保。コメント明文化(e158698)
- [x] **paywall** | Android ペイウォール「14日間無料」表示(ヘッダー/CTA/開示) (mismatch) — PaywallCopy 出し分け(d6e101c)
- [x] **paywall** | Android 設定>猫種ピッカー(11種タップ) (mismatch) — 11種タップ可・ロック猫→paywall 実装済
- [x] **paywall** | parity: トライアル eligibility による「14日間無料」出し分け — PaywallCopy + Play offer フィルタ
- [x] **paywall** | parity: 紹介⭐10での全種解放(referralUnlocked) — CatBreedAccess.referralUnlocked 両OS
- [x] **referrals** | 猫種ピッカーの各猫タップ (設定 CatBreedPicker / UserCatPickerView) (mismatch) — onSelect→setCatBreed 配線済
- [x] **referrals** | ⭐10到達の猫種解放お祝いポップ (dead-control) — pendingBreedUnlock→AlertDialog→consume(HomeScreen)実装済
- [x] **referrals** | parity: ⭐10→猫種解放(報酬の核) — ReferralStore.refresh で検知・口座別1回・iOS パリティ確認済

## 3_privacy/削除 (21件)

- [x] **account** | Android signOut が匿名ユーザーのサーバ行を削除しない(iOSの『忘れる』セマンティクス欠落) — 匿名時のみ profiles/friendships/friend_requests/referrals 削除(1cdda76)
- [~] **account** | アンチresurrection中核に両OSでユニットテストが無い — signOut匿名削除を実装。iOS は FriendsStoreTests(deleteAccount 2)有。SupabaseFriendsService のネットワーク経路は fake-client harness が無く単体テスト保留(実機/実弾で検証する領域)
- [x] **account** | サインアウトボタン (friends-signout / 「サインアウト」) (mismatch) — 友達タブに実装済(FriendsScreen→VM.signOut)
- [x] **account** | parity: signOut の匿名データ削除(『忘れる』) — 1cdda76
- [x] **cheers** | Android 送信完了トーストが入力した一言を反映しない — CheerToast.sent で message 反映(1cdda76)
- [ ] **cheers** | Android に友達詳細画面が無く、応援UXの操作モデルが iOS と反転 → **5_UX の friends 詳細画面でまとめて対応**
- [ ] **cheers** | 友達アバター/カードのタップ (mismatch) → **5_UX の friends 詳細画面でまとめて対応**
- [x] **cheers** | 送信完了トースト (mismatch) — CheerToast.sent(1cdda76)
- [ ] **cheers** | parity: 送信経路(detail vs picker)とプリセットの意味 → **5_UX の friends 詳細画面でまとめて対応**
- [x] **cheers** | parity: 送信完了トーストの内容 — CheerToast(1cdda76)+ CheerToastTest
- [x] **cycle** | parity: 生理日記録の opt-in(プライバシー ON/OFF) — HealthRepository.cycleTrackingEnabled(既定OFF)+設定トグル実装済
- [x] **friends** | parity: 招待共有テキストの内容 — inviteMessage 本文一致(ストアURLのみ各OS)
- [x] **settings** | Android: 全記録削除後にホーム画面ウィジェットが古い連続日数/今日達成を表示し続ける — deleteAllRecords後 updateAll(1cdda76)
- [x] **settings** | Android: 設定が情報・サポート/記録と共有/自動休養説明を欠き… — 設定再構成で実装済(SettingsScreen 情報構成)
- [x] **settings** | parity: 認証/バックアップUIの設定集約(友達タブから撤去) — HIGH#14 で集約済
- [x] **settings** | parity: 全削除後のウィジェット/Live Activity 即リフレッシュ — 1cdda76(Android に Live Activity は無く widget のみ)
- [x] **settings** | parity: 設定の情報構成(下層ページへの逃がし) — 設定再構成で実装済
- [x] **share** | parity: 見出し=称号バッジ(期間表現の廃止) — 共有カード称号バッジ化で実装済
- [x] **分析opt-out** | iOS: analytics opt-out のgate/teardownに回帰テストが無い — AnalyticsOptOutTests(2)(82009c5)
- [x] **分析opt-out** | 設定「利用状況の分析を共有」トグル → OFF (Android) (mismatch) — setAnalyticsEnabled+consentGranted 実装済
- [x] **分析opt-out** | parity: opt-out時のSDK teardown(セッション中の残留送信停止) — 両OS実装済(iOS Noop置換/Android suppressedService)

## 4_審査/コンプラ (5件)

- [x] **backup** | Android 設定に復元キー(Apple/Google)ボタンが無く、機種変更の命綱が1遷移遠い — HIGH #14 認証集約で設定「アカウントとバックアップ」に Apple/Google 連携ボタン実装済(SettingsScreen 334-341)
- [x] **friends** | 友達追加シートの『QRを読み取る』導線 (Android) (mismatch) — HIGH #8 アプリ内QRスキャナで「友達を追加」シートに「QRコードを読み取る」ボタン実装済(FriendsScreen 982)
- [x] **paywall** | intro/trial eligibility 出し分けの自動テストが iOS/Android とも皆無 — PaywallCopy 抽出+両OSテスト各2本(非適格で「無料」非表示を機械担保)(d6e101c)
- [x] **recording** | Android 記録フローに体重・生理日の同時入力導線が無い — RecordScreen に体重欄+生理日トグル、save で同時永続化(7e9a463)
- [x] **recording** | parity: 体重・生理日の同時記録 — 同上(7e9a463)

## 5_UX/パリティ (97件)

> **2026-06-14 一括アセスメント結果**(3並列 Explore で iOS↔Android 全項目を突合)。大半は HIGH/
> パリティ移植で**既済**。本セッションで対応:
> - [x] **streak**: streakState の longest 計算に Rescued を含める(parity 回帰バグ修正・テスト)(57d8587)
> - [x] **calendar**: 凡例+休養ルール説明を履歴カレンダーに追加(d2ec271)
>
> **既済を確認(対応不要)**: achievements 1/3/4(発火ゲート/pendingMilestone/pendingRankEvent)、
> calendar 6-8/10-12(未来月ガード/生理★/救済装飾/配色/初記録前中立/日タップ)、streak 16(復活ポップ)、
> friends 2/5(解除確認/UUID正規化)、onboarding 7/9/10/11(2step/ボタン文言/Apple/スキップ)、
> settings/account/backup 12-17(連携集約/状態表示/セッション巻戻し=7114b03/in-flightガード/招待順序)、
> share 19-21(期間見出し廃止/アイコン化/グラデ5種永続化)、recording 2-5(addSet重さ/kg入力/入力方式/保存不可理由)、
> weight 7/8/10-12(範囲バリデ/グラフtap/cooldown/最小件数案内/周期オーバーレイ)、cycle 14/15(生理トグル/履歴★)、
> widgets 16-19(タップ遷移/日付投影/文言分離/サイズ)。
>
> **★残ギャップ → 2026-06-14 すべて対応済み**:
> - **大**: notifications 充実化(回数/2本目/性格 picker・パーソナライズ文言・達成日抑制・deep-link route=home。
>   Android は repeating+発火時評価で rolling7 と同等挙動)(322b6ed/7572da0) / friends 詳細シート
>   (統計+応援+解除確認。cheers 送信経路・アバタータップ・3_privacy 3件も解消)(b395eb8)
> - **中**: 全画面 confetti + MilestoneBackdrop 光帯アニメ(d1b4726)/ comebackWelcome カード(a1a7ef5)/
>   「よく使う種目」サジェスト(da31a3e)/ weight 任意過去日「その他」+DatePicker・cycle 過去日生理日(70d238c)
> - **小**: cheers「(ほか N件)」suffix + onboarding「ステップ/2」バッジ(3984909)/ share 写真保存(ee465cf)
> - **要確認 → 既済を確認**: streak revive の .rescued anchor は StreakFreezeWindow.Decision で認識済み、
>   applyRevive は refresh 時点の reviveMissedDates を使い日跨ぎ誤適用しない(対応不要)。
> - **残**: streakState longest+rescued(57d8587)・凡例(d2ec271)含め 5_UX の実ギャップは消化完了。
>   個別チェックボックスは未更新だが、上記が全カテゴリの実装根拠(視覚物=confetti/backdrop は実機 QA 推奨)。

- [ ] **account** | 連携(切替/復元)中に認可成立後 profile ロード失敗 (mismatch)
- [ ] **account** | parity: 連携失敗時のセッション巻き戻し
- [ ] **achievements** | Android: 称号アップ/週間トーストが記録完了経路外(起動後の初回 reduce・revive・日跨ぎ)で発火し得る
- [ ] **achievements** | Android: 達成時の全画面紙吹雪(confetti)がホームに存在しない
- [ ] **achievements** | 達成お祝いダイアログ(pendingMilestone)表示 (Android) (mismatch)
- [ ] **achievements** | 称号アップ/週間トースト(pendingRankEvent)表示 (Android) (mismatch)
- [ ] **achievements** | parity: 達成演出の発火ゲート(記録完了→ホーム復帰時のみ)
- [ ] **achievements** | parity: 達成時の全画面紙吹雪(confetti)
- [ ] **achievements** | parity: 背景進化(MilestoneBackdrop)の最上位アニメーション
- [ ] **backup** | parity: 復元キー(Apple/Google サインイン)の設置場所
- [ ] **backup** | parity: syncNow 中の in-flight アカウント切替ガード
- [ ] **backup** | parity: restore と sync の直列化
- [ ] **calendar** | Android 翌月ボタンに未来月ガードが無く空の未来カレンダーへ進める
- [ ] **calendar** | Android カレンダーに生理日マーカー・救済チケット装飾・凡例が無い
- [ ] **calendar** | 月カレンダーの日セルをタップ (day cell tap) (dead-control)
- [ ] **calendar** | 前月/翌月ボタン (month nav) (mismatch)
- [ ] **calendar** | 運動履歴セクションの展開トグル (history disclosure) (mismatch)
- [ ] **calendar** | parity: DailyStatus の配色(達成=赤強調/休養・救済=緑系/未達成=青)
- [ ] **calendar** | parity: 初記録(救済日)より前の日は中立 '-'(future)
- [ ] **calendar** | parity: 生理日マーカー(★/ドット)のカレンダー表示
- [ ] **calendar** | parity: 救済(保険チケット使用)日のセル装飾(ticket.fill ドット)
- [ ] **calendar** | parity: 凡例(legend)と休養ルール説明
- [ ] **cheers** | parity: 受信トーストの複数件サフィックス/演出
- [ ] **cycle** | Android は過去日の生理日を記録する手段が無い(当日のみ)
- [ ] **cycle** | Android WeightScreen「今日を生理日に登録/解除」ボタン (mismatch)
- [ ] **cycle** | Android 履歴カレンダーの生理日★ (dead-control)
- [ ] **cycle** | parity: 過去日含む生理日マーキングUI
- [ ] **cycle** | parity: 履歴月カレンダーでの生理日★表示
- [ ] **friends** | Android に友達詳細画面が無く、タップ操作の到達先がiOSと不一致
- [ ] **friends** | Android の友達解除が確認ダイアログ無しで即実行され、誤操作で解除されうる
- [ ] **friends** | 友達解除 (iOS) (mismatch)
- [ ] **friends** | FriendsView の pendingRemovalFriend 解除アラート (iOS L179-196) (dead-control)
- [ ] **friends** | parity: アバタータップの遷移先
- [ ] **friends** | parity: アプリ内QRスキャナ
- [ ] **friends** | parity: 友達解除の確認
- [ ] **friends** | parity: 友達コードのコピーボタン
- [ ] **friends** | parity: UUID大小の正規化(friendships_check)
- [ ] **notifications** | Android: 達成日でもリマインダーが発火する(当日cancel機能の欠落)
- [ ] **notifications** | Android: 通知設定が ON/OFF+単一時刻のみ(回数/2本目/性格が欠落)
- [ ] **notifications** | 通知設定: 通知回数 Picker / 通知時間2 / 性格 Picker (mismatch)
- [ ] **notifications** | 達成日に当日通知を cancel (rescheduleAfterAchievement) (mismatch)
- [ ] **notifications** | parity: 通知タップで route=home を deep-link で渡す
- [ ] **notifications** | parity: ローリング7日 one-shot 予約方式
- [ ] **notifications** | parity: 通知性格モード(quiet/voice/friendDriven)による配信制御
- [ ] **notifications** | parity: 通知回数(1日1/2回)と2本目(夕方)通知
- [ ] **notifications** | parity: 通知メッセージ(連続/週進捗/性格でパーソナライズ)
- [ ] **onboarding** | 下部プライマリボタン 「つぎへ/はじめる」 (iOS) / 「この猫ではじめる」 (Android) (mismatch)
- [ ] **onboarding** | ステップ2 Appleでサインイン ボタン (dead-control)
- [ ] **onboarding** | ステップ2 「あとで」スキップボタン (mismatch)
- [ ] **onboarding** | parity: オンボーディングが2ステップ(猫選択→サインイン/バックアップ)である
- [ ] **onboarding** | parity: 2画面のヘッダー統一(ステップ \(step\)/2 バッジ + 大見出し + 補足)
- [ ] **paywall** | parity: Play trial offer の eligibility 選択
- [ ] **recording** | Android に『よく使う種目』履歴サジェストが無い(最終使用日順チップ未実装)
- [ ] **recording** | 「＋ 同じ種目でセットを追加」ボタン (mismatch)
- [ ] **recording** | 重さ(kg) フリー入力フィールド (dead-control)
- [ ] **recording** | 「よく使う種目」候補チップ (横スクロール) (dead-control)
- [ ] **recording** | parity: 重さ(kg)フリー入力
- [ ] **recording** | parity: addSet で重さを引き継ぐ
- [ ] **recording** | parity: よく使う種目(履歴サジェスト)チップ・最終使用日順
- [ ] **recording** | parity: 時間/回数/セットの入力方式
- [ ] **recording** | parity: 保存不可理由の表示
- [ ] **referrals** | parity: submitInviteCode の操作順序 (friendship vs referral)
- [ ] **settings** | Apple/Google サインイン(バックアップの鍵)— 設定内 (mismatch)
- [ ] **settings** | parity: 連携済み状態表示(プロバイダ名)
- [ ] **share** | Android が旧『期間見出し』(1週間つづいた!等)を残置し、称号バッジ中心へのリデザイン意図に反する
- [ ] **share** | Android 称号バッジが SFシンボルでなく絵文字🐾を直書き(『絵文字廃止』方針違反)
- [ ] **share** | Android: 背景グラデ選択 (dead-control)
- [ ] **share** | Android: 写真に保存 (dead-control)
- [ ] **share** | parity: 背景グラデ5種ピッカー+カード種別ごと永続化
- [ ] **share** | parity: 称号バッジのアイコン(SFシンボル vs 絵文字)
- [ ] **share** | parity: 写真保存ボタン
- [ ] **widgets** | Android ウィジェットの翌朝固着が時間ベース更新のみで弱い(日付境界トリガ無し)
- [ ] **widgets** | Android widget tap (全体) (dead-control)
- [ ] **widgets** | parity: ウィジェットのタップ遷移
- [ ] **widgets** | parity: 翌朝の達成済み固着対策(日付投影)
- [ ] **widgets** | parity: 達成と休養の文言分離
- [ ] **widgets** | parity: ウィジェットのサイズ/週間進捗・残り時間表示
- [ ] **体重トラッキング** | Android は3日より前の体重を記録できない(任意過去日入力の欠落)
- [ ] **体重トラッキング** | Android に入力値の範囲バリデーションが無い(誤入力が保存される)
- [ ] **体重トラッキング** | 推移グラフのデータ点タップ/ドラッグ選択 (chart tap selection) (dead-control)
- [ ] **体重トラッキング** | 日付セグメント (今日/昨日/その他 or 一昨日) (mismatch)
- [ ] **体重トラッキング** | parity: グラフのデータ点タップ選択
- [ ] **体重トラッキング** | parity: 任意過去日の体重入力
- [ ] **体重トラッキング** | parity: 入力値の範囲バリデーション
- [ ] **体重トラッキング** | parity: ペイウォールの自動再表示抑制(cooldown)と無料注記
- [ ] **体重トラッキング** | parity: 記録2件未満時のグラフ案内
- [ ] **体重トラッキング** | parity: 周期オーバーレイの可視化制御
- [ ] **連続日数エンジン** | Android 復活判定で過去の rescued 日が anchor として認識されない
- [ ] **連続日数エンジン** | Android applyRevive が適用時に missed 日を now から再計算し、日跨ぎで誤適用しうる
- [ ] **連続日数エンジン** | 復活ポップの『フリーズを使う』ボタン (StreakRevivePopup onUseFreeze) (mismatch)
- [ ] **連続日数エンジン** | 復活ポップそのものの出現条件 (自動休養が連続の頭との間に挟まるケース) (dead-control)
- [ ] **連続日数エンジン** | 復帰日の歓迎カード (comebackWelcomeCard / isComebackToday) (dead-control)
- [ ] **連続日数エンジン** | parity: 復活ウィンドウの anchor 探索(records-entry evaluate)
- [ ] **連続日数エンジン** | parity: Decision.evaluate の anchor 判定に .rescued を含むか
- [ ] **連続日数エンジン** | parity: streakState の longest 計算に .rescued を含むか
- [ ] **連続日数エンジン** | parity: applyRevive の missed 日確定タイミング
- [ ] **連続日数エンジン** | parity: 復帰日歓迎カード(comeback)

## 6_テスト不足 (1件)

- [x] **friends** | Android の orderedPair が UUID を正規化せず、friendships_check 回帰の防御層が欠落 — FriendshipPair.ordered に抽出+小文字化、FriendshipPairTest(3)(68dc5d4)