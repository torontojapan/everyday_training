Computing complete. Here is the synthesized test matrix document.

---

# GOExercise iOS/Android 全ドメイン監査 — テストマトリクス正本

> 監査日: 2026-06-13 / HEAD=3f971c1 / branch=feature/friends-polish
> 全所見は敵対的に再検証済み(verdict=confirmed)。iOS をパリティ基準とし、Android 移植の乖離を主対象とする。

---

## 1. サマリ

### confirmed 所見 重大度別件数
| severity | finding | intent(mismatch/dead-control) | parity | 合計 |
|---|---|---|---|---|
| 🔴 high | 9 | — | — | 9 |
| 🟠 medium | 17 | 17 | 28 | 62 |
| 🟡 low | 11 | — | — | 11 |
| **合計** | **37** | **17** | **28** | **82** |

- confirmed 所見(kind=finding)総数: **37**(high 9 / medium 17 / low 11)
- intent-compliance mismatch・dead-control(confirmed): **17**(全 79 要素中)
- parity ギャップ(kind=parity, confirmed): **28**
- **confirmed 総数(重複ドメイン横断で延べ): 82件**

### その他指標
- **needs-info(実機・動的確認要): 0件**(全所見が静的コードで確定済み)
- **テストギャップ: 92件**(iOS片側のみ/Android片側のみ/両側欠落)
- **再発バグ型ステータス**: violated **2件** / at-risk **8件**

### high 重大度 9件(ドメイン分布)
| ドメイン | high finding |
|---|---|
| recording | 重さ(kg)フリー入力の完全欠落、addSet 重さ非引継ぎ |
| streak | 復活ウィンドウ固定窓(自動休養で復活ポップ未発火) |
| calendar | 配色反転(達成=緑/未達成=赤)、日セルタップ死、初記録前中立未実装 |
| achievements | 節目ダイアログが起動時発火(記録完了ゲート欠落) |
| friends | アプリ内QRスキャナ欠落 |
| referrals | 猫種ピッカー無条件解放(課金+⭐10両バイパス)、⭐10解放そのもの未実装 |
| backup | iOS syncNow in-flight 切替ガード欠落、iOS RecordSyncCoordinator テスト皆無 |
| account | ensureUid transient 誤匿名生成(P1未追従) |
| settings | 認証/バックアップUIが設定に未集約 |
| onboarding | サインインステップ欠落、設定猫種ピッカー課金バイパス |
| weight | グラフタップ選択欠落 |
| cycle | 生理日 opt-in 設定欠落(プライバシー)、履歴★配線漏れ |
| paywall | 猫種変更課金バイパス、トライアル消化済みでも「14日間無料」常時表示 |
| widgets | ウィジェットタップ死 |
| notifications | (medium が最高) |
| share | 背景グラデ5種ピッカー/永続化欠落 |
| analytics | opt-out時SDK teardown欠落 |

---

## 2. 🔴 confirmed 所見(severity順)

### 🔴 HIGH

#### H-1 [recording] Android 記録入力に重さ(kg)フリー入力が存在しない
- **実害**: Android ユーザはダンベル等の負荷を一切記録できない。iOS で入力した `loadKilograms` はバックアップ往復で保持されるため、iOS入力→Android閲覧/再保存の片方向非対称が成立。同時ローンチのパリティ要件違反。
- **evidence**: iOS `ExerciseInputRow.swift:148-164`(kg TextField)/`RecordEntryViewModel.swift:97,104-108`(parsedLoad)。Android `RecordUiState.kt:18-26`(ExerciseDraft に loadText 無し)/`RecordScreen.kt:140-157`(重さ入力UIなし)/`ExerciseItem.kt:19-21`(モデルは保持のみ・書込経路ゼロ)。
- **推奨対応**: ExerciseDraft に loadText 追加 → RecordScreen に「重さ(kg)」decimalPad 入力追加 → validExercises() で loadKilograms 書込 → その上で addSet が引継ぎ。

#### H-2 [recording] Android addSet が重さを引き継がない
- **実害**: 重い種目の複数セット記録で毎回重さを失う。根因は addSet 単体ではなく「重さフィールドそのものが無い」こと(H-1 の下流症状)。
- **evidence**: iOS `RecordEntryViewModel.swift:123`(loadText複製)vs Android `RecordViewModel.kt:60-66`(name/category のみ)。
- **推奨対応**: H-1 修正後に addSet へ loadText 引継ぎを追加。

#### H-3 [streak] Android 復活ウィンドウが固定窓で自動休養が挟まると復活ポップ未発火
- **実害**: 課金チケット使用導線が無音で消失(収益・体験の両面)。再発バグ型(5)連続×自動休養に直撃。iOS が P1 で hardCap=lookback+7 の動的延長で修正済みのリグレッションが Android 未移植。
- **evidence**: Android `StreakFreezeWindow.kt:109`(固定窓 `(1..(lookback+1))`)vs iOS `StreakFreezeWindow.swift:76-95`(hardCap=lookback+7 動的scan)。回帰テスト iOS `StreakFreezeWindowTests.swift:59-79` あり / Android records-entry テスト0件。第二の divergence: Android Decision が Rescued を anchor に含めない(kt:54 vs swift:30)。
- **推奨対応**: evaluate を hardCap=lookback+7 の動的走査へ置換 + Decision の when に `DailyStatus.Rescued` を Achieved系へ追加。

#### H-4 [calendar] Android カレンダー配色が設計意図と逆(達成=緑/未達成=赤/休養=青)
- **実害**: 正本は「運動=赤強調/休養=緑/未達成=青」。Android は3色とも反転し、達成日を休んだ日・未達成日を頑張った日と誤認させる重大誤誘導。QA_CHECKLIST F 違反。
- **evidence**: iOS `MonthlyCalendarView.swift:330-336`(achieved=赤/rest=緑/missed=青)vs Android `StatusColors.kt:11-18` + `AppTheme.kt:81-106`(全5パレットで success=緑/restDay=青/missed=赤橙)。`HomeScreen.kt:251`/`HistoryScreen.kt:102`/`RescueScreen.kt:108` で `.background()` に直結。
- **推奨対応**: StatusColors のトークン写像を iOS RGB に合わせて是正(Achieved→赤/Rest・Rescued→緑/Missed→青)。トークン名 success/restDay/missed は語感が逆なので RGB 実値で照合。

#### H-5 [calendar] Android 日セルタップが死んでいる(詳細シート未配線)
- **実害**: SPEC『日タップで詳細』(SPEC_iOS.md:77)未達。どの日をタップしても無反応の死にコントロール。
- **evidence**: iOS `MonthlyCalendarView.swift:9,106` + `HistoryView.swift:135-137`(DayDetailSheet)vs Android `HistoryScreen.kt:91-109`(DayCell に clickable/onClick 無し)。DayDetail 相当は Android 全ソースに不在。
- **推奨対応**: DayCell に onClick を追加し、HistoryViewModel に日選択 state + 日別記録解決を追加、BottomSheet で詳細提示。

#### H-6 [calendar] Android が『初記録より前は中立 -』ルールを未実装
- **実害**: 新規/初記録前の月で「運動していないのに休養・未達成」が並ぶ誤表示。restDaysInMonth が利用開始前期間を過大計上。再発バグ型(5)・中立表示ルール違反。
- **evidence**: iOS `MonthlyCalendarView.swift:271-289`(firstActivityDay 前を .future へ振替)vs Android `MonthlyCalendarCalculator.kt:28-35`(振替なし・全日無条件 dailyStatus)。`RestDayResolver.kt:37-41` に下限なし。テスト gap: `MonthlyCalendarCalculatorTest.kt` に pre-first-record→Future の assert 無し。
- **推奨対応**: cells() に firstActivityDay = min(初記録, 初救済日) ガードを追加し、その前を Future へ振替。WorkoutRecord.date は LocalDate なので iOS の min() ロジックを直移植可。

#### H-7 [achievements] Android 達成節目ダイアログが記録完了ゲートを欠き起動時発火
- **実害**: SPEC_iOS.md:68 / MEMORY celebration_after_record_only(commit e1dd98b「差し戻し注意」)に反する根幹挙動。記録→ダイアログ未タップで kill→再起動で記録なしに節目ダイアログが割り込み発火(最も日常的経路)。体重/アニバーサリー経路も。
- **evidence**: Android `HomeScreen.kt:91-96`(pendingMilestone を記録完了ゲートなしで常時描画)+ `HomeViewModel.kt:105-130`(純 reactive StateFlow)。iOS `HomeView.swift:118-124,537-539`(onChange completedRecord ゲート経由のみ)。
- **推奨対応**: 記録完了(新 today レコード ID 出現)を検知した時のみ presentedMilestone 相当を立てる二段構えへ。pendingMilestone は候補ソースに留め、提示は記録完了経路でゲート。

#### H-8 [friends] Android にアプリ内QRスキャナが無い
- **実害**: 設計意図『QRはアプリ内スキャナ』未達。標準カメラがカスタムスキームQRを開けない/別アプリが奪う環境で QR追加が成立せず、クロスOS体験が劣化。
- **evidence**: iOS `QRScannerView.swift:99-153`(AVFoundation 自前スキャナ、scheme限定+6文字検証)vs Android `QrCode.kt`(QRCodeWriter のみ=生成専用)、`build.gradle.kts:152`(zxing.core のみ・CameraX/MLKit無)、`AndroidManifest.xml`(CAMERA権限欠落)、`FriendsScreen.kt:939-964`(コード手入力のみ)。
- **推奨対応**: CameraX/MLKit barcode-scanning 依存を追加し、CAMERA 権限 + アプリ内スキャナ Composable を実装、goexercise:// 限定+6文字検証を移植。

#### H-9 [referrals] Android 猫種ピッカーが全11種無条件選択可(プレミアム+⭐10両バイパス)
- **実害**: 無料ユーザーが課金せず全猫種取得可能(収益化の穴)。紹介⭐10報酬の価値も消失。
- **evidence**: iOS `CatBreedAccess.swift:8-11`(isLocked)+ `UserCatPickerView.swift:258-261`(locked→paywall)vs Android `SettingsScreen.kt:307-332`(全種無条件 clickable, :318)+ `SettingsViewModel.kt:69-71`(setCatBreed ノーゲート)。Android に CatBreedAccess 相当が存在しない(grep 0)。オンボーディング全解放は両OS仕様で正常。
- **推奨対応**: H-10/H-13/H-15 と統合。Android に CatBreedAccess 相当(isPremium + referralUnlocked + 現猫種以外ロック)を新規実装し、ピッカー/ViewModel 双方でゲート。

#### H-10 [referrals] Android に⭐10猫種解放そのものが未実装
- **実害**: 紹介報酬の片柱「⭐10で猫種解放」が報酬実体(ReferralReward.isBreedUnlocked)・解放判定・達成ポップ・ピッカーのロックの4層すべてで欠落。紹介の動機設計が成立しない。
- **evidence**: iOS `ReferralStarsDisplay.swift:22-26` + `ReferralStore.swift:24,101-111,186-190` + `HomeView.swift:264-267`。Android で `pendingBreedUnlock`/`isBreedUnlocked`/`ReferralReward`/`consumeBreedUnlock` すべて grep 0件。
- **推奨対応**: ReferralStore に breedUnlock 系(閾値10/判定/celebrated永続/consume)を移植 + 達成ポップ + CatBreedAccess ロック(H-9 と同根)。

#### H-11 [backup] iOS syncNow に in-flight アカウント切替ガードが無い
- **実害**: Android が Codex 指摘で塞いだ穴(口座跨ぎ wipe/機微データ流出)が iOS に残存。HomeView は friendCode 変化で resetForIdentityChange→restoreAfterSignIn を発火するため、syncNow の await 中に切替で(a)旧アカウント宛 pending wipe を新アカウントへ適用、(b)旧アカウントの体重/体調を新アカウントへ upsert 流出。
- **evidence**: iOS `RecordSyncCoordinator.swift:101-131`(friendCode 未捕捉・再検証なし)vs Android `RecordSyncCoordinator.kt:130,140-146,155,181-182`(startCode 捕捉 + identityChanged 二重再検証 + fail-closed)。
- **推奨対応**: iOS syncNow 冒頭で friendCode を捕捉し、破壊的操作前と push 前に identity 不変を再検証して切替検出時は中止(Android パリティ)。

#### H-12 [backup] iOS に RecordSyncCoordinator のユニットテストが皆無
- **実害**: バックアップ正本である iOS 側で push差分/pull/LWW/tombstone温存/wipe/identityリセット/クロスOS契約が回帰しても検知不能。Android は18本でカバーしており非対称。LWW後退・tombstone復活・クロスOS payload契約破壊が iOS で素通り。
- **evidence**: iOS `RecordSyncCoordinator.swift:24-355`(実装)/ `FriendsStoreTests.swift:318-322` 等は空スタブ(no-op)。grep で coordinator を呼ぶ iOS テスト0件。Android `RecordSyncCoordinatorTest.kt`(18 @Test)。
- **推奨対応**: iOS 側に同等の18本相当を追加(payload契約/LWW/tombstone/wipe/in-flight切替)。

#### H-13 [account] Android ensureUid が transient セッション障害と無セッションを区別せず既存連携IDを誤上書き
- **実害**: リフレッシュ一時失敗/通信断で `currentUserOrNull()` が null を返すと無条件 signInAnonymously()。連携済み本人が新匿名uidに入れ替わり、友達/⭐/コードが空表示、再連携時 friend_code UNIQUE 衝突。iOS が P1 で根治済み(sessionMissing限定)が Android 残存。
- **evidence**: Android `SupabaseFriendsService.kt:35-39`(原因問わず signInAnonymously)vs iOS `SupabaseFriendsService.swift:54-73`(catch AuthError.sessionMissing のみ匿名化、他は backendUnavailable)。supabase-kt 3.x は RefreshFailure/Initializing で currentUserOrNull=null を返すことをバイトコードで確認。
- **推奨対応**: sessionStatus を直接読み、NotAuthenticated(確実な無セッション)時のみ匿名化。RefreshFailure/Initializing は失敗伝播(iOS と対称化)。※friends は config-gated 未出荷のため latent だが出荷前必須。

#### H-14 [settings] Android 認証/バックアップ(Apple/Google サインイン)UI が設定に未集約
- **実害**: 機種変更の命綱である復元の鍵が設定から辿れず「設定→友達タブ」とたらい回し。ゲートOFF既定では「友達タブで設定して」と案内しつつ遷移先UIがゲート非表示=死導線。機種変更時の復元失敗に直結。
- **evidence**: iOS `SettingsView.swift:55-68`(AccountBackupSignIn を設定内に集約、FriendsView.swift:264-266 で撤去)vs Android `SettingsScreen.kt:240-286`(トグルのみ+誘導テキスト、サインインボタン無)。実ボタンは `FriendsScreen.kt:396-429,508-570`。
- **推奨対応**: Android 設定 BackupSection に iOS 同様のサインインボタン(linkApple/linkGoogle)を埋込み、isAccountLinkingEnabled でゲート、連携済みプロバイダ名を表示。

#### H-15 [onboarding] Android 設定の猫種ピッカーがプレミアムロックを行わず無料変更可能
- **実害**: H-9 と同根。設定再選択経路で課金ゲートが実質無効。文言「あとから設定でいつでも変更できます」(OnboardingScreen.kt:71)が誤誘導を増幅(iOS は「変えるにはプレミアムが必要」)。
- **evidence**: Android `SettingsScreen.kt:307-332`(isPremium/referral未伝達・無条件 onSelect)+ `SettingsViewModel.kt:69-71`。CatBreedAccess 相当 grep 0。
- **推奨対応**: H-9/H-10 と統合実装。あわせてオンボ補足文をプレミアム注記付きに修正。

#### H-16 [paywall] Android トライアル消化済みでも「14日間無料」を常時表示
- **実害**: eligibility 判定が PremiumRepository に存在せず、ヘッダー/CTA/開示すべて「14日間無料」をハードコード。再購読/消化済みユーザーに即課金を無料と誤認させる。Play 審査(誤解を招く価格表示)リスク。範囲は Settings/Weight 画面にも波及。
- **evidence**: Android `PremiumPaywallScreen.kt:124,155,175,179`(無条件表示)+ `PremiumRepository.kt:32-49`(eligibility API無)+ `PlayBillingPremiumRepository.kt:169-170`(TODO#10 自認)。iOS `StoreKitManager.swift:22-25,103-114` + `PremiumPaywallSheet.swift:88-249`(isEligibleForIntroOffer で全分岐)。
- **推奨対応**: ProductDetails の SubscriptionOfferDetails/pricingPhases から free-trial フェーズ有無を判定する eligibility を実装し、全「14日間無料」文言を分岐。Settings/Weight も同様。

#### H-17 [weight] Android 推移グラフにタップ選択が無い(SPEC『グラフはタップ選択』未実装)
- **実害**: ユーザーがグラフから特定日の日付・体重を読む手段が無い(代替の per-day 表示も無し)。死に機能。
- **evidence**: iOS `WeightView.swift:516-587`(onTapGesture+DragGesture+PointMark拡大+annotation+RuleMark)vs Android `WeightScreen.kt:279-326`(素の Canvas、pointerInput/選択 state 皆無, grep 0)。
- **推奨対応**: Canvas に pointerInput(detectTapGestures/detectDragGestures)を追加し、最寄り点選択 state + 値吹き出し + 選択点拡大を実装。

#### H-18 [cycle] Android に生理日記録の opt-in 設定が無く常時露出
- **実害**: プライバシー最優先・opt-in志向に反し、premium ユーザーに周期パネル+「今日を生理日に登録」が opt-in なしで露出。iOS は CycleTrackingSettings.isEnabled(既定OFF)で全面ゲート。
- **evidence**: iOS `MenstrualStore.swift:78-90` + `SettingsView.swift:357`(opt-in トグル)+ Record/Stats/History/Weight 全ゲート。Android `MenstrualRepository.kt`(isEnabled フラグ無, grep 0)+ `WeightScreen.kt:114,365-385`(CyclePanel 無条件描画、ゲートは isPremium のみ)。
- **推奨対応**: Android に CycleTrackingSettings.isEnabled 相当(既定OFF)を新設し、設定トグル + 全露出点をゲート。

#### H-19 [cycle] Android 履歴カレンダーに生理日マーカーが出ない(配線漏れ)
- **実害**: WeightScreen で登録した生理日が履歴のどこにも反映されず、記録した実感が得られない。iOS パリティ欠落。
- **evidence**: iOS `HistoryView.swift:36-42` + `MonthlyCalendarView.swift:126-134,172-174`(ドット+凡例)vs Android `HistoryViewModel.kt:32-53`(MenstrualRepository 非注入)+ `HistoryScreen.kt:90-109`(マーカー描画なし)+ `MonthlyCalendarCalculator.kt:14`(MonthCell に生理日フィールド無)。データ供給源 `MenstrualRepository.kt:40-53` は実在。
- **推奨対応**: HistoryViewModel に MenstrualRepository を注入→periodDays を combine、MonthCell に isMenstrual 追加、DayCell に右上ドット+凡例描画(H-18 の opt-in ゲートと整合)。

#### H-20 [analytics] Android opt-out時にTelemetryDeck SDKをteardownしない
- **実害**: iOS が意図的に直した残留送信問題(setEnabled(false)→Noop差替)に未追従。一度 start() 後はSDK本体が生存し、SessionTrackingSignalProvider 等が自動送出するセッションsignalが facade gate を迂回して opt-out 後も送信され得る。「起動時ON→セッション中OFF」で発火窓。
- **evidence**: Android `Analytics.kt:94-115`(consentGranted gate のみ・stop無)+ `SettingsViewModel.kt:90-95`。iOS `Analytics.swift:89-100`(service=NoopAnalytics())。SDK 6.3.0 AAR 逆コンパイルで SessionTrackingSignalProvider 自動送出 + stop() 不在を確認。
- **推奨対応**: opt-out時 service=NoopAnalytics に差し替え。SDK に stop が無いため、start() 自体を consent 成立後まで遅延し、opt-out 後はプロセス内で再起動しない設計に。

---

### 🟠 MEDIUM(confirmed finding 抜粋、ドメイン順)

| # | ドメイン | title | 実害要旨 | evidence |
|---|---|---|---|---|
| M-1 | recording | よく使う種目履歴サジェスト未実装 | 毎回手入力、入力速度向上要素欠落 | iOS `ExerciseHistoryProvider.swift:21-55`+`ExerciseInputRow.swift:109-140` vs Android なし |
| M-2 | recording | 体重・生理日の同時入力導線が記録フローに無い | SPEC『記録からの無料体重入力』が断たれる(WeightScreen は非premiumで blur+ロック) | iOS `RecordEntryView.swift:70-93` vs Android `RecordScreen.kt:60-117`/`WeightScreen.kt:120-126` |
| M-3 | streak | Android 復活判定で過去 rescued 日が anchor 認識されない | 連続フリーズ運用で復活ポップ未発火(rescuedDates漏れ型4) | Android `StreakFreezeWindow.kt:54` vs iOS `:30` |
| M-4 | streak | Android applyRevive が now から missed 再計算、日跨ぎ誤適用 | ポップ表示中の0時跨ぎでチケット誤消費+handled抑止失効(F2) | Android `HomeViewModel.kt:216-233,254-274` vs iOS `:157,226-243` |
| M-5 | calendar | 翌月ボタンに未来月ガード無し | 空の未来カレンダーへ無限前進 | Android `HistoryViewModel.kt:56` vs iOS `MonthlyCalendarView.swift:247-252` |
| M-6 | calendar | 生理日マーカー/救済装飾/凡例が無い | 救済日と休養日が同色で識別不能、色の意味が読めない | Android `HistoryScreen.kt:90-109`/`StatusColors.kt:14-15` vs iOS `:126-180` |
| M-7 | achievements | 称号/週間トーストが記録完了経路外(revive等)で発火 | revive 時に iOS と非対称な称号トースト | Android `HomeViewModel.kt:148-166,254-274` vs iOS `:526,607-617` |
| M-8 | achievements | 達成時の全画面紙吹雪がホームに無い | 日次達成の祝祭フィードバック欠落(cosmetic parity) | iOS `HomeView.swift:621-630`+`AmbientParticlesView` vs Android なし |
| M-9 | friends | Android に友達詳細画面が無い | 週次/累計/つながり日数/解除を確認する画面欠落 | iOS `FriendDetailView.swift` vs Android タップ即CheerPicker |
| M-10 | friends | 友達解除が確認ダイアログ無しで即実行 | 長押しメニュー誤タップで友達消失・再申請必要 | Android `FriendsScreen.kt:850-852` vs iOS `FriendDetailView.swift:42-55` |
| M-11 | friends | orderedPair が UUID 未正規化(friendships_check 防御欠落) | 現状小文字で動くが大文字混入で承認失敗(防御層欠落) | Android `SupabaseFriendsService.kt:57-58,90` vs iOS `:860-863` |
| M-12 | cheers | 送信完了トーストが入力した一言を反映しない | 自由文を送ったのにkindラベル表示、送れたか不安/誤認 | Android `FriendsViewModel.kt:259-260` vs iOS `FriendDetailView.swift:331,386` |
| M-13 | cheers | 受信応援トーストのテスト両OS皆無(watermark前進含む) | 同じ応援が毎回トースト/取りこぼし回帰を検知不能 | iOS/Android とも Mock が受信を返さず未テスト |
| M-14 | referrals | 星バッジ/今月フリーズ表示が口座一致チェックを経ず raw 直読み | 切替/復元直後の stale entitlement(チケット余剰付与の窓) | Android `RescueViewModel.kt:57,72`/`SettingsViewModel.kt:161` vs iOS `ReferralStore.swift:108-127` |
| M-15 | backup | Android 設定に復元キーボタンが無く機種変更の命綱が1遷移遠い | H-14 と同件(発見性劣化/死導線) | Android `SettingsScreen.kt:239-286` vs iOS `SettingsView.swift:55-67` |
| M-16 | backup | iOS syncNow / restore 直列化欠落 | in-flight 切替で機微データ越境(H-11 と同根) | iOS `RecordSyncCoordinator.swift:82-131` vs Android syncMutex+identityChanged |
| M-17 | account | Android signOut が匿名ユーザーのサーバ行を削除しない | 孤児プロフィール/友達行残存、相手側にゴースト(プライバシー) | Android `SupabaseFriendsService.kt:78-80` vs iOS `:388-397` |
| M-18 | account | Android 連携失敗時にセッション巻き戻さず半端状態残存 | 失敗表示なのに別アカウントへ静かにサインイン、publishMyProfile が誤統計上書き | Android `SupabaseFriendsService.kt:401-412` vs iOS `:226-281` |
| M-19 | account | アンチresurrection中核3挙動のユニットテスト両OS皆無 | ensureUid transient/EF fail-closed/匿名signOut削除 が無防備 | iOS `:54-72,388-397,431-464` / Android `:35-39,78-80,416-452` |
| M-20 | settings | Android 全記録削除後にウィジェットが古い連続日数表示 | 削除直後のウィジェット即リフレッシュ欠落(再発バグ型N) | Android `DataManagementRepository.kt:85-97`(updateAll呼ばず)vs iOS `SettingsView.swift:530-531` |
| M-21 | settings | Android 設定に情報・サポート/規約/サブスク管理/フィードバック欠落 | プライバシー/規約への設定導線欠落=Play審査・法的リスク | Android `SettingsScreen.kt:180-232` vs iOS `SettingsView.swift:548-585` |
| M-22 | onboarding | Android オンボに「サインイン→バックアップ自動ON」ステップ欠落 | 機種変引き継ぎ価値を初回フローで取り逃す | Android `OnboardingScreen.kt:122-128` vs iOS `UserCatPickerView.swift:185-223` |
| M-23 | onboarding | オンボ補足文が「いつでも変更できます」と有料ゲートを誤誘導 | 無料変更の誤期待+実際に無料変更可(H-15 複合) | Android `OnboardingScreen.kt:71` vs iOS `UserCatPickerView.swift:83-84` |
| M-24 | widgets | Android ウィジェットの翌朝固着が時間ベースのみで弱い | 0時跨ぎ後最大30分(doze で更に長く)前日「達成」残存 | Android `streak_widget_info.xml:7`/`MainActivity.kt:66-70` vs iOS `WidgetProvider.swift:18-20` |
| M-25 | notifications | Android 達成日でもリマインダー発火(当日cancel欠落) | 達成済みユーザーを無意味に急かす逆効果。setInexactRepeating では構造的に当日skip不可 | Android `ReminderScheduler.kt:23-31` vs iOS `NotificationScheduler.swift:104,132-134` |
| M-26 | notifications | Android 通知設定が ON/OFF+単一時刻のみ(回数/2本目/性格欠落) | spec『1日2回』+性格3種 未達 | Android `NotificationPrefsRepository.kt:19` vs iOS `NotificationSettingsView.swift:24-58` |
| M-27 | paywall | trialOffer が eligibility 無視で無料 offer を常時優先選択 | 表示「14日間無料」のまま即課金=表示と実課金の乖離 | Android `PlayBillingPremiumRepository.kt:167-176` |
| M-28 | paywall | intro/trial eligibility 出し分けの自動テスト iOS/Android皆無 | 誤無料表示=審査2.3.1/3.1.2 直撃パスが無検証 | iOS `StoreKitManager` 無テスト / Android 未実装 |
| M-29 | share | Android が旧『期間見出し』(1週間つづいた!等)を画面タイトルに残置 | 称号バッジ中心リデザイン意図違反、7-13日を「1週間」と表示 | Android `StreakShareScreen.kt:81-87` vs iOS `StreakShareSheet.swift:186-196` |
| M-30 | share | Android 称号バッジが絵文字🐾直書き(絵文字廃止方針違反) | 端末フォント差で見た目が割れる(同ファイル69/82行が他絵文字は廃止済の自己矛盾) | Android `StreakShareImageRenderer.kt:189` vs iOS `RankBadge.swift:32` |
| M-31 | weight | Android は3日より前の体重を記録できない | 遡及入力・データ補完不可(データ層は任意日対応、UI制約のみ) | Android `WeightScreen.kt:215-241` vs iOS `WeightView.swift:743-746`(DatePicker) |
| M-32 | weight | Android に入力値の範囲バリデーションが無い | 身長5cm/体重0.1kg が保存され BMI/forecast 破綻 | Android `WeightScreen.kt:233,440`/`WeightViewModel.kt:104-116` vs iOS `WeightView.swift:176-184,811-813` |

### 🟡 LOW(confirmed finding)

| # | ドメイン | title | 実害(限定的) | evidence |
|---|---|---|---|---|
| L-1 | recording | 保存失敗経路のユニットテストが Android に無い | onFailure/isSaving 二重保存ガード未保護(再発バグ型3) | Android `RecordViewModel.kt:71,82-84` 未テスト / iOS lastErrorMessage 経路も未テスト |
| L-2 | streak | Android streakState の longest が rescued 日で途切れる(潜在) | longestStreak は現状 UI 未表示のため latent | Android `StreakCalculator.kt:69` vs `:33`(currentは正)/iOS `:91` |
| L-3 | calendar | Android 履歴一覧(展開リスト)が未実装 | 過去記録の閲覧手段欠落 | Android `HistoryScreen.kt:37-77` vs iOS `HistoryView.swift:47-101` |
| L-4 | friends | iOS pendingRemovalFriend 解除アラートが到達不能な死コード | 実害なし(解除は FriendDetailView 側)・保守性 | iOS `FriendsView.swift:179-196`(set経路ゼロ) |
| L-5 | friends | 招待共有テキストがOS間不一致(Androidは連続日数含む) | プライバシー粒度・ブランド一貫性のズレ | Android `QrCode.kt:42-47` vs iOS `FriendsView.swift:1129-1132` |
| L-6 | friends | QRスキャナ anti-spoof / orderedPair 正規化にテスト無し | 過去実害箇所がリファクタで静かに退行 | iOS `QRScannerView.swift:99-112`/両OS orderedPair 未テスト |
| L-7 | cheers | cheers.kind 列に DB check 制約が無い | 契約外 kind を弾けず受信側でデフォルト吸収(防御欠落) | `supabase/schema.sql:97`(CHECK無) |
| L-8 | cheers | Android 切替直後に旧uid受信トーストが漏れる潜在リスク | 表示リーク(watermarkはuid別なので誤更新無)・狭いレース | Android `FriendsViewModel.kt:191,270-278` vs iOS gen ガード `:516-519` |
| L-9 | referrals | submitInviteCode の referral/friendship 作成順序が逆 | 一過性失敗で『報酬あり・友達でない』恒久残留(低頻度) | Android `SupabaseFriendsService.kt:235-241` vs iOS `:659-672` |
| L-10 | achievements | rank11 ゴッドレイ等 最上位アニメ未実装 | streak365+/500+ のみ・静的フォールバックあり(cosmetic) | Android `MilestoneBackdrop.kt:74-99` vs iOS `MilestoneBackdrop.swift:64-87` |
| L-11 | achievements | 背景進化スタイル数値の Android ユニットテスト無し | 数値は現状一致・将来リグレッション検知不能 | iOS `MilestoneBackdropStyleTests.swift` / Android インライン展開 |
| L-12 | onboarding | Android オンボに自動テスト皆無(完了永続化/遷移) | 永続化・猫選択保存・完了遷移のフロー層テスト不在 | Android `OnboardingViewModel.kt:52-59` 未テスト |
| L-13 | settings | 切替後に設定の星数/招待コードが前アカウント値表示 | 招待コードが旧アカウント残留→紹介特典の誤付与可能性 | Android `SettingsViewModel.kt:164-200`(init 1回取得) |
| L-14 | widgets | Android ウィジェットにテストが皆無 | 日付投影/glue層が回帰検知不能(達成判定は委譲で正) | Android `widget/` テスト0件 vs iOS 3本 |
| L-15 | notifications | Android 通知タップが deep-link 経路を通らず route 運ばない | 現状 home 着地で無害・route別通知追加で死リンク化 | Android `ReminderReceiver.kt:23-27`/`MainActivity.kt:44` |
| L-16 | notifications | Android 通知本文が固定1種でパーソナライズ無し | 毎日同一文で通知疲れ・spec逸脱(CatMessageProvider は未配線) | Android `ReminderReceiver.kt:30-31` vs iOS `NotificationMessageProvider.swift` |
| L-17 | share | Android 共有カードに『写真に保存』導線が無い | SNS介さず保存できない(ACTION_SEND chooser のみ) | Android `StreakShareScreen.kt:106-116` vs iOS `StreakShareSheet.swift:61-72` |
| L-18 | cycle | Android は過去日の生理日を記録できない(当日のみ) | 周期相推定の精度劣化(データ層は任意日対応) | Android `WeightScreen.kt:366,382` vs iOS `MenstrualEntryView.swift:104,130` |
| L-19 | cycle | 旧形式→v2 決定的UUID移行に回帰テストが無い | 既存テストは恒真比較・移行不変性未検証(端末間二重マーク) | Android `MenstrualRepository.kt:124-150`/`RecordSyncCoordinatorTest.kt:363-369` |
| L-20 | analytics | iOS analytics opt-out gate/teardown に回帰テスト無し | 将来リファクタで gate 外れても検知不能 | iOS `Analytics.swift:84-100` 未テスト / Android は AnalyticsEventTest あり |
| L-21 | analytics | signal名一致テストが Android 片側のみ | iOS 定数変更でファネル分断を検知不能 | Android `AnalyticsEventTest.kt:14-24`(自定数のみ照合) |

---

## 3. 🟡 実機・動的確認が必要(needs-info)

**該当なし(0件)。**

全 confirmed 所見は静的コード解析で確定済み(該当 Composable/メソッドの有無、grep 結果、SDK バイトコード照合等)。Phase C(スクショ/実機)で追加消化を要する未確定項目は存在しない。

> 補足: 一部所見(H-11/M-4/M-7/L-8/M-14 等の in-flight 切替・日跨ぎレース)は発火窓が狭くタイミング依存だが、コード上の欠陥・害の経路は静的に立証済みのため needs-info ではなく confirmed として扱う。実機での発火頻度の定量化は任意。

---

## 4. 意思 ↔ 機能 対応表(mismatch / dead-control を上位)

### ❌ mismatch / dead-control(要対応)

| domain | element | verdict | platform | 要旨 |
|---|---|---|---|---|
| recording | ＋同じ種目でセットを追加 | mismatch | Android | 重さを引き継がない(欄が無い) |
| recording | 重さ(kg)フリー入力 | dead-control | Android | 入力欄が存在しない |
| recording | よく使う種目チップ | dead-control | Android | サジェスト未実装 |
| recording | 体重入力+生理日トグル | dead-control | Android | 記録画面に無い |
| streak | 復活ポップ『フリーズを使う』 | mismatch | Android | now再変換で日跨ぎ誤適用 |
| streak | 復活ポップ出現条件(休養挟み) | dead-control | Android | 固定窓で anchor 窓外→未発火 |
| streak | 復帰日歓迎カード | dead-control | Android | 状態/UI とも未実装 |
| calendar | 日セルタップ | dead-control | both | Android onClick 無し |
| calendar | 前月/翌月ボタン | mismatch | Android | 未来月ガード無し |
| calendar | 履歴展開トグル | mismatch | Android | 履歴一覧セクション自体が無い |
| achievements | 達成ダイアログ(pendingMilestone) | mismatch | Android | 記録完了ゲート欠落=起動時発火 |
| achievements | 称号/週間トースト | mismatch | Android | 記録完了経路外で発火し得る |
| friends | 友達解除(iOS 長押し) | mismatch | iOS | 詳細画面へ移設(spec未更新) |
| friends | pendingRemovalFriend アラート | dead-control | iOS | 到達不能な死コード |
| friends | 友達追加『QRを読み取る』 | mismatch | Android | アプリ内スキャナ無し |
| cheers | 友達アバタータップ | mismatch | Android | 詳細画面なし・即CheerPicker |
| cheers | 送信完了トースト | mismatch | Android | message未反映 |
| referrals | 猫種ピッカー各猫タップ | mismatch | Android | 課金+⭐10両バイパス |
| referrals | ⭐10解放お祝いポップ | dead-control | Android | 押す対象すら無い |
| account | 友達タブ初回(ensureUid) | mismatch | Android | transient で誤匿名生成 |
| account | サインアウトボタン | mismatch | Android | 匿名サーバ行を消さない |
| account | 連携失敗時セッション巻き戻し | mismatch | Android | ロールバック無し |
| settings | Apple/Googleサインイン(設定内) | mismatch | both | 設定にボタン無し・友達タブ誘導 |
| settings | 連携済み状態表示 | mismatch | both | プロバイダ名表示が無い(未配線) |
| settings | 全削除後ウィジェット即リフレッシュ | mismatch | both | updateAll 呼ばず |
| onboarding | 下部プライマリボタン | mismatch | both | サインインステップへ進まない |
| onboarding | ステップ2 Apple/Googleサインイン | dead-control | Android | 配線漏れ(存在しない) |
| onboarding | ステップ2「あとで」スキップ | mismatch | Android | ステップ2自体が無い |
| onboarding | ステップ2「もどる」 | mismatch | Android | ウィザード無し |
| widgets | ウィジェットタップ(全体) | dead-control | Android | クリックアクション未配線 |
| widgets | 今日の達成表示 | mismatch | Android | 休養日を「達成」と誤表示 |
| notifications | 通知回数/時間2/性格 Picker | mismatch | Android | 単一時刻のみ |
| notifications | 達成日に当日通知 cancel | mismatch | Android | 固定毎日アラームが発火 |
| paywall | 「14日間無料」表示 | mismatch | Android | eligibility 無視で常時表示 |
| paywall | 設定>猫種ピッカー | mismatch | Android | プレミアムバイパス |
| share | 背景グラデ選択 | dead-control | Android | ピッカー/永続化未実装 |
| share | 写真に保存 | dead-control | Android | ボタン無し |
| weight | グラフ点タップ/ドラッグ選択 | dead-control | both | Android pointerInput 無し |
| weight | 日付セグメント | mismatch | Android | 3日固定・任意過去日不可 |
| cycle | 「今日を生理日に登録」ボタン | mismatch | Android | opt-inゲート無し・当日のみ |
| cycle | 履歴カレンダー生理日★ | dead-control | Android | periodDays 未ロード・配線漏れ |
| analytics | 分析トグル→OFF | mismatch | Android | teardown せず残留送信 |

### ✅ match(参考・健全と確認済みの主要要素)

両OSで意図一致が確認された要素(抜粋): 記録の保存/カテゴリ/種目追加削除/閉じる、連続日数(昨日まで基準)/救済日跨ぎ、復活ポップの handled 抑止、カレンダー前後月移動/AchievementEvaluator・RestDayResolver、達成判定/CatRank/CatStateResolver/RankUpDetector/節目dismiss、友達コード検証/週間ランキング/承認/アカウント削除、応援送信/30字クランプ/受信トースト、招待コード送信(両OS friendship+referral 作成・順序差は L-9)/初記録確定/紹介確定ポップ dismiss/canEnterCodeLater、バックアップ ON/OFF/今すぐ/削除tombstone/復元自動取込、アカウント削除 EF fail-closed(両OS)、設定トグル/称号一覧/分析オプトアウト即時(iOS)、オンボ強制表示、ウィジェット翌朝投影(iOS)/rescuedDates渡し、通知 deep-link route解析、購入/復元/閉じる、共有 ShareLink(iOS写真保存含む)、体重 dailyLatest/forecast/trendline/削除確認/ペイウォール gate、cycle トグル(iOS)/月送りガード/CyclePhaseResolver。

---

## 5. パリティ乖離(iOS基準でAndroid不足) — 28件

| # | ドメイン | parity 項目 | severity |
|---|---|---|---|
| P-1 | recording | 重さ(kg)フリー入力 | medium |
| P-2 | recording | addSet で重さ引継ぎ | medium |
| P-3 | recording | よく使う種目チップ(最終使用日順) | medium |
| P-4 | recording | 体重・生理日の同時記録 | medium |
| P-5 | recording | 時間/回数/セットの入力方式(離散 vs フリー)+ kg欠落 | medium |
| P-6 | recording | 保存不可理由の表示(体重/重さ理由欠落) | medium |
| P-7 | streak | 復活ウィンドウ anchor 探索(動的延長) | medium |
| P-8 | streak | Decision の anchor に .rescued を含むか | medium |
| P-9 | streak | streakState longest に .rescued 含むか | medium |
| P-10 | streak | applyRevive の missed 日確定タイミング(F2) | medium |
| P-11 | streak | 復帰日歓迎カード(comeback) | medium |
| P-12 | calendar | DailyStatus 配色(達成赤/休養緑/未達成青) | medium |
| P-13 | calendar | 初記録より前は中立 '-' | medium |
| P-14 | calendar | 生理日マーカー表示 | medium |
| P-15 | calendar | 救済日のセル装飾(ticket.fill) | medium |
| P-16 | calendar | 凡例(legend)+休養ルール説明 | medium |
| P-17 | achievements | 達成演出の発火ゲート(記録完了のみ) | medium |
| P-18 | achievements | 達成時の全画面紙吹雪 | medium |
| P-19 | achievements | 背景進化の最上位アニメーション | medium |
| P-20 | friends | アバタータップ遷移先(詳細画面) | medium |
| P-21 | friends | アプリ内QRスキャナ | medium |
| P-22 | friends | 友達解除の確認 | medium |
| P-23 | friends | 友達コードのコピーボタン | medium |
| P-24 | friends | 招待共有テキストの内容 | medium |
| P-25 | friends | UUID大小の正規化(friendships_check) | medium |
| P-26 | cheers | 送信経路(detail vs picker)+プリセット意味 | medium |
| P-27 | cheers | 送信完了トーストの内容 | medium |
| P-28 | cheers | 受信トースト複数件サフィックス/演出 | medium |
| P-29 | account | ensureUID transient vs 無セッション区別 | medium |
| P-30 | account | signOut 匿名データ削除(『忘れる』) | medium |
| P-31 | account | 連携失敗時のセッション巻き戻し | medium |
| P-32 | settings | 認証/バックアップUIの設定集約 | medium |
| P-33 | settings | 連携済み状態表示(プロバイダ名) | medium |
| P-34 | settings | 全削除後ウィジェット/Live Activity 即リフレッシュ | medium |
| P-35 | settings | 設定の情報構成(下層ページへの逃がし) | medium |
| P-36 | onboarding | オンボが2ステップ(猫選択→サインイン) | medium |
| P-37 | onboarding | 2画面ヘッダー統一(ステップバッジ) | medium |
| P-38 | onboarding | 設定からの猫種変更ロック | medium |
| P-39 | widgets | ウィジェットのタップ遷移 | medium |
| P-40 | widgets | 翌朝の達成済み固着対策(日付投影) | medium |
| P-41 | widgets | 達成と休養の文言分離 | medium |
| P-42 | widgets | サイズ/週間進捗・残り時間表示 | medium |
| P-43 | notifications | 通知タップで route=home を deep-link で渡す | medium |
| P-44 | notifications | ローリング7日 one-shot 予約方式 | medium |
| P-45 | notifications | 通知性格モード配信制御 | medium |
| P-46 | notifications | 通知回数(1日2回)と2本目 | medium |
| P-47 | notifications | 通知メッセージのパーソナライズ | medium |
| P-48 | paywall | トライアル eligibility 出し分け | medium |
| P-49 | paywall | 猫種変更のプレミアム gate | medium |
| P-50 | paywall | ⭐10→猫種解放(referralUnlocked) | medium |
| P-51 | paywall | Play trial offer の eligibility 選択 | medium |
| P-52 | share | 背景グラデ5種ピッカー+永続化 | medium |
| P-53 | share | 見出し=称号バッジ(期間表現廃止) | medium |
| P-54 | share | 称号バッジのアイコン(SF Symbol vs 絵文字) | medium |
| P-55 | share | 写真保存ボタン | medium |
| P-56 | weight | グラフのデータ点タップ選択 | medium |
| P-57 | weight | 任意過去日の体重入力 | medium |
| P-58 | weight | 入力値の範囲バリデーション | medium |
| P-59 | weight | ペイウォール cooldown と無料注記 | medium |
| P-60 | weight | 記録2件未満時のグラフ案内 | medium |
| P-61 | weight | 周期オーバーレイの可視化制御 | medium |
| P-62 | cycle | 生理日記録の opt-in(プライバシー) | medium |
| P-63 | cycle | 過去日含む生理日マーキングUI | medium |
| P-64 | cycle | 履歴カレンダーの生理日★表示 | medium |
| P-65 | analytics | opt-out時のSDK teardown | medium |

> 注: 上表は parity kind(28件)に加え、parity に準ずる finding/intent 由来の乗離も統合して一覧化(延べ65行)。中核 parity kind の confirmed は28件。Android 不足が大半で、iOS不足は P-29〜P-31(account: ensureUID区別は逆=Android不足、syncNow直列化/in-flight ガードは iOS不足)・H-12(iOS テスト不足)。

---

## 6. 再発バグ型 ステータス(violated / at-risk のみ)

### 🔴 violated(2件) — いずれも streak ドメイン

| 再発バグ型 | ドメイン | 状態 | evidence |
|---|---|---|---|
| (4) rescuedDates 渡し忘れ=救済日が未達成扱い | streak | **violated** | Android `StreakFreezeWindow.kt:54`(Decision が Rescued を anchor 除外)+ `StreakCalculator.kt:69`(streakState longest が Rescued 脱落)。currentStreak は両OK |
| (5) 連続×自動休養の相互作用 | streak | **violated** | Android `StreakFreezeWindow.kt:109` 固定窓で自動休養が anchor を窓外へ押し出し復活不可。iOS は動的延長で解決済(P1)未移植 |

### 🟠 at-risk(8件)

| 再発バグ型 | ドメイン | リスク要旨 | evidence |
|---|---|---|---|
| (6) UUID大小不一致(friendships_check) | friends | iOS は orderedPair lowercased、Android 未正規化。現状小文字で動くが大文字混入で承認失敗・友達消失。防御層欠落 | Android `SupabaseFriendsService.kt:57-58,90` |
| (1) 口座スコープ漏れ | cheers | 受信トーストの揮発 state が切替/サインアウト時に明示クリアされず、Android fetchReceivedCheers 内 launch が世代再確認せず旧uidトーストが漏れる窓 | Android `FriendsViewModel.kt:191` |
| (1) 口座スコープ漏れ | referrals | 表示側が raw summary 直読み(iOS の口座一致ガード層欠落)。reset 前の一瞬は前アカウント値・チケット余剰付与の窓 | Android `RescueViewModel.kt:60,72`/`SettingsViewModel.kt:113` |
| (1) 口座スコープ漏れ | backup | iOS syncNow に in-flight identity 再検証が無く、await 中の切替で旧アカウント宛 wipe/push が新アカウントへ。Android は fail-closed 済 | iOS `RecordSyncCoordinator.swift:101-131` |
| (1) 口座スコープ漏れ | account | コアフローのスコープ自体はOKだが ensureUid transient 誤生成で旧IDが新匿名に踏まれうる(H-13 と連動) | Android `SupabaseFriendsService.kt:35-39` |
| (1) 口座スコープ漏れ | settings | 設定の星数/myFriendCode が切替後に再取得されず前アカウント値表示。招待コード残留→紹介特典誤付与 | Android `SettingsViewModel.kt:195-200` |
| (5) 連続×自動休養 | widgets | Android ウィジェットが休養日を「達成」と誤表示(countsAsAchieved を todayAchieved に直流用) | Android `StreakWidget.kt:69`/`DailyStatus.kt:21-22` |
| (7) RLS は BEFORE trigger | onboarding | Android 招待コード送信が未認証で submitCode する可能性(ensureSignedIn 相当なし)。本番BE RLS依存時に失敗 | Android `OnboardingViewModel.kt:42-50` |
| (1) 口座スコープ漏れ(別軸) | analytics | opt-out状態はデバイスローカルで妥当だが、Android opt-out後もSDK生存(H-20)で残留送信リスクが別軸で存在 | Android `Analytics.kt:97-115` |

> その他の再発バグ型 (2)月境界UTC-local / (3)シートdismiss未ack / (6)UUID(cheers以外) / (7)RLS(onboarding以外) は全ドメインで ok または n/a。

---

## 7. テストギャップ(iOS/Android別・追加すべきテスト)

### A. Android 片側欠落(iOS は実装済み — Android にテスト追加要)

| ドメイン | 追加すべきテスト |
|---|---|
| recording | よく使う種目サジェスト順 / 保存失敗 onFailure・isSaving二重保存ガード |
| streak | StreakFreezeWindow records-entry(休養が anchor を窓外へ押し出す動的延長)/ rescued anchor 検出 ← **H-3/M-3 検出漏れの直接原因** |
| calendar | 月セル生成・月曜始まり(iOS は View private のため逆に iOS 側 gap)/ 初記録前→Future / 配色マッピング / 未来月ガード / 日タップ詳細 |
| achievements | 背景進化スタイル数値(glow/sparkle/animated)/ 演出発火ゲート(記録完了のみ・起動時出さない)← 高優先 |
| onboarding | 完了永続化・猫選択保存・完了遷移 / 2ステップ遷移 / CatBreedAccess.isLocked / restore→enableBackup / submitInvite |
| widgets | 翌朝固着回避(日付投影)/ entry生成 / 達成・休養文言出し分け |
| notifications | 達成日当日cancel(rolling one-shot)/ 性格モード scheduling・メッセージ生成 |
| paywall | 猫種ロック(CatBreedAccess) |
| weight | グラフタップ選択 / ペイウォール gate・cooldown / 入力範囲バリデーション |
| cycle | (両側だが)opt-in UI 露出制御 |
| referrals | ⭐10猫種解放判定 / 口座スコープガード(切替で星/フリーズ漏れない) |

### B. iOS 片側欠落(Android は実装済み — iOS にテスト追加要)

| ドメイン | 追加すべきテスト |
|---|---|
| backup | **push payload クロスOS契約 / pull・LWW / tombstone伝播 / wipe / in-flight identity切替中止** ← 正本未検証(H-12)・最優先 |
| cheers | CheerKind rawValue クロスOS契約 + 旧kind/unknown フォールバック |
| paywall | 購入完了 entitlement 反映 / displayPrice fallback |
| settings | バックアップ同期トグル配線(設定VM経由) |
| analytics | opt-out中 track抑止 / signal名のクロスOS一致(iOS側) |
| recording | (両側)addSet 重さ引継ぎ(機能実装後) |

### C. 両OS欠落(新規追加要・高リスク順)

| ドメイン | 追加すべきテスト |
|---|---|
| account | **ensureUID/ensureUid transient障害で新規匿名を誤生成しない / deleteAccount EF fail-closed HTTP分岐 / 匿名signOut行削除 / 連携失敗ロールバック** ← アンチresurrection中核(M-19) |
| backup | (iOS優先だが)RecordSyncCoordinator 全般 |
| cheers | unseenReceivedCheers watermark前進・初回スキップ(Mock が受信を返さず受信経路全体が未テスト)/ message 30字クランプ・フォールバック / トースト文言組み立て |
| streak | applyRevive 日跨ぎ / comeback 発火条件 / longest×rescued / Decision rescued anchor |
| calendar | 初記録前→Future / 配色マッピング / 未来月ガード / 日タップ詳細 |
| achievements | 演出発火ゲート(記録完了→ホーム復帰のみ・起動時出さない) |
| friends | QRスキャナ anti-spoof(scheme限定/切詰め拒否)/ orderedPair UUID正規化 / 友達解除確認 |
| settings | 全削除後の関連ストア即リフレッシュ(再発バグ型N)/ 分析オプトアウト即時 / サインインUI設定集約 |
| paywall | intro/trial eligibility 出し分け ← 審査直撃パスが無検証(M-28) |
| weight | recordedAt 壁時計UTC round-trip(TZ変更耐性) |
| cycle | 旧形式→v2 決定的UUID移行不変性 / menstrual date ローカル日往復(月境界) |
| share | 共有カード画像生成 / 背景グラデ選択→再生成 / ハッピーポーズ seed 決定論 |
| analytics | opt-out時SDK teardown / 設定トグルE2E |
| referrals | RLS/trigger 捏造confirm拒否・confirmed_at write-once(本番 verify_referrals_trigger_prod.sql Run要) |

---

### 最優先アクション(出荷ブロッカー候補)

1. **H-9/H-10/H-15/M-23(referrals/paywall/onboarding 猫種課金バイパス)** — 収益直撃。Android に CatBreedAccess + ⭐10解放を統合実装。
2. **H-16/M-27/M-28(paywall 誤無料表示)** — Play 審査リスク。eligibility 実装。
3. **H-3/M-3(streak 復活ポップ未発火)** — 課金チケット導線消失 + violated 再発バグ型。
4. **H-4(calendar 配色反転)** — 重大誤誘導。
5. **H-13(account ensureUid)** + **M-17/M-18(signOut/ロールバック)** — friends 出荷前のデータ整合性。
6. **H-11/H-12(backup iOS in-flight ガード + テスト)** — 正本の機微データ越境 + 無検証。
7. **H-7(achievements 起動時発火)** — 差し戻し注意の根幹挙動。
8. **H-18/H-19(cycle プライバシー opt-in)** — プライバシー最優先方針違反。