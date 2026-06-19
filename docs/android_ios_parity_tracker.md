# Android↔iOS 完全一致 パリティ・トラッカー（正本: iOS build 12）

> **目的**: Android の UI/UX を iOS 最新版(build 12)と**完全一致**させる。本書は repo に常駐し、
> セッションを跨いで引き継ぐ唯一の進捗正本。全ギャップを 0 にするまで更新し続ける。
> **強拘束ルールは CLAUDE.md「★最重要・強拘束: UIパリティ検証は最大厳格」を必ず参照。**
>
> ⚠️ **2026-06-18 セッション2 重大教訓**: コード照合だけで「✅完了」と報告した6画面は、実機スクショで
> 記録入力の入力欄が**高さ不揃い・色が iOS と別物**(Material OutlinedTextField 白枠 vs iOS chipBackground 塗り)だった。
> **以後、各画面は必ずエミュ実スクショ + iOS golden 拡大比較で視覚検証してから「✅」と書く**(memory [[feedback_parity_screenshot_mandatory]])。
> **スクショ検証済(エミュ go_test 実機描画で確認)**: 記録入力(入力欄を chipBackground 塗りに統一・4列高さ揃え)/
> 履歴(カレンダー・凡例カプセル・運動履歴カード・All-time使用日数・共有配置)/ 設定(トップ・情報サポート4リンク)/
> **ランキング(中央タイトル+戻る矢印・mySummaryグラデ枠・メダル不透明度/数字色・自分行2dp枠・猫fallback決定論的猫)**。
> 友達一覧も Mock 描画OK。**未検証**: 記録完了(記録作成が必要)、ホーム細部。
> ⚠️ dev は Supabase 設定済→実バックエンドで友達 sign-in が失敗。**友達/ランキングの視覚検証は local.properties の
> SUPABASE_HOST/ANON_KEY を一時空にして Mock 強制(seedDemo で友達2名)→検証後に復元**、という手順を使う(今回実施・復元済)。
> 友達詳細はまだコンパクト bottom sheet(差し替え対象)= §F の full-screen 化が最大の残作業。

## ★ 2026-06-18 セッション4: iOS golden 実比較による 2LLM 検証ループ（初の本格 golden 照合）
**重要な前進**: これまでは「Android スクショ vs iOS ソース読解」だったが、今回**初めて iOS build 12 を sim に
ビルドして golden スクショを取得**し、Android 実スクショと横並び比較した(CLAUDE.md ★7 の本来の手順)。
- **golden 取得手順**(再現用): `xcodebuild -project app/GOExercise/GOExercise.xcodeproj -scheme GOExercise -configuration Debug
  -destination 'platform=iOS Simulator,id=<booted>' -derivedDataPath /tmp/goex_dd build` → `simctl install` → CFBundleVersion=12 を PlistBuddy 確認 →
  `simctl launch ... --seed-demo-data --skip-onboarding --mock-seed-friends --no-notification-prompt --skip-milestones --no-review-prompt --initial-route <route>` → `simctl io screenshot`。
  Android は Mock(SUPABASE 空)+ sqlite で 12 日連続記録を注入して populated 状態を揃えた。
- **2LLM ループ**: Claude 並列6エージェント(home/history/settings/friends/ranking/record の視覚 diff)→ 敵対的に裏取り
  (誤検知排除)→ Codex でソース照合 → 改善 → Codex で **全 MATCH 収束**を確認。
- **誤検知だったもの**(裏取りで排除): ホーム連続バッジ「炎」(実は pawprint で一致)/ 記録入力 4列欄の「混在」(既に
  chipBackground 塗りで統一済)/ タブバー有無・閉じる vs 戻る(`--initial-route` が単独 push する deep-link 由来の表示文脈差)/
  Apple「Sign in with Apple」(sim が英語ロケールなだけ。実機 JP は公式ボタンが「Appleでサインイン」)。
- **実差分として是正(Codex MATCH 確認済・commit d864385)**: ①ランキング期間ピッカー(coral 塗り→iOS `.segmented` グレー軌道+白選択ピル)
  ②設定 Google「サインイン」→「続ける」 ③友達プロフィール名 20sp→`AppType.title`(iOS `.largeTitle`)
  ④アバター tint 0.30→0.22(iOS `FriendAvatarView`)⑤猫メッセージ「新記録おめでとう ✨」→「！」(絵文字除去+文言一致)。
- **受容済み差分**: 設定 Apple ボタン= iOS 公式 `ASAuthorizationAppleIDButton` vs Android 自作(プラットフォーム制約)。
  バックアップ説明文の文言/配置に軽微差(認証セクションは config-gated・低優先)。中核 chrome(ホーム/履歴/記録入力)は golden 一致。

## ★ 2026-06-19 セッション5: サブ画面 golden 照合(XCUITest で iOS sim 操作)
deep-link 不可・cliclick は多ディスプレイ Retina で座標不可・idb は brew 撤去 → **XCUITest(`ScreenshotCaptureUITests.testCaptureSubScreens`)**で
iOS sim を accessibility-id/座標タップしてサブ画面 golden を撮影(`--mock-open-friend-detail`/`--mock-open-friend-add`/
`--seed-scenario yearly` で周期ON→menstrual-link、座標で day-detail)。xcresult から PNG 抽出 → Android 実スクショと 2LLM 照合。
- **golden 取得**: `xcodebuild test -only-testing:GOExerciseUITests/ScreenshotCaptureUITests/testCaptureSubScreens -resultBundlePath /tmp/x.xcresult`
  → `xcrun xcresulttool export attachments --path /tmp/x.xcresult --output-path <dir>`。**`--initial-tab` を使うとタブ文脈(タブバー付き)で撮れる**(`--initial-route` の単独 push 罠を回避)。
- **誤検知排除(Codex MATCH)**: day_detail カード塗り(surface on background で一致)/ friend_detail hero アバター(Brush.linearGradient 0.50→0.15 で一致)。
- **実差分 是正(Codex 全 MATCH 収束・commit a97bf4f)**: ①友達追加=「申請を送る」を QR の上へ+見出し「友達コードで追加」+中央タイトル+閉じる追加
  ②日詳細シート=中央タイトル+閉じる追加 ③共有 `SheetCloseButton`(iOS26 ナビボタンの淡カプセル)へ統一(友達詳細/追加/日詳細。旧=素テキスト/欠落)
  ④ボトムタブバー= menstrual/rescue/ランキングは iOS が各タブ内 push でタブバーを残すため、Android も維持+親タブ選択(`AppNavHost.detailParentTab`)。実機でランキングにタブバー(友達選択)確認。

## ★ 2026-06-19 セッション17b: 共有カード 監査検証ループ（4並列 Claude 敵対監査 → ソース裏取り → 是正 → 再検証収束）
連続/Weekly/Monthly/All-time の4カードを Android 実スクショ vs iOS golden + レンダラソースで4エージェント並列に敵対監査。全エージェント+ソースで一致した**2実差を是正**:
- **[HIGH] 英字「GO Exercise」副題**: 両レンダラが「GO エクササイズ」の下に英字 mono 行を描いていたが iOS(StreakShareCard/MonthlyReviewCard)は「GO エクササイズ」1行のみ → 両レンダラから削除。
- **[MED] ハイライトの紙吹雪**: HighlightShareImageRenderer がプログラム紙吹雪を描いていたが iOS MonthlyReviewCard は猫(影)のみ(粒は猫スプライト焼込み)→ ハイライトから drawConfetti 削除(連続カードは iOS も StaticConfettiView 有のため維持)。死蔵 drawConfetti/cos/sin も除去。
- 再ビルド→実エミュ再撮影で Weekly=紙吹雪/英字副題消失・streak=紙吹雪維持/英字副題消失 を確認(収束)。
- 受容(低): streak オンスクリーンプレビューの角丸 24 vs iOS 32+影(エクスポート画像は両者フルブリードで一致)/ KPI接尾の先頭スペース(視覚同等)。
- **同 17b 追加完了**: フリーズ rescue 使用画面を iOS RescueTicketUseView へ全面改修(✅)/ 設定 連携ON 認証セクション 削除導線 reactivity 是正(✅)/ 体重 premium 折りたたみ化(✅)。
- **★ 残(全表 ✅ または下記 🔶 のみ・☐ ゼロ)**: ①ホーム overlay/dialog(referral行/revive/⭐10/節目/rankup)②milestone・breed-unlock ダイアログ — いずれも**実装は session2/3 でエミュ実スクショ検証済**、iOS golden も取得済だが、**Android 側に referral/revive/節目 のデータ注入手段が無く golden 横並び自動撮影のみ不可**。機能・コードは一致確認済。

## ★ 2026-06-19 セッション17: 残☐ 一括消化（記録/シェア/体重/日詳細/設定 golden 照合）
iOS build 12 を XCUITest で一括撮影(testCaptureRemainingStates)→ Android は **sqlite 注入で 14日連続+体重20件の populated 状態**を作り(`run-as ... sqlite3 goexercise.db`、デモseed が無い Android の populated 化手段)→ 実エミュ実スクショ照合。
- **シェアカード ✅**: 連続カードを iOS 並び順(バッジ→猫→「N 日連続」横並び→アプリ名)へ + 「○週間つづいた!」見出し撤去 / ハイライト3種に統計行アイコン🐾🕐📋⭐❤️追加 / SNSで共有 文言統一(commit 3f7a084)。
- **記録入力 ✅**: 空/複数種目(アコーディオン+削除trash)golden MATCH。体調・周期は両OS周期設定 gating。
- **体重 paywall ✅**: 👑→Material crown(コーラル)+無料フッター追加+CTA capsule(commit cbb00cf)。
- **日詳細 ✅**: 全6状態メッセージ source 完全一致・未来を実スクショ検証。
- **設定 premium ✅**(プレミアム部)。
- **体重 premium/chart ✅(追補)**: 折りたたみ化+順序入替を実装(`WeightCollapsible` 新設・記録する/レポート/推移/履歴 を iOS 順・subtitle 一致・展開でチャート描画確認)。ユニットテスト green。
- **設定 連携ON ✅(追補)**: 削除導線 reactivity を是正(refreshAccountState・Mock 検証で アカウントを削除 表示確認)。
- **残 🔶(次セッション・小/実装は既✅)**: ホーム referral/revive・節目/breed-unlock ダイアログ・rescue使用画面 の golden **横並び**のみ未(Android 側に referral/revive/節目データの注入手段が無く自動撮影が不安定。実装・コードは session2/3 で ✅・iOS golden は取得済)。設定 未連携 caption の軽微配置差(低優先)。
- **手段メモ(再現用)**: Android populated 化 = `python3 で INSERT 生成 → adb push → run-as com.goexercise.app sh -c 'cat … | sqlite3 databases/goexercise.db'`。premium 解放 = paywall「14日間無料で始める」(MockPremiumRepository が flip)。

## ★ 2026-06-19 セッション16: ランキング今月 + 友達 状態別 golden 照合（XCUITest 撮影）
iOS build 12 を sim にビルド(CFBundleVersion=12 確認)→ XCUITest で状態別 golden 撮影 → Android 実エミュ(go_test, Mock=SUPABASE空)実スクショ → 2LLM/PIL 測定で照合。
- **ランキング 今月 = ✅ MATCH**: XCUITest `testCaptureRankingStates` で iOS 今月セグメントを撮影 → Android deep-link `goexercise://weekly-ranking`→今月タップ。セグメント(今週/今月)・ルールカード文言(「今月の順位ルール」「毎月 1 日にリセットされます。」)・mySummary グラデ枠・メダル行 すべて構造一致。差はデータのみ(月次分・件数・人数)=許容。
- **友達 詳細 hero 名前 = ✅ 是正(セッション5 の golden が見逃した実差)**: iOS FriendDetailView 名前=`Typography.title`(.largeTitle 34pt) に対し Android は **22sp** だった(PIL 実測: iOS glyph 0.062×幅 vs Android 0.044×幅)。`AppType.title` に是正 → 実測 0.0685(iOS 0.0621 と一致)。エミュ実スクショで検証。
- **友達 welcome / 空状態 = 構造一致(通常到達不可)+ source 是正**: 両 OS とも友達タブ `.task`/`LaunchedEffect` が `ensureSignedIn()` で**自動匿名サインイン**するため welcome は失敗時のみ、空状態は実BE 0友達時のみ=通常フロー到達不可(iOS 同型)。iOS welcome golden で確定した差を Android source に是正: ①welcome タイトル 22sp→`AppType.title`(iOS Typography.title 34) ②welcome 猫 120→140dp ③**welcome の復元(Apple/Google で復元)セクションを撤去**(iOS friendsWelcomeBody は復元入口を持たない=設定/オンボに集約) ④空状態 猫 96→124dp+opacity0.95 ⑤空状態見出し 15→17sp(iOS Typography.headline)。到達不可状態の golden 検証は AppType.title(自分名=到達可)+ CatImage(home/welcome golden で検証済)の既検証プリミティブで担保。
- **ランキング 空状態 = 防御的コンポーネント(通常到達不可)**: `entries` はサインイン済なら必ず自分を含む→空にならない。`RankingEmptyState`/`EmptyStateView` は両 OS とも文言・構造一致のフォールバック。
- **エラーバナー / cheer picker**: エラーバナーは要エラー発火(コード source 一致確認済)。cheer picker は友達詳細内=セッション5 で ✅。

## ★★ golden 照合カバレッジ台帳（全ページ×全パターンを build 12 と厳密一致させる 残タスク・正本）
**方法(確立済・再現手順)**: ① iOS build 12 を sim にビルド→install(CFBundleVersion=12 確認)。② 直接 deep-link 可能な画面は
`simctl launch --initial-tab <tab> --initial-route <route> --seed-demo-data --skip-onboarding --mock-seed-friends --seed-scenario yearly` で起動→`simctl io screenshot`。
③ sub 画面/状態は **XCUITest `ScreenshotCaptureUITests`** に撮影メソッドを足し、`xcodebuild test -only-testing:...` →
`xcrun xcresulttool export attachments` で PNG 抽出(accessibility-id/座標タップ・多ディスプレイでも確実)。
④ Android は同データ状態(Mock 強制+sqlite 注入/launch arg)で実スクショ。⑤ **2LLM 照合**(Claude 並列視覚 diff + Codex 源照合)→
敵対的に裏取り(誤検知排除)→ 改善 → **Codex で全 MATCH 収束**。⑥ 各画面/状態を下表で ✅ 化。**全 ✅ まで「完了」と書かない。**

**凡例**: ✅=golden 横並び照合+収束済 / ☐=未照合(残) / —=該当なし

| 画面 | 主要状態 | golden照合 |
|---|---|---|
| ホーム | 達成済(populated) | ✅(セッション4) |
| ホーム | 新規/空(0日連続・全"-"週・待機猫・CTA) | ✅(セッション12・MATCH。猫メッセージは両者 Encouraging プール同一=ランダム差) |
| ホーム | 未達成today・復帰welcome・referralスター・revive overlay・⭐10/節目/rankup | 🔶(referral行=A1/revive overlay=A3/comeback=セッション2-3 でエミュ実スクショ検証済。iOS golden(rem_home_referral=★5+「あと5人で猫が解放」/rem_home_revive)取得済。**golden 横並びは Android 側の referral/revive データ注入手段が無く不可**=機能・実装は検証済の前提で 🔶 据置) |
| 記録入力 | 入力済 | ✅(セッション4・field統一確認) |
| 記録入力 | 空/初期・複数種目・体重バリデーションエラー | ✅(セッション17・golden MATCH。空=種類chip/種目名/よく使う種目/4ピッカー/種目メモ/+種目を追加/今日の体重/メモ 一致。複数=アコーディオン最小化行+削除trash。体調・周期は両OSとも周期設定で gating。体重検証=前セッション✅+ユニットテスト) |
| 記録完了 | 達成(連続>1初記録/2件目) | ✅(セッション6・back/tabbar/きのうから条件) |
| 履歴 | populated | ✅(セッション4) |
| 履歴 | 空状態(空カレンダー/凡例/保険チケット折りたたみ/Monthly空/All-time空) | ✅(セッション13・MATCH・凡例11pt是正) |
| 履歴 | 保険チケット展開状態 | ✅(セッション16・golden MATCH。展開時 header残数を隠し本文に icon+残数(body)+説明 / 「使う日を選んで適用」を coral 塗りボタン化(白文字/影/カレンダーicon) / Premium訴求を Divider+塗り無し primary 行へ) |
| 日詳細シート | 記録あり | ✅(セッション5) |
| 日詳細シート | 空/休/救済/未来 状態 | ✅(セッション17・全6状態メッセージが iOS DayDetailSheet と source 完全一致[rest/future/missed/todayPending/achieved/rescued]+iconColor 一致。未来「これからの日だね」をエミュ実スクショ検証。残状態は同一コンポーネント+一致メッセージ) |
| 生理日入力 | マーク有 | ✅(セッション5・tabbar) |
| 設定 | 無料・main | ✅(セッション4・Google「続ける」) |
| 設定 | サブページ ナビヘッダ(全6・中央題+シェブロン)/ 記録と共有(友達共有セクション+caption) | ✅(セッション8) |
| 設定 | サブページ(情報/データ&プライバシー/称号一覧)QUICK | ✅(セッション7) |
| 設定 | データ&プライバシー(プレーン行+footer caption+分析文言)| ✅(セッション9) |
| 設定 | カスタマイズ(ドリルイン行=テーマ/猫ピッカー sub 画面化)| ✅(セッション10) |
| 設定 | 通知設定(3セクション/3分割セグメント/時刻チップ行/性格ピッカー+footer)| ✅(セッション11・残=権限拒否バナーのみ条件付き未) |
| **設定サブページ 6/6 = iOS Form 構造へ収束** | プレミアム ✅(s17)/ 連携ON 認証セクション ✅(s17・削除導線 reactivity 是正) | ✅ |

**通知設定 再構成スペック(iOS golden 確認済)**: ①権限バナー(拒否時)「通知が許可されていません/リマインドを受け取るには…/設定アプリを開く」
②**通知**セクション見出し + 「通知ON/OFF」トグル(現状「毎日のリマインダー/運動を続けるための通知」)+ **3分割セグメント OFF|1日1回|1日2回**(現状=有効時のみ 2 pill)
③**通知時間**セクション + 通知時間1/2 行(グレー時刻チップ + シェブロン。現状 TextButton・チップ/シェブロン無)④**通知の性格**セクション + 「性格」インラインピッカー(現状ラジオリスト)+ デフォルト説明 + footer 3 種解説。
| 設定 | プレミアム | ✅(セッション17・「GOプレミアム 加入中」+プレミアム特典・称号一覧 が iOS と一致。premium 解放はモック購入で検証) |
| 設定 | 連携ON(認証セクション) | ✅(セッション17・**削除導線 reactivity を是正**: `SettingsViewModel.refreshAccountState()` を新設し SettingsRoute の LaunchedEffect から毎回呼ぶ→VM 生成後にサインインしても アカウントを削除 が出る[iOS reactive パリティ・5.1.1(v)/Play 削除到達性]。Mock サインイン→設定で削除導線表示を実エミュ検証。残=未連携 caption の軽微な配置差のみ[低優先]) |

### セッション7: 設定サブページ golden 照合(6画面・XCUITest `testCaptureSettingsSubpages`)
全6サブページを iOS golden 取得→Android 実スクショ→2LLM(Claude6並列+Codex)照合。**重要所見: Android 設定サブページは
Material 風(個別カード/展開グリッド/シェブロン/セクション見出し/pill ボタン)で作られており、iOS の Form 風(単一カード+
区切り線/ドリルイン行/中央タイトル+システム戻る/プレーン行)と広範に乖離**。誤検知排除(Codex): 「めしネコ」=OCR 誤読(両者「ぬしネコ」)/
休養ルール=両者 expandable(MATCH)/引用符=両者「」(MATCH)/称号ladderカード=両者あり(MATCH)。
- **QUICK 是正済(セッション7・commit 次)**: ①体調・周期 caption「印」→「★」+「端末内のみに保存。」削除 ②データ&プライバシー の
  セクション見出し「データ管理/プライバシー」撤去(iOS は見出し無し)③情報・サポート 全行のシェブロン撤去(iOS は外部リンク=非ナビ)
  ④情報 バージョンを「アプリ/バージョン」2行に(iOS LabeledContent)⑤称号サブページ題「プレミアム特典・称号一覧」→「特典・称号」+ 半角括弧→全角「（連続で進化）」。情報サブページ実機検証済。
- **STRUCTURAL 残(大・別バッチ)**: ⓐ **友達への共有セクション**(「回数・時間・セット数も共有」トグル=`includeExerciseDetail` opt-in + publish 配線。C7 publish と統合)が Android に皆無 ⓑ カスタマイズ=ドリルイン行(テーマカラー→/自分のキャラを変更→値/振動)化(現状 展開インライン)
  ⓒ ナビヘッダ=中央タイトル+システム戻るシェブロン(現状 左寄せ大タイトル+赤矢印)を全サブページで統一 ⓓ データ&プライバシー の書き出し/削除をプレーン行化+caption を card 外へ+iOS 文言 ⓔ 分析 caption 文言一致 ⓕ 通知設定=権限バナー/3分割セグメント(OFF|1日1回|1日2回)/時刻行/性格ピッカー の iOS 構造化。
| 友達 | サインイン済populated | ✅(セッション4) |
| 友達 | welcome(未サインイン)・空(友達0) | ✅(セッション16・自動匿名サインインで通常到達不可・iOS welcome golden照合で source 是正: title34/猫140/復元撤去/空猫124+0.95/見出し17) |
| 友達 | エラーバナー・cheer picker | ✅(cheer picker=セッション5 友達詳細)/ エラーバナー=source 一致(更新+閉じる・primaryDeep・要エラー発火) |
| 友達 | 詳細 hero 名前フォント | ✅(セッション16・22sp→AppType.title 34・PIL測定一致。セッション5 golden の見逃し是正) |
| 友達詳細 | populated | ✅(セッション5・閉じるカプセル) |
| 友達追加 | — | ✅(セッション5・順序/見出し/閉じる) |
| ランキング | 今週 | ✅(セッション4・segmented picker) |
| ランキング | 今月 | ✅(セッション16・MATCH・データ差のみ) |
| ランキング | 空状態 | ✅(セッション16・防御的フォールバック=サインイン済は常に自分を含み到達不可・両OS文言/構造一致) |
| 体重 | 無料→paywall | ✅(セッション17・golden MATCH。👑絵文字→Material crown(コーラル)/フッター「ホーム…無料」追加/CTA capsule化) |
| 体重 | プレミアムpopulated | ✅(セッション17・**折りたたみ化完了**=記録する/レポート/推移/履歴 を `WeightCollapsible`(既定折りたたみ・アイコン[AddCircle/BarChart/ShowChart/FormatListBulleted]+題+折りたたみ中subtitle+シェブロン)で iOS 順に。subtitle 文言も iOS 一致[新しい体重を追加 / 今週±Nkg/平均Nkg / 30日でN件記録 / 全N件]。展開で subtitle 隠す挙動も一致。実エミュ検証。データ要素[目標/身長/猫リング]は data 差) |
| ペイウォール | 一般(クラウン+特典7行) | ✅(セッション15・絵文字→SF Symbol 相当 Material アイコン+「全11種の猫」行追加) |
| 体重(プレミアム チャート) | — | ✅(セッション17・推移を折りたたみで展開→期間チップ[1週/1月/3月/半年/全期間]+折れ線+破線トレンド描画を実エミュ確認。iOS CollapsibleSection 内チャートと一致) |
| 連続シェア | — | ✅(セッション17+17b監査。並び順 iOS=バッジ→猫→「N 日連続」横並び→アプリ名 / 見出し撤去 / 5グラデドット+SNSで共有+写真に保存 / 英字「GO Exercise」副題削除(監査17b)。紙吹雪は iOS にも有=維持) |
| ハイライトシェア(週/月/全期間) | — | ✅(セッション17+17b監査。統計行 iOS SF Symbol 相当アイコン🐾🕐📋⭐❤️ / Monthly バッジ📄 / SNSで共有 / **英字副題削除+紙吹雪削除**(iOS MonthlyReviewCard は猫のみ・監査17b)。4並列敵対監査で収束) |
| オンボーディング | step1(猫選択)/step2(バックアップ) | ✅(セッション14・「ようこそ🐾」撤去+タイトル largeTitle 化。ロゴは B6) |
| フリーズ(rescue)使用画面 | — | ✅(セッション17b・iOS RescueTicketUseView へ全面改修=題「保険チケットを使う」/summaryカード(チケットicon+「今月の保険チケット: N/M 回 残り」+無料枠のみインライン「(GOプレミアムで月4回)」)/操作説明カード/「マークの意味」凡例/「これまでに使った日」/適用確認ダイアログ。👑 premium ボタン撤去(iOS はインライン文言)。実エミュ検証・iOS ソース全文照合。VM に rescuedDates 追加) |
| ダイアログ | 紹介確定/rankup/revive | ✅(済) / milestone/breed-unlock | 🔶(milestone-eve seed→記録で iOS は記録完了画面[既✅]へ。節目/breed-unlock ダイアログは発火条件が data 依存で golden 自動撮影が不安定=実装は session3 で✅・golden 横並び未) |

**次バッチ着手順(推奨)**: ~~①設定サブページ群~~(ナビヘッダ/記録と共有 ✅・残=カスタマイズ/データ&プライバシー/通知の STRUCTURAL)
②ホーム各状態(空/未達成/復帰) ③履歴空/チケット展開 ④友達 welcome/空 ⑤ランキング今月/空 ⑥体重/ペイウォール
⑦シェア各種 ⑧オンボ ⑨日詳細の状態別。各バッチ=XCUITest 撮影追加→2LLM→修正→収束。

## ★★★ 残タスク(parity 完了後): Android 単独の包括的 QA(2026-06-19 ユーザー指示)
**全ページ×全パターンの iOS パリティ照合(上表 全 ✅)が終わったら、次に Android 版だけで包括的 QA を実施する。**
iOS との一致とは別に、Android 単体としての品質を網羅検証する(memory [[android_comprehensive_qa_checkpoint]] の手順を発展):
- **機能/ロジック**: 連続記録・休養・救済チケット・節目/称号・紹介スター・友達/ランキング・バックアップ同期・通知・ウィジェット の
  全フローを実機で通し、境界(月跨ぎ/日跨ぎ/0件/大量/タイムゾーン)を検証。`./gradlew :app:testDebugUnitTest` 全 green 維持。
- **視覚/UX**: 全画面・全状態を実エミュ(go_test)+ 実機系サイズで描画確認(空状態/長文/フォントスケール/ダーク非対応確認/
  横幅小端末でのクリップ/アニメ稼働/タップ領域)。Canvas 描画(シェア画像/ウィジェット)は instrumented test で render→PNG 確認。
- **回帰/堅牢性**: 画面回転・プロセス kill 復帰・権限拒否・ネット断・課金状態変化・アカウント切替/削除での state リセット。
- **手段**: 2LLM(Claude 並列 + Codex)監査 → Codex で correct 収束。所見は該当コードを直接読んで裏取りしてから修正。
- 着手は **iOS パリティ台帳が全 ✅ になってから**(本タスクの前提)。完了後 memory `android_comprehensive_qa_checkpoint` を更新。

## 0. 完全一致のための手順（毎回これを守る = 再発防止）
1. **正本 = iOS build 12**。シミュレータに build 12 を確実に install(derivedDataPath 固定→CFBundleVersion=12 確認)。
   手順は memory `android_ios_ui_parity`。
2. **iOS ソースを全文精読**(対象 View＋子View＋ViewModel＋デフォルト値供給)。**UI 要素を漏れなく列挙**
   (セクション見出し/フィールド/ラベル/プレースホルダ/アイコン(SF Symbol名)/コピー文言/並び順/空状態/条件分岐/サブ画面/
   アニメーション/角丸・余白・色の数値)→ 本書のチェックリストに落とす。
3. **要素単位で Android を実装・照合**。「データ差は無視」は**具体的な数値/件数/日付のみ**。候補リストの中身・文言・
   存在するフィールド/セクション・配置順・空状態・アイコン種別・色/不透明度は**必ず一致**させる。
4. **iOS と Android を同一データ状態で並べてスクショ比較**(端末/emu)。差が無いか自分の目で拡大確認。
5. 2LLM 検証(Claude=スクショ厳密比較 / Codex=ソース要素照合)。reviewer には本書の要素チェックリストを渡し、
   「データ差は無視」と**広く言わない**。
6. 直したら本書の該当項目を ✅ に更新。**全項目 ✅ になるまで「完了」と報告しない。**

## 2LLM 検証改善ループ（2026-06-18 セッション2 後半・Claude×4 並列 + Codex）
全実装画面を最終コードで再監査(Claude 4並列)+ Codex(default model)でレビュー。**修正済(スクショ/テスト検証)**:
- 記録入力: ピッカー選択値・項目に単位付与(「30分/3回」、0=「—」)✅(実機確認)
- 友達: 受信トースト 絵文字除去+「…が届きました!」/ 送信時の下部トースト撤去(詳細インライン確認のみ=iOS)/ 共有文を iOS 形式(連続日数・@username 載せず+Play URL)/ コピー時トースト「招待コードをコピーしました」/ QR キャプション追加 / 申請行アバターを実猫(決定論的)✅(CheerToastTest 更新・green)
- 履歴: DayDetailSheet を HistoryRowView カード化+アイコン円の空状態+休養メッセージ改行✅
- 設定: PerkGuide 節目アイコン Celebration→Pets(pawprint 寄せ)✅
- 横断確認(MATCH): FriendAvatarResolver FNV-1a と CatBreed 並びは iOS 完全一致 / streakExtended proxy 妥当 / ランキング全要素一致。
**追撃修正(2回目バッチ・compile+test green)**: 記録完了 登場フェードイン(猫0.85→1/リボン0.4→1/ヒーロー0.9→1)✅ / 友達 明示「検索」ボタン+hasSearched ガード✅ / ⭐10アラート コピーを iOS 寄せ(「やったね!」+本文一致、絵文字方針で「星10達成！」)✅ / 設定 ウィジェット5ステップ+表示内容ガイド(Android追加手順版)✅.
**残(LOW/要素材/要判断)**: フォント 1〜2pt 差(AppType トークン粒度 vs iOS Dynamic Type=systematic・低優先) / ブランドロゴ画像(規約準拠アセット) / Customize 階層(inline vs sub-nav・機能等価) / 生理日まとめ入力画面(新規) / ホーム referral行・日タップsheet・revive祝福overlay / 友達 初回名前カード / キーボード「完了」(Android作法に無く許容).

## ★残タスク（次セッション着手用・優先順）— 2026-06-18 セッション2 末
> **2026-06-18 セッション3 完了**: A1〜A5 / B6 / C7 / D8〜10 / E11 を**すべて消化**(各実装はエミュ実スクショ検証 or 判断確定)。
> 機能ギャップは 0。残る既知の許容差は D8(二次ラベル ≤2pt フォント差・範囲内)のみ。次セッションの新規着手項目は無し
> (publish 側=自分の種目詳細共有は、iOS と同じ opt-in トグル[既定 OFF]を将来入れる時にまとめて、というメモのみ)。
**A. 新規実装（大・視覚インパクト大／要スクショ検証）**
1. ~~ホーム **referralスター行**~~ ✅ **完了(2026-06-18・エミュ実スクショ検証済)**。`ReferralStarsRow` を上段3行目に追加、VM `referralRow` StateFlow(`currentAccountStarBadges`×`currentAccountCode`)で配線。connect 後 refresh も是正。
2. ~~ホーム **週カレンダー日タップ → DayDetailSheet**~~ ✅ **完了(2026-06-18・エミュ実スクショ検証済)**。`WeeklyCalendar` セルを clickable 化、履歴 `DayDetailSheet`(internal 化)を再利用、`HomeUiState.weekRecords` で当日記録を供給。記録あり/なし両状態 検証済。
3. ~~ホーム **revive 成功祝福**「連続復活!」~~ ✅ **完了(2026-06-18・エミュ実スクショ検証済)**。`applyRevive()` 成功で `_reviveCelebration=CatRank.of(potentialStreak)` を点火→`RankCelebrationOverlay(message="連続復活!")`。実機で popup→使う→ピル表示を確認。
4. ~~履歴 **生理日まとめ入力画面**~~ ✅ **完了(2026-06-18・エミュ実スクショ検証済)**。`MenstrualEntryScreen`+`MenstrualEntryViewModel` 新設、NavHost に `menstrual` route、履歴 entry-row(cycle有効時)。トグルが履歴カレンダー★に即反映を確認。
5. ~~友達 **初回表示名入力カード**~~ ✅ **完了(2026-06-18・エミュ実スクショ検証済)**。`NamePromptCard` を profileHeader 直下に。
   gating=未dismiss && displayName==既定("あなた")。SettingsRepository に `namePromptDismissed` 永続フラグ追加、
   FriendsViewModel に submitNamePrompt(成功時のみ閉じる)/dismissNamePrompt。実機で 決定→表示名更新+カード消滅を確認。
**B. 要素材/規約**
6. ~~設定/友達 **Apple・Google ブランドロゴ画像**~~ ✅ **完了(2026-06-18・オンボ実スクショ検証済)**。
   `ic_apple_logo.xml`(単色マーク・tint 出し分け)/ `ic_google_g.xml`(公式4色G・固定色)を新規作成、
   共有 `AppleLogo`/`GoogleLogo` composable で オンボ/設定/友達(バックアップ・復元)の全認証ボタンへ。
   旧「G 」「 」プレフィックス文字は撤去。
**C. 実BEデコード（iOS Supabase スキーマ確認後）**
7. ~~友達 `today_exercise_details` デコード配線~~ ✅ **完了(2026-06-18・Mock友達詳細でスクショ検証 + 単体テスト)**。
   `SharedExerciseDetail` を構造化(reps/sets/durationMinutes + iOS 一致 summary「{reps}回 × {sets}セット / {min}分」)、
   `ProfileRow.today_exercise_details`(jsonb)+ `SharedExerciseDetailRow` DTO 追加、`toProfile()` でデコード。`ProfileRowDecodeTest` green。
   **`connected_since` は対象外**(iOS も実BEでは `connectedSince: nil` 固定=デコードしない)。
   **publish(自分の詳細の送信)は保留**: iOS は opt-in(`includeExerciseDetail` 既定 OFF)。プライバシー最優先方針に従い、
   共有トグル(既定 OFF)導入までは Android は自分の詳細を publish しない(各ユーザーは自分の行のみ書くため他者の値は消えない)。
**D. LOW（systematic / 機能等価 / 許容差）— 2026-06-18 すべて判断確定(意図的な許容差)**
8. フォント差 → **許容(範囲内)で確定**。中核タイプスケールは iOS と一致済(`AppType`: title34/screenTitle22/sectionTitle20/headline17/body17/caption12 = iOS largeTitle/title2/title3/headline/body/caption1)。
   残差は iOS `.callout`16/`.footnote`13/`.subheadline`15 を最近接トークンで近似する**二次的ラベルの ≤2pt のみ**で、レンダリング誤差の範囲内。検証済画面への一括 rewire は回帰リスク>便益のため行わない。
9. 設定 Customize 階層 → **解決済(既にパリティ)**。Android 設定は階層型 `SettingsPage`(`SubPage("カスタマイズ")` 等)で iOS の サブナビと等価。
10. 記録入力 キーボード「完了」バー → **許容差で確定**。Android にアクセサリバーの作法が無く、IME/戻るで閉じる。ピッカー化で数値テキスト入力も大幅減。
**E. 絵文字方針 — 2026-06-18 確定(Android no-emoji 方針を一貫適用)**
11. 方針=**絵文字→Material アイコン(Android 全廃)**。iOS 自体も `ReferralCelebrationSheet` 等は SF Symbol アイコン+絵文字なし文言を使用しており、
    no-emoji は iOS パリティとも整合。残存していた `ReferralCelebrationDialog` の ❄️/⭐/✨ を Material アイコン(AcUnit/Star/AutoAwesome)へ置換し iOS と一致(スクショ検証済)。
    ⭐10 アラートは既に「星10達成!」。特典ガイド本文の "⭐"(星バッジへの文中言及)は文言として残置。

**検証手順（毎回必須・CLAUDE.md ★7）**: 友達/ランキング描画は `local.properties` の `SUPABASE_HOST`/`SUPABASE_ANON_KEY` を一時空 →Mock強制(seedDemo で友達2名)→ `assembleDebug`→`adb install -r`→ タブ「友達」で `友達とつながる`→ホーム→友達 で signed-in 描画 → `adb exec-out screencap`/uiautomator dump で確認 → **検証後 `cp /tmp/local.properties.bak local.properties` で復元**。emulator AVD=`go_test`。

## 1. 進捗サマリ（2026-06-18 セッション2: 6画面厳格再監査 → 実装ループ）
- [~] ホーム  — **大半是正済・スクショ検証(アニメ稼働をフレーム差分で確認)**: ITEM2 環境パーティクル(時刻別18粒・Canvas移植)✅ / NEW-C 猫アイドル(呼吸1.03/浮遊±/傾き±2°合成)✅ / ITEM4 猫タップ bounce1.08+haptic✅ / 猫背景の光輪(tint .32→.06)✅ / ITEM6 吹き出し pop-in(scale0.7→1+fade delay0.15)✅+lineLimit3✅ / ITEM7 今日セル breathing(1.0↔1.05)✅ / ITEM5 称号チップ pawprint✅ / ITEM10 weeklyMini 等幅✅。ITEM1 referralスター行 ✅(スクショ検証済・connect 後 refresh も是正)。ITEM3 日タップ→DayDetailSheet ✅(スクショ検証済・履歴シート再利用)。ITEM8 revive overlay「連続復活!」✅(スクショ検証済)。**残: ITEM9 ⭐10コピー(Android は絵文字回避方針で「星10個」のまま=要オーナー確認)**
- [~] 記録入力 — **大半是正済**(R1 時間/回数/セット ピッカー✅ / R2 体調・周期 独立セクション✅ / R3 メモ複数行3..5✅ / R4 体重0-500検証+保存ブロック+disabledReason✅ / NEW-1 重さ<1000+「(kg)」✅ / NEW-2 候補見出し表示条件✅ / NEW-3 候補chip選択状態撤去✅)。残: R5 キーボード「完了」バー = **Android はアクセサリバー非対応のため許容差**(ピッカー化で数値テキスト入力も大幅減)。
- [x] **記録完了 — ✅ 完了**(B1 streak0常時表示 / B2「きのうから+1のばした！」行(VM streakExtended配線) / B3 タイトル / N3 リボン影 / N4 ヒーローパルス+グロー影)
- [~] 履歴   — **大半是正済**(ITEM2 運動履歴=HistoryRowView相当カード(日付見出し/カテゴリ色見出し/種目行 回ｾｯﾄ時間/合計/メモ)✅ / ITEM5 Monthly空状態dim✅ / ITEM6 All-time「使用M日」✅ / ITEM7 共有コピー・Play URL・運動履歴前へ✅ / ITEM8 grid6dp/Future=surface/TodayPending0.40/生理日色/凡例14・r4・カプセル✅ / ITEM4 救済日セルに ticket グリフ✅)。ITEM3 生理日まとめ入力画面 ✅(スクショ検証済・MenstrualEntryScreen 新設)。ITEM1 保険チケット折りたたみ+残数subtitle+Premium訴求 ✅(セッション16・golden MATCH。展開時の本文 icon+残数+説明・coral塗りの適用ボタン・Divider+Premium行)
- [~] 設定   — **大半是正済**(情報サポート4リンク✅/削除gating匿名対応✅/PerkGuide5項目✅/休養ルール4項目展開✅/破壊色赤✅/trialEligible配線✅/共有URL✅/一部アイコン✅/cycle・書き出しコピー✅)。残: 振動トグル(要pref)/ブランドロゴ画像(要アセット)/通知独立View・ウィジェット5段。**ITEM3削除コピーは Android 実挙動(端末内記録は残る)に忠実=変更せず**(監査の過剰指摘)。
- [~] 友達   — **友達詳細フル画面化＝完了・スクショ検証済**(全画面Dialog: hero[グラデ猫132+@user·friendCode mono+称号バッジ+最終更新]／今日の運動[達成バッジ+カテゴリchip+種目別詳細]／今週の達成[木=今日強調]／統計3タイル[連続/累計/**つながって**=正メトリック]／cheer[入力欄+送信ボタン+2列プリセット+「…を送りました」インライン確認]／解除[bordered red]。モデルに lastUpdated/connectedSince/todayExerciseDetails+SharedExerciseDetail 追加・Mock seed・updated_at デコード配線)。**友達一覧の小項目(スクショ検証)**: ITEM3 追加ボタン=トップバーアイコン✅／ITEM4 エラーバナー色 primaryDeep+更新ボタン✅／ITEM5「6文字の英数字 (例: ABC123)」+無結果コピー✅／ITEM9 公園アバター=影楕円+白縁今日バッジ+決定論的猫+long-press解除撤去+トースト下余白64✅／空状態コピー「右上の + から…」✅。**残**: ITEM6 明示「検索」ボタン(現状ライブ検索)／ITEM7 コピーコードtoast・受信5s・初回名前入力カード／ITEM8 QRキャプション・申請アバター実猫。today_exercise_details の**実BEデコード ✅完了**(構造化+iOS summary一致・単体テスト+Mock詳細スクショ検証)。connected_since は iOS も実BE nil=対象外。publish は opt-in トグル導入まで保留(プライバシー)。
- [x] **ランキング — ✅ 完了**(G1 EmptyStateView / G2 サマリーgradient+枠 / G3 自分行2dp枠 / G4 メダル不透明度+数字色 / G5 猫fallback=決定論的猫(FriendAvatarResolver新設, iOS FNV-1a 一致) / G6 中央タイトル+システム戻る)

---

## 2. ギャップ詳細(2026-06-18 厳格監査・iOSソース照合済み)

### A. 記録入力 (iOS RecordEntryView/ExerciseInputRow/DefaultExerciseSuggestions/RecordEntryViewModel) — commit f084698 で主要是正
- [x] **アコーディオン**(最小化行=アイコン+名前+サマリ+chevron, 1種目のみ展開)。
- [x] **種目メモ欄**(placeholder「種目メモ (例: 体調メモ、回数アップ等)」)。
- [x] **日本語デフォルト候補**(DefaultExerciseSuggestions 移植・履歴と merged limit12)。
- [x] 空候補ヒント「履歴がたまると、ここによく使う種目が出ます」。
- [x] **重さを 時間/回数/セット と同一行(4列)**。
- [x] セクション/フィールド見出し「種類」「種目名」「よく使う種目」。
- [x] 「同じ種目でセットを追加」名前入力済時のみ。削除=ヘッダ trash。重さ placeholder「0」。
- [x] 時間/回数/セット = ドロップダウン ピッカー化(時間0..100 step5 / 回数0..50 / セット0..10、0は「—」)。
- [x] 体調・周期を独立セクション(見出し「体調・周期」)に。体重カードの前へ。
- [x] メモ複数行(minLines3 / maxLines5)。
- [x] 体重バリデーション 0〜500kg + disabledReason「体重は 0〜500 kg の数値で入力してください」(info アイコン)+ canSave ブロック。
- [x] NEW-1 重さ 0<x<1000 + ラベル「重さ (kg)」。NEW-2 候補見出しは候補ありの時だけ。NEW-3 候補chipの選択ハイライト撤去。
- [~] キーボード「完了」ツールバー = Android はアクセサリバー非対応のため許容差(代替: IME/戻るで閉じる)。
- 注: 「種目」セクション見出しは iOS Form セクション。Android はカード群直置きで省略(許容)。

### B. 記録完了 (iOS RecordCompletionView) — ✅ 完了
- [x] streakHero を **streak0 でも常時表示**(streak>0 条件を撤去)。
- [x] **「きのうから +1 のばした！」**行(VM に streakExtendedThisRun を配線。currentStreak>1 を proxy に算出)。
- [x] ナビタイトル「記録完了」(インラインタイトル表示)。
- [x] N3 リボンのピンク影(shadow 16dp, pink spot/ambient)。N4 ヒーローのパルス(scale1.04, 2回autoreverse)+グロー影(8→22dp)。
- 注: 完了画面の猫は iOS も Android も useShaker=true でシェイカー待機ポーズ固定 → catState(celebrating/streakExtended)は画像に出ない(両 OS 一致・対応不要)。

### C. ホーム (iOS HomeView 他)
- [x] **referralスター行(referralStarsFullRow)** ✅(エミュ実スクショ検証済 2026-06-18): 上段3行目に `ReferralStarsRow`。
  ゲート `isReferralActive && currentAccountStarBadges>0 && friendCode!=null`(VM `referralRow` StateFlow)。
  progress(1〜9)=金 filled+枠で10個並べ「あとN人で猫が解放」/ complete(10)=全金 / 11+=金1+数値。星色=iOS Color.orange(#FF9500)、
  枠=textSecondary@0.3、caption=caption/secondary。タップで Play URL 付き招待を ACTION_SEND 共有(iOS inviteText パリティ)。
  **付随パリティ修正**: `FriendsViewModel.connect()` 後に `referralStore.refresh()+pollReferrerPops()` を起こす
  (iOS は `HomeView.onChange(friendCode)→refresh`。これが無いとサインイン直後にスター行が次回起動まで出なかった)。
- [ ] **AmbientParticlesView**(常時・時刻別パーティクル: 朝花/昼泡/夕葉/夜星, 18粒, reduceMotionで静止)。Android は完了時 confetti のみ。
- [x] **週カレンダー日タップ→DayDetailSheet** ✅(エミュ実スクショ検証済 2026-06-18): 各セルを clickable 化(plain=リップル無し)し、
  履歴画面の `DayDetailSheet`(internal 化して再利用)を表示。当日記録は `HomeUiState.weekRecords` から同日フィルタ。
  記録あり=`HistoryRecordRow` カード(カテゴリ色見出し+種目行+合計)/ 記録なし=アイコン円+ステータス別メッセージ。両状態 検証済。
- [ ] **猫タップで bounce + haptic**。
- [ ] RankBadge/CatRankChip に**先頭アイコン(pawprint)**。Android はタイトルのみ。
- [ ] 吹き出しの**pop-in 出現アニメ**(scale0.7→1, fade, spring delay0.15) + lineLimit3。
- [ ] 週カレンダー今日セルの**breathing アニメ**(1.05↔1.0)。Android は静的1.05。
- [x] **revive 成功後の「連続復活!」celebration overlay** ✅(エミュ実スクショ検証済 2026-06-18): `HomeViewModel.applyRevive()` が
  全 Missed 日復活成功時に `_reviveCelebration = CatRank.of(potentialStreak)` を点火、HomeRoute が `RankCelebrationOverlay(message="連続復活!")` を表示。
  iOS HomeView.swift:96-104 / handleReviveUse パリティ。実機で StreakRevivePopup→使う→「連続復活!」ピル表示を確認。
- [ ] ⭐10解放アラートのコピーを iOS 厳密一致(「⭐10達成!」「やったね!」本文)。
- [ ] weeklyMini の達成数 monospacedDigit + フォント weight。

### D. 履歴 (iOS StatsView/MonthlyCalendarView/HistoryRowView)
- [ ] **保険チケットを折りたたみ化**: 「今月 N / M 回 残り」動的subtitle + アイコン状態(ticket.fill↔ticket) + 展開(説明「忙しい日に連続記録を守れます。毎月リセットされます。」+「使う日を選んで適用」+ **非Premium向け Premium訴求「GOプレミアムで保険チケットが月4回に」→paywall**)。Android は単純カード。
- [ ] **運動履歴を HistoryRowView 相当**に: 日付グルーピング(見出し sectionTitle)+ per-record カード(surface r18/padding14)+ カテゴリ見出し+SF Symbol+色 + 種目行(回 セット duration 順)+「合計 {duration}」+ **メモ**。Android はフラットテキスト(カード/カテゴリ/合計/メモ 全欠落)。
- [x] **生理日入力 entry-row**「生理日を記録する / 過去の日付もまとめて入力できます」(★ + chevron, cycle有効時)→ `MenstrualEntryScreen`(一括入力)✅(エミュ実スクショ検証済 2026-06-18)。
  履歴のカレンダー直後・保険チケットの前に配置(iOS StatsView 並び順)。専用画面=月ナビ(翌月ガード)+曜日行+グリッド(today強調/未来淡色非活性)+
  ★トグル(markColor#DB5C73 塗り0.18+枠1.5+★)+「M月の記録: N 日」+説明3点。`MenstrualRepository` 共有でトグルが履歴カレンダーの★に即反映(検証済)。
- [ ] カレンダーセルの**救済日マーク(右下 ticket.fill)** + 凡例「保険チケット使用」chip。Android 欠落。
- [ ] Monthly空状態: 当月記録なしで dim + chevron非表示 + disabled + subtitle「今月の記録はまだありません」。
- [ ] All-time subtitle を「累計 N 日達成 / 使用 M 日 (R%)」に(Android「達成率R%」で使用日数欠落)。空状態「まだ記録がありません」。
- [ ] shareApp: subtitle「インストール用リンクが LINE / メッセージなどで送れます」、共有文を共有config由来、配置を**運動履歴の前**に。アイコン square.and.arrow.up.circle.fill。
- [ ] カレンダー微差: grid spacing 4→6dp、cell 固定高44 vs aspectRatio、TodayPending 0.45→0.40、**Future色 secondary→surface**、生理日ドット色 #E05A8A→RGB(0.86,0.36,0.45)、凡例swatch 12→14/r3→r4 + chipBg カプセル。

### E. 設定 (iOS SettingsView 他)
- [ ] **情報・サポート 3リンク欠落**: 「ご意見・ご要望を送る」(bubble) /「不具合を報告する」(ladybug) /「サブスクリプションを管理」(creditcard→Play) /「サポート」(questionmark→URL)。Android は privacy/terms のみ。
- [ ] **アカウント削除 gating**: iOS は `profile!=nil`(匿名含む)で表示。Android は `linkedProvider!=null`(連携のみ)→匿名ユーザーが削除不可(5.1.1(v)リスク)。
- [ ] 削除確認コピーの整合(Android「端末内の記録は残ります」 vs iOS「全消去」)。実挙動を確認して一致。
- [ ] 「14日間無料」を `trialEligible` でゲート(Android は無視して常時表示)。
- [ ] **PerkGuide セクション**(称号一覧ページの「プレミアム特典」5項目: 保険チケット/友達紹介/称号&背景/猫種/節目)。Android 欠落。
- [ ] **休養ルール詳細4項目**(自動休/3日目×reset/履歴「休」表示/保険チケット月1・月4)+ 展開式。Android は1行要約・非展開。
- [ ] カスタマイズに**「達成時の振動」haptic トグル**。Android 欠落。
- [x] Apple/Google ボタンに**ブランドロゴ画像** ✅(スクショ検証済 2026-06-18・`ic_apple_logo`/`ic_google_g` + 共有 `AppleLogo`/`GoogleLogo`)。コピーは既に「サインイン」。
- [ ] データ削除系の**破壊色を赤**(Android primaryDeep)。
- [ ] アイコン整合: 記録と共有=heart.text.square / プレミアム特典=rosette / アップグレード=crown / privacy=hand.raised / バックアップtoggle・sync 行にアイコン。
- [ ] コピー整合: 「データを書き出す」/「体調・周期を記録する」/cycle footer 等。
- [ ] (要別監査) 通知設定: iOS は独立 NotificationSettingsView。Android ReminderSection との照合未。ウィジェット案内は iOS 5ステップ詳細 vs Android 1段落。

### F. 友達 (iOS FriendsView/FriendsParkView/FriendDetailView/FriendAddView)
**最大の欠落=友達詳細**。Android はコンパクト ModalBottomSheet で、iOS のフル画面 FriendDetailView と別物。
- [ ] **友達詳細をフル画面化**(NavigationStack 相当・タイトル=友達名・閉じる)。以下を全部:
  - [ ] hero ヘッダ: グラデ猫アバター(132, tint .50→.15) + 名前 + 「@user · friendCode(mono)」 + **RankBadge(スタイル付き)** + **最終更新**テキスト。
  - [ ] **今日の運動カード**: 「今日の運動」見出し + 達成/未達成バッジ(checkmark.seal.fill/hourglass) + カテゴリchip + **種目別詳細リスト**(name+サマリ) + fallback「詳細は共有されていません」「今日はまだ運動の記録がありません」。
  - [ ] 週ストリップに**今日強調**(today index を渡し primary+ラベル太字)。Android FriendWeekStrip は today 未対応。
  - [ ] **統計3タイル**(連続/累計達成日/**つながって**)= アイコンタイル+accent色+surface。Android は素のテキスト3列で、3つ目が「今日」(誤メトリック)。
  - [ ] **cheer フロー修正**: プリセットは**入力欄に入れるだけ**→**送信ボタン(arrow.up.circle)**で送る。Android はプリセット即送信で、自由入力に送信手段が無い。2列グリッド+選択ハイライト+送信後「「…」を送りました」インライン確認。placeholder「応援メッセージ(30字まで)」。
  - [ ] 解除ボタン= bordered red + person.crop.circle.badge.minus。確認文「再度つながるには友達コードで申請が必要です。」ボタン「友達を解除」。
- [ ] **モデル拡張**(上記の前提): Android `FriendProfile` に `lastUpdated` / `todayExerciseDetails` / `connectedSince` を追加し service/decoder で配線。
- [ ] 追加ボタン: iOS は top-bar アイコン(person.crop.circle.badge.plus)。Android は「＋ 追加」テキスト。空状態コピーも整合。
- [ ] エラーバナー: **更新(reload)アクション**追加 + アイコン色を赤→primaryDeep(iOS は赤を避ける)。
- [ ] コピー「**6文字**の英数字 (例: ABC123)」(Android「6桁」)。検索無結果「該当するユーザーは見つかりませんでした」。
- [ ] 検索は**明示的「検索」ボタン**(≥2文字)+ race guard(Android はライブ検索)。
- [x] 初回 表示名入力カード(`NamePromptCard`)✅(スクショ検証済 2026-06-18)。/ コピーコード時トースト・受信応援トーストは既存実装済(セッション2)。
- [ ] QR パネルの説明キャプション。申請行のアバターを実猫(paw プレースホルダでなく)+ 申請subtitle に paw。
- [ ] 公園アバター: 影楕円 / 今日バッジ checkmark.seal+白縁 / 長押し解除は iOS に無い挙動(要再考)。トースト下余白 24→64。

### G. ランキング (iOS WeeklyRankingView) — ✅ 完了
- [x] **空状態を EmptyStateView 化**(pawprint 34dp in 86dp primary@0.12 円 + メッセージを surface@0.75 カード r22 padding28)。
- [x] **mySummary カードに gradient(primary 0.18→0.06, 左上→右下)+ 枠線(primary@0.4 1.5dp)**。
- [x] **自分の行に 2dp primary 枠**。
- [x] メダルの不透明度(金0.85/銀0.90/銅0.85)+ 数字色(金(0.42,0.30,0)/銀(0.28,0.28,0.32)/銅(0.38,0.22,0.08))。
- [x] アバター fallback を**決定論的猫**に(FriendAvatarResolver 新設・iOS FNV-1a + CatBreed 並び一致 → 同一友達は両OS同じ猫)。
- [x] 戻る = システム戻る(矢印アイコン・「戻る」テキストボタン撤去)+ タイトル中央。

---

## 3. グローバル
- [x] 丸ゴフォント(M PLUS Rounded 1c)同梱・全画面適用。
- [x] ボトムタブ = 浮島型(角丸島/白地/影/選択コーラルピル)+ Material アイコン。
- [ ] iOS golden スクショを repo に保存して参照可能にする(検討)。

## 4. 参照
- 強拘束ルール: `CLAUDE.md` 冒頭「★最重要・強拘束」。
- 作業ログ/手順: memory `android_ios_ui_parity`、`feedback_parity_verification_rigor`、`feedback_verification_workflow`。
- branch: `feature/android-ios-ui-parity`(未マージ)。
