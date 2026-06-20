# Android↔iOS パリティ 残タスク・バックログ(動く正本)

> **これが同期残タスクの唯一の動く正本。** 体系立てて 1 項目ずつ消化する。
> 関連: 方針=`PARITY_100_PLAN.md` / 旧履歴=`android_ios_parity_tracker.md` / 規約=`CLAUDE.md`。
> 最終更新: 2026-06-20。

> ## 🔲 真に未完の残タスク(2026-06-20 時点・ここを上から潰す)
> 下の §1–§5 はほぼ ✅ だが、その多くは **Mock-force ビルド or source 照合**での確認。
> **実ビルド(実 Supabase)+ オンライン状態の実視覚照合が未済**の項目が残る。優先順:
> 1. ✅ **友達 サインイン後「コード画面」の実視覚照合 — 完了(2026-06-20)**。Mock-force ビルド(SUPABASE 2行コメントアウト)で
>    density393 撮影 → iOS golden `/tmp/ios_golden/clean/08_friends.png` と横並び照合。証跡 `proofs/friends_code_screen_ios_vs_android_FIXED.png`(+QR展開 `proofs/friends_code_qr_expanded_android.png`)。
>    **是正4件**(横並びで判明): (1) ヘッダ全体を surface カードで包んでいた→iOS は**アバター行をカード化せず**素の背景に置く構造へ
>    (2) 友達コードカードの塗りが **chipBackground(ピンク)→ iOS は surface(白)・r14→r18**(色反転を修正)
>    (3) コピー/シェア/QR の円ボタン塗りが **background(クリーム)→ iOS は chipBackground(ピンク)**(同じく反転)
>    (4) 右上「友達を追加」アイコン tint `primaryDeep`(濃)→ iOS アクセント `primary`(salmon)。
>    付随: namePrompt「決定」の無効色を灰→ iOS 同様 primaryDeep@0.35(色相維持)、QR 画像 160→140dp(iOS 一致)。unit green 維持。
> 2. ✅ **友達 welcome 接続失敗バナー — 最終 sign-off 完了(2026-06-20)**。文言は iOS(`FriendsView.swift:242`)へ統一済(commit 97efe43)。
>    **実ビルド(実 Supabase)+ ネット不達**で友達タブ→サインイン失敗→welcome 着地を**ライブ撮影**し、猫140/「友達と一緒に続けよう」/
>    body/固定文「うまくつながれませんでした。少し時間をおいて、もう一度お試しください。」/「友達とつながる」(person.2)/シェア行 まで iOS spec と一致を確認。
>    証跡 `proofs/friends_welcome_signoff_android_realbuild.png`。connecting 状態「準備しています…」も iOS friendsConnectingBody と一致。
> 3. ✅ **戻るボタン色の最終統一 — 完了(2026-06-20)**。iOS26 サブページ back は **surface(白)円 + textPrimary(charcoal)chevron.left**。
>    旧 Android は **chipBackground(ピンク)円 + primaryDeep(赤)chevron** で別物だった → surface + textPrimary に統一。
>    対象4箇所: 設定 SubPage(共有・全設定サブページ)/ 生理日 / 週間ランキング / 記録完了(旧 plain ArrowBack → 同 円形 chevron 化)。
>    証跡 `proofs/back_button_ios_vs_android_FIXED.png`(設定サブpage 実撮影で色一致確認)。残3箇所は同一共有パターン(source 一致)。
>    **残(微差・受容)**: drill 行の chevron は既に `>`(KeyboardArrowRight)。iOS は約1px細い `>`(chevron.right)・やや淡灰だが知覚閾値以下のため現状維持。
>    インライン展開(休養ルール/特典)の `⌄`(ExpandMore)は iOS も下向きで正しい。
> 4. ✅ **ウィジェット — 完了(2026-06-20・ユーザー承認の上で実施)**。`SmallWidgetView` の実画像取得を実現:
>    widget view 3ファイル(SmallWidgetView/WidgetCatView/RecordPromptChipView)を **app target にも追加**(project.yml・WidgetSnapshot と同一モジュール化)し、
>    `GOExerciseTests/WidgetRenderSnapshotTest` が `ImageRenderer`(170pt@3x=510px・containerBackground グラデ再現)で**実 view・実アセット・実フォント**で 3 状態を描画。
>    **iOS 実描画 × Android 実レンダを横並び照合し全状態一致**(見出し色/サブ/N/7リング/CTA有無/猫状態)。証跡 `proofs/widget_ios_vs_android_3states.png` / `proofs/ios_widget_golden/`。
>    安全策: xcodegen 再生成後に **Info.plist がバイト不変**を確認(手動キーは project.yml 宣言で保持)、**Release ビルド成功**で Archive 安全を確認(CLAUDE.md §3)。
> 5. ✅ **全画面 最終回帰 sweep — 完了(2026-06-20)/ 新規バグゼロ**。density393 実描画で再走:
>    ホーム(365)/履歴/記録入力/**記録完了**/設定(メイン+サブページ)/友達(コード+welcome)/paywall/**体重 premium HeroCard+推移チャート(weight 30件シード)**/**オンボ猫ピッカー(data clear)**。
>    差はデータ/通貨ロケール/文脈(paywall=Weight headline 一致)/CJK タイトル折返し(オンボ大見出しのみ・フォントメトリクス由来の微差)のみ。証跡 `proofs/sweep_*`。
>    **体重チャート**: 期間セグメント(1週|1月|3月|半年|全期間)・surface カード・Y軸kgグリッド・X軸日付・折れ線+破線トレンドが §1-A 是正どおり描画を density393 で再確認。
>    **オンボ猫ピッカー**: ステップ1/2 バッジ・見出し・補足・大プレビュー猫・11種グリッド・招待コード欄まで一致(iOS golden 01)。
>    ✅ **設定の猫ピッカー — 完了(2026-06-20)**。iOS golden を新規撮影(`testCaptureSettingsCatPicker`)→横並びで是正:
>    大プレビュー猫+名前を追加(欠落していた)・タイトル「自分のキャラ」→「自分のキャラを選ぶ」・surface カード撤去(iOS 素背景)・グリッド56dp・11種ブレッド名一致。
>    証跡 `proofs/settings_catpicker_ios_vs_android_FIXED.png` / `proofs/ios_golden_set_cat_picker.png`。残(受容): iOS=sheet(キャンセル/決定) vs Android=push+back(他サブページと統一・即適用)。
>
> ⚠️ **環境前提**: オンライン依存画面(友達/ランキング/設定サインイン/バックアップ)の**実ビルド**確認は、
> このエミュがネット不達のとき不可(memory [[gotcha_android_emulator_no_internet_vpn]])。着手前に `adb shell ping -c1 1.1.1.1`。
> 視覚パリティだけなら **Mock-force でオフライン検証可**(ネット不要)。

## 0. 完了の定義 & 検証手順(毎回これを守る)
1 画面×1 状態の「DONE」= **density 393 で iOS golden と横並び**し、要素(高さ/色/余白/角丸/フォント/整列/アイコン種別/
文言/並び順/空状態)を 1 つずつ照合して一致(差はデータのみ)を確認 + 証跡を `tools/parity/proofs/` に保存。
**証跡なしに ✅ を付けない**(CLAUDE.md ★7)。旧台帳の ✅ は density393 未確認なら本書では未チェック扱い。

**検証ワークフロー(確立済)**:
1. iOS golden: `xcodebuild test -only-testing:GOExerciseUITests/ScreenshotCaptureUITests/<method>`(下表「iOS撮影」列)
   → `xcrun xcresulttool export attachments` → `/tmp/ios_*_golden/clean/`。SIM=iPhone 17 Pro Max(`12A9D608-…`)・build 12。
2. Android: `adb shell wm density 393` 必須。状態は sqlite シード / deep-link / Mock-force ビルドで再現(下表「Android到達」列)。
3. `python3 tools/parity/diff.py --pairs <pairs.json>` で SSIM + 横並び合成 → 要素目視照合 → 是正 → 再照合。
4. DONE にしたら本書の ☑ を埋め、証跡名を記す。

**Android 状態再現の道具**:
- `capture_android.py --match-ios-width`(density393)/ `--seed-streak N [--end-offset M] [--skip-recent K]`。
- Mock-force(友達/ランキング/設定サインイン/紹介): `app-android/local.properties` の SUPABASE 2行をコメントアウト→
  `:app:assembleDebug`→install→検証後 `/tmp/local.properties.realbak_session` から復元。
- premium 解放: Mock billing(既定)で paywall「14日間無料で始める」(in-memory・再起動で揮発)。
- 紹介スター: `goexercise://debug-stars?n=5`(行)/`n=10`(breed-unlock)。
- 周期 ON / 目標・身長: 設定 or 体重タブの UI から入力(DataStore 永続)。

---
## 1. 🔶 旧✅の density393 再照合(最優先・信頼度不明)
> 旧台帳で ✅ だが 440dp 横並び未確認。今回 8 件超の実バグが旧✅から出たため、全数再走が必要。

### 1-A. コア(Supabase 不要・sqlite シードのみ)
- [x] ホーム 達成済(365 seed)— 週ストリップ◎是正済 `proofs/home_weekstrip_*`
- [x] ホーム today-pending(`--seed-streak 9 --end-offset 1`)— todayPending マーカー確認
- [x] 履歴 populated(365 seed)— 凡例/生理日ゲート確認
- [x] 記録入力(空/種目チップ)— 過去欠陥全解消確認
- [x] 記録完了画面(`--end-offset 1`→記録)— praise プール一致
- [x] 体重 paywall/teaser — crown 化確認
- [x] 体重 premium HeroCard — **達成リング実装**(`proofs/weight_hero_ring_*`)
- [x] **体重 premium チャート展開**(推移=Canvas 折れ線+破線トレンド+期間チップ)— golden=`/tmp/ios_golden/clean/06_weight_premium.png`、証跡 `proofs/weight_chart_expanded_ios_vs_android_FIXED.png`。
  **是正4件**(density393 横並びで判明): (1) 期間セレクタ=分割ピル→iOS `.segmented` 相当の一体型セグメント(薄灰トラック+白サム・等幅全幅)
  (2) チャートを surface カード(角丸18・padding16)に載せた(iOS chartSection と同じ・旧=無地直描き)
  (3) Y軸グリッド+kgラベル(右4本)/ X軸 month/day ラベル(下)を追加(旧=軸ゼロ)
  (4) 折れ線/破線トレンドを catmull-rom 平滑化(旧=直線ポリライン)。
  **付随是正**: BMI ストリップの 📏絵文字→ruler アイコン(絵文字全廃)・塗りを chipBackground ピンク→surface@0.6(iOS は Capsule surface.opacity(0.6))・編集ボタン「編集」→pencil+「身長」(iOS Label)。
  残差(データ/設計): iOS は周期帯(Android は周期未シードで非表示=データ差)。設計差2件は §3 へ。
- [x] **日詳細シート 全6状態**(記録/空/休/救済/未来/達成)— golden=`/tmp/ios_sub/clean/sub_day_detail`、証跡 `proofs/day_detail_record_ios_vs_android.png`(記録)+`proofs/day_detail_empty_states_android.png`(休/今日/未来)。
  **是正3件**: (1) 空状態アイコン色を iOS iconColor へ是正(rest/future=textSecondary、missed/todayPending/achieved/rescued=primary。旧 Android は rest/rescue=緑・missed=灰で不一致)
  (2) 空状態を iOS `.medium` detent 相当に=heightIn(min 340dp)領域へ縦中央寄せ(旧=タイトル直下に上寄せの小シート)(3) アイコン円 bg を 0.15→0.12(iOS)。
  記録状態=カテゴリ色見出し+種目行+合計(duration時のみ・iOS同条件)で一致。視覚捕捉=記録/休/今日(=空と同経路)/未来の4状態(density393)。
  救済(snowflake/primary)は rescuedDates シード要のため source 照合で確認(色 緑→primary 是正済)。
- [x] **生理日入力画面**(周期 ON)— golden=`/tmp/ios_sub/clean/sub_menstrual`、証跡 `proofs/menstrual_ios_vs_android.png`(10〜14 マーク済で一致)。
  カレンダーカード(surface r22)/月ナビ(pink 円 chevron)/曜日/グリッド/マーク(pink塗り+赤枠+★+赤数字)/today 強調/未来淡色/「M月の記録:N日」/
  説明カード(chipBg@0.6・3行: タップ★/履歴に★/未来不可)/タブバー残置 まで一致。設計差(back ボタン様式)は §3 へ。
- [x] **オンボーディング step2**(バックアップ)— golden=`/tmp/ios_onboard_step2.png`(新規 `testCaptureOnboardingStep2`)、証跡 `proofs/onboarding_step2_ios_vs_android.png`。
  **是正5件**: (1) タイトル「記録をバックアップしよう」→「機種変更でも記録を引き継ぐ」(2) 説明文を iOS backupStep に一致(自動BU/双方向/メール不要)
  (3) 猫ヒーロー(160dp)を step2 にも追加(iOS は step1/2 とも猫表示。旧 Android は step2 で猫欠落)(4) ボタンをブランド準拠へ=Apple 黒「Apple でサインイン」/ Google 白枠「Google で続ける」+ スキップ「あとで」(旧=pink「…してはじめる」)
  (5) footer caption「あとから設定→…でも有効」中央 + 「もどる」戻る導線を追加。
  残差: もどる様式(§3)/ 猫ヒーロー=iOS は avatar 円・Android は全身(step1 と同一の既定差)/ Apple ボタン文言は iOS system(英表記)vs Android 日本語。
- [x] **ウィジェット StreakWidget** — **iOS `SmallWidgetView` 構図へフル再設計**。証跡 `proofs/widget_android_3states.png`(未達成/達成/回復日)+`proofs/widget_android_{pending,achieved,rest}.png`。
  Glance は任意 Canvas 不可のため、iOS と同一構図を **Android Canvas で 1 枚の Bitmap にレンダ**(`StreakWidgetRenderer` 新設)し Glance は Image 表示。値は iOS の各 View にソース一致:
  背景=温かリニアグラデ+右上ラジアル光彩 / 猫=halo ラジアル円(状態別色: celebrating緑/resting青/…)+白枠 / 週達成リング(bg peach+primary arc+中央 `N/7`) /
  見出し(達成済み!=緑 / 回復日・1分だけでも=橙)+サブ(また明日も続けよう / むりせず整えよう / 23:59まであとN時間) / 未達成のみ CTA「✓ 運動を記録」グラデ capsule・左寄せ。
  旧 Android(中央寄せ・🔥絵文字・「N日連続/今日 達成」)を全廃。**検証**: instrumented `StreakWidgetRenderTest` が 510px 角で render→PNG(MediaStore)→adb pull で3状態を実描画確認(test green)。
  注: iOS golden 側は widget 拡張ターゲット分離で test から ImageRenderer 不可 → 照合は iOS ソース仕様への値一致 + Android 実レンダで担保(横並び iOS 実画像は未取得=ターゲット制約)。

### 1-B. Mock-force ビルドが要る(友達/ランキング/設定サインイン)
- [x] 友達ヘッダ(@username 是正)/ 申請/リスト — `proofs/friends_*`
- [x] ランキング 今週(構造)— `proofs/ranking_*`
- [x] 設定 削除/招待行(プロフィール確立後)— `proofs/settings_*_with_profile`
- [x] **ランキング 今月セグメント** — golden=`/tmp/ios_sr/clean/rank_monthly`、証跡 `proofs/ranking_monthly_ios_vs_android.png`。
  今週|今月 セグメント(今月=白サム)/「今月の順位ルール」カード(①連続日数が長い[pink]・②運動時間が長い[blue]+毎月1日リセット)/
  自分順位カード(N位 pink 円+🐾連続・⏱分)/順位行(金/銀/銅 円+猫アバター+名前+🐾paw・⏱分)+「あなた」自己行ハイライト まで一致。差はデータ(人数/値)のみ。**是正なし**。
- [x] **友達詳細**(hero/統計タイル/cheer 送信)— golden=`/tmp/ios_sub/clean/sub_friend_detail`、証跡 `proofs/friend_detail_ios_vs_android.png`。
  hero(グラデ円アバター+名前+@user·コード+称号バッジ+最終更新)/今日の運動(達成バッジ+カテゴリchip+種目別詳細)/今週の達成(週ストリップ+N/7)/
  統計タイル(連続日数/累計達成日/つながって=connectedSince 有時のみ・iOS と同条件)/応援(入力欄+↑送信+2×2プリセット)/友達を解除 まで一致。
  残差: 第3タイル「つながって」は connectedSince の有無で出/不出(iOS golden=けんじは無し2枚・Android=はるは有り3枚=データ差)。**是正なし**(元から一致)。
- [x] **友達追加シート**(見出し/申請を送る/QR/閉じる)— golden=`/tmp/ios_sub/clean/sub_friend_add`、証跡 `proofs/friend_add_ios_vs_android_FIXED.png`。
  **是正(構造)**: iOS は inset-grouped Form(白カードに 入力欄/申請を送る/QR を行で並べ hairline 区切り・行ボタンは tint 色アイコン+文言・左寄せ)。
  旧 Android は OutlinedTextField 白枠 + 塗りボタン + Outlined ボタンの別部品混在(CLAUDE.md「コンポ型混在/Material 白枠で代用」違反)→ 白カード+行(`FormActionRow`/`FormRowDivider` 新設)へ作り直し。
  申請を送る=コード無効時 dim(iOS disabled)、QR=常時 pink。検索も同じ白カード+「検索」行ボタン化(旧 OutlinedTextField+OutlinedButton 廃止)。結果行もカード内 row に。
- [x] **友達 welcome / 空状態**(通常到達不可=source 照合)— iOS golden は通知ダイアログ被りで不可 → 規定どおり source 照合。
  welcome(未サインイン): 猫140(ユーザー種)+「友達と一緒に続けよう」(title)+「つながると、おたがいの連続記録を見て応援し合えます。\nメールもパスワードも不要です。」+連携ボタン(person.2)— iOS friendsWelcomeBody と一致。
  空状態(0友達): **是正**= iOS friendsEmptyState はカード無しの素 VStack・猫はユーザー選択種 → Android も Surface カード撤去+`myBreed` を `FriendsSection`→`FriendsEmptyState` に配線(旧=surface カード+Default 猫)。猫124@0.95/「まだ友達がいません」(17)/「右上の + から…猫があなたの友達を待っています。」一致。
- [x] **設定サブページ 6種**(density393 横並び)— golden=`/tmp/ios_sr/clean/set_*`、証跡 `proofs/settings_subpages_6up_ios_vs_android.png`(6面一括)+`proofs/settings_notifications_ios_vs_android_FIXED.png`。**STRUCTURAL残は全て解消**(下記とも iOS inset-grouped カードへ一致):
  - [x] カスタマイズ — 1カード3行(テーマカラー→/自分のキャラを変更…オレンジトラ→/達成時の振動 toggle)。ドリルイン化済で一致。
  - [x] 記録と共有 — 周期トグル+caption / 休養ルール disclosure / 友達共有トグル+「体重・体調は共有されません」(green)。一致。
  - [x] 通知設定 — 通知 section+3分割セグメント(OFF|1日1回|1日2回)/通知時間1・2/性格メニュー+説明。**是正**: iOS の「保存して戻る」ボタン+「変更はすぐに反映されます。」caption を追加(旧 Android 欠落)。性格 hint 文言を iOS に一致(例: ひとこと呼ぶ=「朝と夕方、猫からひとこと呼ぶ (デフォルト)」)。
  - [x] データ&プライバシー — 書出/全削除カード+caption 外出し+分析トグル+caption。iOS と一致(プレーン行化済)。
  - [x] 情報・サポート — 意見/不具合カード+アプリ情報カード(アプリ/バージョン/サブスク管理/プライバシー/利用規約/サポート)。一致(version 値は別アプリ採番=データ差)。
  - [x] プレミアム特典・称号一覧 — 無料特典行+称号一覧(色ドット+日数)。一致(現在称号「いま」バッジ・次称号は streak データ差)。
  残差(軽微): disclosure/drill 行の chevron が Android `⌄`/iOS `>`、戻るボタン色(§3 と同根)。

---
## 2. ☐ 未撮影/特殊状態(専用シード or フロー)
- [x] ホーム紹介スター行(`debug-stars?n=5`)— `proofs/home_referral_*`
- [x] 節目ダイアログ(`--seed-streak 9/29 --end-offset 1`→記録→ホーム復帰)— 炎廃止確認
- [x] rescue-use 画面 — `proofs/rescue_use_*`
- [x] **ホーム revive overlay**(RankCelebration + 復活ポップ)— source 照合 + 是正。
  復活ポップ `StreakRevivePopup`(snowflake=AcUnit/「連続N日を守れます」/保険チケットを使う・プレミアムを見てみる/今回はしない)を iOS と照合し、
  **本文文言を iOS に一致**(「お休みした日が埋まって連続記録が続きます(残りN回)。」/「連続を守るには保険チケットがF回必要です(残りN回)。GOプレミアムなら毎月4回使えます。」)。
  RankCelebration は下記「rankup チップ」と同一コンポーネント(ドロップイン追加済)。復活後ホーム=祝福猫+紙吹雪は §1 ホームと共通(既検証)。
- [x] **⭐10 breed-unlock ダイアログ**(`debug-stars?n=10`)— 証跡 `proofs/breed_unlock_android.png`。
  本文「友達を10人紹介しました!設定や猫選びの画面から、好きな猫が無料で選べるようになりました。」+ ボタン「やったね!」= iOS と完全一致(ネイティブ alert)。
  タイトルのみ iOS「⭐10達成!」→ Android「星10達成！」(絵文字全廃方針の意図的置換)。**是正なし**。
- [x] **rankup チップ**(称号が上がる瞬間)— `RankCelebrationOverlay`(上部カプセル=rank チップ+文言・ultraThin/surface@0.94・shadow)を iOS と照合。
  **是正**: iOS は上から spring で「降りてくる」(offset -80→8)→ Android も同じドロップイン offset を追加(旧=alpha フェードのみ)。残: iOS の中央リップル光輪は未移植(極短時の微細演出)。
- [x] **エラーバナー**(友達=通信エラー)— **是正**: iOS errorBanner はアイコン+縦積み(メッセージ上・更新/閉じるを下行)。
  旧 Android は 1 行に icon+message[weight]+更新+閉じるを詰めていた(長文で窮屈)→ icon+Column(message / 更新・閉じる)へ。chipBackground・primaryDeep・⚠️Warning は一致。
- [x] **権限拒否バナー**(通知設定=権限拒否時)— **是正(新規追加)**: 証跡 `proofs/notif_permission_denied_banner_android.png`。
  iOS は未許可時に「通知が許可されていません」+「設定アプリを開く」バナーを出すが Android は欠落していた → `NotificationPermissionBanner` 新設(⚠️+文言+⚙️設定アプリを開く=`ACTION_APP_NOTIFICATION_SETTINGS`)。権限は ON_RESUME で再判定。

---
## 3. ☑ 要判断 → ユーザー裁定(2026-06-20)で確定・対応済
- [x] **画面タイトル/戻るボタンの様式** → 裁定:**iOS に寄せる(中央インライン+丸戻る)**。
  **是正**: 体重「体重」(左22sp)→「体重管理」中央 screenTitle / 友達「友達」(左22sp)→中央(追加アイコンは右上維持)。
  履歴・設定は既に中央 screenTitle・設定 SubPage は既に iOS26 風 丸 chevron 戻る。生理日/ランキングの戻るを素 ArrowBack→丸 chevron(chipBg 円)へ統一。ホームは iOS 同様タイトル無し。
- [x] **体重 推移セクションの内側見出し** → 裁定:**現状維持(重複排除)**。Android はヘッダのみ・選択値はチャート上に浮かせる案を許容。変更なし。
- [x] **初回 paywall 自動提示** → 裁定:**シート型 paywall+cooldown を実装**。証跡 `proofs/weight_paywall_sheet_autopresent_android.png`。
  **実装**: 体重タブ未加入&cooldown 外で `ModalBottomSheet`+`PremiumPaywallRoute` を自動提示(全画面 navigate のループ footgun を回避)。閉じる(×/スワイプ)で 6h cooldown(`SettingsRepository.weightPaywallDismissedAtMs` 新設)、購入時はクリア。手動「GOプレミアムを見る」でも開く。実機で 自動提示→閉→再訪で非提示(cooldown) を確認。
- [x] **設定 STRUCTURAL 残** — **解消済**(§1-B 設定6サブページ照合で確認)。カスタマイズ=ドリルイン化 / データ&プライバシー=プレーン行+caption 外出し /
  通知=3分割セグメント、いずれも iOS Form 構造に一致。

---
## 4. ✅ 今セッション(2026-06-19)是正済の実バグ(参考・再発防止)
1. シード JSON エスケープ破損(全シード無効化)2. 週ストリップ◎マーカー字形 3. 友達@username 自動生成欠落
4. 共有カード グラデ色(2→3stop)+連続既定 ocean+ピッカー位置 5. ハイライトピッカー位置 6. crown(6箇所:paywall/設定×2/体重/履歴/節目バッジ≥100)7. 体重 HeroCard 達成リング+猫+日付の欠落 8. 達成演出の炎(ユーザー指摘)9. 絵文字スイープ(❄️🔘⚪🤝🗑)。
**根本原因の仕組み化**: density393(幅一致)+ golden 横並び を全画面で徹底(旧 411dp/コード照合が見逃しの主因)。

---
## 5. ★ Android 単独 包括 QA(2026-06-20 実施中)
手順=memory [[android_comprehensive_qa_checkpoint]]。3 並列 Claude 監査(ロジック/同期/通知・ウィジェット)+ 実機堅牢性 + Codex 交差検証。

### ✅ 堅牢性(実機 emulator-5554)
- プロセス死→復帰(am kill→再起動): History タブ復元・クラッシュ無し。
- 回転(縦↔横): クラッシュ無し・レイアウト適応(縦優先アプリ・横はスクロール)。全タブ sweep 無事。
- ネット断(wifi/data off)→友達: クラッシュ無し・welcome(再試行 CTA)へ degrade。

### ★是正した実バグ(3件 + テスト追加。unit 343 green)
1. **紹介確認ポップ取りこぼし**(`SupabaseFriendsService.unseenReferrerConfirmations`): UPDATE が取得行に限定されず、SELECT〜UPDATE 間に届いた confirmed を seen 化して祝祭を永久ロス。`isIn("referee_user_id", refereeIds)` を追加(iOS パリティ)。
2. **復活が紹介フリーズボーナスを無視**(`HomeViewModel.reviveState`/`applyRevive`): `RescueTicketAllowance.current(isPremium)` の bonus 無し版で「枠不足」誤判定。`referralStore.currentAccountFreezeBonus` を配線。
   **2b(Codex 交差検証で追加発見)**: ボーナスを全 Missed 日に一律加算していたが iOS は当月のみ(`allowance(for:)`)。月境界で前月 Missed の救済に当月ボーナスを食わせない `RescueTicketAllowance.forDate(date,today,…)` を新設し canReviveAll/applyRevive を per-date 化(境界テスト追加・Codex correct 収束)。
3. **月次達成日数の OS 間乖離**(`HomeStateReducer.monthlyAchievedDays`): Android=カレンダー達成判定+救済込み / iOS=当月に記録のある distinct 日数。友達月次ランキングが不公平。iOS `FriendSharingPreferences` に厳密一致(distinct 記録日)へ。
4. **paywall cooldown を純関数化+テスト**(`WeightPaywallGate` 新設・境界4ケース): 新規ロジックの test gap を解消。

**2LLM 収束**: Claude 3並列監査 → 実バグ確定 → 是正 → **Codex 交差検証で月境界の追加バグ(2b)を発見→是正→Codex「No findings」で correct 収束**。unit 344 green。

### 既知の非ブロッキング所見
- `ReminderScheduler.nextTrigger` が `Calendar.getInstance()`(system clock)で Clock 未注入=テスト不能(実害なし・将来 extract 推奨)。
- ステータス色: iOS は opacity 0.3-0.65 の淡色 / Android は solid(同 hue・従来から受容)。
- 視覚/UX 全状態: §1-§3 で density393 実スクショを全画面で取得済(本 QA でも追加状態を確認)。

---
## 6. 2026-06-20 セッション(友達 初期画面の挙動 & welcome 文言)
ユーザー報告:「Android 友達の初期画面が iOS と違う(iOS は最初からコードが見えるが Android は welcome のまま)」。

### 確定したこと
- **挙動は既に一致**: iOS / Android とも**タブを開く→自動で匿名サインイン→コード画面**(iOS `FriendsView.swift:97-101` / Android `FriendsScreen.kt:138` `LaunchedEffect{ ensureSignedIn() }`)。lazy 廃止のワンステップ化が両 OS 済。
- **「Android だけ welcome」の真因=エミュのネット不達**(ホスト VPN がエミュ NAT 破壊+ゲスト時計破損)。`signInAnonymously()` がネット不達で例外→ generic error→ welcome 着地。**アプリのバグではない**。Supabase 匿名サインインはホストから HTTP 200 で正常(プロジェクト/anon key OK)。詳細 memory [[gotcha_android_emulator_no_internet_vpn]]。

### 是正(commit 97efe43 → main マージ 55b05e6 → push 済)
- **友達 welcome 接続失敗の文言を iOS と統一**: 生の `errorMessage`(「通信に失敗しました…」)→ iOS 固定文「うまくつながれませんでした。少し時間をおいて、もう一度お試しください。」(`FriendsView.swift:242`)。**実機オフライン welcome 撮影で文言一致を確認**(`/tmp/and_welcome_fixed.png`)。

### この画面で残ること(§冒頭「真に未完」#1・#2 に反映済)
- 友達 **サインイン後コード画面**の iOS golden 横並び実視覚照合(**Mock-force ビルドで実施可**=ネット不要)。welcome バナーの最終 sign-off。
