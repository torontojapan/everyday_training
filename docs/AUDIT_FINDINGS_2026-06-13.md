# 監査所見 (Phase A 確定分) — 2026-06-13

`Workflow goexercise-full-audit` (run wf_9721f39f-bb5) の Phase A 多エージェント監査+敵対的検証で **confirmed** となった所見。

**前提**: 自動テスト土台は全緑(iOS 400 / Android 231 / Supabase S8-S11)。

**未確定**: セッション上限により onboarding/widgets/notifications/paywall/share/weight/cycle/analytics の8ドメインは検証未完→再開要(下記)。Codex クロスチェック(Phase B)・スクショ監査(Phase C)も未実施。


**確定件数: 185 (high=24 / medium=140 / low=21)**


> 注: これは Claude の静的監査+Claude自己検証の結果。Codex 第2監査と実画面確認を経るまでは『候補』扱い。


---
## 🔴 HIGH (24件)


### account


**Android ensureUid が transient セッション障害と無セッションを区別せず、既存連携IDを新規匿名で上書きしうる(iOSが根治済みのP1リグレッションがAndroidに残存)** (?)

- 実害: 設計意図の中核『transientセッション障害で新規匿名を誤生成しない』に違反。currentUserOrNull() が null を返す原因はローカルキャッシュ未ロード/リフレッシュトークン一時失効/通信断など多数あるが、Android は原因を問わず即 signInAnonymously() する。リフレッシュ一時失敗時に Apple/Google 連携済みの本人が突然新しい匿名uidに入れ替わり、友達・⭐・コードが空表示になり、再連携時に friend_code UNIQUE 衝突や identity_already_exists を誘発しうる。iOS は AuthError.sessionMissing のみに限定して同バグを明示的に根治済み。

- 根拠: `Android(欠陥): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/data/friends/SupabaseFriendsService.kt:35-39 — `currentUserOrNull()?.id?.let { return it }; client.auth.signInAnonymously(); return currentUserOrNull()?.id ?: throw NotSignedIn`(エラー種別の分岐なし)。

iOS(根治済み・正本): /Users/jun/Documents/Business_Project_Management/serial_training/ap`


### achievements


**Android: 達成節目ダイアログが『記録完了→ホーム復帰時のみ』ゲートを欠き、起動時に発火する** (?)

- 実害: 設計正本(SPEC_iOS.md:68『記録完了→ホーム復帰時のみ、起動時には出さない』、MEMORY celebration_after_record_only)に反し、Android の pendingMilestone は uiState から導出する純 StateFlow で、HomeScreen が常時 pendingMilestone?.let{ MilestoneCelebrationDialog } を描画する。未acknowledge の節目(=実質、記録で節目到達したが何らかで未消化のケース、もしくは将来 candidates が増えた瞬間)があるとアプリ起動/タブ復帰だけで節目ダイアログが割り込み表示される。iOS は onChange(of: completedRecord) からしか fireRecordCelebrations→presentedMilestone を立てない。差し戻し注意対象の根幹挙動が Android で破れている。

- 根拠: `Android(バグ): app-android/app/src/main/java/com/goexercise/app/presentation/home/HomeScreen.kt:91-96(pendingMilestone を記録完了ゲートなしで直接描画)+ HomeViewModel.kt:105-130(reactive 純 StateFlow 導出、起動/復帰で非 null 化)。candidates の非記録系経路: domain/Milestone.kt:84-108(Anniversary/LifetimeDays/WeightLoss を含む)、nextPending: Milestone.kt:111-112。migration はゲートにならない: data/milestone/MilestoneRepository.kt:64-71。
iOS(正): View`


### backup


**iOS syncNow に in-flight アカウント切替ガードが無く、口座跨ぎ wipe/流出の残余リスク** (?)

- 実害: Androidは syncNow 開始時に friendCode を捕捉し、backupWipeAll/backupMarkDeleted の直前と backupUpsert の直前に identityChanged(startCode) を再検証して切替検出時は同期を中止する(fail-closed)。iOS syncNow にはこの再検証が一切無い。HomeView は friendCode 変化のたびに resetForIdentityChange→restoreAfterSignIn を発火するため、syncNow の await 中にアカウント切替が走ると、(a) 旧アカウント宛の pending wipe を backupWipeAll() で新アカウントへ適用してバックアップを誤消去、(b) 旧アカウントの体重・体調等の機微データを新アカウントへ upsert 流出、の二経路が理論上成立する。Androidが明示的にCodex指摘として塞いだ穴がiOS(=パリティ基準実装)に残っている。

- 根拠: `iOS 欠落: app/GOExercise/GOExercise/Services/RecordSyncCoordinator.swift:101-131(friendCode 未捕捉、:115 backupWipeAll 前・:126 backupUpsert 前に再検証なし)。Android ガード: app-android/app/src/main/java/com/goexercise/app/data/backup/RecordSyncCoordinator.kt:130(startCode 捕捉),:140-146(wipe/削除前 identityChanged→return),:155(upsert 前 identityChanged→return),:181-182(fail-closed)。切替発火経路: app/GOExercise/GOExercise/Views`


**iOS に RecordSyncCoordinator のユニットテストが皆無(正本実装が未検証)** (?)

- 実害: バックアップの正本はiOS実装と明記されているが、push差分・pull・LWW・tombstone温存/復活防止・wipe・identityリセットを検証するiOSユニットテストが存在しない。FriendsStoreTests/AccountLinkingTests に出てくる backupUpsert/backupFetchAll は空スタブで、同期ロジックを一切通さない。Androidは同等項目を19本でカバーしているため、回帰検出力が両OSで非対称。クロスOS契約(キー名/日付ISO/day文字列)の破壊や LWW 後退バグがiOS側で素通りする。

- 根拠: `iOS実装(検証対象・テスト無し): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/RecordSyncCoordinator.swift:24-314(syncNow:101-131, changedRecords:144-189, apply/LWW:193-288, restoreAfterSignIn:82-98, resetForIdentityChange:136-140, RecordSyncTombstones:318-355, クロスOS契約コメント:17-23)。
iOS空スタブ(no-op・アサーション無し): /Users/jun/Documents/Business_Project_Management/seri`


### calendar


**Android カレンダーの配色が設計意図と逆(達成=緑/未達成=赤/休養=青)** (?)

- 実害: 設計意図の正本は『運動した日=赤強調 / 休養・フリーズ=緑系 / 未達成=青』。iOS はこれを実装(achieved=赤, rest/rescued=緑, missed=青)。一方 Android colorForStatus は Achieved→success(緑), Rest/Rescued→restDay(青系), Missed→missed(赤/橙)で、3色の意味がほぼ反転。ユーザーが『赤=がんばった日』『青=未達成』として読む正本と矛盾し、Android 利用者は達成日を休めた日と誤認する重大な誤誘導。QA_CHECKLIST F『達成/休養/未達成の色分け』にも反する。

- 根拠: `iOS 正本(意図と一致): app/GOExercise/GOExercise/Views/MonthlyCalendarView.swift:330-331(意図コメント), :333 achieved=赤(0.93,0.33,0.30), :334 rest=緑(0.36,0.65,0.40), :335 rescued=緑, :336 missed=青(0.38,0.55,0.90)。
Android 反転: app-android/app/src/main/java/com/goexercise/app/ui/theme/StatusColors.kt:11-18(Achieved→success, Rescued/Rest→restDay, Missed→missed)。
トークン実RGB(全パレットで方向一致): app-android/.../ui/theme/AppThe`


**Android で日セルタップが死んでいる(詳細シート未配線)** (?)

- 実害: SPEC『日タップで詳細』(SPEC_iOS.md:77)に対し iOS は DayDetailSheet を開く。Android の DayCell は onClick/clickable が一切無く、どの日をタップしても無反応。主要操作の死にコントロール。

- 根拠: `docs/SPEC_iOS.md:77 (日タップで詳細 要件); app/GOExercise/GOExercise/Views/MonthlyCalendarView.swift:9,106 (onDayTapクロージャ公開と発火); app/GOExercise/GOExercise/Views/HistoryView.swift:43-45,135-137 (open(date:)配線とDayDetailSheet提示); app-android/app/src/main/java/com/goexercise/app/presentation/history/HistoryScreen.kt:91-109 (DayCellにclickable/onClick無し・タップ引数無し); grep結果: history配下のonClickはHistoryScreen.kt:54,63,`


**Android が『初記録より前は中立 -』ルールを実装しておらず過去日を休養/未達成表示する** (?)

- 実害: 設計意図『初記録(救済日)より前の日は中立 -(future)』。iOS は firstActivityDay より前を .future へ振替え、記録ゼロのユーザーの過去日も '-' にする。Android MonthlyCalendarCalculator にこの振替が無く、RestDayResolver が初記録前の空白期間を週最大2日 Rest・残りを Missed と評価。新規/初記録前の月で『運動してもいないのに休養・未達成』が並ぶ誤表示。再発バグ型(5)休養日相互作用および中立表示ルールの違反。

- 根拠: `iOS rule present: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/MonthlyCalendarView.swift:271-289 (firstActivityDay computed at :273-275; pre-activity -> .future at :279-283; zero-record past days -> .future at :284-288).
Android missing rule: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexer`


### cycle


**Android に生理日記録の opt-in(ON/OFF)設定が無く、プライバシー要件に反して常時露出** (?)

- 実害: iOS は SPEC『体調・周期の記録ON/OFF』に従い CycleTrackingSettings.isEnabled で生理日UI・★・オーバーレイを全面ゲートし、デフォルトOFF・友達に共有しない設計。Android には対応設定が一切無く、premium ユーザーには周期パネルと『今日を生理日に登録』ボタンが opt-in 無しで表示される。プライバシー最優先・opt-in志向(設計意図)に反する明確なパリティ欠落。

- 根拠: `iOS gate/toggle/default:
- /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/MenstrualStore.swift:78-90 (CycleTrackingSettings, isEnabledKey, isEnabled get/set; defaults.bool => 既定false)
- /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/SettingsView.swift:340,349,357 (Toggle「体調・周期を記録する」)
- /Users/jun`


**Android 履歴カレンダーに生理日★が出ない(配線漏れ=dead control)** (?)

- 実害: iOS は履歴の月カレンダーに opt-in時★+凡例を描画(SPEC『月カレンダー…生理日(★)』)。Android の HistoryViewModel は MenstrualRepository.periodDays を一切購読せず、HistoryScreen に生理日マーク描画も無い。ユーザーが(WeightScreenで)登録した生理日が履歴のどこにも反映されず、記録した実感が得られない。iOSパリティの主要10件に『友達公園/設定再構成』等は移植済だが、履歴★だけ欠落している。

- 根拠: `Android欠落: app-android/app/src/main/java/com/goexercise/app/presentation/history/HistoryViewModel.kt:32-53 (MenstrualRepository 非注入・periodDays 非購読); app-android/.../presentation/history/HistoryScreen.kt:90-109 (DayCell は status+日付のみ、生理日マーク描画なし); app-android/.../domain/MonthlyCalendarCalculator.kt:14 (MonthCell に生理日フィールド無し). Android で periodDays を使うのは weight のみ: WeightViewModel.kt:69-90, WeightScre`


### friends


**Android にアプリ内QRスキャナが無く、設計意図『QRはアプリ内スキャナ』を満たさない** (?)

- 実害: iOS は AVFoundation 自前スキャナ(scheme=goexercise限定/生6文字検証)で友達のQRを読み取れるが、Android の友達追加はコード手入力のみで、QR読取は端末標準カメラ→goexercise://ディープリンク頼み。標準カメラがカスタムスキームQRを開けない/別アプリが奪う環境ではQR追加が成立せず、クロスOSのQR追加体験がAndroidで劣化する。設計意図の中核要件の欠落。

- 根拠: `iOS in-app scanner: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/QRScannerView.swift:5-8 (設計意図), :99-112 (scheme限定+6文字検証), :153 (.qr metadata). Android lacks scanner: app-android/app/src/main/java/com/goexercise/app/presentation/friends/QrCode.kt:9 (QRCodeWriter のみ=生成専用), :14,:39 (標準カメラ依存をコメントで明言); app-android/app/build.gradle.kts:152 (zxing.core`


### onboarding


**Androidオンボに「Apple/Googleサインイン→バックアップ自動ON」ステップが丸ごと欠落(設計意図の中核未実装)** (?)

- 実害: 設計意図は『猫選択(1/2)→サインイン(2/2・スキップ可)の2ステップ。サインインで記録バックアップ自動ON』。iOSは AccountBackupSignIn でApple/Google/スキップ/もどるを提供し、成功時 recordSync.enableBackup() を呼ぶ。Androidの OnboardingScreen は猫選択のみで onFinish(selected) が即 setOnboardingComplete し本編へ遷移。新規Androidユーザーは初回にバックアップを設定する導線がオンボ内に存在せず、機種変更/再インストール時の復元体験(本機能の主目的)に到達しにくい。サインイン基盤(AccountAuthCoordinator.kt/AccountLinking.kt/RecordSyncCoordinator.kt)は実装済みだがオンボに配線されていない。

- 根拠: `Android single-step: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/onboarding/OnboardingScreen.kt:122-128 (button -> onFinish), OnboardingViewModel.kt:53-59 (complete sets breed + onboardingComplete, no backup). No backup wiring: grep enableBackup/AccountBackupSignIn over presentation/onboarding returned empty.
iOS tw`


**Android設定の猫種ピッカーがプレミアムロックを一切行わず、非プレミアムでも全猫種に変更可能(課金ゲート無効)** (?)

- 実害: 意図は『オンボ確定後(設定)のみロック=非プレミアムは現猫種以外ロック、変更にはプレミアム必要』。iOSは設定再選択で CatBreedAccess.isLocked によりロック猫タップ→paywall、確定時もロック猫は現状維持。Android SettingsScreen の CatBreedPicker は isPremium/referral/lock を全く参照せず onSelect(breed) を無条件に呼ぶため、無料ユーザーが設定でいくらでも有料猫種に変更できる。プレミアム/紹介報酬の収益ゲートがAndroidで実質無効。Android側に CatBreedAccess 相当の実装が存在しないことも一因。

- 根拠: `Android (欠陥): app-android/app/src/main/java/com/goexercise/app/presentation/settings/SettingsScreen.kt:197 (CatBreedPicker に isPremium/referral 未伝達), :307-332 (clickable{onSelect(breed)} 無条件・lock/paywall 無し); presentation/settings/SettingsViewModel.kt:69-71 (setCatBreed ノーゲート), :59 isPremium / :161 referralSummary は存在(配線可能なのに未使用); data/settings/SettingsRepository.kt:85 (素通し保存)。Android に CatBreedAc`


### paywall


**Android: 猫種変更が無料ユーザーでも無制限=プレミアム機能のバイパス** (?)

- 実害: 設定の CatBreedPicker は isPremium/referralUnlocked を受け取らず全11種を無条件 clickable にし、onSelect=setCatBreed が即永続化する。iOS は CatBreedAccess.isLocked で『現在の猫以外はロック、タップでペイウォール、確定時も巻き戻し』を強制(SPEC_iOS.md:143)。Android は猫種変更というプレミアム/紹介解放対象の機能を無料で完全開放しており、課金動機の毀損と iOS パリティ破れ。CatBreed.kt に isLocked の移植自体が無い

- 根拠: `Android (no gating): app-android/app/src/main/java/com/goexercise/app/presentation/settings/SettingsScreen.kt:307-332 (CatBreedPicker signature lacks isPremium/referralUnlocked; line 318 `.clickable { onSelect(breed) }` for all entries), :87 (onSelectBreed = viewModel::setCatBreed), :197 (call site); SettingsViewModel.kt:69-71 (setCatBreed persists unconditionally); app-android/app/src/main/java/c`


**Android: トライアル消化済みでも「14日間無料」を常時表示(誤無料表示・審査リスク)** (?)

- 実害: ドメイン設計意図の正本『トライアル消化済みなら14日間無料を出さない』に正面から反する。Android paywall はヘッダー/CTA/開示すべてに「14日間無料」をハードコードし、eligibility 判定が PremiumRepository に存在しない。再購読/トライアル消化済みユーザーに即課金を無料と誤認させる。iOS は isEligibleForIntroOffer で前面復帰/復元/更新時に再評価する対比(Codex R1/R2 で是正済みの観点が Android 側に欠落)

- 根拠: `Android 欠陥本体:
- /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/premium/PremiumPaywallScreen.kt:124 (ヘッダー無条件「14日間無料。いつでも解約できます。」), :155 (CTA「14日間無料で始める」), :175 (開示「14日間の無料体験後…」), :179 (開示「無料体験中に解約すれば課金されません」)
- /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/`


### recording


**Android 記録入力に重さ(kg)フリー入力が存在しない(設計意図の中核機能欠落)** (?)

- 実害: 設計意図『重さkgフリー入力』『+同じ種目でセットを追加で名前/種類/重さを引継ぎ複製』のうち、Android は重さ入力 UI も ExerciseDraft.loadText フィールドも無い。ダンベル等の負荷を記録できず、iOS と保存内容に非対称が生じる。loadKilograms はモデルに残るがアプリからの書き込み経路がゼロのため、iOS で入力→Android で閲覧/再保存した際にだけ値が残る片方向状態。同時ローンチのパリティ要件に反する

- 根拠: `iOS書き込み経路あり: app/GOExercise/GOExercise/Views/ExerciseInputRow.swift:148-164 (重さ(kg) TextField($draft.loadText)), app/GOExercise/GOExercise/ViewModels/RecordEntryViewModel.swift:19-20 (var loadText), :97 (loadKilograms: Self.parsedLoad(draft.loadText)), :104-108 (parsedLoad), :123 (addSet が loadText 引継ぎ)。
Android欠落: app-android/app/src/main/java/com/goexercise/app/presentation/record/RecordUiState.`


**Android addSet が重さを引き継がない(セット複製の意図を部分的にしか満たさない)** (?)

- 実害: iOS addSet は name/category/loadText を複製し『重さ違いの複数セットを種目選び直しなしで』記録できる。Android は重さ欄が無いため name/category のみ複製。重い種目を複数セット記録する主要ユースケースで毎回重さを失う。テスト(RecordViewModelAddSetTest)も重さを検証しないため回帰で固定化されている

- 根拠: `iOS(機能あり): app/GOExercise/GOExercise/Views/ExerciseInputRow.swift:148-161 (重さ(kg) TextField -> draft.loadText) ; app/GOExercise/GOExercise/ViewModels/RecordEntryViewModel.swift:97 (loadKilograms: parsedLoad(draft.loadText)) ; RecordEntryViewModel.swift:123 (addSet が loadText を複製) ; ExerciseDraft 定義 RecordEntryViewModel.swift:7,20,30,39。
Android(機能欠落): app-android/app/src/main/java/com/goexercise/a`


### referrals


**Android で猫種ピッカーが全11種を無条件選択可能=プレミアム課金と⭐10紹介報酬の両方をバイパス** (?)

- 実害: iOS は CatBreedAccess.isLocked(isPremium, referralUnlocked) で『無料ユーザーは今の猫以外ロック、プレミアム or 紹介⭐10で解放』を強制し、ロック猫タップで paywall を出す。Android の CatBreedPicker は全猫を無条件 clickable で即適用し、ロック概念が存在しない。結果、無料ユーザーが課金せず全猫種を取得でき(収益化の穴)、かつ紹介⭐10報酬の価値も消失する。意図(プレミアム解放/紹介報酬)に対する明確な mismatch

- 根拠: `iOS (enforced): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Models/CatBreedAccess.swift:8-11; /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/UserCatPickerView.swift:21-26,163-169,254-261,275-280; /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/SettingsVi`


**Android に⭐10猫種解放そのものが未実装(達成ポップも解放ロジックも無い)** (?)

- 実害: iOS の紹介報酬は『今月フリーズ+1』と『累計10人で猫種解放』の2本柱。Android ReferralStore には pendingBreedUnlock / ReferralReward.isBreedUnlocked / consumeBreedUnlock / breedUnlockCelebrated 永続フラグが一切無く、達成ポップも出ない。ピッカー側にロックも無い(上記 finding と表裏)。星バッジ表示はあるが報酬実体が片方欠落しており、紹介の設計意図がAndroidで成立しない

- 根拠: `iOS(報酬定義): app/GOExercise/GOExercise/Models/ReferralStarsDisplay.swift:22-26 (ReferralReward.breedUnlockThreshold=10, isBreedUnlocked)
iOS(ストア状態): app/GOExercise/GOExercise/Services/ReferralStore.swift:24 (pendingBreedUnlock), :101-102 (達成判定), :108-111 (isBreedUnlocked forAccount), :186-190 (consumeBreedUnlock), :19-21 (breedUnlockCelebratedKey 永続)
iOS(達成ポップ): app/GOExercise/GOExercise/Views/HomeV`


### settings


**Android: 認証/バックアップ(Apple/Google サインイン)UI が設定に集約されておらず、設計意図と逆に友達タブに残存** (?)

- 実害: 設計意図は『認証/バックアップUIは設定に集約・友達タブから撤去』。iOS は設定の「アカウントとバックアップ」セクションに AccountBackupSignIn(Apple/Google ボタン)を置き、未連携=ボタン/連携済=『Apple/Google アカウントでバックアップ中』を表示し、FriendsView から撤去済(コメント明記)。Android 設定にはサインインボタンも連携済み状態表示も無く、代わりに『友達タブの「Apple/Googleでバックアップ」も設定してください』と誘導。実際のバックアップ/復元/切替/アカウント削除UIは依然 FriendsScreen の BackupCard/RestoreSection に存在。機種変更の命綱である復元の鍵が設定から辿れず、ユーザーは『設定→友達タブ』とたらい回しになる。機種変更時の復元失敗(命綱不全)に直結する重大なパリティ欠落。

- 根拠: `iOS consolidated: app/GOExercise/GOExercise/Views/SettingsView.swift:12-18 (linkedStatusText), :55-68 (AccountBackupSignIn + linked-status under "アカウントとバックアップ"). iOS removed from Friends: app/GOExercise/GOExercise/Views/FriendsView.swift:264-266 (restoreSection撤去 comment), :441-442 (backupCard撤去 comment in signedInBody), :282 & :591 orphaned defs (restoreSection 0 call sites).
Android NOT consolid`


### share


**Android 共有カードに背景グラデ5種ピッカー/永続化が未実装(コア要件の欠落)** (?)

- 実害: 設計意図の正本に『背景グラデ5種選択(カード種別ごとに記憶)』が明記されているが、Android にはピッカー UI も @AppStorage 相当の永続化も一切無い。背景は StreakLevel.gradientColors(連続日数で機械的に決まる固定配色)に縛られ、ユーザーは色を選べない。iOS の中核 UX がそのまま欠落しており、パリティ未達。

- 根拠: `iOS実装(存在): app/GOExercise/GOExercise/Views/ShareCardGradient.swift:6-49 (enum ShareCardGradient 5 cases: sunset/ocean/twilight/forest/daybreak), :53-85 (struct ShareGradientPicker, ○×5 UI); app/GOExercise/GOExercise/Views/StreakShareSheet.swift:13 (@AppStorage("shareCard.gradient.streak")), :75 (ShareGradientPicker(selectionRaw: $gradientRaw)), :96 (.onChange(of: gradientRaw) -> renderImage)。

And`


### widgets


**Android ウィジェットがタップで何も起きない(ホーム遷移の配線漏れ・死にコントロール)** (?)

- 実害: iOS はウィジェット全体に goexercise://home を付与しタップでホームを開く。Android StreakWidget は actionStartActivity / clickable / onClick が一切無く、タップしても明示的なホーム遷移が起きない。記録誘導の動線(ウィジェット→アプリで記録)が Android で断たれており、iOS パリティ未達かつユーザーの『押したら開く』期待に反する死にコントロール。

- 根拠: `Android(欠陥): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/widget/StreakWidget.kt:84-92 (Column modifier に clickable/action 無し), 同ファイル全体で `androidx.glance.action` import 0件。widget/ パッケージは StreakWidget.kt のみ。
iOS(参照・配線あり): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExerciseWidget/GOExerciseWid`


### 体重トラッキング


**Android 推移グラフにタップ選択が無く SPEC『グラフはタップ選択』が未実装(死に機能)** (?)

- 実害: iOS はグラフ点を tap/drag で選択し日付・体重を吹き出し表示+選択点拡大+RuleMark を出すが、Android の WeightChart は素の Canvas で drawPath/drawCircle のみ。pointerInput/detectTapGestures/選択 state が皆無で、ユーザーがグラフから特定日の値を読む手段が無い。SPEC・QA の中核 intent を満たさない実害ありの機能欠落。

- 根拠: `iOS 実装(タップ選択あり): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/WeightView.swift:516-587(PointMark拡大 symbolSize 130/40 @521、値annotation @528-539、RuleMark @541-545、onTapGesture+DragGesture @562-587、根拠コメント @560-561)。

Android 実装(タップ選択なし): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app`


### 分析opt-out


**Android: opt-out時にTelemetryDeck SDKをteardownせず、iOSが意図的に直した残留送信問題に未追従** (?)

- 実害: iOSはAnalytics.setEnabled(false)でservice=NoopAnalytics()にしSDK実体を捨てる。Analytics.swift:90-91のコメントは『旧実装はtrackのgateのみで、既に初期化済みのTelemetryDeckはセッション中liveのまま=厳格なレビュアが残留を問題視し得る』として明示的に是正したと記録している。Androidはこのfixをパリティ移植しておらず、Analytics.consentGranted=falseがfacade.trackをgateするだけ。一度TelemetryDeck.start()された後はTelemetryDeckAnalyticsもTelemetryDeck SDK本体も生存し続ける。TelemetryDeck Kotlin SDKはstart時にセッション/ライフサイクルsignalを自動送出する性質があり、facadeのtrack gateを経由しない送信はopt-out後も止まらない恐れがある。『opt-outで送信停止・teardown。プライバシー最優先』という設計意図に対し実害(opt-out済みユーザーからの計測残留)。修正方針: Analytics.ktにiOS setEnabled相当を設け、opt-out時 service=NoopAnalytics かつ Teleme

- 根拠: `Android (穴): app-android/app/src/main/java/com/goexercise/app/analytics/Analytics.kt:94-100 (consentGranted gate のみ・setEnabled/stop 無し), :107-115 (configureIfPossible が TelemetryDeck.start を呼ぶが teardown 経路無し); app-android/app/src/main/java/com/goexercise/app/presentation/settings/SettingsViewModel.kt:90-95 (opt-out=consentGranted=false のみ); app-android/app/src/main/java/com/goexercise/app/GOExerci`


### 連続日数エンジン


**Android 復活ウィンドウが固定窓で、自動休養が挟まると復活ポップが出ない(iOS P1 修正の未移植)** (?)

- 実害: StreakFreezeWindow.evaluate が statuses を (1..(lookback+1)) の固定窓で組む。missed 日と連続の頭(achieved)の間に自動休養(週最大2日)が挟まると anchor が窓の外へ押し出され foundPrior=false となり、復活可能なのに復活ポップが発火しない。iOS は同じ不具合を hardCap=lookback+7 の動的延長(休養を読み飛ばして anchor 探索)で既に修正済み(コード内 P1 コメント+専用回帰テスト2本)。Android に未移植のリグレッション。再発バグ型(5)連続×自動休養 に直撃。課金チケットを使う導線が無音で消えるため収益・体験の両面で実害

- 根拠: `Android 固定窓: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/domain/StreakFreezeWindow.kt:109 `val statuses = (1..(lookback + 1)).map { offset -> ... }`(records 入口、動的延長なし)。
iOS 動的scan: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/StreakFreezeWindow.swift:76 `let hardCap = lookba`


---
## 🟡 MEDIUM (140件)


### account


**Android signOut が匿名ユーザーのサーバ行を削除しない(iOSの『忘れる』セマンティクス欠落)→ 孤児プロフィール/友達行が残存** (?)

- 実害: iOS signOut は匿名セッション時に profiles/friendships/friend_requests/referrals を本人uidで削除してから signOut し、再生成不能な匿名痕跡を残さない。Android は bare client.auth.signOut() のみで、匿名ユーザーがサインアウトすると公開 profiles 行・友達関係・紹介行がサーバに孤児として残る。相手側の友達一覧に消えないゴーストが残り、プライバシー/データ衛生上の実害。UIには『サインアウト』ボタンが実在し到達可能。

- 根拠: `Android (孤児を残す側): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/data/friends/SupabaseFriendsService.kt:78-80 (signOut が bare client.auth.signOut() のみ); 同ファイル:75 (signIn が profiles upsert), :124 (friend_requests insert), :131 (friendships upsert) で孤児対象行を生成。到達経路: app/src/main/java/com/goexercise/app/presentation/friends/FriendsScree`


**Android 連携失敗時にセッションを巻き戻さず、半端な切替状態が残りうる** (?)

- 実害: iOS signInWithApple/Google は認可成立後の profile ロード失敗時に signOut(scope:.local) で切替を巻き戻し、その後の ensureSignedIn(自動既定名)が他人の既存プロフィールを上書きするのを防ぐ。Android signInWithGoogle/signInWithAppleWeb は finishIdentitySwitch で uid 取得失敗時に throw するだけでセッションのロールバックをしない。VMの recoverIdentityAfterFailure は UI 状態のみ是正しセッションは戻さないため、認可済み他アカウントセッションが残ったまま次の ensureUid/signIn が走ると既存プロフィール上書きの恐れ。

- 根拠: `Android missing rollback: app-android/app/src/main/java/com/goexercise/app/data/friends/SupabaseFriendsService.kt:358-365 (signInWithGoogle: only throw mapLinkError), :389-398 (signInWithAppleWeb: only throw), :401-412 (finishIdentitySwitch: throw AccountLinkError.Failed, no signOut). VM: app-android/.../presentation/friends/FriendsViewModel.kt:335-350 (recoverIdentityAfterFailure only bumpIdentit`


**アンチresurrection中核(ensureUID transient分岐 / deleteAccount EF fail-closed / signOut匿名削除)に両OSでユニットテストが無い** (?)

- 実害: 本ドメインで最も差し戻し/退行リスクの高い3挙動(transient障害で新匿名を作らない、EF非404失敗をfail closedにする、匿名signOutでサーバ行を消す)が実Client経路で未テスト。既存テストはMockFriendsService経由でこれらの分岐を通過しないため、Androidの上記リグレッションが緑のまま見逃された。最低限フェイクClientで session例外/HTTPステータス分岐を駆動するテストが必要。

- 根拠: `iOS impl: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/SupabaseFriendsService.swift:54-72 (ensureUID sessionMissing vs transient), :388-397 (signOut anon-only row delete), :431-464 (deleteAccount EF httpError code!=404 fail-closed at 453-460). | Android impl: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/`


**友達タブ初回表示 (ensureUid / 匿名lazy生成) (mismatch)** (?)

- 実害: intent: 同上 — transient障害で新規匿名を誤生成しない / actual: Android ensureUid は currentUserOrNull() が null なら無条件に signInAnonymously() する。session読取の一時障害(リフレッシュトークン失効/通信断)と『無セッション』を区別しない。iOSが明示的に根治した P1 リグレッションがAndroidに残存=既存の友達/連携IDが新匿名uidで上書きされうる。

- 根拠: `Android defect: app-android/app/src/main/java/com/goexercise/app/data/friends/SupabaseFriendsService.kt:35-39 (ensureUid unconditionally calls signInAnonymously when currentUserOrNull()==null). New-account side effect: same file :65-76 (signIn creates fresh profile + generateUniqueCode for the new uid).

iOS correct intent (the P1 fix Android lacks): app/GOExercise/GOExercise/Services/SupabaseFrie`


**サインアウトボタン (friends-signout / 「サインアウト」) (mismatch)** (?)

- 実害: intent: 匿名ユーザーがサインアウトしたら、その匿名の痕跡(プロフィール/友達行)はサーバに残らない(『忘れる』) / actual: iOS: 匿名セッション時のみ profiles/friendships/friend_requests/referrals を本人uidで削除してから signOut。Androidは bare client.auth.signOut() のみで匿名サーバ行を一切削除しない+ローカルキャッシュ消去もservice側に無い。孤児行が残る。

- 根拠: `Android (孤児化する bare signOut): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/data/friends/SupabaseFriendsService.kt:78-80 — `override suspend fun signOut() { client.auth.signOut() }`。匿名判定・行削除なし。

iOS (匿名行削除あり): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/SupabaseFriendsService`


**連携(切替/復元)中に認可成立後 profile ロード失敗 (mismatch)** (?)

- 実害: intent: 連携が途中失敗したら半端な切替状態を残さず、元の安全な状態へ戻る / actual: iOS signInWithApple/Google は profile ロード失敗時 signOut(scope:.local) で切替を巻き戻しローカルキャッシュも消す。Androidの signInWithGoogle/signInWithAppleWeb は finishIdentitySwitch で uid 取得失敗時 throw するだけで signOut ロールバックをせず、半端に切替わったセッションが残存しうる(VM側 recoverIdentityAfterFailure は UI 状態のみ是正、セッションは戻さない)。

- 根拠: `iOS rollback あり: app/GOExercise/GOExercise/Services/SupabaseFriendsService.swift:226-234 (signInWithGoogle catch → signOut(scope:.local)), :272-281 (signInWithApple catch → signOut(scope:.local))。
Android rollback 無し: app-android/app/src/main/java/com/goexercise/app/data/friends/SupabaseFriendsService.kt:358-365 (signInWithGoogle: signInWith(IDToken) 後 finishIdentitySwitch、catch は throw のみ), :389-`


**parity: ensureUID: transient障害 vs 無セッションの区別** (?)

- 実害: iOSは AuthError.sessionMissing のみで新規匿名作成、他例外は温存。Androidは currentUserOrNull()==null で無条件 signInAnonymously。Androidはリフレッシュ失敗/通信断時に既存連携IDを新匿名uidで上書きするリスク(設計意図の中核『transientセッション障害で新規匿名を誤生成しない』に違反)。

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/SupabaseFriendsService.swift:54-73 (catch AuthError.sessionMissing でのみ匿名作成、他は backendUnavailable で伝播; コメント56-60が設計意図を明記)。
Android: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/data/friends/SupabaseFriendsService.kt:35-39 (curr`


**parity: signOut の匿名データ削除(『忘れる』)** (?)

- 実害: iOSは匿名時に profiles/friendships/friend_requests/referrals を削除。Androidは bare signOut のみで孤児行が残存。

- 根拠: `iOS 実装あり: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/SupabaseFriendsService.swift:382-401 (匿名時のみ profiles=L390 / friendships=L391-392 / friend_requests=L393-394 / referrals=L395-396 を本人 uid 範囲で delete、その後 auth.signOut)。

Android 欠落: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/`


**parity: 連携失敗時のセッション巻き戻し** (?)

- 実害: iOSは post-auth profile ロード失敗で signOut(.local) しクリーン化。AndroidはsignOutロールバック無し。

- 根拠: `iOS rollback present: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/SupabaseFriendsService.swift:272-281 (signInWithApple catch → signOut(scope:.local)) and :226-234 (signInWithGoogle catch → signOut(scope:.local)); rationale doc :244-247.
Android no session rollback: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/`


### achievements


**Android: 称号アップ/週間トーストが記録完了経路外(起動後の初回 reduce・revive・日跨ぎ)で発火し得る** (?)

- 実害: HomeViewModel.init{} が uiState.streak の distinctUntilChanged を collect して rankUpDetector.evaluate を実行し _pendingRankEvent を立て、HomeScreen が常時 overlay 表示する。RankUpStore(SharedPreferences の lastRank/lastWeeklyMultiple)dedup により『既に見たランク』の再発火は防げるが、初インストール後の初記録でホーム再表示する前のタイミングや、復活(revive)で streak が跳ねた瞬間など、iOS が『記録完了→ホーム復帰時のみ』に限定している経路外でトーストが出る余地がある。iOS は evaluateRankCelebration() を fireRecordCelebrations() からしか呼ばない。

- 根拠: `Android: app-android/app/src/main/java/com/goexercise/app/presentation/home/HomeViewModel.kt:148-166(streak distinctUntilChanged で rankUpDetector.evaluate を常時実行)、:86-94(uiState combine に rescuedDates と ticker を含む)、:216-233 + :254-274(revive が useTicket→rescuedDates 更新)、HomeStateReducer.kt:39(streak は rescuedDates 込みで計算)、HomeScreen.kt:81-88(overlay 常時表示)、RescueTicketRepository.kt:43-48(rescuedDates`


**Android: 達成時の全画面紙吹雪(confetti)がホームに存在しない** (?)

- 実害: 設計正本は達成演出に『紙吹雪』を含む(SPEC_iOS.md:68, ドメイン説明)。iOS は evaluateCelebration() で todayStatus==.todayAchieved の時 ConfettiView を4秒・celebratedDay キーで日次1回だけ再生する。Android のホームには confetti/CelebrationOverlay 相当が無く(confetti 実装は StreakShareImageRenderer のシェア画像生成内のみ)、達成時の紙吹雪体験が欠落している。パリティ不足。

- 根拠: `iOS spec: /Users/jun/Documents/Business_Project_Management/serial_training/docs/SPEC_iOS.md:68 (紙吹雪 listed in home 演出). iOS impl: app/GOExercise/GOExercise/Views/HomeView.swift:37 (celebratedDay AppStorage), :52-54 (AmbientParticlesView(isCelebrating:)), :621-630 (evaluateCelebration guards todayAchieved + once/day, 4s); app/GOExercise/GOExercise/Views/AmbientParticlesView.swift:10,22-23,108-109 (`


**達成お祝いダイアログ(pendingMilestone)表示 (Android) (mismatch)** (?)

- 実害: intent: 記録完了→ホーム復帰時のみ節目ダイアログが出る(起動時に出さない) / actual: pendingMilestone は uiState/firstUseDate/milestones.state 等から導出する純 StateFlow で、HomeScreen が collectAsStateWithLifecycle して pendingMilestone?.let{...} で常時描画。記録完了という条件ゲートが無く、未acknowledgeの節目があればアプリ起動/タブ復帰でそのままダイアログが出る。iOS の completedRecord ゲートが欠落

- 根拠: `Android (gate absent):
- app-android/.../presentation/home/HomeScreen.kt:61 — `val pendingMilestone by viewModel.pendingMilestone.collectAsStateWithLifecycle()`
- app-android/.../presentation/home/HomeScreen.kt:91-96 — `pendingMilestone?.let { milestone -> MilestoneCelebrationDialog(...) }` rendered unconditionally (no record-completion gate)
- app-android/.../presentation/home/HomeViewModel.kt:10`


**称号アップ/週間トースト(pendingRankEvent)表示 (Android) (mismatch)** (?)

- 実害: intent: 記録完了→ホーム復帰時のみ称号トーストが出る / actual: init{} で uiState.streak の distinctUntilChanged を collect し rankUpDetector.evaluate を実行→_pendingRankEvent にセット。HomeScreen が常時 overlay 描画。RankUpStore の dedup(lastRank/lastWeeklyMultiple)で既見ランクは再発火しないが、起動後に実 streak が初めて reduce された時や revive/日跨ぎで streak が変化した時、記録完了経路でなくてもトーストが出得る。iOS は evaluateRankCelebration を記録完了経路からしか呼ばない

- 根拠: `Android: app-android/app/src/main/java/com/goexercise/app/presentation/home/HomeViewModel.kt:148-166 (streak collector が常時 evaluate), :91-93 (uiState が rescuedDates を combine 入力に), :254-274 (applyRevive が rescuedDates 更新); HomeStateReducer.kt:39 (streak=StreakCalculator.streakState(...,rescuedDates)); HomeScreen.kt:64,81-88 (常時 overlay); RankUpDetector.kt:33-50 (lastRank/lastWeeklyMultiple dedup).`


**parity: 達成演出の発火ゲート(記録完了→ホーム復帰時のみ)** (?)

- 実害: iOS は completedRecord の onChange という明示ゲートで節目/称号/紙吹雪を起動。Android は pendingMilestone と pendingRankEvent を純 reactive StateFlow で常時描画し、記録完了ゲートが無い。結果として『起動時に出さない』という設計正本を Android が満たさない(未ack節目が起動時に即ダイアログ表示)。MEMORY: celebration_after_record_only と直接矛盾

- 根拠: `iOS gate: app/GOExercise/GOExercise/Views/HomeView.swift:118-124 (completedRecord onChange→fireRecordCelebrations), :524-528 (fireRecordCelebrations), :530-540 (handleAutoPresentations が pendingMilestone を初めて提示), :544-552 (refreshHomeStateでは出さない設計コメント). Android no-gate: app-android/.../presentation/home/HomeScreen.kt:54-59 (HomeRoute に記録完了引数なし), :91-96 (pendingMilestone を無条件にダイアログ描画). Android pend`


**parity: 達成時の全画面紙吹雪(confetti)** (?)

- 実害: iOS は evaluateCelebration() で todayStatus==.todayAchieved の時 isCelebrating→ConfettiView を4秒・celebratedDay キーで日次1回だけ再生。Android home には confetti/CelebrationOverlay 相当が存在せず(confetti は StreakShareImageRenderer のシェア画像内のみ)。設計正本『紙吹雪』が Android ホームで欠落

- 根拠: `iOS 実在: app/GOExercise/GOExercise/Views/HomeView.swift:37 (@AppStorage celebratedDay), :52-57 (AmbientParticlesView(isCelebrating:) を全画面背景に配置), :621-630 (evaluateCelebration: todayStatus==.todayAchieved + 日次1回 + 4秒); app/GOExercise/GOExercise/Views/AmbientParticlesView.swift:10,22-24,109-136 (isCelebrating 時のみ drawConfetti を重ね描き)。
Android 欠落: app-android/.../presentation/home/HomeScreen.kt:174-205`


**parity: 背景進化(MilestoneBackdrop)の最上位アニメーション** (?)

- 実害: iOS は sparkle を TimelineView でアニメ、rank>=10 で光帯を移動、rank>=11 で godRays を描画。Android はスパークル/光帯とも静的で『アニメは入れない』、rank11 の godRays も無し。数値(richness*0.42 グロー, 4+rank*2 上限24 のスパークル数)は一致。差は最上位(streak365+/500+)の演出リッチさのみ

- 根拠: `iOS sparkle anim: app/GOExercise/GOExercise/Views/Components/MilestoneBackdrop.swift:64-69,117-119 / iOS movingBand rank>=10: MilestoneBackdrop.swift:74-82,145-159 / iOS godRays rank>=11: MilestoneBackdrop.swift:84-87,161-174 / iOS数値: app/GOExercise/GOExercise/Models/MilestoneBackdropStyle.swift:24-26. Android静的sparkle: app-android/app/src/main/java/com/goexercise/app/ui/components/MilestoneBackdr`


### backup


**Android 設定に復元キー(Apple/Google)ボタンが無く、機種変更の命綱が1遷移遠い** (?)

- 実害: iOSは設定『アカウントとバックアップ』内にサインインボタンを直置きし、その場で復元キーを確立できる。Androidの設定 BackupSection は実ボタンを持たず『友達タブで設定してください』というテキスト誘導のみで、設定トグルだけでは匿名アカウントしか作られない。匿名アカウントは再インストール/機種変更で復元できないため、ユーザーが設定のトグルONだけで安心して放置すると、いざ機種変更時に復元不能になる導線リスク。実ボタンは友達タブにあるため到達は可能だが、最も重要な復元設定の発見性がiOSに劣る。

- 根拠: `iOS 直置きサインイン(ゲート付き): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/SettingsView.swift:55-67(55 `if SupabaseConfig.isAccountLinkingEnabled`、65 `AccountBackupSignIn()`)。
Android 誘導テキストのみ・実ボタン無し: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/settings/SettingsScreen.kt:23`


**parity: 復元キー(Apple/Google サインイン)の設置場所** (?)

- 実害: iOSは設定『アカウントとバックアップ』セクション内に AccountBackupSignIn() を直接埋め込み、その場でサインイン=復元できる。Androidの設定 BackupSection は実ボタンを持たず『友達タブで設定してください』というテキスト誘導のみ。設定のトグルは匿名アカウントしか作らず、Android では復元キー確立に友達タブへの追加遷移が必要。機種変更の命綱の到達性がiOSより1ステップ遠い

- 根拠: `iOS 埋込サインイン: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/SettingsView.swift:55-68 (AccountBackupSignIn() を設定セクション内に直接配置) / /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/AccountBackupSignIn.swift:32-45 (AppleIDButton/GoogleSignInButton で即サインイン実行)。Android 誘導テキストのみ: /Users/jun/Documents/Business_Pr`


**parity: syncNow 中の in-flight アカウント切替ガード** (?)

- 実害: Androidは syncNow 冒頭で startCode=friendCode を取り、破壊的操作(wipe/markDeleted)直前と push 直前に identityChanged(startCode) を再検証し、切替検出で同期中止(旧アカウント宛wipeを新アカウントに当てる/機微データ流出を防止)。iOS syncNow にはこの再検証が無く、await中にアカウントが変わると誤適用の余地。iOSは @MainActor 直列だが await 跨ぎの切替は起こり得る

- 根拠: `iOS missing guard: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/RecordSyncCoordinator.swift:101-131 (syncNow: no startCode capture, no identity re-check before wipe/markDeleted at 114-118 or before backupUpsert at 126; pending captured at 113). iOS concurrent switch trigger: /Users/jun/Documents/Business_Project_Management/serial_training/app/`


**parity: restore と sync の直列化** (?)

- 実害: Androidは syncMutex で restoreAfterSignIn と syncNow を直列化。iOSは syncNow に isSyncing ガードのみで、restoreAfterSignIn は isSyncing を見ず・立てず apply を直接実行。@MainActor で真の並行はないが await 点で交錯し得る

- 根拠: `iOS /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/RecordSyncCoordinator.swift:82-98 (restoreAfterSignIn が isSyncing を参照/設定せず apply を直接実行), :102-104 (syncNow の isSyncing 単独ガード), :124-127 (syncNow が pull→push 後、await を跨いだ identity 再検証なしで backupUpsert+stamp), :136-140 (resetForIdentityChange は同期的だが mutex 相当の直列化なし)。呼び出し元 /Users/jun/.../Views/HomeVi`


### calendar


**Android 翌月ボタンに未来月ガードが無く空の未来カレンダーへ進める** (?)

- 実害: iOS は canShiftForward で現在月以降の前進を disabled 化。Android nextMonth() は無条件 plusMonths(1) で未来月へ無限に進め、全日 Future('-')の空カレンダーを表示する。混乱を招く操作可能領域の差異。

- 根拠: `iOS gated: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/MonthlyCalendarView.swift:60-69 (next button .disabled(!canShiftForward), 色も分岐), :247-252 (canShiftForward = nextStart <= todayMonthStart), :312-316 (shiftMonth early-return). Android unguarded: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/co`


**Android カレンダーに生理日マーカー・救済チケット装飾・凡例が無い** (?)

- 実害: QA_CHECKLIST F:59,72 は『生理日 / 救済 の色分け』『カレンダー★表示』を必須化。iOS は生理日ドット・ticket.fill・色スウォッチ凡例・休養ルール説明文を表示。Android は色塗りのみで生理日/救済固有マーカーと凡例が皆無のため、救済日と休養日が区別できず、色の意味も読めない。

- 根拠: `QA要件: /Users/jun/Documents/Business_Project_Management/serial_training/docs/QA_CHECKLIST.md:59, :72
iOS実装(要件充足): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/MonthlyCalendarView.swift:126-134 (生理日ドット), :135-143 (ticket.fill 救済), :150-180 (footer 凡例+ルール文), :163-236 (legend 各種)
Android欠落: /Users/jun/Documents/Business_Project_Management/serial_trai`


**月カレンダーの日セルをタップ (day cell tap) (dead-control)** (?)

- 実害: intent: 日をタップしたらその日の詳細(記録/状態)シートが開いてほしい / actual: iOS: Button { onDayTap?(date) } → open(date:) で status/records を解決し .sheet(item:$selectedDay){ DayDetailSheet } を表示。Android: DayCell は素の Box で onClick 配線が一切無く、タップしても何も起きない。

- 根拠: `iOS（正しく機能）: app/GOExercise/GOExercise/Views/MonthlyCalendarView.swift:105-107（Button { onDayTap?(date) }）, :145（.buttonStyle(.plain)）; app/GOExercise/GOExercise/Views/HistoryView.swift:36-45（onDayTap→open(date:)配線）, :140-152（open(date:) で status/records 解決→selectedDay）, :135-137（.sheet(item:$selectedDay){ DayDetailSheet }）。

Android（dead-control・欠落）: app-android/app/src/main/java/com/goexercise/ap`


**前月/翌月ボタン (month nav) (mismatch)** (?)

- 実害: intent: 翌月ボタンは未来(現在月より先)へは進めないでほしい / actual: iOS: canShiftForward で現在月以降は disabled、chevron も淡色化。Android: nextMonth() が無条件に selectedMonth.plusMonths(1)。未来月へ無限に進め、全日 Future('-')の空カレンダーが表示される。

- 根拠: `iOS (正しい): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/MonthlyCalendarView.swift:247-252 (canShiftForward 判定), :60-69 (chevron 淡色化 + .disabled(!canShiftForward)), :312-316 (shiftMonth の months>0 && !canShiftForward 早期return)。

Android (バグ): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexerc`


**運動履歴セクションの展開トグル (history disclosure) (mismatch)** (?)

- 実害: intent: 履歴一覧を畳んで必要時だけ展開したい / actual: iOS: isHistoryExpanded トグルで展開/折りたたみ、a11y value も付与。Android: 履歴一覧セクション自体が HistoryScreen に存在しない(カレンダー+保険チケットボタンのみ)。

- 根拠: `iOS 履歴一覧+展開トグル+a11y: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/HistoryView.swift:11(isHistoryExpanded), :50-101(disclosure section), :53-79(toggle button), :81-82(accessibilityLabel/Value), :84-100(展開時 HistoryRowView), :135-137(DayDetailSheet 経路)。
Android 履歴リスト不在: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app`


**parity: DailyStatus の配色(達成=赤強調/休養・救済=緑系/未達成=青)** (?)

- 実害: 設計意図とiOSは『運動した日=赤』『休養・フリーズ=緑』『未達成=青』。Android colorForStatus は Achieved→success(緑)、Rest/Rescued→restDay(青系)、Missed→missed(赤/橙)で、赤緑青の意味が反転〜入れ替わっている。ユーザーの『赤=運動した強調』『青=未達成』という正本に真っ向から反する。

- 根拠: `iOS 正本: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/MonthlyCalendarView.swift:330-339 (achieved=赤0.93/0.33/0.30:333, rest=緑0.36/0.65/0.40:334, rescued=緑0.36/0.65/0.40:335, missed=青0.38/0.55/0.90:336)。

Android 写像: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/ui/theme/StatusColo`


**parity: 初記録(救済日)より前の日は中立 '-'(future)** (?)

- 実害: iOS は firstActivityDay(min(初記録, 初救済日))より前を表示層で .future('-')へ振替え、記録の無いユーザーの過去日も future にする。Android MonthlyCalendarCalculator にこのロジックが無く、初記録前の日が RestDayResolver により Rest(週最大2)または Missed として評価・表示される。設計意図『初記録より前は中立 -』の違反。

- 根拠: `iOS(振替あり): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/MonthlyCalendarView.swift:273-289(firstActivityDay = [firstRecordDay, firstRescuedDay].min(); date < first なら .future。記録ゼロの過去日も .future)。

iOS 共有評価器(振替なし=ビュー層専用と確認): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Models/DailyStatus.swift(.future = `


**parity: 生理日マーカー(★/ドット)のカレンダー表示** (?)

- 実害: iOS は menstrualDates を右上ドット+凡例+a11y で表示(QA_CHECKLIST F に必須記載)。Android HistoryScreen/Calculator に生理日の概念・引数・描画が一切無い。

- 根拠: `iOS 実装: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/MonthlyCalendarView.swift:6,17,23 (引数), :102 (isMenstrual), :126-134 (topTrailing 赤ドット), :172-174 (凡例 legendDot), :146 (a11y "生理日")
Android 欠落: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/domain/MonthlyCalendarCalculator.kt:1`


**parity: 救済(保険チケット使用)日のセル装飾(ticket.fill ドット)** (?)

- 実害: iOS は rescuedDates の日に右下 ticket.fill アイコン+凡例。Android は色(restDay)以外の救済固有マーカーが無く、休養日と視覚的に区別不能。

- 根拠: `iOS マーカー有: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/MonthlyCalendarView.swift:135-143 (ticket.fill オーバーレイ), :175-177 (凡例チップ), :334-335 (rest 0.55 vs rescued 0.32 背景差)。
Android マーカー無: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/history/HistoryScreen.kt:90-109 (D`


**parity: 凡例(legend)と休養ルール説明** (?)

- 実害: iOS は色スウォッチ凡例+『休養日は週2日まで自動カウント…最初の記録より前は集計されない』説明文を表示。Android は『達成 N 日』テキストのみで凡例・説明が無く、色の意味が読み取れない。

- 根拠: `iOS legend+explanation present: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/MonthlyCalendarView.swift:154 (legendRow), :156 (rest-day rule text "休養日は週2日まで自動でカウント…最初の記録より前の日は集計されません"), :163-180 (legendSwatch entries: 運動した日/休養日/保険チケット/未達成). Cell colors these swatches map to: :326-340.
Android missing both: /Users/jun/Documents/Business_Project_Man`


### cheers


**Android 送信完了トーストが入力した一言を反映しない** (?)

- 実害: 自由文の一言を添えて応援を送っても、送信完了トーストは kind.label(例『がんばれ』)しか表示せず、ユーザーが入力したmessageが出ない。iOS は『「<実テキスト>」を送りました』と送った内容をそのまま見せる。送れたか不安になる/別の文言を送った誤認を生む。送信自体は message 付きで届く(機能は正常)が、フィードバックの内容パリティ欠落。

- 根拠: `Android(欠陥): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/friends/FriendsViewModel.kt:259-260 (message を sendCheer に渡すがトーストは kind.label のみ); 呼び出し元 /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/friends/FriendsScreen.kt:983,996-1002 (自由文 m`


**Android に友達詳細画面が無く、応援UXの操作モデルが iOS と反転** (?)

- 実害: iOS は友達タップ→詳細シート(連続/称号/応援セクション/削除)で、プリセットは入力欄に反映するだけ・↑ボタンで明示送信。Android は友達タップが即 CheerPickerSheet を開き、プリセットチップ自体が即送信ボタン。詳細画面が存在せず(*FriendDetail* 0件)、プリセットの意味(反映 vs 即送信)が逆。誤タップで意図しない応援が即送信される誤誘導リスク。

- 根拠: `Android (one-tap immediate send, no detail screen):
- /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/friends/FriendsScreen.kt:750 (onTap = onOpenCheerPicker)
- FriendsScreen.kt:814-816 (combinedClickable onClick = { onTap(friend) } on avatar)
- FriendsScreen.kt:983 (preset chip: Modifier...clickable { onSend(kind, mess`


**受信応援トーストの単体/結合テストが両OSとも皆無(watermark前進含む)** (?)

- 実害: unseenReceivedCheers の『初回は今を起点で過去を出さない』『取得成功後のみ max(createdAt) へ watermark前進』『複数件サフィックス』はユーザー体験の核だが、両OSとも単体テストが無く、Mock も受信を返さないため受信経路全体が未テスト。watermark前進バグ(同じ応援が毎回トースト/逆に取りこぼし)が回帰しても検知できない。

- 根拠: `iOS prod: app/GOExercise/GOExercise/Services/SupabaseFriendsService.swift:765-799 (初回起点770-772, watermark前進795-797). iOS consumer: app/GOExercise/GOExercise/Services/FriendsService.swift:262-264,514-519; app/GOExercise/GOExercise/Views/FriendsView.swift:142-148 (複数件サフィックス148). iOS mock no-override: app/GOExercise/GOExercise/Services/FriendsService.swift:142 (default {[]}); MockFriendsService.swift`


**友達アバター/カードのタップ (mismatch)** (?)

- 実害: intent: 友達をタップしたら詳細(連続/称号)を見て応援したい / actual: iOS: detailFriend シートで FriendDetailView(プロフィール詳細+応援+削除)。Android: onTap が直接 CheerPickerSheet を開くだけで、友達詳細画面が存在しない。

- 根拠: `iOS tap→detail: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendsView.swift:981-982 (FriendsParkView onTap → detailFriend = friend), :175-178 (.sheet(item: $detailFriend) { FriendDetailView }); iOS detail content: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendDetailView.swift:18-57 (hero`


**送信完了トースト (mismatch)** (?)

- 実害: intent: 送った内容が分かるフィードバックが欲しい / actual: iOS: 実際に送った text(自由文/ラベル)を「『…』を送りました」。Android: kind.label のみ表示で、入力した自由文messageを反映しない。

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendDetailView.swift:331 (`Text("「\(sentCheerText)」を送りました")`), :386 (`sentCheerText = text`), :376 (text=trimmedCheerText), :379 (コメント「表示は常に message が優先される」). Android: app-android/app/src/main/java/com/goexercise/app/presentation/friends/FriendsViewModel.kt:260 (送信トーストが kind.label のみ・message 未使用`


**parity: 送信経路(detail vs picker)とプリセットの意味** (?)

- 実害: iOS は『友達詳細シート内の応援セクション』+『プリセット=入力欄に反映、↑で送信』。Android は『カードタップで即CheerPickerSheet』+『プリセットチップ=即送信』。詳細画面がAndroidに無く、操作モデルが反転。

- 根拠: `iOS: app/GOExercise/GOExercise/Views/FriendsView.swift:175-178 (.sheet → FriendDetailView), :980 (アバタータップで詳細・応援); app/GOExercise/GOExercise/Views/FriendDetailView.swift:18-31 (詳細1画面集約), :286-345 (cheerSection 入力欄+↑送信), :348-371 (cheerButton: プリセット=入力欄反映のみ), :375-395 (sendCheerMessage). Android: app-android/app/src/main/java/com/goexercise/app/presentation/friends/FriendsScreen.kt:799-817 (ParkAvat`


**parity: 送信完了トーストの内容** (?)

- 実害: iOS は実送信テキストを表示。Android は kind.label のみで自由文messageを反映しない。送ったはずの一言がフィードバックに出ない。

- 根拠: `iOS message echoed in send toast: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendDetailView.swift:386 (sentCheerText = text, where text = trimmedCheerText at :376) and :331 (Text("「\(sentCheerText)」を送りました")).

Android send toast ignores message: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com`


**parity: 受信トーストの複数件サフィックス/演出** (?)

- 実害: iOS は未読複数時『(ほかN件)』表示+成功haptic、表示3.0秒。Android は最新1件のみ、サフィックス無し・haptic無し、トースト2.0秒。複数受信時の取りこぼし感。

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendsView.swift:148 (suffix 件数), :151 (本文連結), :152 (hapticFeedback.success()), :154 (sleep 3.0秒)
Android: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/friends/FriendsViewModel.kt:273-276 (最新1件のみ・サフィックス無し・haptic無し)
`


### cycle


**Android は過去日の生理日を記録する手段が無い(当日のみ)** (?)

- 実害: iOS は専用 MenstrualEntryView の月カレンダーで任意の過去日をタップして★トグルできる(後付け記録)。Android の唯一の入口 WeightScreen CyclePanel は LocalDate.now() 固定で『今日』しかトグルできず、過去の生理日を遡って登録できない。周期オーバーレイは過去の period start が無いと相を推定できないため、機能としても実用性が大きく劣化する。

- 根拠: `iOS arbitrary-day toggle: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/MenstrualEntryView.swift:104 (Button per day), :130 (.disabled(isFuture) — only future blocked), :214-216 (toggle -> store.set on that date). Entry point: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/StatsView.swift:358-360 (`


**Android WeightScreen「今日を生理日に登録/解除」ボタン (mismatch)** (?)

- 実害: intent: (iOS同等なら)opt-in済みの時だけ当日を生理日トグル / actual: premium かつ周期パネル表示時に常時表示され、opt-in ゲート無しで当日トグル。当日のみで過去日マーク手段が無い

- 根拠: `Android（実装）:
- WeightScreen.kt:114 CyclePanel を premium 画面に常時配置（gate 無し）
- WeightScreen.kt:381-386 「今日を生理日に登録/解除」ボタンを無条件表示、onClick=onTogglePeriodDay(today)
- WeightScreen.kt:382 当日固定（today のみ）→ 過去日マーク不可
- WeightViewModel.kt:118 togglePeriodDay(date) = menstrual.toggle(date)（唯一の呼び出し元が今日固定）
- presentation/settings/SettingsViewModel.kt / SettingsScreen.kt: cycle/周期/menstrual の opt-in 設定が皆無（theme/prem`


**Android 履歴カレンダーの生理日★ (dead-control)** (?)

- 実害: intent: 記録した生理日が履歴カレンダーに★で出る(iOSパリティ) / actual: HistoryViewModel は periodDays を一切ロードせず、HistoryScreen に生理日マーク描画が無い=履歴に★が出ない(配線漏れ)

- 根拠: `Android missing (no period load): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/history/HistoryViewModel.kt:40-49 (combine without MenstrualRepository), :24-28 (HistoryUiState has no period field). Android no marker render: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/`


**parity: 生理日記録の opt-in(プライバシー ON/OFF)** (?)

- 実害: iOS は CycleTrackingSettings で全面ゲート(SPEC『体調・周期の記録ON/OFF』)。Android には対応する設定が存在せず、生理日記録/オーバーレイが opt-in 無しで露出

- 根拠: `iOS opt-in ゲートの定義: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/MenstrualStore.swift:77-91 (CycleTrackingSettings.isEnabled, key="cycle.tracking.enabled", defaults.bool 既定 false)。
iOS 設定トグル: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/SettingsView.swift:357 Toggle("体調・周期を記録する") + footer:359-`


**parity: 過去日含む生理日マーキングUI** (?)

- 実害: iOS は専用 MenstrualEntryView(月カレンダーで任意過去日トグル)+ Record画面の当日スイッチの2経路。Android は WeightScreen の『今日』ボタンのみで過去日を記録できない

- 根拠: `iOS calendar (arbitrary past-day toggle): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/MenstrualEntryView.swift:104-130 (Button{toggle(date:)} ... .disabled(isFuture)); wired at /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/StatsView.swift:360. iOS today switch: /Users/jun/Documents/Business_Proj`


**parity: 履歴月カレンダーでの生理日★表示** (?)

- 実害: iOS は履歴カレンダーに★+凡例を opt-in 時表示。Android 履歴は periodDays 未ロードで★非表示

- 根拠: `iOS 表示あり: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/HistoryView.swift:36-43 (menstrualDates を opt-in で注入); /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/MonthlyCalendarView.swift:126-134 (生理日ドット描画), :172-174 (生理日凡例)。
Android 非表示: /Users/jun/Documents/Business_Project_Management/serial_training`


### friends


**Android に友達詳細画面が無く、タップ操作の到達先がiOSと不一致** (?)

- 実害: iOS はアバタータップで FriendDetailView(週カレンダー/累計/つながって日数/応援/解除)を開くが、Android はタップで応援ピッカーを直接開くだけで、友達の週次達成・累計・解除を確認できる詳細画面が存在しない。iOS をパリティ基準とすると Android に画面1枚分の機能欠落。

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendsView.swift:175-176 (sheet→FriendDetailView), :981-984 (tap sets detailFriend); /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendDetailView.swift:18-57 (screen body), :209-228 + :433-478 (weekly strip), :238-256 (stats incl. connectedSinc`


**Android の友達解除が確認ダイアログ無しで即実行され、誤操作で解除されうる** (?)

- 実害: iOS は解除前に確認アラート(『再度つながるには友達コードで申請が必要』)を挟むが、Android は長押しドロップダウンの『友達を解除』タップで確認なしに即 remove する。長押しメニューの誤タップで友達が消え、復旧には再申請が必要。

- 根拠: `Android (no confirmation, immediate remove): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/friends/FriendsScreen.kt:851 (DropdownMenuItem onClick = { showMenu = false; onRemove(friend) }), reached via onLongClick at FriendsScreen.kt:816; wired through FriendsScreen.kt:136 (onRemove = viewModel::removeFriend) and Frien`


**Android の orderedPair が UUID を正規化せず、friendships_check 回帰の防御層が欠落** (?)

- 実害: iOS は承認時の friendships_check 違反バグ(UUID.uuidString が大文字でcheck(user_a<user_b)に違反)を orderedPair の両側 lowercased で根治した。Android の orderedPair は lowercase せず生比較で、refreshFriends も生文字列一致(it.userA==uid)。実行時の Supabase auth id は小文字のため現状は動くが、大文字IDが一箇所でも混じると順位反転で承認失敗/友達消失になる。iOSの再発防止策がAndroidに移植されていない。

- 根拠: `iOS 正規化(根治): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/SupabaseFriendsService.swift:860-863 — `let lx = x.lowercased(), ly = y.lowercased(); return lx < ly ? (lx, ly) : (ly, lx)`、コメント857-859 が iOS 承認失敗バグの修正と明記。
Android orderedPair(生比較・正規化欠落): app-android/app/src/main/java/com/goexercise/app/data/friends/SupabaseFriendsService.kt:57-58 — `pr`


**友達解除 (iOS) (mismatch)** (?)

- 実害: intent: 長押し等で友達を解除できる / actual: iOS: 公園には長押し解除が無い。解除は FriendDetailView 内の『友達を解除』ボタン→確認アラート経由のみ。設計意図の『長押し→解除』はiOS未実装(詳細画面に移設)

- 根拠: `/Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendsParkView.swift:43-44 (Button{ onTap(friend) }), :92 (buttonStyle(.plain)) — 長押し/contextMenu/swipe/解除 は grep でゼロヒット。 /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendDetailView.swift:399-411 (removeButton「友達を解除」), :42-55 (確認アラート→ friendsStore.`


**FriendsView の pendingRemovalFriend 解除アラート (iOS L179-196) (dead-control)** (?)

- 実害: intent: -(内部状態) / actual: pendingRemovalFriend を立てる呼び出し元がコード上に存在せず(grep で set箇所ゼロ)、このアラートは発火しない死コード。解除はすべて FriendDetailView 側で処理

- 根拠: `FriendsView.swift:29 (宣言 nil); :172 (onChange ==nil 比較・読み取り); :180,182,185 (presenting/getter 読み取り); :183,189,192 (=nil 代入のみ — 非nil 代入は皆無); :179-196 (発火しないアラート本体); :982 (友達タップ→detailFriend のみ設定); :1041 (==nil 読み取り)。解除の実機能: FriendDetailView.swift:43-48 (独立アラート→friendsStore.remove(friend)), :403 (解除ボタン)。リポ全 grep 結果: pendingRemovalFriend は FriendsView.swift のみに出現、非nil 代入ゼロ。`


**友達追加シートの『QRを読み取る』導線 (Android) (mismatch)** (?)

- 実害: intent: QRはアプリ内スキャナで読み取って友達追加できる(設計意図) / actual: Android の AddFriendSheet はコード手入力欄のみ。アプリ内QRスキャナが存在せず、QR読取は端末標準カメラ→goexercise://ディープリンク頼み。設計意図『QRはアプリ内スキャナ』を満たさない

- 根拠: `Android (intent違反の実体):
- app-android/app/src/main/java/com/goexercise/app/presentation/friends/FriendsScreen.kt:940-964 (AddFriendSheet=コード手入力欄+申請ボタンのみ、スキャナ無)
- app-android/app/src/main/java/com/goexercise/app/presentation/friends/QrCode.kt:16-22,38-39 (生成専用 QRCodeWriter().encode、decode/scan 無)
- app-android/app/build.gradle.kts:152 + gradle/libs.versions.toml:42 (zxing-core のみ。embedded/CameraX/ML`


**parity: アバタータップの遷移先** (?)

- 実害: iOS=タップで FriendDetailView(週カレンダー/累計/つながって日数/応援/解除を集約した詳細画面)。Android=タップで CheerPickerSheet を直接開くのみで、友達の週次/累計/解除を確認できる詳細画面が存在しない。iOS基準で Android に詳細画面が欠落

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendsView.swift:981-984 (FriendsParkView tap → detailFriend = friend); /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendDetailView.swift:18-57 (body: heroHeader/todayCard/weeklySection/statsCard/cheerSection/removeButton), :209-228 (週カレンダー), `


**parity: アプリ内QRスキャナ** (?)

- 実害: iOS=AVFoundation自前スキャナ(QRScannerView)で goexercise:// 限定読取。Android=スキャナ未実装。Android の友達追加はコード手入力 or 端末標準カメラのディープリンク依存で、設計意図『QRはアプリ内スキャナ』に未到達

- 根拠: `iOS スキャナ実装: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/QRScannerView.swift:128-160 (AVCaptureSession/AVCaptureMetadataOutput, metadataObjectTypes=[.qr]), :99-112 (goexercise://限定の friendCode抽出)。
iOS スキャナ提示: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendAddView.swift:41-46 (「QRコードを読み取る」ボタン`


**parity: 友達解除の確認** (?)

- 実害: iOS=解除前に確認アラート(『再度つながるには申請が必要』)。Android=長押しドロップダウンの『友達を解除』タップで確認なしに即 remove。誤タップ解除リスクの差

- 根拠: `iOS confirm gate: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendDetailView.swift:42-55 (.alert with destructive confirm + "再度つながるには友達コードで申請が必要です。") and FriendDetailView.swift:399-411 (button only sets pendingRemoval=true). Android immediate removal: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/jav`


**parity: 友達コードのコピーボタン** (?)

- 実害: iOS=コード横にコピー専用ボタン(pasteboard+トースト)。Android=コピー専用ボタンが無く共有(ACTION_SEND)アイコンのみ

- 根拠: `iOS copy button: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendsView.swift:808-820 (UIPasteboard.general.string = profile.friendCode + showCopyToast, id "copy-friend-code"); iOS share+QR separately at 821-839. Android (no copy button): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexerci`


**parity: 招待共有テキストの内容** (?)

- 実害: iOS=連続日数を載せない簡素文(ユーザー要望で削除)。Android=friendShareText が username と『🔥N日連続』を含む。共有文の内容が不一致

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendsView.swift:1129-1132 (shareText: code + shareURL のみ、streak/username 無し、コメント「連続日数は載せない(ユーザー要望)」), 同821 (ShareLink(item: shareText(for: profile)) で使用)。
Android: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/frien`


**parity: UUID大小の正規化(friendships_check)** (?)

- 実害: iOS orderedPair は両IDを lowercased してから比較・格納(UUID.uuidStringが大文字でcheck違反した承認バグの修正)。Android orderedPair は lowercase せず生文字列比較。実行時のSupabase authidは小文字のため現状は破綻しないが、正規化の防御がiOSにのみ存在

- 根拠: `iOS 正規化あり: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/SupabaseFriendsService.swift:860-863 (let lx = x.lowercased(), ly = y.lowercased(); return lx < ly ? (lx, ly) : (ly, lx)) — コメント857-859に「iOS固有の承認失敗バグの修正」と明記。
Android 正規化なし: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/da`


### notifications


**Android: 達成日でもリマインダーが発火する(当日cancel機能の欠落)** (?)

- 実害: iOS は記録達成時 rescheduleAfterAchievement で当日の催促通知を抑制し翌日以降だけ残す(spec『達成後通知は原則不要』QA『達成日に当日通知をcancel』)。Android は setInexactRepeating の固定毎日アラームのみで、記録/達成時にスケジューラを呼ばないため、今日運動を終えたユーザーにも夜の催促が届く。習慣化アプリの体験上、達成者を無意味に急かす逆効果。構造的に setInexactRepeating では当日skipが不可能で、iOSのrolling one-shot方式への移植が必要。

- 根拠: `Android (欠落側): app-android/app/src/main/java/com/goexercise/app/notification/ReminderScheduler.kt:23-31 (setInexactRepeating INTERVAL_DAY 固定毎日, 当日skip不能); ReminderReceiver.kt:20-37 (発火時に達成状態を読まず無条件 notify, ガード無し); SettingsViewModel.kt:78-83 (唯一の schedule/cancel 呼び出し=設定変更時のみ); HomeViewModel.kt (reminderScheduler 呼び出しゼロ — grep no hits)。呼び出し全数=SettingsViewModel.kt:81 + BootReceiver.kt:21 のみ、達成フロー経由なし`


**Android: 通知設定が ON/OFF+単一時刻のみ(回数/2本目/性格が欠落)** (?)

- 実害: spec 13.5 と iOS は 通知回数(1日1/2回)・通知時間1/時間2・性格モード(静か/標準/友達駆動)を提供。Android の ReminderPrefs は enabled/hour/minute の3項目のみで、初期仕様『1日2回』(spec 13.2/24.5)を満たさず、2本目の夕方通知も性格制御も存在しない。iOSパリティとして大きな機能不足。

- 根拠: `Android (欠落側): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/data/settings/NotificationPrefsRepository.kt:19 (data class ReminderPrefs = enabled/hour/minute のみ), :24/:45 (set シグネチャも enabled,hour,minute のみ); .../presentation/settings/SettingsViewModel.kt:78-83 (setReminder 単一hour/minute → schedule(hour,minute) 1回のみ); .../notificati`


**通知設定: 通知回数 Picker / 通知時間2 / 性格 Picker (mismatch)** (?)

- 実害: intent: 通知ON/OFF・回数(1日1/2回)・時間1/時間2・性格(静か/標準/友達駆動)を設定できる(spec 13.5) / actual: iOS=全部あり。Android=ON/OFF と単一時刻のみ。回数・2本目時刻・性格モードが存在しない

- 根拠: `iOS has features: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/NotificationSettingsView.swift:24-28 (count Picker 1日1回/1日2回), :32-37 (通知時間1 + conditional 通知時間2), :40-58 (性格 Picker + footer). Android missing: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/data/settings/Notification`


**達成日に当日通知を cancel (rescheduleAfterAchievement) (mismatch)** (?)

- 実害: intent: 今日達成したら今日の催促通知は消し、翌日以降は残す(QA I, spec 達成後通知は原則不要) / actual: iOS=記録達成で rescheduleAfterAchievement→todayAchieved で当日分skip。Android=記録/達成時にスケジューラを一切呼ばず、setInexactRepeating の固定毎日アラームが達成日も発火する

- 根拠: `iOS 達成後 reschedule: app/GOExercise/GOExercise/Views/HomeView.swift:159-164 (rescheduleAfterAchievement 呼び出し); 当日スキップ実装: app/GOExercise/GOExercise/Services/NotificationScheduler.swift:132-134 (todayAchieved:true), :82 (removeAllPendingNotificationRequests), :100-104 (isToday && todayAchieved で今日分 continue)。

Android 固定毎日アラーム: app-android/app/src/main/java/com/goexercise/app/notification/ReminderSch`


**parity: 通知タップで route=home を deep-link で渡す** (?)

- 実害: iOS は userInfo["route"]=home を明示付与し DeepLinkRouter 経由で解決。Android の ReminderReceiver は data URI も extra も付けず、MainActivity の deep-link 消費経路(intent.dataString)を通らない。今は startDestination=home のため結果オーライだが、将来 route 別通知(streak-share 等)を足すと Android だけ無反応になる脆い実装

- 根拠: `iOS route 付与: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/NotificationScheduler.swift:174 (content.userInfo = ["route": AppRoute.home.rawValue])
iOS route 解決: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/AppDelegate.swift:41-47 (userInfo["route"] → DeepLinkRouter.shared.pendingRoute)
Andr`


**parity: ローリング7日 one-shot 予約方式** (?)

- 実害: iOS は removeAll→今日+7日分の one-shot を貼り直し、達成日skip/時刻超過skip/64件上限考慮。Android は setInexactRepeating の単一繰り返しアラームで「達成日だけ抑制/翌日以降残す」が構造的に不可能

- 根拠: `iOS rolling one-shot: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/NotificationScheduler.swift:54 (rollingDays=7), :82 (removeAllPendingNotificationRequests), :100-104 (offset 0...rollingDays + todayAchieved skip), :160 (fireDate<=now skip), :138-142 (per-day identifier). iOS achievement-driven reschedule: app/GOExercise/GOExercise/Views/HomeV`


**parity: 通知性格モード(quiet/voice/friendDriven)による配信制御** (?)

- 実害: iOS は personality で 朝夕/夕のみ/抑制 を切替、quiet は streakAtRisk 時のみ。Android に personality 概念が存在しない

- 根拠: `iOS personality gating: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/NotificationScheduler.swift:90-119 (line 91 friendDriven early-return, 92-93 quiet streakAtRisk gate, 106-114 voice morning+evening, 115-119 quiet evening-only). iOS enum + persistence: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise`


**parity: 通知回数(1日1/2回)と2本目(夕方)通知** (?)

- 実害: iOS は morning+evening の2枠を notificationCount で制御。Android は単一時刻アラームのみで2本目が無い(spec 初期1日2回に未達)

- 根拠: `iOS 2枠+count制御: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/NotificationScheduler.swift:19-21,26-27,84,106-114(notificationCount, morning/evening, voice時 count>1 で evening 追加)。store の上限2: 同 :199,205-211。
Android 単一アラーム: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/notificati`


**parity: 通知メッセージ(連続/週進捗/性格でパーソナライズ)** (?)

- 実害: iOS は NotificationMessageProvider で streak/週進捗/性格/日付シードに応じ本文生成。Android は固定文言1種「今日の運動、どう？」

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/NotificationScheduler.swift:90-119 (personality分岐), :162-172 (message呼び出し with slot/personality/streak/weeklyProgressRate/seedDate); /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/NotificationMessageProvider.swift:19-77 (quiet/週進捗/streak/朝晩/日`


### onboarding


**Androidオンボ補足文が「あとから設定でいつでも変更できます」と表示し、有料ゲートを誤誘導** (?)

- 実害: iOSは『あとで種類を変えるにはプレミアムが必要』と明記。Androidは『あとから設定でいつでも変更できます』と表示。本来はプレミアム要だが、上記設定ロック欠落と相まって『無料で変更できる』という誤った期待を与える(かつ現状Androidは実際に無料変更できてしまう)。文言とゲートの両方が意図と乖離。

- 根拠: `Android copy (no premium caveat): app-android/app/src/main/java/com/goexercise/app/presentation/onboarding/OnboardingScreen.kt:71 — "選んだ猫はホーム画面・達成演出・友達一覧で使われます。あとから設定でいつでも変更できます。"
iOS copy (premium caveat present): app/GOExercise/GOExercise/Views/UserCatPickerView.swift:83-84 — "...今だけ全種類から自由に選べます(あとで種類を変えるにはプレミアムが必要)。"
Intended rule: app/GOExercise/GOExercise/Models/CatBreedAccess.swift:8-11 — is`


**下部プライマリボタン 「つぎへ/はじめる」 (iOS) / 「この猫ではじめる」 (Android) (mismatch)** (?)

- 実害: intent: 猫を確定し、2ステップ目(サインイン)へ進む。連携無効ビルドではそのまま完了 / actual: iOS: commitSelectedCat後 isTwoStepOnboarding なら showBackupStep=true、そうでなければ完了。Android: onFinish(selected)で即 settings.setCatBreed+setOnboardingComplete し本編へ — サインインステップが存在しない

- 根拠: `iOS 2ステップ分岐: app/GOExercise/GOExercise/Views/UserCatPickerView.swift:171-179 (advanceFromCatSelection → isTwoStepOnboarding ? showBackupStep=true : completeOnboarding()); :45-47 (isTwoStepOnboarding = isOnboarding && SupabaseConfig.isAccountLinkingEnabled); :185-208 (backupStep = Apple/Google サインイン AccountBackupSignIn)。ゲート: app/GOExercise/GOExercise/Services/SupabaseConfig.swift:39-48 (appleLinkEn`


**ステップ2 Appleでサインイン ボタン (dead-control)** (?)

- 実害: intent: タップでApple認証→記録バックアップ自動ON→オンボ完了 / actual: iOS: AppleIDButton→signInWithApple→restoreWithApple→recordSync.enableBackup()→onFinished(true)→completeOnboarding。Android: オンボにこのボタンが存在しない(配線漏れ)

- 根拠: `iOS wired flow: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/AccountBackupSignIn.swift:32-45 (Apple/Google buttons), :65-79 (signInWithApple→restoreWithApple), :92-107 (finish→recordSync.enableBackup()→onFinished(true)). iOS onboarding step 2 integration: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/V`


**ステップ2 「あとで」スキップボタン (mismatch)** (?)

- 実害: intent: サインインせずオンボを完了できる(任意) / actual: iOS: showsSkip=true で表示、onFinished(false)→completeOnboarding。Android: ステップ2自体が無いため概念上スキップは常時(暗黙)だが明示的選択肢なし

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/AccountBackupSignIn.swift:14 (var showsSkip), :46-52 (if showsSkip { Button("あとで") { onFinished(false) } ... accessibilityIdentifier("backup-signin-skip") }); /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/UserCatPickerView.swift:174-178 (isTwoStep`


**parity: オンボーディングが2ステップ(猫選択→サインイン/バックアップ)である** (?)

- 実害: iOSは isTwoStepOnboarding 時に2ステップ(猫選択→AccountBackupSignIn)。Androidは猫選択1ステップのみで、サインイン/バックアップステップが完全に欠落。設計意図の中核(サインインで記録バックアップ自動ON)がAndroidオンボで提供されない

- 根拠: `iOS 2-step onboarding: app/GOExercise/GOExercise/Views/UserCatPickerView.swift:36-41 (body switches to backupStep), :45-47 (isTwoStepOnboarding = isOnboarding && SupabaseConfig.isAccountLinkingEnabled), :171-179 (advanceFromCatSelection sets showBackupStep), :185-223 (backupStep with AccountBackupSignIn — sign-in auto-enables backup). Gate: app/GOExercise/GOExercise/Services/SupabaseConfig.swift:4`


**parity: 2画面のヘッダー統一(ステップ \(step\)/2 バッジ + 大見出し + 補足)** (?)

- 実害: iOSは onboardingHeader を両ステップで共有しステップバッジを表示。Androidは1ステップのみで「ようこそ🐾」+見出しのハードコード、ステップ表記なし(2画面統一の概念が不在)

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/UserCatPickerView.swift:45-70 (isTwoStepOnboarding ゲート + 共有 onboardingHeader + ステップ \(step) / 2 バッジ), :79 (step:1), :130 (つぎへ/はじめる), :185-223 (backupStep step2 全体), :217 (もどる). Android: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/ap`


**parity: 設定からの猫種変更でロック判定(非プレミアムは現猫種以外ロック・paywall)** (?)

- 実害: iOSは設定再選択時 CatBreedAccess.isLocked でロック猫タップ→showPaywall、確定時もロック猫は現状維持。Androidの設定CatBreedPickerは isPremium等を一切参照せず onSelect(breed) を無条件呼出し=非プレミアムでも全猫種変更し放題。プレミアムゲートがAndroid設定で無効

- 根拠: `iOS gate def: app/GOExercise/GOExercise/Models/CatBreedAccess.swift:8-11
iOS settings-only lock + paywall: app/GOExercise/GOExercise/Views/UserCatPickerView.swift:258-261 (cell lock→showPaywall), :163-168 (commit revert), :256-258 (onboarding intentionally unlocked)
Android picker no gate: app-android/app/src/main/java/com/goexercise/app/presentation/settings/SettingsScreen.kt:307-332 (esp. :318 ``


### paywall


**Android: trialOffer が eligibility 無視で無料 offer を常時優先選択** (?)

- 実害: purchase()/displayPrice() が trialOffer() で priceAmountMicros==0 を含む offer を無条件優先する。コメントが『paywall は常に14日無料表示するため』と認めており、Play 側でトライアル非対象(消化済み)ユーザーに対し offer eligibility を確認していない。表示・購入フローが実際の課金と乖離し得る。TODO(#10)として既知だが未着手で、上記の常時無料表示問題と複合する

- 根拠: `app-android/app/src/main/java/com/goexercise/app/data/billing/PlayBillingPremiumRepository.kt:167-176 (trialOffer eligibility無視, コメント自認/TODO#10); :134 (purchase が trialOffer 使用); :160-165 (displayPrice が trialOffer 使用); app-android/app/src/main/java/com/goexercise/app/presentation/premium/PremiumPaywallScreen.kt:124,155,175,179 (「14日間無料」「解約すれば課金されません」を無条件ハードコード); app/GOExercise/GOExercise/Services`


**intro/trial eligibility 出し分けの自動テストが iOS/Android とも皆無** (?)

- 実害: 誤無料表示は App 審査(2.3.1/3.1.2)直撃の最重要パスだが、iOS の refreshIntroEligibility/refreshPurchaseState・Android(未実装)とも単体テストが無い。猫種ロックは iOS のみ CatBreedAccessTests で守られているが Android は無検証。回帰検知が効かない

- 根拠: `iOS eligibility 実装(無テスト): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/StoreKitManager.swift:25 (isEligibleForIntroOffer), :106 (refreshIntroEligibility), :121 (refreshPurchaseState), :187-189 (restorePurchases→refreshPurchaseState), :199-206 (handleVerified)。GOExerciseTests/ 内で当該シンボルを参照するテスト 0 件(grep -rl 結果空)。CatBreedAccessTests.swift:1-17 は `


**Android ペイウォール「14日間無料」表示(ヘッダー/CTA/開示) (mismatch)** (?)

- 実害: intent: トライアル消化済みなら「14日間無料」を見せない / actual: eligibility 判定が一切無く、常に「14日間無料。いつでも解約できます。」「14日間無料で始める」「14日間の無料体験後…」をハードコード表示。PremiumRepository に isEligibleForIntroOffer 相当が存在しない

- 根拠: `Android (実在・無条件表示): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/premium/PremiumPaywallScreen.kt:124,155,175,179
Android (eligibility API 不在): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/data/billing/PremiumRepository.kt:32-49(interface), :55-77(Mo`


**Android 設定>猫種ピッカー(11種タップ) (mismatch)** (?)

- 実害: intent: 無料/未解放ユーザーは現在の猫のみ。種類変更はプレミアム(または紹介⭐10)。タップ時はペイウォール誘導 / actual: CatBreedPicker は isPremium も referralUnlocked も受け取らず、全11種が無条件で clickable。onSelect=setCatBreed が即永続化。ロック無し・ペイウォール誘導も無し=プレミアム機能のバイパス

- 根拠: `Android (バグ): app-android/app/src/main/java/com/goexercise/app/presentation/settings/SettingsScreen.kt:307-332 (CatBreedPicker、gate無し・312-318行で全種無条件 clickable→onSelect)、同 :87 (onSelectBreed = viewModel::setCatBreed)、SettingsViewModel.kt:69-71 (setCatBreed 無条件)、data/settings/SettingsRepository.kt:85-87 (DataStore へ無条件 write)。オンボ別経路: presentation/onboarding/OnboardingViewModel.kt:53-59。
iOS (正本/inte`


**parity: トライアル eligibility による「14日間無料」出し分け** (?)

- 実害: iOS は isEligibleForIntroOffer で文言を再評価・前面復帰/復元/更新でも更新。Android は eligibility 概念そのものが無く、全ユーザーに「14日間無料」を常時表示。トライアル消化済み Android ユーザーに即課金を無料と誤認させる(設計意図の正面衝突)

- 根拠: `iOS source-of-truth: app/GOExercise/GOExercise/Services/StoreKitManager.swift:25 (isEligibleForIntroOffer property), :106-115 (refreshIntroEligibility via sub.isEligibleForIntroOffer, false when unloaded), :121-124 (refreshPurchaseState on foreground), :187-189 (restore re-eval), :204-205 (transaction-update re-eval). iOS gated copy: app/GOExercise/GOExercise/Views/PremiumPaywallSheet.swift:88-90 `


**parity: 猫種変更のプレミアム gate** (?)

- 実害: iOS は設定からの猫種変更を CatBreedAccess.isLocked + 確定時巻き戻しで二重に gate し、ロック猫タップでペイウォール誘導。Android は全11種が無料で自由に切替可能=課金機能のバイパス。CatBreed.kt に isLocked 移植が無い

- 根拠: `iOS gate definition: app/GOExercise/GOExercise/Models/CatBreedAccess.swift:8-11 (`!isPremium && !referralUnlocked && breed != current`). iOS enforcement in picker cell (lock + paywall): app/GOExercise/GOExercise/Views/UserCatPickerView.swift:258-261 (locked computed only when !isOnboarding) and :261 (`if locked { showPaywall = true }`), lock overlay :275-280. iOS commit-time revert: UserCatPickerV`


**parity: 紹介⭐10での全種解放(referralUnlocked)** (?)

- 実害: iOS は CatBreedAccess に referralUnlocked パラメータがあり紹介解放を猫種ロックに反映。Android は猫種 gate 自体が無いため referralUnlocked の連動も存在せず(rescue 枠には referralBonus 連動あり=部分実装)

- 根拠: `iOS gate定義: app/GOExercise/GOExercise/Models/CatBreedAccess.swift:8-11 (isLocked に referralUnlocked パラメータ)。iOS gate施行: app/GOExercise/GOExercise/Views/UserCatPickerView.swift:21 (referralUnlocked 算出), :163-169 (commitSelectedCat でロック時に現状維持へ巻き戻し), :259 (グリッドでロック判定)。

Android 猫種ロック未実装: app-android/app/src/main/java/com/goexercise/app/domain/CatBreed.kt:8-54 (gate ロジック皆無)。Android picker が無条件選択: app-a`


**parity: Play trial offer の eligibility 選択** (?)

- 実害: Android は trialOffer() が priceAmountMicros==0 を含む offer を無条件優先し『常に14日無料表示するため』とコメント。Play 側 eligibility(消化済みなら trial offer が返らない/別 base plan)を考慮せず、表示と実購入が乖離するリスク。TODO(#10)として既知だが未対応

- 根拠: `app-android/app/src/main/java/com/goexercise/app/data/billing/PlayBillingPremiumRepository.kt:167-176 (trialOffer は 0円フェーズ含む offer を無条件優先、TODO(#10) eligibility 未対応); :134 (purchase が同 trialOffer を使用); :163 (displayPrice も同 offer); app-android/.../billing/PremiumRepository.kt:32-49 (interface に eligibility プロパティ無し); app-android/.../presentation/premium/PremiumPaywallScreen.kt:124,155,175,179 (「14日間`


### recording


**Android に『よく使う種目』履歴サジェストが無い(最終使用日順チップ未実装)** (?)

- 実害: 設計意図『よく使う種目は横スクロールチップ(種目は最終使用日順)』に対し Android はサジェスト機構・UI が皆無。毎回種目名を手入力する必要があり、iOS の主要な入力速度向上要素が欠落。ExerciseHistoryProvider 相当が未移植

- 根拠: `iOS implemented: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/ExerciseHistoryProvider.swift:21-55 (topExerciseNames, lastUsedDate-desc sort at :46-52); /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/ExerciseInputRow.swift:109-140 (「よく使う種目」horizontal chips, tap sets draft.name at :119). Android `


**Android 記録フローに体重・生理日の同時入力導線が無い** (?)

- 実害: iOS は記録画面で今日の体重(kg)と生理日トグルを任意入力でき、体重ストア/周期に反映する(『ホームの記録からの体重入力は無料』という SPEC の前提導線)。Android の記録画面には両方とも無く、無料体重入力の導線が断たれている可能性。記録ドメイン内のクロス機能導線の欠落

- 根拠: `iOS (前提が実在):
- /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/RecordEntryView.swift:70-75 (生理日トグル), :77-93 (今日の体重(任意)入力), :111-112 (weightStore/menstrualStore へ反映)
- /Users/jun/Documents/Business_Project_Management/serial_training/docs/SPEC_iOS.md:82 「未加入時はぼかし+ペイウォール(「ホームの記録からの体重入力は無料」と明記)」

Android (導線欠落 + 無料経路の遮断):
- /Users/jun/Documents/Business`


**「＋ 同じ種目でセットを追加」ボタン (mismatch)** (?)

- 実害: intent: 名前・種類(カテゴリ)・重さ(kg) を引き継いだ行を直下に複製し、回数/時間/セットだけ入れ直せる / actual: iOS: addSet(after:) が name/category/loadText を複製(reps/sets/minutes/memo は空)。Android: addSet が name/category のみ複製、重さ(loadKilograms)は引き継がない=そもそも入力欄が無い

- 根拠: `iOS(正): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/ViewModels/RecordEntryViewModel.swift:123 `let copy = ExerciseDraft(name: source.name, category: source.category, loadText: source.loadText)`; loadText 定義 :20/:30/:39; 保存変換 :97 `loadKilograms: Self.parsedLoad(draft.loadText)`.
Android(欠落): /Users/jun/Documents/Business_Project_Management/serial_train`


**重さ(kg) フリー入力フィールド (dead-control)** (?)

- 実害: intent: 種目ごとに器具重量を kg で自由入力でき、保存・複製・サマリに反映される / actual: iOS: TextField($draft.loadText) decimalPad、parsedLoad で 0<v<1000 を保存、collapsedSummary に kg 表示。Android: ExerciseDraft に loadText/重さフィールドが存在せず、UI も無い(VM doc に『体重/種目サジェストは後続』)

- 根拠: `iOS present: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/ExerciseInputRow.swift:148-164 (TextField loadText, decimalPad), :55-56 (collapsedSummary kg); /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/ViewModels/RecordEntryViewModel.swift:97 (loadKilograms save), :104-108 (parsedLoad 0<v<1000), :123 (add`


**「よく使う種目」候補チップ (横スクロール) (dead-control)** (?)

- 実害: intent: 履歴から最終使用日の新しい順に種目名チップが出て、タップで種目名を一発入力 / actual: iOS: suggestions(for:category) を ExerciseInputRow が横スクロールチップ表示、タップで draft.name 代入、空なら案内文。Android: サジェスト機能・チップ自体が未実装

- 根拠: `iOS implemented: ExerciseInputRow.swift:109-140 (chips + tap sets draft.name + empty-state text), ExerciseHistoryProvider.swift:21-55 (recency-first sort), RecordEntryViewModel.swift:149-150 (suggestions wiring), RecordEntryView.swift:31 (passes suggestions). Android missing: RecordScreen.kt:140-146 (plain OutlinedTextField, no suggestion chips; FilterChip at :137 is category-only), RecordViewMode`


**parity: 重さ(kg)フリー入力** (?)

- 実害: iOS は種目ごとに重さ(kg)をフリー入力し保存・サマリ表示・セット複製に引き継ぐ。Android は入力 UI 自体が無く ExerciseDraft に loadText フィールドも無い。設計意図『重さkgフリー入力』を満たさない。loadKilograms はバックアップ往復のためモデルにだけ残るが書き込み経路ゼロ

- 根拠: `iOS: app/GOExercise/GOExercise/Views/ExerciseInputRow.swift:148-164 (kg TextField, $draft.loadText), :55-57 (summary 'Nkg'); app/GOExercise/GOExercise/ViewModels/RecordEntryViewModel.swift:97 (loadKilograms: parsedLoad(draft.loadText)), :104-108 (parser), :123 (addSet carries loadText); app/GOExercise/GOExercise/Models/ExerciseItem.swift:11,33 (loadKilograms). Android: app-android/app/src/main/jav`


**parity: addSet で重さを引き継ぐ** (?)

- 実害: iOS addSet は name/category/loadText を複製。Android addSet は name/category のみ。重さ欄自体が無いため必然的に欠落。設計意図『名前/種類/重さを引継ぎ複製』のうち重さが欠ける

- 根拠: `app/GOExercise/GOExercise/ViewModels/RecordEntryViewModel.swift:123 (iOS addSet copies loadText); app-android/app/src/main/java/com/goexercise/app/presentation/record/RecordViewModel.kt:64 (Android addSet omits load); app-android/.../record/RecordUiState.kt:18-26 (ExerciseDraft has no weight field) and :40-48 (validExercises never sets loadKilograms); app-android/.../domain/ExerciseItem.kt:19-21 (`


**parity: よく使う種目(履歴サジェスト)チップ・最終使用日順** (?)

- 実害: iOS は ExerciseHistoryProvider が『最終使用日の新しい順→使用回数→名前順』でサジェストし、デフォルト候補とマージして横スクロールチップ表示。Android にはサジェスト機構・UI が一切無い。設計意図『よく使う種目は横スクロールチップ(種目は最終使用日順)』未達

- 根拠: `iOS present: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/ExerciseHistoryProvider.swift:21-55 (sort lhs.lastUsedDate > rhs.lastUsedDate then count then localizedStandardCompare, lines 46-52); /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/ExerciseInputRow.swift:109-140 ("よく使う種目" horizontal chip`


**parity: 体重・生理日の同時記録** (?)

- 実害: iOS は記録画面で体重(kg)と生理日トグルを任意入力可。Android の記録画面には無い(別ドメインだが記録フロー内導線が欠落)

- 根拠: `iOS 体重入力: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/RecordEntryView.swift:77-93 (Section「今日の体重 (任意)」+ TextField「体重 (kg)」decimalPad)
iOS 生理日トグル: 同ファイル:70-75 (Section「体調・周期」+ Toggle「今日は生理日」, cycleSettings.isEnabled ゲート)
iOS 保存連動: 同ファイル:111-112 (weightStore へ save / menstrualStore?.set)

Android 記録画面に両方とも無し: /Users/jun/Documents/Business_Project_`


**parity: 時間/回数/セットの入力方式** (?)

- 実害: iOS はプルダウン(離散値・全角防止狙い)、Android は数字キーボードのフリー入力。保存される意味は同等だが UX とバリデーション(iOS:離散・上限 / Android:桁数clamp)が異なる

- 根拠: `iOS 離散プルダウン: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/ExerciseInputRow.swift:145-147(labeledPicker 呼出)、:232-234(minuteOptions 0..100 step5 / repOptions 0..50 / setOptions 0..10)、:236-271(Menu+Picker 実装)、:148-162(重さ kg フリー入力 loadText)。
Android フリー入力: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java`


**parity: 保存不可理由の表示** (?)

- 実害: iOS は disabledReason で『種目名を1つ以上』『体重は0〜500kg』と理由を出し分け。Android は種目名未入力の固定文のみで、不正値理由(体重・重さ)は無い(該当入力が無いため部分的)

- 根拠: `iOS disabledReason: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/ViewModels/RecordEntryViewModel.swift:72-80 (branches), :49-63 (parsedWeight/hasWeightInputButInvalid), :104-108 (parsedLoad), :66 (canSave). iOS inputs: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/RecordEntryView.swift:77-89 (body-weig`


### referrals


**Android の星バッジ/今月フリーズ表示が口座一致チェックを経ず raw summary を直読み** (?)

- 実害: iOS は表示・allowance 反映を必ず currentAccountStarBadges/currentAccountFreezeBonus/isBreedUnlocked(forAccount:) の口座一致ガード経由にして、切替/復元直後(未refresh)の stale entitlement を防ぐ。Android は SettingsScreen(referralStarBadges) と RescueViewModel(freezeBonusThisMonth) が raw な referralStore.summary を直読み。resetForIdentityChange() の同期クリアに依存するが、reset 呼び出し経路に乗らない/呼ぶ直前の一瞬は前アカウントの星・フリーズ枠が見え得る(再発バグ型(1)口座スコープ漏れの at-risk)

- 根拠: `iOS guards (present): app/GOExercise/GOExercise/Services/ReferralStore.swift:108-111 (isBreedUnlocked forAccount), :116-119 (currentAccountStarBadges), :124-127 (currentAccountFreezeBonus); consumed at app/GOExercise/GOExercise/Views/RescueTicketUseView.swift:19. Android raw reads (no guard): app/src/main/java/com/goexercise/app/presentation/rescue/RescueViewModel.kt:57,60,72; app/src/main/java/co`


**猫種ピッカーの各猫タップ (設定 CatBreedPicker / UserCatPickerView) (mismatch)** (?)

- 実害: intent: 無料ユーザーは今の猫以外ロック。紹介⭐10達成 か プレミアムで全種解放され選べる / actual: iOS は CatBreedAccess.isLocked(isPremium, referralUnlocked) でロック判定し、ロック猫タップで paywall を出す(UserCatPickerView.swift:258-261)。Android の CatBreedPicker は全11種を無条件 clickable で onSelect(breed) 即適用=ロック概念なし。紹介⭐10解放もプレミアム制限も両方バイパス

- 根拠: `iOS gate present: app/GOExercise/GOExercise/Models/CatBreedAccess.swift:8-11 (isLocked = !isPremium && !referralUnlocked && breed != current); app/GOExercise/GOExercise/Views/UserCatPickerView.swift:258-261 (locked computed, locked tap -> showPaywall=true) and :163-169 (commitSelectedCat reverts locked selection), :21-26 (referralUnlocked scoped to account). Android gate ABSENT: app-android/app/sr`


**⭐10到達の猫種解放お祝いポップ (dead-control)** (?)

- 実害: intent: 累計紹介10人で猫種解放され、達成時に1度だけ祝祭が出る / actual: iOS は pendingBreedUnlock を refresh で deterministic 判定し、HomeView.swift:264-267 でポップ表示・consumeBreedUnlock で永続フラグ。Android には pendingBreedUnlock・ReferralReward.isBreedUnlocked・お祝いポップが一切存在しない=押す対象すら無い

- 根拠: `iOS intent: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/ReferralStore.swift:24,101-102,108-111,186-190 ; /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/HomeView.swift:264-267 ; /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Models/ReferralStarsDispla`


**parity: ⭐10→猫種解放(報酬の核)** (?)

- 実害: iOS は ReferralReward.isBreedUnlocked / isBreedUnlocked(forAccount:) / pendingBreedUnlock / consumeBreedUnlock を実装し、猫ピッカーのロック解除と達成ポップに配線。Android は ReferralStore に breed unlock 系が皆無で、ピッカーにもロックが無い。紹介の主要報酬の片方(星バッジ加算は表示あり、猫解放は欠落)が Android で機能しない

- 根拠: `iOS 実装あり: app/GOExercise/GOExercise/Models/ReferralStarsDisplay.swift:22-27 (ReferralReward.breedUnlockThreshold=10 / isBreedUnlocked); app/GOExercise/GOExercise/Services/ReferralStore.swift:24,101,108-111,186-190 (pendingBreedUnlock / isBreedUnlocked(forAccount:) / consumeBreedUnlock); app/GOExercise/GOExercise/Models/CatBreedAccess.swift:8-11 (referralUnlocked ゲート); app/GOExercise/GOExercise/Vie`


**parity: submitInviteCode の操作順序 (friendship vs referral)** (?)

- 実害: iOS は friendship upsert を先・referral insert を後にし、insert 失敗の再試行でも friendship が冪等再作成され最悪『友達だが報酬なし』に収束(明示コメントあり)。Android は referral insert を先・friendship upsert を後で逆順。referral insert 成功直後に friendship upsert が一過性失敗すると、再試行が duplicate-referee guard で弾かれ『報酬はあるが友達でない』状態が残り得る

- 根拠: `iOS (safe order, with intent comment): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/SupabaseFriendsService.swift:648-673 — guard at 659-661 (duplicate-referee), upsertFriendship at 668 BEFORE referral insert at 670-672; rationale comment at 662-667.

Android (unsafe reverse order, no transaction/compensation): /Users/jun/Documents/Business_Pro`


### settings


**Android: 全記録削除後にホーム画面ウィジェットが古い連続日数/今日達成を表示し続ける** (?)

- 実害: 再発バグ型N(全削除後の各ストア即リフレッシュ)。iOS は deleteAllData() 直後に WidgetSnapshotPublisher.publish と CatLiveActivityController.stopAll を呼び、ウィジェット/ロック画面を即更新。Android の StreakWidget は render 時に Room/DataStore を直読みするが、updateAll は MainActivity.onCreate でしか呼ばれない。設定の deleteAllRecords(SettingsViewModel.kt:116-127)も DataManagementRepository.deleteAllRecords(DataManagementRepository.kt:85-93)も StreakWidget().updateAll(context) を呼ばないため、削除後アプリを再起動するまでウィジェットが削除前の連続日数・今日達成を表示し続ける。Codex/3LLM 監査で iOS 側を是正した既知のバグ型が Android に未移植。

- 根拠: `iOS(即リフレッシュあり): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/SettingsView.swift:520-537(特に 530 WidgetSnapshotPublisher.publish / 531 CatLiveActivityController.shared.stopAll / 527-529 コメントで目的明記)。
Android 削除フロー(updateAll 呼ばず): app-android/app/src/main/java/com/goexercise/app/presentation/settings/SettingsScreen.kt:96-98(onDeleteAll); .../presentat`


**Android: 設定が情報・サポート/記録と共有/自動休養説明を欠き、規約・プライバシー・サブスク管理への導線が設定に無い** (?)

- 実害: iOS 設定は下層ページに『情報・サポート』(プライバシーポリシー/利用規約/サポート/サブスクリプション管理/フィードバック・不具合報告)、『記録と共有』(体調・周期トグル/自動休養2日の説明/友達への共有範囲)、『データ&プライバシー』を備える。Android 設定はテーマ/猫/称号/通知/データ/プライバシーのみで、規約・プライバシーポリシー・サブスク管理・フィードバック導線、体調周期トグル、自動休養ルール説明が設定に存在しない。プライバシーポリシー/利用規約への導線欠落は Play 審査・法的要件上の実害となり得る。

- 根拠: `iOS(存在): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/SettingsView.swift:548-563(フィードバック・不具合報告), :567-575(サブスクリプション管理), :576-585(プライバシーポリシー/利用規約/サポート), :357(体調・周期トグル), :363-377(自動休養2日ルール説明)。
Android(設定の全セクション、欠落): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/setting`


**Apple/Google サインイン(バックアップの鍵)— 設定内 (mismatch)** (?)

- 実害: intent: 未連携=設定でサインインボタン/連携済=状態表示。認証UIは設定に集約 / actual: iOS: 未連携で AccountBackupSignIn() を設定内インライン表示、連携済で linkedStatusText を表示(SettingsView.swift:55-68)。Android: 設定にサインインボタンが一切無く『友達タブの「Apple/Googleでバックアップ」も設定してください』と誘導(SettingsScreen.kt:277-281)

- 根拠: `iOS(intentどおり・設定内サインイン): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/SettingsView.swift:55-68(未連携 AccountBackupSignIn() / 連携済 linkedStatusText)。サインイン部品実体: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/AccountBackupSignIn.swift:32-45(AppleIDButton/GoogleSignInButton)・65-90(signInWithApple/Google)`


**parity: 認証/バックアップUIの設定集約(友達タブから撤去)** (?)

- 実害: 設計意図『認証/バックアップUIは設定に集約・友達タブから撤去』。iOS は実装済(設定に AccountBackupSignIn、FriendsView.swift:264-266 で『友達タブからは撤去』)。Android は逆: 設定にサインインボタンが無く、Apple/Google バックアップ・復元・切替・削除UIが依然 FriendsScreen に存在(BackupCard/RestoreSection)。設定からは『友達タブで設定して』と誘導

- 根拠: `iOS 集約済み: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/SettingsView.swift:55-68 (AccountBackupSignIn at :65, header :70); 撤去コメント+実装: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendsView.swift:264-266; backupCard/restoreSection/showBackupCard は定義のみで body から未参照 (FriendsView.swift:282, :583, :5`


**parity: 連携済み状態表示(プロバイダ名)** (?)

- 実害: iOS は設定で『Apple/Google アカウントでバックアップ中』を表示(SettingsView.swift:12-18,56-59)。Android 設定には連携済み状態の表示が無い(myFriendCode!=null で文言が変わるのみで、Apple/Google 連携済みかは出さない)

- 根拠: `iOS 連携済み表示: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/SettingsView.swift:12-18 (linkedStatusText: providerName→Apple/Google 出し分け), :55-68 (isAccountLinkingEnabled && isBackedUp で checkmark.seal.fill バッジ + linkedStatusText 表示)。
Android 欠落: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexerc`


**parity: 全削除後のウィジェット/Live Activity 即リフレッシュ** (?)

- 実害: iOS は削除後にウィジェットスナップショット publish と Live Activity 停止を実行。Android は Glance widget の updateAll を呼ばず、ホーム画面ウィジェットが古い連続日数/今日達成を表示し続ける(MainActivity.onCreate でしか updateAll しない)

- 根拠: `SettingsView.swift:530-531; SettingsViewModel.kt:116-127; DataManagementRepository.kt:85-97; MainActivity.kt:66-70; StreakWidget.kt:54-72`


**parity: 設定の情報構成(下層ページへの逃がし)** (?)

- 実害: iOS は単一画面に4セクション+下層NavigationLink(カスタマイズ/記録と共有/通知/データ&プライバシー/情報サポート)。Android は全項目フラットに1スクロール(テーマ/猫/称号/通知/データ/プライバシー)。情報・サポート(規約/プライバシー/サブスク管理/フィードバック)、記録と共有(体調周期トグル/共有範囲)、自動休養の説明が Android 設定に欠落

- 根拠: `iOS: app/GOExercise/GOExercise/Views/SettingsView.swift:27-206 (フラットでなく List+5 NavigationLink), :357 (cycle toggle), :364-376 (自動休養説明), :380-396 (共有範囲, friendsEnabled gate), :549-562 (feedback/bug), :567-575 (サブスク管理), :576-590 (terms/privacy/support). Android: app-android/app/src/main/java/com/goexercise/app/presentation/settings/SettingsScreen.kt:172-232 (Column+verticalScroll フラット, 下層ページ無し). 欠落の`


### share


**Android が旧『期間見出し』(1週間つづいた!等)を残置し、称号バッジ中心へのリデザイン意図に反する** (?)

- 実害: redesign では期間表現を廃し称号バッジを主役にしたが、Android は (a) カード rank0 時フォールバックに level.headline、(b) StreakShareScreen がカード上部に level.headline(『1週間つづいた!』等)を常時タイトル表示。これは『1年達成固定廃止』と同系の不正確な期間表現で、7〜13日を一律『1週間』と出す等 iOS が意図的に消した文言が画面に再出現している。

- 根拠: `Android 実害(画面タイトル): app-android/app/src/main/java/com/goexercise/app/presentation/share/StreakShareScreen.kt:81-87 (Text(level.headline...) を常時表示)。到達経路: app-android/app/src/main/java/com/goexercise/app/navigation/AppNavHost.kt:102。
Android レンダラ rank0 フォールバック(軽微な文言差): app-android/app/src/main/java/com/goexercise/app/share/StreakShareImageRenderer.kt:63-67。rank0 閾値: app-android/app/src/main/java/com`


**Android 称号バッジが SFシンボルでなく絵文字🐾を直書き(『絵文字廃止』方針違反)** (?)

- 実害: redesign 方針『絵文字(🎉✨🔥)廃止→SFシンボル/紙吹雪』に対し、Android の drawRankBadge は称号ラベルを `"🐾 $title"` と絵文字付きで描画。iOS は Image(systemName: pawprint.fill) のベクターアイコン。プラットフォーム/端末フォント差で🐾の見た目が割れ、ブランド方針とも不一致。

- 根拠: `Android(問題箇所): app-android/app/src/main/java/com/goexercise/app/share/StreakShareImageRenderer.kt:189 `val label = "🐾 $title"`(描画は :209 `canvas.drawText(label, ...)`、メソッド :187-211)。
内部矛盾の証拠(同ファイル): :69 `// 🔥 行は廃止(iOS 同様、絵文字装飾をやめる)。`、:82 `// ✨ 絵文字きらめきは廃止(…安っぽい絵文字をやめる)。`。
iOS(正しい実装/パリティ基準): app/GOExercise/GOExercise/Views/StreakShareSheet.swift:187 `RankBadge(rank: rank, ...)`、同ファイル :162 `🔥/✨ の絵文字装飾`


**Android: 背景グラデ選択 (dead-control)** (?)

- 実害: intent: 5プリセットから背景を選び、カード種別ごとに記憶したい(iOS パリティ) / actual: ピッカー UI も永続化も実装されていない。背景は level.gradientColors 固定でユーザーは変更できない

- 根拠: `iOS 機能存在(intent の根拠):
- /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/ShareCardGradient.swift:6-49 (5プリセット enum), :53-85 (ShareGradientPicker UI)
- StreakShareSheet.swift:13 (@AppStorage "shareCard.gradient.streak"), :75 (picker 配置), :96 (onChange→再レンダ), :128 (gradient.colors 反映)
- WeeklyHighlightShareSheet.swift:17 (.weekly キー), :79
- MonthlyRevi`


**Android: 写真に保存 (dead-control)** (?)

- 実害: intent: カードを端末ギャラリーに保存したい(iOS パリティ) / actual: 保存ボタンが存在しない。共有 chooser 経由のみ

- 根拠: `iOS 保存機能 (実在・機能している):
- /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/StreakShareSheet.swift:61-72 — 「写真に保存」専用 Button (ShareLink とは別)
- StreakShareSheet.swift:139-157 — saveToPhotos(_:) → ImageSaver().save
- /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/ImageSaver.swift:17 — UIImageWriteToSaved`


**parity: 背景グラデ5種ピッカー+カード種別ごと永続化** (?)

- 実害: iOS は ShareGradientPicker(5プリセット)を持ち @AppStorage で記憶。Android は完全欠落、level.gradientColors 固定。spec『背景グラデ5種選択(カード種別ごとに記憶)』をAndroidが満たさない

- 根拠: `iOS実装あり: app/GOExercise/GOExercise/Views/ShareCardGradient.swift:6 (5プリセットenum), :53 (ShareGradientPicker); StreakShareSheet.swift:13,75; WeeklyHighlightShareSheet.swift:17,79; MonthlyReviewSheet.swift:36,86; LifetimeStatsShareSheet.swift:14,76 (各@AppStorageカード種別ごと永続化+picker)。Android欠落: ShareCardGradient/ShareGradientPicker grep=0 hits; share/にStreakShareImageRenderer.ktのみ; StreakShareImageRendere`


**parity: 見出し=称号バッジ(期間表現の廃止)** (?)

- 実害: iOS カードは rank>0 で RankBadge を表示、period 文言(『1週間つづいた!』等)を廃止。Android はカード上に level.headline(『1週間つづいた!』)を rank0 時のフォールバックに使い、さらに StreakShareScreen が level.headline を画面タイトルとして常時表示。spec『1年達成固定廃止』『連続日数を共有文から削除』の意図(期間/固定文言の排除)と乖離

- 根拠: `真の欠陥(画面タイトルの期間文言恒常露出): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/share/StreakShareScreen.kt:60(level=StreakLevel.of(streak)) および :81-87(Text(level.headline) を rank ゲート無しで常時描画)。

iOS 側に同等の画面タイトルが存在しない証拠: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/StreakShareShee`


**parity: 称号バッジのアイコン(SFシンボル vs 絵文字)** (?)

- 実害: redesign 方針は『絵文字廃止→SFシンボル』。iOS RankBadge は Image(systemName: pawprint.fill)。Android drawRankBadge は文字列 "🐾 $title" と絵文字を直書きしており方針違反

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/Components/RankBadge.swift:32 (Image(systemName: rank.iconSymbol)); /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Models/CatRank.swift:66 (var iconSymbol: String { "pawprint.fill" }). Android: /Users/jun/Documents/Business_Project_Management/serial_trai`


**parity: 写真保存ボタン** (?)

- 実害: iOS は『写真に保存』ボタンあり。Android は無し(共有のみ)

- 根拠: `iOS 写真保存ボタン: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/StreakShareSheet.swift:61-71 (Button「写真に保存」), :139-157 (saveToPhotos→ImageSaver().save でカメラロール保存)。iOS 共有: 同 :40-54 (ShareLink「SNSで共有」)。
Android 共有のみ: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/share/StreakS`


### widgets


**Android ウィジェットの翌朝固着が時間ベース更新のみで弱い(日付境界トリガ無し)** (?)

- 実害: iOS は翌日0:00 の timeline entry と projected(to:) で日付が変わった瞬間に『達成済み』を解き記録誘導を再表示する確定的保証を持つ。Android は provideGlance の都度再計算に依存するが、トリガは updatePeriodMillis=30分 と onStop の updateAll のみで、夜間アプリ未起動だと日付跨ぎ後も最大30分前日の『達成』が残る。設計意図『翌朝まで達成済み固着しない』の Android 担保が iOS より緩い。

- 根拠: `Android weak side: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/res/xml/streak_widget_info.xml:7 (updatePeriodMillis=1800000); /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/MainActivity.kt:66-70 (onStop updateAll, only on app-leave); /Users/jun/Documents/Business_Project_Management/seri`


**Android widget tap (全体) (dead-control)** (?)

- 実害: intent: タップしたらアプリ(ホーム)が開く（iOSパリティ） / actual: StreakWidget に actionStartActivity / clickable / onClick が一切無い。タップしてもランチャ既定挙動以外の明示的なホーム遷移配線が無く、iOS の goexercise://home 相当が欠落

- 根拠: `Android(欠落): app-android/app/src/main/java/com/goexercise/app/widget/StreakWidget.kt:84-92(Column にクリック修飾子なし)、84-105(WidgetBody 全体に actionStartActivity/clickable/onClick なし)。grep actionStartActivity/actionRunCallback/clickable/onClick → widget ディレクトリでヒット0。iOS(パリティ基準): app/GOExercise/GOExerciseWidget/GOExerciseWidget.swift:34 `.widgetURL(URL(string: "goexercise://home"))`; ハンドラ app/GOExercise/GOExe`


**parity: ウィジェットのタップ遷移** (?)

- 実害: iOS は widgetURL=goexercise://home で明示的にホームを開く。Android はクリックアクション未配線で deep-link 遷移が無い

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExerciseWidget/GOExerciseWidget.swift:34 (.widgetURL goexercise://home); /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/App/GOExerciseApp.swift:138 (.onOpenURL handler). Android (欠落): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/`


**parity: 翌朝の達成済み固着対策(日付投影)** (?)

- 実害: iOS はタイムラインに翌日0:00 entry + projected(to:) で日付跨ぎを未記録に投影。Android Glance は provideGlance 実行時に LocalDateTime.now() で都度再計算だが、再計算トリガは updatePeriodMillis=30分 と onStop の updateAll のみ。アプリ未起動の夜間は最大30分の遅延で日付跨ぎ後も前日の『達成』が残り得る(明示的な日付境界トリガが無い=iOSの保証より弱い)

- 根拠: `iOS(強い保証): app/GOExercise/GOExerciseWidget/WidgetProvider.swift:18-22 (entryDates を projected で写像, policy .atEnd) ; app/GOExercise/GOExercise/Services/WidgetTimelineDates.swift:10 (startOfTomorrow=翌0:00 entry),:15 ; app/GOExercise/GOExercise/Models/WidgetSnapshot.swift:19-44 (別日entryで todayAchieved=false / isRestDay=false に投影).
Android(弱い): app-android/app/src/main/java/com/goexercise/app/widget/S`


**parity: 達成と休養の文言分離** (?)

- 実害: iOS は todayAchieved(達成済み)と isRestDay(回復日)を別ラベルで出し分け。Android は countsAsAchieved に休養を含めるため休養日も『達成』表記になり文言が不正確

- 根拠: `iOS 正しい出し分け:
- /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/WidgetSnapshotPublisher.swift:38-39 — `todayAchieved: todayStatus == .todayAchieved || todayStatus == .achieved, isRestDay: todayStatus == .rest`(休養を別フラグ化、todayAchieved から rest/rescued を除外)
- /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExerciseWid`


**parity: ウィジェットのサイズ/週間進捗・残り時間表示** (?)

- 実害: iOS small/medium は週間達成リング・残り時間・記録誘導チップ・週次カウントを表示。Android は連続日数+猫+達成可否のみで週間進捗/残り時間/誘導チップが無い(small 相当のみ、medium 相当なし)

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExerciseWidget/GOExerciseWidget.swift:38 (両ファミリ宣言); SmallWidgetView.swift:54-78 (週間リング/週次カウント), :51 (残り時間), :29 (CTAチップ); MediumWidgetView.swift:16-25 (週次カウント), :69 (残り時間), :40 (CTAチップ); WidgetSnapshot.swift:8-12,52-53 (weeklyAchieved/weeklyTotal/nightDeadlineHoursLeft フィールド存在). Android: /Users/jun/Documents/Bus`


### 体重トラッキング


**Android は3日より前の体重を記録できない(任意過去日入力の欠落)** (?)

- 実害: iOS は『その他』で DatePicker により ...Date() の任意過去日を入力可。Android は今日/昨日/一昨日の3固定チップのみで、過去測定値の遡及入力・データ補完ができない。体重トラッキングの基本ユースケースを一部欠く。

- 根拠: `Android制約: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/weight/WeightScreen.kt:215 (`daysAgo` 0/1/2), :216 (labels「今日/昨日/一昨日」), :220-231 (3チップのみ), :241 (`LocalDate.now().minusDays(daysAgo.toLong())`)。weight配下に DatePicker 0件 (grep)。/Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/ma`


**Android に入力値の範囲バリデーションが無い(誤入力が保存される)** (?)

- 実害: iOS は体重 0<w<500、身長 50–250cm を範囲チェックして弾く。Android は weight.toDoubleOrNull()/NumberDialog の toDoubleOrNull のみで上下限が無く、身長5cm・体重0.1kg 等が保存され BMI/forecast が破綻し得る。

- 根拠: `iOS (バリデーション有り): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/WeightView.swift:176-177 (身長 50-250), :184 (目標 0<w<500), :811-813 (体重 0<w<500)。

Android (バリデーション無し): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/weight/WeightScreen.kt:233 (filter digits/dot のみ), :241 (`


**推移グラフのデータ点タップ/ドラッグ選択 (chart tap selection) (dead-control)** (?)

- 実害: intent: グラフ上の点をタップ/なぞると、その日の日付と体重(kg)がピル/吹き出しで表示され、再タップで解除できる(SPEC『グラフはタップ選択』) / actual: iOS=WeightView.swift:562-587 で .onTapGesture(最寄り点へ選択/再タップ解除)+DragGesture(なぞり選択)を実装、選択点は symbolSize 130 に拡大しannotationで値表示、RuleMark併記。Android=WeightScreen.kt:278-326 WeightChart は素の Canvas で drawPath/drawCircle のみ。pointerInput/detectTapGestures/選択 state が一切無い(grep 0 件)。

- 根拠: `iOS 実装あり: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/WeightView.swift:567-585 (onTapGesture+DragGesture 選択/再タップ解除), :521 (symbolSize 130/40), :528-529 (annotation 値ピル), :541-545 (RuleMark), :15/:607 (chartSelectedDate state)。
Android 未実装: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexerci`


**日付セグメント (今日/昨日/その他 or 一昨日) (mismatch)** (?)

- 実害: intent: 記録日を素早く選べる。任意の過去日も選べる / actual: iOS=今日/昨日/『その他』→DatePicker(...Date() で任意過去日)(WeightView.swift:723-748)。Android=今日/昨日/『一昨日』の3固定チップのみ、**任意過去日を選ぶ DatePicker が無い**(WeightScreen.kt:215-231)。3日以上前の体重を記録できない。

- 根拠: `iOS 任意過去日DatePicker: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/WeightView.swift:735-747 (「その他」チップ→ DatePicker(... in: ...Date()) 744行、下限なし)。
Android 3固定チップのみ: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/weight/WeightScreen.kt:215 (var daysAgo 0/1/2), :216 (label`


**parity: グラフのデータ点タップ選択** (?)

- 実害: iOS は点タップ/ドラッグで選択し日付・体重を表示(SPEC『グラフはタップ選択』の中核)。Android Canvas は描画のみで選択操作が完全に欠落。Android ユーザーは特定日の値をグラフから読めない。

- 根拠: `iOS 選択実装: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/WeightView.swift:516-587 (chartOverlay の onTapGesture 567-577 / DragGesture 578-585 / 選択時 symbolSize 拡大 521 / 値の annotation 528-539 / RuleMark 541-545)。chartDate 変換ヘルパー 599-604。
Android Canvas 描画のみ・選択欠落: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main`


**parity: 任意過去日の体重入力** (?)

- 実害: iOS は『その他』で DatePicker により任意の過去日を入力可。Android は今日/昨日/一昨日の3日固定で、3日より前の記録(インポート漏れ補完・過去測定値の遡及入力)ができない。

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/WeightView.swift:735-747 (line 744 DatePicker with `in: ...Date()`, no lower bound). Android: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/weight/WeightScreen.kt:215 (`var daysAgo by remember { mutableStateOf(0) } //`


**parity: 入力値の範囲バリデーション** (?)

- 実害: iOS は体重 0<w<500、身長 50–250cm をバリデート。Android は toDoubleOrNull のみで上下限チェック無し。誤入力(例:身長 5cm、体重 0.1kg)が保存され BMI 等が破綻し得る。

- 根拠: `iOS: app/GOExercise/GOExercise/Views/WeightView.swift:177 (身長 50–250), :184 (目標体重 0<w<500), :813 (記録体重 0<w<500)。Android(検証欠落): app-android/app/src/main/java/com/goexercise/app/presentation/weight/WeightScreen.kt:241,243 (体重 toDoubleOrNull のみ), :440 (身長/目標 toDoubleOrNull のみ); WeightViewModel.kt:104-112,115-116 (素通し); data/settings/HealthRepository.kt:59-65 (DataStore 書込のみ、範囲チェック無し); data/WeightRepo`


**parity: ペイウォールの自動再表示抑制(cooldown)と無料注記** (?)

- 実害: iOS は X 閉じ後6hの cooldown で自動 sheet 再提示を制御し『ホーム記録は無料』を明記。Android は自動 paywall 提示も cooldown も無く(押下式のみ)、無料注記文も欠落。nag 制御の概念差。

- 根拠: `iOS auto-present + cooldown: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/WeightTabRootView.swift:11-14 (paywallCooldownKey, 6h cooldownSeconds), :37-49 (sheet onDismiss が cooldown 書込), :52-66 (updateGate が cooldown 外で showPaywall=true 自動提示, isInCooldown 判定). iOS 無料注記: 同 :87-91 「ホーム画面の『記録する』からの体重入力は引き続き無料でご利用いただけます」. Android 欠落: /Users/jun/Docume`


**parity: 記録2件未満時のグラフ案内** (?)

- 実害: iOS は2件未満で『N以内に2件以上の記録があるとグラフが表示されます』を表示。Android は dailyChart.size>=2 のときだけ ChartSection を出し、それ未満では区画ごと無言で消える(空状態の説明なし)。

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/WeightView.swift:466-472 (visible.count < 2 で案内文カードを表示)。Android: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/weight/WeightScreen.kt:110-112 (if (state.dailyChart.size >= 2) { ChartSection(...) } に else 無し)。ChartSect`


**parity: 周期オーバーレイの可視化制御** (?)

- 実害: iOS は周期トラッキング opt-in 設定(cycleSettings.isEnabled)とデータ有無で自動表示、画面内に ON/OFF トグル無し。Android は per-screen のタップトグル(showCycle 既定 true)。制御モデルが異なる。

- 根拠: `iOS opt-in 設定(画面内トグル無し): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/WeightView.swift:615-620 (cyclePhaseSpans が cycleSettings.isEnabled + データ有無のみでゲート); WeightView.swift:20 (private let cycleSettings = CycleTrackingSettings()); WeightView.swift:642-643 (凡例 toggle は説明展開のみ、可視性ではない)。グローバル設定の正体: /Users/jun/Documents/Business_Project_Management/seria`


### 分析opt-out


**iOS: analytics opt-out のgate/teardownに回帰テストが無い** (?)

- 実害: iOS側はAnalytics.isEnabledのtrack gateとsetEnabled(false)のNoop差し替えがプライバシーの要だが、GOExerciseTestsにAnalytics系の単体テストが存在しない(NotificationSettingsViewModelTests等にも無し)。Androidは同等挙動をAnalyticsEventTestで固定しているのと非対称。将来のリファクタでgateが外れても検知できない。

- 根拠: `iOS gate実装(テスト無し): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/Analytics.swift:84-87 (track gate), :93-100 (setEnabled teardown→NoopAnalytics), :79-82 (isEnabled 既定true+UserDefaults永続)。
iOSテスト不在の証拠: GOExerciseTests/*.swift 全48ファイルに対し `Analytics\.|Analytics(` / `TelemetryDeck|NoopAnalytics|AnalyticsService|AnalyticsEvent|configureIfPossible` の`


**設定「利用状況の分析を共有」トグル → OFF (Android) (mismatch)** (?)

- 実害: intent: OFFにしたらその場で送信停止。SDKもteardownされ残留送信ゼロ(iOSパリティ) / actual: Analytics.consentGranted=falseにしfacade.trackをgateするのみ。一度TelemetryDeck.start()済みならSDK実体(TelemetryDeckAnalytics + 起動済みTelemetryDeck)は生きたまま=teardownしない。iOS Analytics.swift:90-91が明示的に問題視した旧実装そのもの

- 根拠: `Android(問題箇所):
- /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/settings/SettingsViewModel.kt:90-95 (setAnalyticsEnabled は consentGranted 更新のみ、Noop 戻し/teardown 無し)
- /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/analytics/Analytics.kt:97-100 (track の c`


**parity: opt-out時のSDK teardown(セッション中の残留送信停止)** (?)

- 実害: iOSはsetEnabled(false)でservice=NoopAnalytics()にしSDK実体を捨てる(Analytics.swift:90-91のコメントで旧track-gate方式が厳格レビュアに残留問題視され得ると明記し是正済)。AndroidはconsentGrantedフラグのtrack-gateのみで、起動済みTelemetryDeckを止めない=iOSが意図的に直した挙動に未追従。TelemetryDeck Kotlin SDKはstart時にセッション/ライフサイクルsignalを自動送出しうるため、facade gateだけでは完全停止を保証しない

- 根拠: `Android facade-only gate: app-android/app/src/main/java/com/goexercise/app/presentation/settings/SettingsViewModel.kt:90-94; app-android/app/src/main/java/com/goexercise/app/analytics/Analytics.kt:94-100,107-115. SDK start gating (漏れ窓の限定): app-android/app/src/main/java/com/goexercise/app/GOExerciseApp.kt:35-45. SDK 自動 session/lifecycle providers と stop() の存在(実AAR解凍検証): ~/.gradle/caches/modules-2/f`


### 連続日数エンジン


**Android 復活判定で過去の rescued 日が anchor として認識されない** (?)

- 実害: StreakFreezeWindow.Decision.evaluate の anchor 判定が Achieved/TodayAchieved のみで、iOS が含める .rescued を欠落。途切れの直前が(過去のフリーズで救済された)rescued 日だった場合、anchor を見つけられず revivable=false になり復活ポップが出ない。rescuedDates 漏れの再発バグ型(4)に該当。連続フリーズ運用ユーザーで顕在化

- 根拠: `Android missing rescued anchor: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/domain/StreakFreezeWindow.kt:54 (when only matches Achieved, TodayAchieved) with Rescued falling through to else at :70-73. iOS includes rescued: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/StreakFr`


**Android applyRevive が適用時に missed 日を now から再計算し、日跨ぎで誤適用しうる** (?)

- 実害: iOS は refresh 時点の絶対日付 reviveMissedDates をキャプチャして applyRevive/breakKey に使う(監査 F2 対策)。Android applyRevive は today=LocalDate.now(clock) を取り直し missedDatesForOffsets(missedOffsets, today) で再変換するため、ポップ表示中に日付が変わると本来と違う日へフリーズを消費し、breakKey もずれて handled 抑止が効かなくなる。チケットの誤消費(課金資産)に直結

- 根拠: `Android (drift): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/home/HomeViewModel.kt:216-233 (reviveState combine captures today_A, stores missedOffsets), :259-261 (applyRevive re-reads today_B and re-derives missedDates), :267 (useTicket on shifted date), :270 (markHandled on shifted breakKey); same pattern :279-281 `


**復活ポップの『フリーズを使う』ボタン (StreakRevivePopup onUseFreeze) (mismatch)** (?)

- 実害: intent: 途切れた連続を、提示された missed 日にフリーズを当てて確実に復活させたい / actual: iOS は refresh 時点で確定した絶対日付 reviveMissedDates を applyRevive で使用(F2対策)。Android は applyRevive 内で today=LocalDate.now(clock) から missedOffsets を再変換するため、ポップ表示中に日付が変わると別の日へフリーズを当てる/復活キーがずれる

- 根拠: `iOS absolute-date capture + F2 guard: app/GOExercise/GOExercise/ViewModels/HomeViewModel.swift:157 (reviveMissedDates = missed.map{startOfDay}), :226-235 (applyRevive uses stored reviveMissedDates with F2 comment), :241-243 (reviveBreakKey from stored absolute dates). Android offset re-resolution against fresh now(): app-android/app/src/main/java/com/goexercise/app/presentation/home/HomeViewModel.`


**復活ポップそのものの出現条件 (自動休養が連続の頭との間に挟まるケース) (dead-control)** (?)

- 実害: intent: 途切れの手前に連続があれば(間に休養日があっても)復活ポップが出てほしい / actual: iOS は records-entry evaluate を hardCap=lookback+7 で動的延長し休養を読み飛ばして anchor を探す。Android は固定窓 1..(lookback+1) のため、missed と anchor の間に自動休養(週最大2日)が挟まると anchor が窓外へ押し出され foundPrior=false → 復活可能なのにポップが出ない

- 根拠: `iOS 動的scan: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/StreakFreezeWindow.swift:76 (hardCap = lookback + 7), :77 (for offset in 1...hardCap), :87-88 (.rest → continue で延長), :60-63 (P1 修正意図コメント)。
Android 固定窓: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/domain/StreakFreezeWi`


**復帰日の歓迎カード (comebackWelcomeCard / isComebackToday) (dead-control)** (?)

- 実害: intent: 前日にミスした翌日にアプリを開いたら、低圧な『おかえり』カードで再開を促してほしい / actual: iOS は yesterdayStatus==.missed かつ未達成かつ生涯達成3日以上で comebackWelcomeCard を表示。Android には isComebackToday 相当の状態も歓迎カードも存在しない(完全未実装)

- 根拠: `iOS state: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/ViewModels/HomeViewModel.swift:140-142 (isComebackToday = yesterdayStatus(...)==.missed && !todayStatus.countsAsAchieved && lifetimeStats.achievedDays>=3). iOS render: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/HomeView.swift:78 (comebackWelcom`


**parity: 復活ウィンドウの anchor 探索(records-entry evaluate)** (?)

- 実害: iOS は休養日を読み飛ばす動的延長(hardCap=lookback+7)で anchor を確実に拾う。Android は固定窓 1..(lookback+1) のまま。これは iOS が監査P1で修正した『休養が anchor を窓外へ押し出すと復活ポップ未発火』のリグレッションそのもの。Android に未移植

- 根拠: `主所見(固定窓の未移植): Android /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/domain/StreakFreezeWindow.kt:109 `(1..(lookback + 1)).map { offset -> ... }` vs iOS /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/StreakFreezeWindow.swift:77-95(hardCap=lookback+7 の動的延長、line 76 `let hardCap = l`


**parity: Decision.evaluate の anchor 判定に .rescued を含むか** (?)

- 実害: iOS は Decision で .achieved/.todayAchieved/.rescued を anchor として扱う(過去のフリーズ救済日も連続の頭)。Android Decision は Achieved/TodayAchieved のみで Rescued を欠落。途切れ手前が rescued 日のとき anchor を見つけられず復活ポップが出ない

- 根拠: `iOS anchor includes rescued: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/StreakFreezeWindow.swift:30 (`case .achieved, .todayAchieved, .rescued:`). Android anchor omits Rescued: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/domain/StreakFreezeWindow.kt:54 (`DailyStatus.Achiev`


**parity: streakState の longest 計算に .rescued を含むか** (?)

- 実害: iOS streakState は .achieved/.todayAchieved/.rescued で running を加算。Android streakState は line69 で Achieved/TodayAchieved のみ、Rescued が else→running=0 に落ち longest が救済日で途切れる。現状 longestStreak は Android UI に未表示のため実害は潜在的だが、ロジックは乖離

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/StreakCalculator.swift:91 (case .achieved, .todayAchieved, .rescued: → running+1, longest更新) と対比される currentStreak:32 も .rescued 含む。
Android(欠落): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/domain/StreakCalculator.kt:69 (Achie`


**parity: applyRevive の missed 日確定タイミング** (?)

- 実害: iOS は refresh 時点の絶対日付をキャプチャして適用(F2)。Android は適用時に now から再計算。日跨ぎで誤適用しうる

- 根拠: `iOS(正・F2修正済): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/ViewModels/HomeViewModel.swift:37-39（reviveMissedDates を絶対日付で保持）, :157（missed.map startOfDay で保存）, :226-235（applyRevive が保存済み絶対日付 reviveMissedDates を消費、:227-228 で F2 警告）。
Android(欠落): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/a`


**parity: 復帰日歓迎カード(comeback)** (?)

- 実害: iOS のみ実装。Android に状態/UI とも無し

- 根拠: `iOS state: app/GOExercise/GOExercise/ViewModels/HomeViewModel.swift:34 (var isComebackToday), :140-142 (判定ロジック), :172-186 (yesterdayStatus). iOS UI: app/GOExercise/GOExercise/Views/HomeView.swift:452-477 (comebackWelcomeCard 「おかえり」), :431-438 (復帰日CTA「ただいま記録」), :78 (本体レイアウトへの実描画). Android 欠如: app-android/app/src/main/java/com/goexercise/app/presentation/home/HomeUiState.kt:18-33 (isComebackToday 相当`


---
## ⚪ LOW (21件)


### achievements


**Android: 背景進化(MilestoneBackdrop)の最上位アニメ・rank11 ゴッドレイが未実装** (?)

- 実害: iOS は sparkle を TimelineView でアニメ、rank>=10 で光帯を移動、rank>=11 で godRays を描画して『段が上がるほど豪華』を演出。Android は全要素静的で rank11 の godRays も無い(コメントに『アニメは入れない』)。グロー/スパークル数の数値は一致。影響は streak365+/500+ の高ランクのみで静的フォールバックは存在するため実害は限定的だが、設計の『背景進化が豪華になる』体験差として記録。

- 根拠: `iOS: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/Components/MilestoneBackdrop.swift:64-69 (sparkle TimelineView animate), :73-82 (movingBand animated rank>=10), :84-87 + :161-174 (godRays rank>=11). Android: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/ui/components/MilestoneBa`


**Android: 背景進化スタイル数値のユニットテストが無い** (?)

- 実害: iOS は MilestoneBackdropStyleTests.swift で glowOpacity=richness*0.42・sparkleCount=min(4+rank*2,24)・animated=rank>=10 を検証。Android は同ロジックを MilestoneBackdrop.kt の Composable 内にインライン展開しており、純粋関数として切り出されていないためテストが無い。将来の数値リグレッションを検出できない test gap。

- 根拠: `iOS 純粋型+テスト: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Models/MilestoneBackdropStyle.swift:24-26(glowOpacity=richness*0.42 / sparkleCount=min(4+rank*2,24) / animated=rank>=10); /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExerciseTests/MilestoneBackdropStyleTests.swift:1-38(これら定数の機械検証).
Android インライン(テスト無し): /Use`


### calendar


**Android 履歴一覧(過去記録の展開リスト)が未実装** (?)

- 実害: iOS 履歴タブは月カレンダー下に展開可能な運動履歴一覧(合計N日)を持つ(SPEC『記録一覧』)。Android HistoryScreen はカレンダー+保険チケットボタンのみで履歴リストが無い。

- 根拠: `iOS 一覧実装: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/HistoryView.swift:47-101 (トグル 53-82, 記録行 84-100, HistoryRowView 94), 日詳細シート HistoryView.swift:135-137 + open() 140-152。
SPEC 根拠: /Users/jun/Documents/Business_Project_Management/serial_training/docs/SPEC_iOS.md:52 (「記録一覧」), :79 (「記録一覧(折りたたみ)」)。
Android 欠落: /Users/jun/Documents/Business_Projec`


### cheers


**cheers.kind 列に DB check 制約が無く契約外 kind を弾けない** (?)

- 実害: schema.sql の cheers.kind は `text not null` のみで、契約値(fight/wontlose/protein/catpunch/custom/旧great/clap/fire)に限定する check 制約が無い。両OSのクライアントは正しい rawValue を送るため実害は低いが、サーバ側に契約担保が無く、不正/将来の不整合 kind を受信側 received(fromRaw) のデフォルト『応援/heart』に黙って吸収するため、契約逸脱が検知されない。

- 根拠: `supabase/schema.sql:97 (kind text not null, CHECK 無し); supabase/schema.sql:178-188 (cheers_insert RLS は from_user と友達関係のみ検証、kind 値域チェック無し); supabase/schema.sql:102-103 (message には char_length check 有り=kind に無いことの対照); iOS app/GOExercise/GOExercise/Services/FriendsService.swift:155-159 (enum CheerKind=fight/wontlose/protein/catpunch のみ、custom 無し), :180-187 (received(fromRaw:) default→("応援","heart.fi`


**Android 切替直後に旧uid受信トーストが漏れる潜在リスク** (?)

- 実害: fetchReceivedCheers() は load() の gen一致ブランチ内(:191)から呼ばれるが、内部 viewModelScope.launch は自前で identityGeneration を再確認せず、unseenReceivedCheers の await 中にアカウント切替/サインアウトが割り込むと旧uidの応援トーストが新アカUI上に出る余地。watermark自体は uid別なので誤更新は無いが、口座スコープ(再発バグ型1)の表示リークとして at-risk。

- 根拠: `Android (バグ): app-android/app/src/main/java/com/goexercise/app/presentation/friends/FriendsViewModel.kt:191 (gard 内で fetchReceivedCheers 呼出), :270-278 (新規 viewModelScope.launch で gen 再確認なし・:276 で共有 _uiState へ無条件トースト), :88 (identity 跨ぎ共有 _uiState), :174-176/:188 (load 本体のガード基準). uid スコープの裏取り: app-android/app/src/main/java/com/goexercise/app/data/friends/SupabaseFriendsService.kt:167 (捕捉 uid), :177 `


### cycle


**旧形式→v2 決定的UUID移行に回帰テストが無い** (?)

- 実害: Android の legacy epochDay Set → v2(決定的UUID nameUUIDFromBytes)移行は同期収束の要(再読込・再端末で id 不変が前提)。実装は妥当だが、移行不変性を検証する単体テストが無く、legacyId 文字列やキー名を将来変更すると id が変わり同期が二重化/不整合になる回帰を検知できない。

- 根拠: `app-android/app/src/main/java/com/goexercise/app/data/settings/MenstrualRepository.kt:124-150 (mergedEntries / write / legacyId=UUID.nameUUIDFromBytes("goexercise-menstrual-$epochDay") / legacyCreatedAt); 既存テスト app-android/app/src/test/java/com/goexercise/app/data/backup/RecordSyncCoordinatorTest.kt:363-369 (menstrualLegacyId_isDeterministic は assertEquals(legacyId(day),legacyId(day)) の恒真比較+UUID形式`


### friends


**iOS FriendsView の解除アラート(pendingRemovalFriend)が到達不能な死コード** (?)

- 実害: FriendsView は pendingRemovalFriend 用の解除確認アラートを保持するが、これを true 設定する呼び出し元が存在せず(代入は nil 化のみ)、公園表示一本化後に到達不能。実害は無いが、解除導線がここに在ると誤認させる死コードで、tryPresentPendingAdd のガード条件(pendingRemovalFriend==nil)も無意味化している。

- 根拠: `非nil set 経路なし(網羅 grep): app/GOExercise/GOExercise/Views/FriendsView.swift:29(宣言), 172/180/182/185/1041(読み取り), 183/189/192(= nil のみ)。到達不能アラート定義: FriendsView.swift:179-196。無意味化したガード: FriendsView.swift:1041 `detailFriend == nil, pendingRemovalFriend == nil`。実際の生存する解除導線: app/GOExercise/GOExercise/Views/FriendDetailView.swift:48 `await friendsStore.remove(friend)`。公園一本化の経緯: FriendsView.swift:979-981 コメ`


**招待共有テキストの内容がOS間で不一致(Androidは連続日数を含む)** (?)

- 実害: iOS は招待共有文から連続日数を意図的に外した(ユーザー要望)が、Android の friendShareText は username と『🔥N日連続』を含む。共有文面のブランド一貫性とプライバシー粒度がOS間でずれる。

- 根拠: `iOS no-streak (intentional): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/FriendsView.swift:1129-1132 ("連続日数は載せない(ユーザー要望)"; emits code + AppSharingConfig.shareURL). iOS live call site: FriendsView.swift:821 (ShareLink(item: shareText(for: profile))). Android streak+username: /Users/jun/Documents/Business_Project_Management/serial_training/app-and`


**QRスキャナ anti-spoof と orderedPair 正規化にユニットテストが無い** (?)

- 実害: iOS QRScannerView.friendCode(from:) の goexercise://限定/生6文字切詰め拒否(Codex P1/P2修正)と、両OSの orderedPair UUID正規化(iOS固有承認バグ修正)に直接の回帰テストが無い。いずれも過去に実害が出た箇所で、リファクタ時に静かに退行しうる。

- 根拠: `iOS QRScanner anti-spoof 実装(未テスト): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/QRScannerView.swift:99-112 (スキーム限定 :104-105, 切詰め拒否 :110-111)。テスト全体で QRScannerView 参照 NONE(grep over GOExerciseTests/GOExerciseUITests/app-android test+androidTest)。既存の近接テストは別関数: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise`


### notifications


**Android: 通知タップが deep-link 経路を通らず route=home を運ばない(将来拡張で死にリンク化)** (?)

- 実害: iOS は通知に userInfo["route"]=home を付け DeepLinkRouter で解決。Android ReminderReceiver の contentIntent は data URI も extra も持たず、MainActivity は intent.dataString からしか deep link を消費しないため通知タップ時は dataString=null。現状は NavHost startDestination=home のため結果的にホーム着地となり実害は軽微だが、iOS同様に route 別通知(streak-share / weekly-ranking 等)を将来追加した瞬間 Android だけ無反応になる脆い実装。setData("goexercise://home") 付与で恒久的にパリティ化すべき。

- 根拠: `Android: app-android/app/src/main/java/com/goexercise/app/notification/ReminderReceiver.kt:23-27 (Intent に setData/putExtra 無し) → MainActivity.kt:44,56 (intent.dataString のみ消費), :80-86 (consumeIntentUri は null→null) → navigation/AppNavHost.kt:63-64 (deepLinkUri null で早期 return), :91 (startDestination=AppRoute.Home.path) → navigation/DeepLink.kt:56-61 (resolve は route(uri)==null で null to null), na`


**Android: 通知本文が固定1種でパーソナライズ無し** (?)

- 実害: iOS は NotificationMessageProvider が連続日数/週進捗/性格/日付シードで本文を出し分け、spec 21章の文言バリエーションを実現。Android は『今日の運動、どう？🐱』固定で、毎日同一文のため通知疲れ・spec逸脱。

- 根拠: `Android fixed body: app-android/app/src/main/java/com/goexercise/app/notification/ReminderReceiver.kt:30-31 (setContentTitle "今日の運動、どう？ 🐱" / setContentText "1 分だけでも OK。猫が待ってるよ。"); same receiver fired daily with no message extras: ReminderScheduler.kt:23-31 (setInexactRepeating INTERVAL_DAY) and :50-58 (pendingIntent builds Intent with only ACTION_FIRE, no putExtra). iOS personalized body: app/GOEx`


### onboarding


**Androidオンボーディングに自動テストが皆無(完了永続化・招待・遷移)** (?)

- 実害: iOSは OnboardingBackupUITests / CatBreedAccessTests / AccountLinkingTests / ReferralRewardsTests を保有。Android側はオンボ関連のunit/UIテストが存在せず(AnalyticsEventTestのみ)、完了永続化・猫選択保存・招待コード適用の回帰検知ができない。上記欠落機能を移植する際の安全網も無い。

- 根拠: `app-android/app/src/main/java/com/goexercise/app/presentation/onboarding/OnboardingViewModel.kt:52-59 (complete(): setCatBreed→setOnboardingComplete→track、テスト無し); 同:28-31 (isComplete null=判定中ステート、テスト無し); grep `OnboardingViewModel|SettingsRepository|ReferralStore|setOnboardingComplete|onboardingComplete|setCatBreed` over app-android/app/src/test = 0件; androidTest 全体 = app-android/app/src/androidTes`


### recording


**保存失敗経路のユニットテストが Android に無い** (?)

- 実害: Android は repository.save 例外時に errorMessage を立て saved one-shot を発火しないが、この onFailure 経路と isSaving 二重保存ガードのテストが無い。再発バグ型(3)dismiss/演出再発の根治コードが回帰で保護されていない。iOS も store.lastErrorMessage 経路(保存失敗で nil/onSaved 抑止)のテストが無い

- 根拠: `Android source: app-android/app/src/main/java/com/goexercise/app/presentation/record/RecordViewModel.kt:71 (isSaving guard), :82-84 (onFailure sets errorMessage, does NOT send _saved). Android tests (only files in record/): app-android/app/src/test/java/com/goexercise/app/presentation/record/RecordViewModelAddSetTest.kt:20 (FakeRepo.save no-op, never throws), :26-50 (only addSet tests); RecordUiSt`


### referrals


**Android submitInviteCode の referral/friendship 作成順序が逆で『報酬あり・友達でない』残留の可能性** (?)

- 実害: iOS は friendship upsert を先・referral insert を後にし、insert 失敗の再試行でも friendship が冪等再作成され最悪『友達だが報酬なし』(安全側)に収束させる明示設計。Android は referral insert→friendship upsert の逆順で、referral insert 成功後に friendship upsert が一過性失敗すると、再試行が duplicate-referee guard で弾かれ友達関係が永久に作られない『報酬はあるが友達でない』状態が残り得る

- 根拠: `Android (バグ): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/data/friends/SupabaseFriendsService.kt:235-241 — guard(235-238) → referrals.insert(239) → friendships.upsert(240-241) の逆順、try/catch なし。
iOS (正): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Services/SupabaseFriendsService.swif`


### settings


**Android: アカウント切替後に設定の『紹介した友達』星数が前アカウント値を表示し得る** (?)

- 実害: 再発バグ型(1)口座スコープ漏れの at-risk。設定の myFriendCode/referralSummary は SettingsViewModel.init で一度だけ myProfile()/referralStore.refresh() を呼ぶ(SettingsViewModel.kt:195-200)。Apple/Google でアカウント切替しても設定VMが再生成されない限り星バッジ数・招待コードが旧アカウントのまま残る。iOS も referral 再取得は限定的だが、Android は連携UI自体が別タブにあるため切替→設定戻りで再取得されない経路がより明確。実害は星数の一時的な誤表示で限定的。

- 根拠: `Android (stale): app-android/app/src/main/java/com/goexercise/app/presentation/settings/SettingsViewModel.kt:164-165 (_myFriendCode は per-VM MutableStateFlow)、:195-200 (init で1回のみ取得)、:146 (setBackupEnabled でのみ追加更新)、:180-182 (inviteMessage が当該コードを使用)。VM 常駐: app-android/.../MainActivity.kt:95 (App() 直下 hiltViewModel、アクティビティスコープ)。アカウント切替が SettingsVM に触れない証跡: app-android/.../friends/FriendsViewModel.k`


### share


**Android 共有カードに『写真に保存』導線が無い** (?)

- 実害: iOS は共有とは別に『写真に保存』ボタンで端末ギャラリー保存できるが、Android は ACTION_SEND chooser のみ。ユーザーが SNS を介さず画像だけ保存したい意図を満たせず、機能パリティ未達。

- 根拠: `iOS 写真保存導線あり: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/StreakShareSheet.swift:61-72 (「写真に保存」Button) および :139-157 (saveToPhotos→ImageSaver)。共有導線は :40-59 (ShareLink)。
Android 写真保存導線なし: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/share/StreakShareScreen.kt:106-116`


### widgets


**Android ウィジェットにテストが皆無** (?)

- 実害: iOS は WidgetTimelineDates/SnapshotFactory/SnapshotPublisher の3テストで日付投影・entry生成・rescued反映を検証。Android の widget は達成判定の誤り(休養日=達成)や遷移欠落を含むがユニット/UIテストが1件も無く回帰検知ができない。

- 根拠: `Android ウィジェット唯一の実装: /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/widget/StreakWidget.kt:52-118 (provideGlance は state を1回計算しレンダリングのみ、日付投影なし)。達成表示は委譲: StreakWidget.kt:61,69 (HomeStateReducer.reduce + state.todayStatus.countsAsAchieved)。countsAsAchieved の Rest 包含(意図的仕様): /Users/jun/.../app-android/.../domain/DailyStatus.kt:22。Andr`


### 体重トラッキング


**Android ペイウォールに cooldown/自動提示と『ホーム記録は無料』注記が欠落** (?)

- 実害: iOS は未加入時に6h cooldown 付きで paywall を自動提示し、ロック画面に『ホームの記録からの体重入力は無料』を明記(SPEC 2.5 の必須コピー)。Android は LockedOverlay にボタン導線のみで自動提示も cooldown も無く、無料注記文も無い。誘導の妥当性とユーザー誤解防止の面で iOS に劣後。

- 根拠: `iOS 自動提示+cooldown: /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/WeightTabRootView.swift:14 (6h定数), :37-66 (sheet+onDismiss cooldown書込+isInCooldown), :52-60 (updateGate 自動提示)。iOS 無料注記: 同 :87-91。SPEC: /Users/jun/Documents/Business_Project_Management/serial_training/docs/SPEC_iOS.md:82。Android 欠落: /Users/jun/Documents/Business_Project_Management/ser`


**Android は記録2件未満時にグラフ区画が無言で消え、案内が出ない** (?)

- 実害: iOS は2件未満で『N以内に2件以上の記録があるとグラフが表示されます』を提示。Android は dailyChart.size>=2 のときのみ ChartSection を描画し、それ未満では区画ごと消えるため、ユーザーは『なぜグラフが出ないか』が分からない。

- 根拠: `Android (案内なしで区画消失): /Users/jun/Documents/Business_Project_Management/serial_training/app-android/app/src/main/java/com/goexercise/app/presentation/weight/WeightScreen.kt:110-112 — `if (state.dailyChart.size >= 2) { ChartSection(state, palette, onSetPeriod, onToggleCycle) }`(else 分岐なし)。

iOS (案内提示): /Users/jun/Documents/Business_Project_Management/serial_training/app/GOExercise/GOExercise/Views/We`


### 分析opt-out


**signal名一致テストがAndroid片側のみ=iOS定数変更を検知不能** (?)

- 実害: AnalyticsEventTest.kt:14-24がiOSとのsignal名一致を固定しているが、これはAndroid定数のスナップショットに過ぎず、iOS Analytics.swiftのname定義を変更してもこのテストはAndroid値しか見ないため失敗しない。クロスプラットフォーム集計のファネル分断リスクが残る(ドキュメント/CIでの突合せが別途必要)。

- 根拠: `app-android/app/src/test/java/com/goexercise/app/analytics/AnalyticsEventTest.kt:14-24 (assertEquals がハードコード文字列リテラルと Android 定数のみを照合、iOS 参照なし); docstring の保証は同ファイル:9-10。iOS 定義 app/GOExercise/GOExercise/Services/Analytics.swift:20-31 (name 定義・現状一致だが独立した別ソース)。代替検知の不在: iOS 側 signal 名 assert test 0件(GOExerciseTests/ 内に Analytics 参照テスト無し)、CI は .github/workflows/ios-ci.yml が iOS 単独で Android/突合せ step 無し。`


### 連続日数エンジン


**Android streakState の longest 計算が rescued 日で途切れる(潜在)** (?)

- 実害: streakState の when(line69)が Achieved/TodayAchieved のみで running 加算し、Rescued が else→running=0 に落ちるため longestStreak が救済日で分断される。iOS は .rescued を含む。現状 longestStreak は Android UI に未表示のため即時の実害は無いが、将来表示/共有値に使うと過小表示。回帰バグ型(4)の潜在

- 根拠: `Android bug: app-android/app/src/main/java/com/goexercise/app/domain/StreakCalculator.kt:69 (case lacks DailyStatus.Rescued) with reset at :77. Correct sibling: same file :33 (currentStreak includes DailyStatus.Rescued). iOS reference (correct): app/GOExercise/GOExercise/Services/StreakCalculator.swift:91 (includes .rescued). longestStreak consumers: declared only at app-android/app/src/main/java/`
