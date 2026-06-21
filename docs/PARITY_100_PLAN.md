# Android↔iOS 100% 一致 計画(2026-06-19・ユーザー厳命)

> 目的: **二度と個別指摘を要さず、Android を iOS build 12 と完全一致**させる。
> リソース/工数は問わない。本書は「なぜズレたか(根本原因)」と「ズレ得ない仕組み」を定義する。

---
## ⚠️ 同期ステータス(正直版・2026-06-19 更新)= **未完了**

> 📋 **動く残タスク台帳の正本 = `docs/PARITY_REMAINING_TASKS.md`**(体系的バックログ・チェックボックス式)。
> 次セッションは**まずそれ**を開いて 1 項目ずつ消化する。本セクションは要約。

**全ページ・全パターンの同期は完了していない。** 旧 ✅ 台帳(`android_ios_parity_tracker.md`・削除済)(セッション4〜17b)は
**信頼できない**: 今セッションで **density 393(=iPhone 17 Pro Max 幅一致)+ golden 横並び**で再照合したところ、
旧 ✅ 画面から**実バグを 8 件超発見・是正**した(週ストリップ◎マーカー字形/友達@username 欠落/共有カードのグラデ色2→3stop・
連続既定 ocean/ハイライト&連続のピッカー位置/**体重 HeroCard の達成リング+猫が丸ごと欠落**/crown がリボン/絵文字 ❄️🔘⚪🤝🗑/節目の炎)。
→ **旧 ✅ は 411dp・コード照合・単発スクショ時代の判定で、視覚一致を保証しない。**

### ✅ 今セッション density393 + golden 横並びで確定(MATCH or 是正済=信頼できる)
ホーム(達成済 / today-pending)・履歴・記録入力・設定(削除/招待行=状態ゲート)・友達ヘッダ(@username)・ランキング(構造)・
連続シェアカード・ハイライト3種・体重 paywall/teaser/HeroCard(達成リング実装)・フル paywall(radio アイコン)・記録完了画面・
節目ダイアログ(炎廃止)・rescue-use・crown 全6箇所・絵文字スイープ。証跡=`tools/parity/proofs/`(~22枚)。

### 🔶 要 density393 再照合(旧 ✅ だが今回未再検証 or 旧✅がバグ含有と判明したカテゴリ)
旧台帳で ✅ だが **440dp 横並びで未再確認**=信頼度不明。優先的に再走すること:
- 設定サブページ 6種(カスタマイズ/記録と共有/通知設定/データ&プライバシー/情報/称号一覧)— 通知設定/データ&プライバシー/
  カスタマイズは STRUCTURAL 残も tracker に記載あり。
- 友達詳細(hero/統計タイル/cheer)・友達追加シート・友達 welcome/空状態・エラーバナー。
- 日詳細シート 全6状態(記録/空/休/救済/未来/達成)。
- 生理日入力画面(周期 ON 時)。
- ランキング 今月セグメント。
- 体重 premium チャート**展開時**(推移=Canvas 折れ線+破線トレンド+期間チップ)。
- オンボーディング step1(猫選択=ほぼ一致確認済)/ step2(バックアップ=未照合)。
- ウィジェット(StreakWidget)。

### ☐ 未撮影/特殊状態(専用シード or 判断が必要)
- ホーム revive overlay(broken→revived: `--skip-recent` で×日作成→rescue 適用フロー)。
- ⭐10 breed-unlock ダイアログ(`debug-stars?n=10`)・rankup チップ。
- 初回 paywall 自動提示(iOS=シート+6h cooldown / Android=teaser のみ。**要判断**: Android paywall は別ルートでループ footgun)。
- 設定の STRUCTURAL 残(tracker §セッション7: カスタマイズ ドリルイン/データ&プライバシー プレーン行/通知 3分割セグメント等)。

### 完了の唯一の基準
**全画面×全状態を density 393 + iOS golden 横並びで再走し、SSIM/要素照合で MATCH を確定**するまで「完了」と書かない。
旧台帳の ✅ は density393 で再確認するまで「未検証」として扱う(今回 8件超の実バグがそれを証明した)。
手段は本書 B/C 章(ハーネス)+ `capture_android.py`(`--match-ios-width`/`--seed-streak`/`--end-offset`/`--skip-recent`)+ Mock-force ビルド。

## A. このセッションで私(AI)が指摘された誤り・根本原因
1. **修正後の自己監査(スクショ横並び)を毎回やっていなかった** ← 最大の欠点。
   - 「コード照合した」「1枚スクショ撮った」で `✅/MATCH` と報告 → 実際は iOS と別物だった。
2. **フォント**: 「iOS は `.rounded`」だけ見て Android 全文字を丸ゴ(M PLUS)にした。実際は
   **iOS の和文は Hiragino ゴシック**(SF Rounded は欧文/数字のみ)。和文の字形が常時ズレていた。
3. **色**: iOS の RGB は移植したが **opacity を落とした**(全不透明)。週ストリップ等が鮮やかすぎた。
4. **共有カード**: 監査エージェントが「カード枠が違う」と挙げたのを「軽微」と却下。実際は
   **iOS=全面グラデ背景+浮きコンパクトカード / Android=クリーム背景+全画面比フルブリード**で完全別物。
   さらに **ハイライトにグラデ選択ピッカーが存在しない**、preview が画面を埋めてピッカー/ボタンが画面外、
   という構造欠陥を見逃していた。
5. **共通の病根**: 「コード一致 ≒ 見た目一致」と過信。golden 横並び+数値差分での検証を習慣化していなかった。

## B. 「ズレ得ない」ための仕組み(これを全部入れる)

### 1. 単一の真実=デザイントークン化(色/不透明度/サイズ/余白/角丸/順序)
- iOS の `Palette` / `Typography` / 各 View の数値(色 RGB**と opacity**・font size・spacing・cornerRadius・
  icon 名・要素順)を **機械可読トークン(JSON)** に抽出し、**iOS と Android が同一トークンを参照**する。
- 「opacity を落とした」「サイズを取り違えた」級のミスを構造的に不可能にする。
- 実装: `design-tokens/*.json` を正本化。iOS は生成 or 手動同期、Android は `AppTheme`/`AppType`/Status色を
  このトークンから生成(ビルド時コード生成 or テストで突合)。トークン不一致は **CI で fail**。

### 2. ★自動ピクセル差分ハーネス(本命)
- 全 画面×状態 で **iOS golden(build 12 sim)** と **Android(emulator)** を**同一データ・同一ロケール・
  固定時刻・対応する画面サイズ**で撮影 → **知覚差分(SSIM / ピクセルΔ)**を自動算出。
- しきい値超で **CI fail**。差分ヒートマップでズレた要素を即特定。人間の「本当に比較した?」を排除。
- 必要要素:
  - **決定論データ**: Android=sqlite 注入(記録)+debug deep-link(`goexercise://debug-stars` 等)+
    `--mock-force-signed-out`/scenario seed。iOS=`--seed-scenario`/`--mock-*`。両者を**同じ状態**に揃える。
  - **固定環境**: 固定時刻(clock 注入)、ja_JP、iPhone17ProMax↔同等 dp/density の対応表、ステータスバー固定。
  - **撮影自動化**: iOS=XCUITest `ScreenshotCaptureUITests`(既存を全状態へ拡張)、Android=adb+uiautomator
    スクリプト(既存手順をスクリプト化)。

### 3. 画面×状態 マトリクスの全網羅
- `semantic_diff.py`(step5)を全画面へ拡張し、**各画面に要素値等値+golden 差分を必須**化。
- 状態到達は **デバッグフックで全て再現可能に**する(referral 星/⭐10/revive/節目/空/エラー/連携ON 等)。
  本セッションで `debugInjectStars` を追加済。同様に revive/節目/エラー/連携状態の debug 注入を全部用意。

### 4. 共有カード等「描画物」は仕様駆動で同一生成
- 共有カード(連続/週/月/全)は **1 つのレイアウト仕様**(要素・相対サイズ・色・順序)から iOS/Android が
  それぞれ描く。最低でも **export 画像**は同仕様・同寸法で生成し、ピクセル差分で担保。
- 「猫を iOS 比率(カード幅比≈0.55)で描く」等の比率もトークン化。

### 5. プロセス規律(AI/人間共通の鉄則)
- **`✅/MATCH` と書く時は必ず「iOS golden と Android の横並び画像 + 数値差分スコア」を添付**する。
  添付の無い完了報告は無効。← 今回の私の失敗を二度と起こさない第一防壁。
- 修正 → **必ず再ビルド→実機→横並び自己監査→差分OK**まで1サイクル。途中で報告しない。
- 2LLM 監査は **コードでなく差分画像**に対して敵対的に行う。

### 6. フォント/ロケール/レンダラ差の明文化
- 和文=端末ゴシック(Noto Sans CJK)、欧文/数字=丸ゴ(M PLUS Latin)。トークンに記載済の方針を固定。
- SwiftUI↔Compose のレンダラ差(アンチエイリアス/字間)は **しきい値(SSIM≥0.97 等)で吸収**。
  「完全同一ピクセル」は font/エンジン差で原理的に不可能 → **知覚的に区別不能**を合格基準とする。

## C. 実行順(この計画の着手手順)
1. 撮影+差分の CI スクリプトを作る(iOS XCUIT 全状態 / Android adb 全状態 / SSIM 比較 / レポート HTML)。
2. デバッグ状態フックを全状態ぶん用意(注入/seed/deep-link)。
3. デザイントークン JSON を iOS から抽出 → Android を突合(不一致 fail)。
4. 全 画面×状態 を差分にかけ、**しきい値超を 0 にするまで**修正ループ(横並び添付必須)。
5. 以後の変更は CI の差分ゲートを通らないとマージ不可。

> これを全部入れれば、Android は iOS build 12 と**知覚的に区別できない**水準で固定され、
> 個別指摘は不要になる。基準=各セル SSIM ≥ 0.97 かつ構造(要素/順序/文言/色トークン)完全一致。

---
## 現在地 / 再開手順(2026-06-19 セッション末・コンテキスト満杯で中断)
**完了済(コミット済・branch feature/android-ios-ui-parity)**:
- 今セッションの UI 是正: ランキング今月/友達(welcome/空/詳細名前)/履歴 保険チケット展開/共有カード
  (連続・ハイライト=全面グラデ背景+浮きコンパクトカード+グラデ選択ピッカー+iOS配色ボタン+X、
  サイズ/猫比率を iOS へ、**絵文字を全廃し白単色ベクターアイコン**へ)/体重 折りたたみ+paywall/設定 削除reactivity/
  フォント(和文ゴシック+欧文丸ゴ)/週ストリップ色を iOS 低不透明度へ/節目を全画面祝福+ボタン対称化/rescue画面/
  referral スター・⭐10(debugInjectStars 追加)。
- **ハーネス構築完了**: `tools/parity/diff.py`(SSIM+差分ヒートマップ+HTMLレポート+**マスク領域**)/
  `tools/parity/capture_android.py`(adb 駆動・sqlite シード・画面レシピ)/ `tools/parity/README.md`。
  end-to-end 動作確認済(撮影→差分→parity_report/index.html)。

---
## 差分ゼロ化ループ 第1サイクル実施ログ(2026-06-19 セッション3)
**ハーネス end-to-end 実走を確立**(撮影→シード→差分→目視照合のフルサイクルを実証):
- iOS golden 11画面を XCUIT で撮影し抽出済(`testCaptureAppStoreScreenshots` → `/tmp/goex_golden.xcresult`
  → `xcrun xcresulttool export attachments` → `/tmp/ios_golden/clean/{01..11}.png`)。
- Android を iOS yearly と同一データ(365日連続)に sqlite シードして撮影(home/history)。

### 🐞 是正した実バグ(2件)
1. **シード JSON エスケープ破損(致命的)** `tools/parity/capture_android.py`: SQL 単一引用符文字列内で
   二重引用符を `\"` にエスケープしていたため exercisesJson が無効JSON化→`WorkoutMappers.toDomain` の
   decode 失敗→exercises 空→**全シード記録が活動日に数えられず 0日連続**になっていた。`.replace('"','\\"')` を削除。
2. **週ストリップ活動マーカーの字形差(home フラグシップの実視覚欠陥)** `HomeScreen.kt`:
   iOS は `status.symbol`(◎)を **SF Rounded のテキストグリフ=細い二重リング**で描くが、Android の
   `AppType.headline`=M PLUS Latin サブセットに◎が無く端末フォント(Noto)へフォールバック→**小さい塗りドット**
   になっていた。`WeekdayStatusMarker` を新設し ◎/○/・ を **Canvas で SF 相当の細リング**に再現(休/×/- は Text 維持)。
   証跡=`tools/parity/proofs/home_weekstrip_ios_vs_android_fixed.png`(横並び・修正後一致確認済)。

### ✓ 照合の結果「一致」または「誤検知」と確定(裏取り済)
- **home バッジ**(レジェンドネコ青グラデ+黒肉球 / 今日は達成済み 緑+スカラップ✓):一致。
- **猫メッセージプール**:`comm` で「Android にしか無い文言=0、iOS にしか無い=55」だが、欠落55は iOS の
  **dead code** `CatMessageProvider.message(for status:time:)`(DayTime 版・**外部呼び出し無し**)由来。
  home/ウィジェットは両OSとも CatState 版を使い Celebrating=10件**完全一致**。→ **欠陥でなく誤検知**。
- **履歴 生理日行**:iOS は `cycleSettings.isEnabled` 条件付き。Android も `if(cycleTrackingEnabled)` で
  同文言「生理日を記録する/過去の日付もまとめて入力できます」+★22sp Black 同色を描画。**一致**(私のキャプチャは
  周期 OFF だったため非表示=設定差)。
- **記録入力(過去 MATCH 誤報告の画面)= 全要素一致を density393 で確認**(証跡 `proofs/record_ios_vs_android.png`):
  過去欠陥の「種目メモ欄欠落」→PRESENT / 「重さ配置違い」→4列目に正配置 / 「候補チップ日本語デフォルト未表示」→
  スクワット/腕立て伏せ/プランク/腹筋… PRESENT / 「アコーディオン無し」→種類アコーディオン(^)PRESENT、全て解消。
  「体調・周期/今日は生理日」トグルは両OSとも `cycleTrackingEnabled` ゲート(非表示=設定差で一致)。
  体重ヒントは両OSとも同一ロジック(`前回: %.1f kg` / 無ければ `体重を入れるとグラフに反映されます`)=データ差のみ。

### 設定画面(density393 で照合・セッション継続分)
- **「アカウントを削除」(5.1.1(v) コンプラ)/「友達を招待する」が現キャプチャで非表示** → **欠陥でなく状態差**と確定:
  両行とも Android コード上存在し iOS と**同条件ゲート**(削除=`if(hasAccount)` ↔ iOS `profile != nil`、コメントにも明記/
  招待=`isReferralActive`+friendCode)。非表示の理由=`myFriendCode = friendsService.myProfile()?.friendCode` が
  **null**(プロフィール未確立)。本 APK は local.properties 空ビルドで**友達タブが「準備しています…」でスタック**し
  匿名サインインが完了しないため。
- 一致確認: 設定タイトル/バックアップトグル/サインインボタン2種/アプリを友達にシェア/GOプレミアム+14日間無料/
  プレミアム特典・称号一覧>/紹介した友達 0人/招待コード入力。
- **LOW 文言差**: バックアップ節の説明文。iOS(サインアウト時)=「Apple / Google でサインインすると…(メール・パスワード不要)。」
  をボタン上+長文を section footer(節末)に。Android=長文をトグル直下+「機種変更で確実に復元するには…(連携でバックアップが自動 ON)。」。
  文言と配置順が微差。機能は等価。次サイクルで iOS サインアウト状態を厳密採寸して寄せる。

### 🐞 是正した実バグ④: 共有カード(連続)のグラデが iOS と別物(failure#4 領域)
`ShareCardGradient.kt` の 5 プリセットが **2 ストップの Material 近似色**で iOS の **3 ストップ カスタム RGB** と
別物だった。さらに連続カード既定が **Sunset(暖色)** で iOS の **ocean(寒色)** と相違、ピッカーが**ボタンの上**に
あり iOS(「写真に保存」の**下**)と順序逆だった。是正:
- 5 プリセット色を iOS `ShareCardGradient.swift` の 3 ストップ RGB を厳密移植(sunset/ocean/twilight/forest/daybreak)。
- 連続カード既定を **Ocean** に(`SettingsRepository.shareGradient` 未設定既定 + `StreakShareUi` 初期値、
  iOS `@AppStorage("shareCard.gradient.streak")=.ocean` パリティ)。
- `StreakShareScreen` のピッカーを**最下部(写真に保存の下)**へ移動。
- SNSで共有ボタンの「濃い色」差は**背景グラデ差(暖色)由来**で、ocean 既定化で解消(ボタン自体は black@0.45 で一致)。
- 横並び実証=`proofs/streak_share_ios_vs_android_FIXED.png`(ocean 背景・浮きカード・ピッカー最下部が一致)。全テスト green。
- **ハイライト3カードも照合完了**(iOS golden=`testCaptureRemainingStates` の rem_hl_*):
  背景の per-kind 既定色は一致(weekly=ティール緑/monthly=twilight紫/alltime=橙→珊瑚)、カード構造・統計表(最長連続/
  合計時間/種目数/イチオシのカテゴリ/推し種目)も一致。**ピッカーがボタンの上にあった同型バグを最下部へ是正**
  (`HighlightShareScreen`)。証跡=`proofs/highlight_share_x3_ios_vs_android.png`。統計の数値は seed データ差(単一種目シードのため 0分/種目数小)。

### 残状態の seed レシピ整備(次サイクルで確定的に到達するための infrastructure)
`capture_android.py seed_streak` に 2 オプション追加(2026-06-19 検証済):
- `--end-offset N`: 連続の終端を today から N 日前へ。**milestone-eve** = `--seed-streak 9 --end-offset 1`
  (9日連続・昨日まで=今日 pending → 今日記録で 10 日連続=節目発火。Android 連続節目しきい値=最小 10、以後 30/50/100…)。
  実機で「9日連続・今週 月火水木=◎/金=・(todayPending)・CTA『今日の運動を記録する』」を確認。
- `--skip-recent N`: 連続中の直近 N 日を未記録に=**× 未達成日**を作る(rescue-use の適用対象が要る画面用)。
- これで rescue-use / 節目ダイアログ / today-pending ホーム等が再現可能に(節目ダイアログ・rescue-use の最終撮影は
  記録→ホーム復帰 / 履歴→保険チケット→適用 の UI フローが要るため次サイクル)。

### ✅ 是正した実バグ⑦(HIGH): 体重 HeroCard の「達成リング+猫」+日付を実装
`WeightHeroDashboard.ringWithCat` を Android に移植: `HealthPrefs.progressRatio()`(iOS 完全移植)+ `WeightViewModel` に
breed(settings.catBreed)/progress を追加 + `WeightScreen.WeightAchievementRing`(Canvas drawArc 背景リング+進捗 -90°round-cap +
中央 surface円+CatImage + 右下%バッジ primaryDeep capsule 白枠)+ HeroCard を「ヘッダ(最新の体重·日付)→ Row[体重+チップ |
リング]→ 開始→目標」に再構成。50% デモで リング/猫/%/日付/開始→目標 全要素一致を実証
(`proofs/weight_hero_ring_ios_vs_android_FIXED.png`)。全ユニットテスト green。

#### (参考)是正前の所見
Mock 購入(`PLAY_BILLING_ENABLED` 未設定=Mock billing。paywall「14日間無料で始める」で isPremiumActive=true・**ただし
in-memory でアプリ再起動で揮発**)→ 体重 entries+目標+身長をシード/設定して照合(`proofs/weight_premium_ios_vs_android.png`):
- **構造一致**: HeroCard / 記録する / レポート / 推移(「30日で30件記録」は iOS と完全一致)/ 履歴。
- **欠落①(コンポーネント)**: iOS `WeightHeroDashboard.ringWithCat` = HeroCard 右の **達成リング(円弧進捗)+ 中央に選択猫 + 右下%バッジ**が
  **Android HeroCard に存在しない**。iOS 仕様: ring 108 / line 9 / 背景リング primary@0.18 / 進捗 primary round-cap -90°開始 /
  中央 surface円(84)+猫画像(82, clipCircle) / バッジ "{N}%" white on primaryDeep capsule offset(30,38)+白枠2。
  実装に要: `WeightUiState` に **progress(=(start-cur)/(start-target) clamp)** と **breed** を追加(VM に breed flow 注入)+ Compose Canvas drawArc + 既存 CatAvatar。
- **欠落②**: 「最新の体重 · {日付}」の**日付**が Android に無い(iOS は記録日時を表示)。
- 開始値(開始 75.0 →)は Android コードに有(`WeightScreen` line270 `startKg?.let`)だが私のシードで startKg 未導出のため非表示=データ差。
- **LOW**: チップ構成差(iOS「圏内 達成」/ Android「✓目標圏内」+「🎯目標達成」+「⏳あと約N日」の3つ)。

### ホーム紹介スター行 / rescue-use(セッション継続分)
- **ホーム紹介スター行=一致を実証**(`proofs/home_referral_ios_vs_android.png`): Mock build で友達タブ訪問(profile/code 確立)
  → `goexercise://debug-stars?n=5` → ホームに「★5金+5空 / あと5人で猫が解放」が iOS と同配置・同文言で表示。
  行は**コード元から正**(`isReferralActive && stars>0 && code!=null`=iOS 同条件)で、現 APK(実 Supabase・connect 前)では code=null のため非表示だっただけ=**状態ゲート**。
- **rescue-use(保険チケットを使う)=次サイクル送り**: 365連続シードだと×(未達成)日が無く rescue-use 導線が出ない+
  無料は「今月 1/1回残り」(iOS golden は 4/4=premium)。クリーン照合には**専用シード(過去に未達成日を作る)+premium mock** が要る。

### 体重タブ / ペイウォール照合(セッション継続分)
- **ペイウォール本体=ほぼ完全一致**(`proofs/paywall_ios_vs_android.png`): タイトル「GOプレミアム」/「体重タブの全機能を
  解放しよう」/特典7項目(アイコン+文言: 記録+推移グラフ/週次月次レポート/周期オーバーレイ/目標BMI達成リング/
  保険チケット月4回/減量マイルストーン/全11種の猫)/年額おすすめ+月額/14日間無料で始める/購入を復元/fine print。
  **価格の数値**(iOS ¥22.99 vs Android ¥3,800 等)は StoreKit/Play のストア環境差(「実質約¥317/月・34%お得」コピーは一致)。
- **体重タブ teaser(非premium)**: iOS `WeightTabRootView.lockedOverlay` と Android `WeightScreen.LockedOverlay` は
  文言一致(「体重タブは GOプレミアム機能です」/「14日間無料でお試し…推移グラフ・BMI・レポート・周期オーバーレイ…」/
  「GOプレミアムを見る」/「ホーム画面の『記録する』からの体重入力は引き続き無料」)。
- ✅ **アイコン crown=是正済**: `ic_crown.xml`(3山+基部バンドの王冠ベクター)を新設し、WorkspacePremium(リボン)を
  4箇所(PremiumPaywallScreen/WeightScreen teaser/設定アップグレード行/設定加入中行)で置換。体重 teaser で王冠描画を実証
  (`proofs/premium_crown_icon_FIXED.png`)。
- **⚠️ 未是正の差(要判断)**:
  1. **初回自動提示**: iOS は weight タブを開くと**未加入なら paywall シートを自動提示**(`updateGate()`→`showPaywall=true`、
     X 閉じで 6h cooldown)。Android は teaser のみで自動提示しない。**ただし Android の paywall は別ルート(全画面)なので
     自動 navigate はループ footgun リスク**があり、安易移植は不可。iOS と同じ「シート型 paywall + cooldown」を別途設計してから実装する(要判断)。

### Mock-force ビルド手順(確立)+ 友達/ランキング/設定サインイン照合(セッション継続分)
- ⚠️ `secret()` は **`app-android/local.properties`**(repo ルートでなく gradle ルート)を読む。ここに実 Supabase 鍵が
  入っていると friends が実接続待ちで「準備しています…」スタック。**Mock 化** = `app-android/local.properties` の
  `SUPABASE_HOST`/`SUPABASE_ANON_KEY` をコメントアウト → `:app:assembleDebug`(BuildConfig が `SUPABASE_HOST=""` に
  再生成=isConfigured false→MockFriendsService)→ install。**検証後 `/tmp/local.properties.realbak_session` から復元**(済)。
  ※ local.properties 変更は Gradle のタスク入力に乗らず BuildConfig が stale になりがち → 確実を期すなら `:app:clean`。

### 🐞 是正した実バグ③: 友達 自分プロフィールの @username が空(Mock でなく実挙動)
- iOS は匿名サインインで `username: generatedUsername()`=`"neko"+UUID英数字6文字小文字`(例 @neko2f669b)を付与し、
  自分ヘッダに **@username 表示**+username 検索可。Android `FriendsViewModel.connect()` は `username = ""` を渡し、
  FriendsScreen は username 非空時のみ @行を描くため **@ハンドルが出ず・検索もできなかった**。
  → `generatedUsername()` を iOS 完全移植(同companion)して `connect()` で付与。`@nekoc9d16b` 表示を実証
  (`proofs/friends_self_username_FIXED.png`)。friends ユニットテスト green。

### ✓ 友達/ランキング/設定(プロフィール確立後・Mock build・density393)で照合
- **設定**: プロフィール確立後に「**アカウントを削除**」(5.1.1(v) 赤・trash)と「**友達を招待する**」が**出現**=
  状態ゲートだった分析をスクショで確証(`proofs/settings_android_with_profile_delete_invite_present.png`)。
- **友達**: ヘッダ(アバター/表示名/@username[修正後]/連続)/友達コード+copy/share/QR/表示名決めカード/アプリ共有/
  申請カード+承認・×/友達リスト+順位を見る・連続日数順=一致。友達数(2 vs 10)・名前=mock データ差。
- **ランキング**: タイトル/今週・今月セグメント/順位ルールカード(①連続②運動時間)/自分順位カード/メダル色丸(金銀銅)+
  名前+🐾連続+⏱分=一致(`proofs/ranking_ios_vs_android.png`)。**LOW**: 戻る=iOS 丸囲み`<` / Android 赤`←`。人数=データ差。
- **LOW**: 設定「友達を招待する」は iOS=プレーン行(Label+share icon)/ Android=副題付きカード。機能等価。

### ✅ 方法論ギャップ=解消済(density で幅一致)
- **emulator go_test は論理幅 411dp、iPhone 17 Pro Max は 440pt**(約6.5%狭い)。幅依存レイアウトで
  **偽の差分**が出ていた。実例=履歴の凡例「未達成」が Android で「未達」に切れていた。
- **根治**: `adb shell wm density 393` で 1080/(393/160)=439.7dp ≈ 440pt にすると **iPhone 17 Pro Max と幅一致**。
  これで凡例「未達成」が**完全表示**になることを実証(証跡 `tools/parity/proofs/history_legend_android_440dp_fits.png`)。
  → **凡例切れはコード欠陥でなく device-width アーティファクトと確定**。LegendSwatch は両OSとも 11sp で一致。
- `capture_android.py --match-ios-width` で density=393 を自動適用(撮影は必ずこれを付ける)。戻すには `adb shell wm density reset`。
- SSIM 全画面値はアスペクト比差(iOS 0.460 / Android 0.450)+ 猫アート差で原理的に 0.97 に届きにくい。
  **SSIM はスクリーニング、合否は要素単位の目視**(CLAUDE.md)。home masked SSIM=0.91 だが要素照合では週ストリップ以外一致。

### 次セッションでやること
1. ~~幅一致 AVD~~ → **解決済**: `adb shell wm density 393`(または `capture_android.py --match-ios-width`)。
   ★全 Android 撮影は density 393 で行う(411dp で撮ると幅依存画面が偽 FAIL)。
2. 残り画面の Android 撮影(record/settings/weight/friends/ranking)→ iOS golden と要素照合。friends/ranking は
   Mock ビルド(local.properties SUPABASE 空)+ deep-link/mock arg が要。
3. **両OS決定論フック**(連続/猫種/グラデ/poseSeed/時刻)で共有カード等を揃える。揃えにくい領域は `masks`。
4. 全セル要素一致で完了 → 差分ゲート CI 化。

**再現コマンド(検証済)**:
```
# iOS golden(sim=iPhone 17 Pro Max booted, build12)
xcrun simctl uninstall <UDID> com.goexercise.app
xcodebuild test -project app/GOExercise/GOExercise.xcodeproj -scheme GOExercise \
  -destination 'id=<UDID>' -derivedDataPath /tmp/goex_dd \
  -only-testing:GOExerciseUITests/ScreenshotCaptureUITests/testCaptureAppStoreScreenshots \
  -resultBundlePath /tmp/goex_golden.xcresult
xcrun xcresulttool export attachments --path /tmp/goex_golden.xcresult --output-path /tmp/ios_golden
# (manifest.json の suggestedHumanReadableName で {01..11}.png にリネーム)
# Android(emulator go_test, debuggable APK install 済, PATH に platform-tools)
python3 tools/parity/capture_android.py --seed-streak 365   # ★app停止中に実行→WAL checkpoint→起動
adb shell am force-stop com.goexercise.app && adb shell am start -n com.goexercise.app/.MainActivity
adb exec-out screencap -p > /tmp/and_caps/home.png
python3 tools/parity/diff.py --pairs pairs.json --out-dir parity_report
```

**環境**: emulator go_test 起動中(411dp)/ Mock 撮影は local.properties の SUPABASE 空+再ビルド(検証後 /tmp/local.properties.realbak2 から復元)/ iOS golden は build 12 sim(/tmp/goex_dd)+ XCUIT 撮影 → xcresulttool export。

---
## D. 恒久化した強制レイヤ(2026-06-21・約150件のフォントドリフト発覚を受けて)

### なぜ §B/§C があっても ~150 件のズレが残ったか(真因の更新)
1. **§B の「デザイントークン」は提案止まりで未強制**だった。コードに生 `fontSize` 136 / 生 `fontWeight` 101 /
   ハードコード色 16 が残存し、毎回手打ちでドリフトしていた(iOS 値と機械的に結ばれていない)。
2. **★ §B-2 の SSIM/ピクセル差分は、今回の不具合を原理的に検出できない。** `.heavy`(800)↔`Black`(900) の
   1段差や 12↔13sp の 1px 差は **SSIM ≥ 0.97 を通過**する。perceptual 検証は微小タイポグラフィに盲目で、
   ハーネスは ~150 件を全部グリーン判定していた。→ **検証は perceptual でなく semantic(値そのものの突合)にすべき。**
3. **「✅ は横並び添付必須」は規律依存**で、規律は繰り返し破れた。

### 実装済みの強制(コミット済・これで新規ドリフトは構造的に不可能)
- **トークン拡張** `ui/theme/Font.kt`: iOS Dynamic Type 全スタイルを `AppType` に追加
  (callout16 / subheadline15 / footnote13 / caption2:11 / largeTitleXL28 / navTitle=headline)。「正しいトークンが無く近似」を解消。
- **ドリフト源ガード** `tools/parity/parity_guard.py`: presentation 配下で 生 `fontSize` / `Color(0x…)` /
  `FontWeight.Black` を**禁止**。正当例外は行末 `// parity-allow: 理由`。baseline 方式で**新規違反のみ fail**。
- **iOS 値固定テスト** `AppTypeParityTest`: AppType の (size, weight) が iOS build 12 の値と一致しなければ CI fail。
- **CI ゲート** `.github/workflows/android-parity.yml`(guard + token テスト)。**ローカル** `.githooks/pre-commit`
  (`git config core.hooksPath .githooks` で有効化)。

### 残ロードマップ(完全一致=baseline 0 までの funded 作業)
1. **既存 156 ベースラインの token 化**: 各生 fontSize を、iOS ソースの該当要素を実測して対応 `AppType.X` に置換し
   baseline を減らす。完了後 `parity_guard.py --strict` を CI 既定にする(= 生値ゼロを恒久強制)。
2. **★ semantic UI ツリー差分ハーネス(本命の検証)**: iOS snapshot ツリー(XCUITest)と Android semantics ツリーから
   各 Text の (文言 / 解決後 size / 解決後 weight / 色トークン) を抽出し**要素単位で等値検証**。
   SSIM が盲目な 1段・1px 差を決定論的に検出する。これを全画面×状態で CI ゲート化したら「個別指摘」は不要になる。
3. **フォント監査ワークフローの保存**: 本セッションの「5並列で Android 生フォント vs iOS ソースを要素突合」を
   名前付きワークフロー化し pre-merge 必須にする。
