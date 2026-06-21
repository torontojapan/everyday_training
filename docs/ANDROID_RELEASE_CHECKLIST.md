# Android リリース前チェックリスト(2026-06-21 作成)

> iOS 先行戦略([[release_strategy_dual_launch]])のため Android は iOS が製品完全版になってから公開。
> 本書はその「公開前にやること」の正本。自走可否で分類。検証根拠は本セッション(branch `parity/tokenize-strict-2026-06-21`)。
> 関連: パリティ=`PARITY_REMAINING_TASKS.md` / QA=`QA_MASTER_PLAN.md` / 規約=`CLAUDE.md`。

## 現状の確定事項(本セッション検証済)
- release ビルド(R8 minify + resource shrink)= **BUILD SUCCESSFUL**(`assembleRelease`、約1m16s)。
- merged manifest 権限: INTERNET / ACCESS_NETWORK_STATE / CAMERA / POST_NOTIFICATIONS / FOREGROUND_SERVICE / WAKE_LOCK / BILLING / RECEIVE_BOOT_COMPLETED / WRITE_EXTERNAL_STORAGE(maxSdk28)。
- proguard-rules.pro: kotlinx.serialization @Serializable モデル keep + TelemetryDeck datetime dontwarn 済。
- compileSdk/targetSdk=36・minSdk=26・applicationId=com.goexercise.app。
- アカウント削除導線=実装済(`AccountDeletionFlow`)。privacy/terms/support=`docs/*.md` 存在。
- iOS↔Android データ互換=記録 payload クロスOS契約一致・friend code 同一仕様・RLS/状態機械防御済(本セッション検証)。

## A. 自走できる(私が実行)
- [x] **A1 version 実値化**: `build.gradle.kts` versionCode/versionName→ versionName="1.3.0"(iOS 1.3 機能整合)/versionCode=1 に設定済。
- [x] **A2 R8 release の実行時 smoke**: release を一時署名で install → 実 Supabase 匿名サインイン/記録同期/友達コードを通し R8 ランタイム破壊が無いか検証 → **PASS**: minified release を debug 鍵で署名・install、オンボ→友達タブで匿名サインイン+profile デシリアライズ+friend code 生成が R8 下で正常動作。logcat のエラーは「fresh install で保存セッション無し」の良性のみ。keep 追加不要。
- [x] **A3 権限/マニフェスト/セキュリティ監査**: cleartext=既定で無効(targetSdk36・opt-in無)✓ / exported=MainActivity(launcher+deeplink)・BootReceiver(BOOT_COMPLETED)のみで妥当✓ / **allowBackup=true→false に変更**(健康データの Google 自動バックアップ抑止・opt-in方針)。resConfig 'ja' pin は任意。
- [x] **A4 secrets/keystore テンプレ整備**: `keystore.properties.template` / `secrets` 必要キー一覧→ **local.properties.template / keystore.properties.template 作成**(全 secret キー+鍵作成手順を明記)。
- [x] **A5 Play スクショ生成**: → 7枚(home/history/settings/record/paywall/weight_premium/friends)を density393 で 1080x2400(Play phone 規格)書き出し=`tools/parity/proofs/play_screenshots/`。
- [x] **A6 ローカライズ監査**: 英語/デバッグ文字列の混入チェック・ja_JP のみ確認 → values-xx 無し(単一ロケール)・strings.xml に英語混入なし・app_name='GO エクササイズ'。clean。
- [x] **A7 semantic_diff 全画面拡張** → harness を scroll/html-unescape 対応に拡張、settings/home で実行。**実検出**: ①招待プロンプト全角→半角是正済 ②バックアップ補足文言差=Android 意図的詳細化で許容 ③**a11y ギャップ**: Android の Canvas 描画(週ストリップ ◎ マーカー等)が accessibility に未露出(iOS は露出)=TalkBack パリティの品質課題(出荷ブロッカーではない)。残画面も同手順で実行可。
- [x] **A8 データセーフティ申告 下書き**: → `docs/PLAY_DATA_SAFETY.md` 作成(収集データ種別/共有範囲/暗号化/削除/権限用途を実装事実から記述)。提出は要ユーザー。
- [x] **A9 アイコン/アダプティブ/スプラッシュ資産の有無確認**と不足補完 → **launcher 未設定だった(既定ロボット)を発見・是正**: 猫アイコン(iOS AppIcon を flood-fill 透過)で adaptive icon(fg+cream bg)+legacy 5密度+round 生成、manifest に icon/roundIcon 追記。App info で表示確認。

## B. ユーザーしかできない(外部アカウント/実機/コンソール)
- [~] **B1 アップロード鍵 + Play App Signing** — **鍵生成・署名 AAB・SHA は完了(私)**: `app-android/keystore/upload-keystore.jks`(gitignore済)/ 署名 AAB=`app/build/outputs/bundle/release/app-release.aab`/ SHA-1=CC:DE:FC:9C:D3:19:7D:34:41:3B:4B:2B:78:B1:06:2E:F9:32:4B:5A / SHA-256=71:8B:DA:98:5F:7D:95:B6:4A:1C:14:52:11:E8:FE:FE:05:2D:FB:1C:72:AE:7D:2F:44:21:66:A5:FE:C0:39:26。**残=Play App Signing 登録 + AAB アップロード(あなた)**。鍵パスワードは keystore.properties(ローカル)に保存・要バックアップ。
- [ ] **B2 Play Console**: アプリ作成・データセーフティ提出・コンテンツレーティング・ストア掲載(説明/スクショ)・価格/配信国(日本)・段階公開・提出。
- [ ] **B3 Google Cloud**: アプリ SHA-1/256 登録(**SHA は B1 で算出済→貼るだけ**) + `GOOGLE_WEB_CLIENT_ID`(Google ネイティブサインイン)。
- [ ] **B4 Supabase**: Android 用 Apple Web/PKCE redirect URL allowlist・Google provider 設定確認。
- [ ] **B5 Play 課金商品作成**: `com.goexercise.app.premium_monthly` / `_yearly`(コード側 `PremiumRepository.kt` と一致させる)。
- [ ] **B6 gating 本番 ON**: `FRIENDS_APPLE_LINK_ENABLED` / `FRIENDS_GOOGLE_LINK_ENABLED` / `PLAY_BILLING_ENABLED` を secrets で true(実インフラ完成後)。
- [ ] **B7 実 Android 端末 E2E**: 機種変更(同 Apple/Google ID で記録復元)・実課金購入/復元・通知発火・QR カメラ。
- [ ] **B8 本番 Supabase テストデータ掃除**: §6 で残した けんじ/cheers/friendship。
- [~] **B9 Codex 2LLM 監査** — **headless では codex がハング(CPU0%・既知 [[feedback_verification_workflow]])で完走せず**(4回試行: model誤指定1/即ハング2/`approval_policy=never`+read-onlyで diff 全読込まで進むが verdict前に要watchdog kill)。→ **対話端末か `/second-opinion` skill で実行が必要**(あなた側)。代替として本セッションで等価の敵対検証を自走実施済(トークン化のピクセル一致実証・Black→ExtraBold の iOS ソース照合・44sp 残ドリフトの明示・parity_guard --strict・346 unit green)。
- [x] **B10 privacy/terms/support 公開 URL** — **完了**: GitHub Pages 稼働中(main/docs・public repo)、Android 設定が iOS と同一 URL(`torontojapan.github.io/everyday_training/{privacy,terms,support}/`)を参照。

## C. 残存リスク・未検証領域(出荷判断の材料・2026-06-21)
> 「バグは起きないか?」への正直な回答 = **バグゼロは保証できない**。下記を出荷前に踏まえること。

### 強く担保済み(バグが出にくい)
- 再発バグの**全11型**([[gotcha_recurring_bug_classes]])を Android で防御確認 + 回帰テスト。
- ロジック **346 unit tests green**、RLS 状態機械(報酬捏造防止)、`parity_guard --strict`(見た目ドリフトの構造封鎖)。
- R8(難読化)実行時 smoke で主要 Supabase 経路の健全性を確認。
- iOS↔Android データ互換(記録 payload 契約・friend code)をコード/契約レベルで一致確認。

### まだ未検証=バグが残りうる(リスク順)
1. **実機が1台も未テスト**(全てエミュ+シミュ)。OEM スキン/OS 8〜15/画面/メモリ依存の**端末依存バグ**は未知。**最大リスク**。
2. **実課金・実 OAuth が end-to-end 未実施**(dev は Mock)。実 Play 課金購入/復元・実機 Apple/Google サインイン連携は未通し(B5/B3/B6 未完)。
3. **機種変更(記録引き継ぎ)が実機間で未検証**(契約一致は確認済だが実物未通し)。
4. **2LLM 敵対監査(Codex)未完走**(独立レビュー1層が欠落)。
5. **a11y ギャップ**(週ストリップ等 Canvas 描画が TalkBack 未露出)= クラッシュではない品質バグ。
6. 並行処理/低速回線/低メモリ/特定ロケール・時計の端は部分カバーのみ。

### ギャップを閉じる手段(出荷前推奨)
- **B7 実機 E2E を1周**(課金購入・OAuth・機種変更)= 最も効く。
- **段階公開**(Play internal testing → クローズドβ)で端末多様性に当てる。
- **B9 Codex 対話 or `/second-opinion`** で独立レビューを追加。
