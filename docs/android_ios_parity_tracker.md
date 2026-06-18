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
- [~] 履歴   — **大半是正済**(ITEM2 運動履歴=HistoryRowView相当カード(日付見出し/カテゴリ色見出し/種目行 回ｾｯﾄ時間/合計/メモ)✅ / ITEM5 Monthly空状態dim✅ / ITEM6 All-time「使用M日」✅ / ITEM7 共有コピー・Play URL・運動履歴前へ✅ / ITEM8 grid6dp/Future=surface/TodayPending0.40/生理日色/凡例14・r4・カプセル✅ / ITEM4 救済日セルに ticket グリフ✅)。ITEM3 生理日まとめ入力画面 ✅(スクショ検証済・MenstrualEntryScreen 新設)。**残: ITEM1 保険チケット折りたたみ+残数subtitle+Premium訴求(VMに残数配線要)**
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
