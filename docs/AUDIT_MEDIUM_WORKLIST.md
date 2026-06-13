# MEDIUM 所見 worklist (2026-06-14) — 140件

HIGH 24/24完了後の残り。影響カテゴリ別。各=domain | title。詳細は docs/AUDIT_FINDINGS_2026-06-13.md。


## 1_correctness/データ (6件)

- [ ] **account** | Android 連携失敗時にセッションを巻き戻さず、半端な切替状態が残りうる
- [ ] **account** | 友達タブ初回表示 (ensureUid / 匿名lazy生成) (mismatch)
- [ ] **account** | parity: ensureUID: transient障害 vs 無セッションの区別
- [ ] **cheers** | 受信応援トーストの単体/結合テストが両OSとも皆無(watermark前進含む)
- [ ] **paywall** | parity: 猫種変更のプレミアム gate
- [ ] **referrals** | Android の星バッジ/今月フリーズ表示が口座一致チェックを経ず raw summary を直読み

## 2_課金 (10件)

- [ ] **onboarding** | Androidオンボ補足文が「あとから設定でいつでも変更できます」と表示し、有料ゲートを誤誘導
- [ ] **onboarding** | parity: 設定からの猫種変更でロック判定(非プレミアムは現猫種以外ロック・paywall)
- [ ] **paywall** | Android: trialOffer が eligibility 無視で無料 offer を常時優先選択
- [ ] **paywall** | Android ペイウォール「14日間無料」表示(ヘッダー/CTA/開示) (mismatch)
- [ ] **paywall** | Android 設定>猫種ピッカー(11種タップ) (mismatch)
- [ ] **paywall** | parity: トライアル eligibility による「14日間無料」出し分け
- [ ] **paywall** | parity: 紹介⭐10での全種解放(referralUnlocked)
- [ ] **referrals** | 猫種ピッカーの各猫タップ (設定 CatBreedPicker / UserCatPickerView) (mismatch)
- [ ] **referrals** | ⭐10到達の猫種解放お祝いポップ (dead-control)
- [ ] **referrals** | parity: ⭐10→猫種解放(報酬の核)

## 3_privacy/削除 (21件)

- [ ] **account** | Android signOut が匿名ユーザーのサーバ行を削除しない(iOSの『忘れる』セマンティクス欠落)→ 孤児プロフィール/友達行が残存
- [ ] **account** | アンチresurrection中核(ensureUID transient分岐 / deleteAccount EF fail-closed / signOut匿名削除)に両OSでユニットテストが無い
- [ ] **account** | サインアウトボタン (friends-signout / 「サインアウト」) (mismatch)
- [ ] **account** | parity: signOut の匿名データ削除(『忘れる』)
- [ ] **cheers** | Android 送信完了トーストが入力した一言を反映しない
- [ ] **cheers** | Android に友達詳細画面が無く、応援UXの操作モデルが iOS と反転
- [ ] **cheers** | 友達アバター/カードのタップ (mismatch)
- [ ] **cheers** | 送信完了トースト (mismatch)
- [ ] **cheers** | parity: 送信経路(detail vs picker)とプリセットの意味
- [ ] **cheers** | parity: 送信完了トーストの内容
- [ ] **cycle** | parity: 生理日記録の opt-in(プライバシー ON/OFF)
- [ ] **friends** | parity: 招待共有テキストの内容
- [ ] **settings** | Android: 全記録削除後にホーム画面ウィジェットが古い連続日数/今日達成を表示し続ける
- [ ] **settings** | Android: 設定が情報・サポート/記録と共有/自動休養説明を欠き、規約・プライバシー・サブスク管理への導線が設定に無い
- [ ] **settings** | parity: 認証/バックアップUIの設定集約(友達タブから撤去)
- [ ] **settings** | parity: 全削除後のウィジェット/Live Activity 即リフレッシュ
- [ ] **settings** | parity: 設定の情報構成(下層ページへの逃がし)
- [ ] **share** | parity: 見出し=称号バッジ(期間表現の廃止)
- [ ] **分析opt-out** | iOS: analytics opt-out のgate/teardownに回帰テストが無い
- [ ] **分析opt-out** | 設定「利用状況の分析を共有」トグル → OFF (Android) (mismatch)
- [ ] **分析opt-out** | parity: opt-out時のSDK teardown(セッション中の残留送信停止)

## 4_審査/コンプラ (5件)

- [ ] **backup** | Android 設定に復元キー(Apple/Google)ボタンが無く、機種変更の命綱が1遷移遠い
- [ ] **friends** | 友達追加シートの『QRを読み取る』導線 (Android) (mismatch)
- [ ] **paywall** | intro/trial eligibility 出し分けの自動テストが iOS/Android とも皆無
- [ ] **recording** | Android 記録フローに体重・生理日の同時入力導線が無い
- [ ] **recording** | parity: 体重・生理日の同時記録

## 5_UX/パリティ (97件)

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

- [ ] **friends** | Android の orderedPair が UUID を正規化せず、friendships_check 回帰の防御層が欠落