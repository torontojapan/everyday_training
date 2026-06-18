# Android↔iOS 完全一致 パリティ・トラッカー（正本: iOS build 12）

> **目的**: Android の UI/UX を iOS 最新版(build 12)と**完全一致**させる。本書は repo に常駐し、
> セッションを跨いで引き継ぐ唯一の進捗正本。全ギャップを 0 にするまで更新し続ける。
> **強拘束ルールは CLAUDE.md「★最重要・強拘束: UIパリティ検証は最大厳格」を必ず参照。**

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

## 1. 進捗サマリ
- [ ] ホーム  — 重大欠落あり(referralスター行/環境パーティクル/日タップ詳細/猫タップ/各種アニメ)
- [~] 記録入力 — 主要是正済(種目メモ✅/日本語候補✅/重さ4列✅/アコーディオン✅/見出し✅)。残: ピッカー化/体重0-500検証/体調周期独立セクション/メモ複数行/キーボード完了
- [ ] 記録完了 — ほぼ一致(残: きのうから+1行/streak0表示/タイトル)
- [ ] 履歴   — 重大欠落あり(保険チケット折りたたみ+Premium訴求/運動履歴カード/生理日入力行/救済日マーク)
- [ ] 設定   — 欠落あり(情報サポート3リンク/削除gating/PerkGuide/休養ルール詳細/振動トグル/ブランドロゴ/破壊色)
- [ ] 友達   — 重大欠落あり(友達詳細リッチ化/cheer送信ボタン/ブランドロゴ 等。未監査詳細は要追記)
- [ ] ランキング — ほぼ一致(残: 空状態EmptyStateView/サマリーgradient+枠/自分行枠/メダル不透明度/アバターfallback)

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
- [ ] **残**: 時間/回数/セット = ドロップダウン ピッカー化(現状テキスト入力。ラベルは「時間 (分)」化済)。
- [ ] **残**: 体調・周期を独立セクション(見出し「体調・周期」)に(現状 体重カード内ネスト)。
- [ ] **残**: メモ複数行(3..5)。
- [ ] **残**: 体重バリデーション 0〜500kg + disabledReason「体重は 0〜500 kg の数値で入力してください」(info.circle)。
- [ ] **残**: キーボード「完了」ツールバー。
- 注: 「種目」セクション見出しは iOS Form セクション。Android はカード群直置きで省略(許容)。

### B. 記録完了 (iOS RecordCompletionView) — ほぼ一致
- [ ] streakHero を **streak0 でも常時表示**(Android は streak>0 条件)。
- [ ] **「きのうから +1 のばした！」**行(streakExtendedThisRun)。VM に該当フラグ供給が必要。
- [ ] ナビタイトル「記録完了」。

### C. ホーム (iOS HomeView 他)
- [ ] **referralスター行(referralStarsFullRow)**: 上段3行目。`isReferralActive && stars>0 && friendCode!=nil` で ReferralStarsRow(星表示+「あとN人で猫が解放」+招待ShareLink)。Android 完全欠落。
- [ ] **AmbientParticlesView**(常時・時刻別パーティクル: 朝花/昼泡/夕葉/夜星, 18粒, reduceMotionで静止)。Android は完了時 confetti のみ。
- [ ] **週カレンダー日タップ→DayDetailSheet**。Android セル非クリック。
- [ ] **猫タップで bounce + haptic**。
- [ ] RankBadge/CatRankChip に**先頭アイコン(pawprint)**。Android はタイトルのみ。
- [ ] 吹き出しの**pop-in 出現アニメ**(scale0.7→1, fade, spring delay0.15) + lineLimit3。
- [ ] 週カレンダー今日セルの**breathing アニメ**(1.05↔1.0)。Android は静的1.05。
- [ ] revive 成功後の「連続復活!」celebration overlay の有無確認。
- [ ] ⭐10解放アラートのコピーを iOS 厳密一致(「⭐10達成!」「やったね!」本文)。
- [ ] weeklyMini の達成数 monospacedDigit + フォント weight。

### D. 履歴 (iOS StatsView/MonthlyCalendarView/HistoryRowView)
- [ ] **保険チケットを折りたたみ化**: 「今月 N / M 回 残り」動的subtitle + アイコン状態(ticket.fill↔ticket) + 展開(説明「忙しい日に連続記録を守れます。毎月リセットされます。」+「使う日を選んで適用」+ **非Premium向け Premium訴求「GOプレミアムで保険チケットが月4回に」→paywall**)。Android は単純カード。
- [ ] **運動履歴を HistoryRowView 相当**に: 日付グルーピング(見出し sectionTitle)+ per-record カード(surface r18/padding14)+ カテゴリ見出し+SF Symbol+色 + 種目行(回 セット duration 順)+「合計 {duration}」+ **メモ**。Android はフラットテキスト(カード/カテゴリ/合計/メモ 全欠落)。
- [ ] **生理日入力 entry-row**「生理日を記録する / 過去の日付もまとめて入力できます」(★ + chevron, cycle有効時)→ MenstrualEntryView 相当(一括入力)。Android 欠落。
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
- [ ] Apple/Google ボタンに**ブランドロゴ画像**。Google コピー「続ける」→iOS「サインイン」。
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
- [ ] コピーコード時トースト「招待コードをコピーしました」。受信応援トースト(5秒)。初回 表示名入力カード。
- [ ] QR パネルの説明キャプション。申請行のアバターを実猫(paw プレースホルダでなく)+ 申請subtitle に paw。
- [ ] 公園アバター: 影楕円 / 今日バッジ checkmark.seal+白縁 / 長押し解除は iOS に無い挙動(要再考)。トースト下余白 24→64。

### G. ランキング (iOS WeeklyRankingView) — ほぼ一致
- [ ] **空状態を EmptyStateView 化**(pawprint 34dp in 86dp primary@0.12 円 + メッセージを surface@0.75 カード)。Android はテキストのみ。
- [ ] **mySummary カードに gradient(primary 0.18→0.06)+ 枠線(primary@0.4 1.5dp)**。Android はフラット12%。
- [ ] **自分の行に 2dp primary 枠**。
- [ ] メダルの不透明度(金0.85/銀0.90/銅0.85)+ 数字色(金(0.42,0.30,0)/銀(0.28,0.28,0.32)/銅(0.38,0.22,0.08))。
- [ ] アバター fallback を**猫アセット**に(Android は breed null で Pets アイコン)。
- [ ] 戻る = システム戻る(iOS は「戻る」テキストボタン無し)。タイトル中央。

---

## 3. グローバル
- [x] 丸ゴフォント(M PLUS Rounded 1c)同梱・全画面適用。
- [x] ボトムタブ = 浮島型(角丸島/白地/影/選択コーラルピル)+ Material アイコン。
- [ ] iOS golden スクショを repo に保存して参照可能にする(検討)。

## 4. 参照
- 強拘束ルール: `CLAUDE.md` 冒頭「★最重要・強拘束」。
- 作業ログ/手順: memory `android_ios_ui_parity`、`feedback_parity_verification_rigor`、`feedback_verification_workflow`。
- branch: `feature/android-ios-ui-parity`(未マージ)。
