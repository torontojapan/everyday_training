## P0 — High impact, must fix

- [記録入力 / `app/CerealExercise/CerealExercise/Views/RecordEntryView.swift:102`] 保存ボタンが無効化されるため、未入力時に何を直せばよいかユーザーが分かりません。保存ボタンは押せる状態にして、`ExerciseInputRow` の「種目名」直下に「種目名を入力してください」をインライン表示してください。  
  Effort: M

- [記録入力 / `app/CerealExercise/CerealExercise/Views/ExerciseInputRow.swift:47`] 「分 / 回数 / セット」が横並びのプレースホルダーだけで、入力後に単位や意味が消えます。各 `TextField` を `LabeledContent` 風にして、上に「時間」「回数」「セット」、右に「分」「回」「セット」を残してください。  
  Effort: M

- [記録入力 / `app/CerealExercise/CerealExercise/Views/RecordEntryView.swift:73`] 体重が不正値でも運動記録は保存され、体重だけ silently に無視されます。`weightInput` が空でない && `parsedWeight == nil` の時は「0〜500kgの範囲で入力してください」を表示し、保存時にも警告してください。  
  Effort: S

- [共通ボタン / `app/CerealExercise/CerealExercise/Views/Components/PrimaryButton.swift:39`] `DragGesture(minimumDistance: 0)` が全PrimaryButtonに入っており、フォームやスクロール中のタッチを奪いやすいです。押下アニメーションは `ButtonStyle` の `configuration.isPressed` に移し、スクロール摩擦を減らしてください。  
  Effort: M

- [友達一覧 / `app/CerealExercise/CerealExercise/Views/FriendsView.swift:321`] 友達カード全体が `Button` なのに内部にも応援 `Button` があり、タップ対象が競合します。カードの詳細遷移は上部プロフィール行だけに限定し、応援ボタン行は親ボタンの外へ分離してください。  
  Effort: M

- [友達一覧 / `app/CerealExercise/CerealExercise/Views/FriendsView.swift:408`] `contextMenu` の「友達を解除」が即実行で、誤操作から戻れません。`FriendDetailView` と同じ確認ダイアログ、または5秒程度のUndoトーストを挟んでください。  
  Effort: M

- [月間カレンダー / `app/CerealExercise/CerealExercise/Views/MonthlyCalendarView.swift:111`] 日付セルの高さが38ptで、Apple推奨の44ptタップ領域を下回ります。セルを `frame(height: 44)` にし、グリッド間隔を6→4程度に調整して月表示を保ってください。  
  Effort: S

- [月間カレンダー / `app/CerealExercise/CerealExercise/Views/MonthlyCalendarView.swift:47`] 月移動ボタンが36ptで小さく、親指操作で押しにくいです。見た目の円は36ptのままでも、外側に `.frame(width: 44, height: 44)` を足してヒット領域を広げてください。  
  Effort: S

## P1 — Worth doing

- [ホーム / `app/CerealExercise/CerealExercise/Views/HomeView.swift:33`] 最重要CTAがスクロールコンテンツ内にあり、下へ流れると再記録導線が消えます。`safeAreaInset(edge: .bottom)` に「今日の運動を記録する」を固定表示し、既存位置はサマリー下へ移すか重複を避けてください。  
  Effort: M

- [ホーム / `app/CerealExercise/CerealExercise/Views/HomeView.swift:161`] 「あとX時間」だけでは何の残り時間か分かりにくいです。「今日の締切まで あとX時間」または「0時まで あとX時間」に変更してください。  
  Effort: S

- [ホーム / `app/CerealExercise/CerealExercise/Views/HomeView.swift:187`] 月次レビューはデータがない月でも常に押せるため、空レビューに見えます。前月記録が0件なら「先月の記録はまだありません」と副文を変え、ボタンを弱めるか空状態シートにしてください。  
  Effort: S

- [週間カレンダー / `app/CerealExercise/CerealExercise/Views/WeeklyCalendarView.swift:32`] 今日セルの `repeatForever` アニメーションが常時動き、低モーション設定への配慮がありません。`@Environment(\.accessibilityReduceMotion)` で停止し、動きの代わりに枠線で強調してください。  
  Effort: S

- [週間カレンダー / `app/CerealExercise/CerealExercise/Views/WeeklyCalendarView.swift:45`] 記号だけの丸表示は、達成・休養・未達成の意味が初見で分かりにくいです。カード下部に「○ 達成 / 休 休養 / × 未達成」の小さな凡例を追加してください。  
  Effort: S

- [月間カレンダー / `app/CerealExercise/CerealExercise/Views/MonthlyCalendarView.swift:106`] 日付セル内の状態が記号中心で、★とチケットの意味も画面上に説明がありません。`footerSummary` の下に「★ 体調・周期 / 🎫 保険チケット」の凡例を出してください。  
  Effort: S

- [月間カレンダー / `app/CerealExercise/CerealExercise/Views/MonthlyCalendarView.swift:119`] 体調・周期マークが★で、達成評価のスターに見えやすいです。小さな `drop.fill` や `heart.fill` など意味が近いSF Symbolに変え、色だけに頼らないラベルを凡例に入れてください。  
  Effort: S

- [履歴 / `app/CerealExercise/CerealExercise/Views/HistoryView.swift:46`] 日付見出しが `yyyy/MM/dd` だけで曜日がなく、習慣の振り返りに弱いです。`M月d日(E)` に変更し、年は年跨ぎ時だけ補足してください。  
  Effort: S

- [履歴 / `app/CerealExercise/CerealExercise/Views/HistoryRowView.swift:14`] 種目、回数、セット、時間が1行テキストに結合され、長い種目名で読みにくくなります。種目名を左、数値サマリーを右のチップ群に分けて視線のスキャン性を上げてください。  
  Effort: M

- [設定 / `app/CerealExercise/CerealExercise/Views/SettingsView.swift:53`] 共有設定の説明が1文に詰まり、重要な「体重・体調は共有されない」が埋もれています。本文を2行に分け、プライバシー保護文だけ `Label("体重・体調は共有されません", systemImage: "lock.fill")` にしてください。  
  Effort: S

- [設定 / `app/CerealExercise/CerealExercise/Views/SettingsView.swift:75`] 「Toggle」が日本語UIに露出しています。「ONにすると、運動記録画面に体調メモの項目が表示されます」に置き換えてください。  
  Effort: S

- [設定 / `app/CerealExercise/CerealExercise/Views/SettingsView.swift:112`] 自動休養日の説明が長く、設定画面の主タスクを押し下げています。初期表示は2行要約にし、「詳しく見る」で展開する DisclosureGroup にしてください。  
  Effort: M

- [友達一覧 / `app/CerealExercise/CerealExercise/Views/FriendsView.swift:260`] ランキング、リーグ、並び替えが小さなアイコン/絵文字ボタンで並び、何の操作か見つけにくいです。「ランキング」「リーグ」「並び順」のテキスト付きチップに統一してください。  
  Effort: S

- [友達一覧 / `app/CerealExercise/CerealExercise/Views/FriendsView.swift:363`] 今日の種目名を `" / "` で連結しており、長いメニューでカードが読みにくくなります。最大2件をチップ表示し、3件以上は「ほかN件」で詳細画面へ誘導してください。  
  Effort: M

- [友達追加 / `app/CerealExercise/CerealExercise/Views/FriendAddView.swift:30`] 友達コードの入力ルールがエラー時だけ出るため、初回入力で迷います。TextField下に常時「6桁・O/0/I/1なし」を薄く表示し、無効時は赤ではなく修正方法として表示してください。  
  Effort: S

- [友達追加 / `app/CerealExercise/CerealExercise/Views/FriendAddView.swift:54`] 検索未実行でも入力した瞬間に「見つかりませんでした」が出る可能性があります。`hasSearched` 状態を追加し、検索完了後だけ空結果を表示してください。  
  Effort: S

- [プロフィール作成 / `app/CerealExercise/CerealExercise/Views/FriendsView.swift:526`] 表示名・ユーザー名に文字数や使用可能文字の即時フィードバックがありません。ユーザー名欄の下に「半角英数字・2〜20文字」などの条件と、重複/無効時のインラインエラーを出してください。  
  Effort: M

- [友達詳細 / `app/CerealExercise/CerealExercise/Views/FriendDetailView.swift:288`] 応援ボタンが2列固定で、短いラベルでも押下結果がボタン内に残りません。送信済みの種類だけ選択状態にし、`cheerInFlight` 中は該当ボタンに `ProgressView` を表示してください。  
  Effort: M

- [週間ランキング / `app/CerealExercise/CerealExercise/Views/WeeklyRankingView.swift:34`] 順位ルールの説明がリスト下にあり、初見では何で競っているか後から分かります。`headerCard` 内に「今週の達成日数で順位が決まります」を入れ、下の説明は補足にしてください。  
  Effort: S

- [リーグ / `app/CerealExercise/CerealExercise/Views/LeagueView.swift:107`] 昇格圏/降格圏が色付き順位バッジだけで、意味が分かりにくいです。行の右または順位下に「昇格圏」「降格圏」の小ラベルを追加してください。  
  Effort: S

- [リーグ / `app/CerealExercise/CerealExercise/Views/LeagueView.swift:28`] 「N日後にリーグ判定」が本文として浮いています。`leagueHeroCard` の右上バッジに移し、「判定まで N日」として優先度を明確にしてください。  
  Effort: S

## P2 — Polish

- [カテゴリチップ / `app/CerealExercise/CerealExercise/Views/Components/CategoryChip.swift:15`] 未選択チップが `secondary.opacity(0.7)` だけで、テーマによって選択との差が弱くなります。未選択は `Palette.chipBackground` + 1pt枠、選択は `Palette.primary` + checkmark にしてください。  
  Effort: S

- [記録入力 / `app/CerealExercise/CerealExercise/Views/RecordEntryView.swift:25`] 横スクロールのカテゴリチップはスクロール可能だと気づきにくいです。右端に少しフェードを入れるか、最後のチップが半分見える幅調整にしてください。  
  Effort: S

- [種目候補 / `app/CerealExercise/CerealExercise/Views/ExerciseInputRow.swift:25`] 候補チップも横スクロールで、履歴候補かデフォルト候補か分かりません。「よく使う種目」ラベルを追加し、候補が多い時は2行折り返しの `LazyVGrid` にしてください。  
  Effort: M

- [ホーム / `app/CerealExercise/CerealExercise/Views/HomeView.swift:56`] 全画面一律20pt paddingで、カード間の優先度差が出にくいです。猫メッセージ下は24pt、記録CTA下は16pt、補助カード群は12〜14ptにして主導線を強めてください。  
  Effort: S

- [猫メッセージ / `app/CerealExercise/CerealExercise/Views/CatMessageView.swift:18`] メッセージが引用符付き本文のみで、長文時に吹き出しが重く見えます。引用符を外し、1行目は本文、必要なら下に小さく「GOからのひとこと」を置いてください。  
  Effort: S

- [月間カレンダー / `app/CerealExercise/CerealExercise/Views/MonthlyCalendarView.swift:104`] 日付13pt・状態11ptは視力が弱いユーザーに小さめです。日付を14〜15pt、状態はSF Symbolまたは13ptに上げ、Dynamic Type時は状態記号を非表示にして日付優先にしてください。  
  Effort: M

- [友達一覧 / `app/CerealExercise/CerealExercise/Views/FriendsView.swift:337`] 「更新 x日前」が10ptで読みにくく、重要度も曖昧です。`Typography.caption` に上げ、「最終更新: 今日 / 2日前」の形式にしてください。  
  Effort: S

- [ランキング共通 / `app/CerealExercise/CerealExercise/Views/WeeklyRankingView.swift:100`] 数値列が等幅指定されておらず、桁数が変わると視線が揺れます。順位・日数の数値に `.monospacedDigit()` を付けて比較しやすくしてください。  
  Effort: S

- [リーグ / `app/CerealExercise/CerealExercise/Views/LeagueView.swift:89`] 「上位 2 名で シルバー昇格」のように空白が不自然です。「上位2名でシルバー昇格」に詰め、数字だけ強調する表示にしてください。  
  Effort: S

- [設定シート / `app/CerealExercise/CerealExercise/Views/SettingsView.swift:237`] ウィジェットガイド先頭の固定56ptスペーサーは端末サイズで余白過多になりやすいです。閉じるボタン分は `safeAreaInset` または toolbar に寄せ、本文開始位置を自然にしてください。  
  Effort: S

## Cross-cutting themes

全体として、キャラクターと達成感の雰囲気は強い一方で、入力画面と友達画面は「何を押せるか」「なぜ押せないか」が弱いです。特に記録入力は習慣化アプリの最重要フローなので、保存不可の理由、単位、候補、任意入力の扱いを常に見える形にすると離脱が減ります。

カレンダー、ランキング、リーグは色・絵文字・記号で意味を伝える設計が多めです。日本語ユーザー向けには、かわいさを残しつつ「凡例」「昇格圏」「休養日」「保険チケット」などの短いテキストラベルを足すと、初見理解とアクセシビリティが上がります。

モバイル ergonomics では、36〜38ptの小さなタップ対象、横スクロールチップ、カード内ネストボタンが主な摩擦です。主要操作は44pt以上、横スクロールには発見手がかり、カード内操作は「詳細を見る」と「応援する」を分離する方向で整えるのがよいです。

参考: Vercel Web Interface Guidelines（アクセシビリティ、フォーム、タッチ領域の観点をSwiftUI向けに読み替え）https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md
