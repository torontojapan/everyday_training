# Android↔iOS 100% 一致 計画(2026-06-19・ユーザー厳命)

> 目的: **二度と個別指摘を要さず、Android を iOS build 12 と完全一致**させる。
> リソース/工数は問わない。本書は「なぜズレたか(根本原因)」と「ズレ得ない仕組み」を定義する。

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
- `docs/android_ios_parity_tracker.md` の表を「全 画面×全 状態」へ拡張し、**各セルに golden 差分スコアを必須**化。
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

### ⚠️ 方法論ギャップ(次サイクルで先に直すこと)
- **emulator go_test は論理幅 411dp、iPhone 17 Pro Max は 440pt**(約6.5%狭い)。幅依存レイアウトで
  **偽の差分**が出る。実例=履歴の凡例「未達成」が Android で「未達」に切れる(両OSとも horizontalScroll で
  クリップ、幅一致なら iOS 同様に収まる)。LegendSwatch は両OSとも 11sp で**コードは一致**。
  → **幅一致 AVD(440dp 相当)を用意**してから全画面 SSIM を回すこと(でないと width-sensitive 画面が全部 FALSE FAIL)。
- SSIM 全画面値はアスペクト比差(iOS 0.460 / Android 0.450)+ 猫アート差で原理的に 0.97 に届きにくい。
  **SSIM はスクリーニング、合否は要素単位の目視**(CLAUDE.md)。home masked SSIM=0.91 だが要素照合では週ストリップ以外一致。

### 次セッションでやること
1. **幅一致 AVD を作成**(1080x2454 @ 392dpi 等で 440dp に合わせる、または iPhone を 411pt 機種に変更)。これが最優先。
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
