# 全体監査ランブック (GOExercise iOS / Android / Supabase)

「漏れなく厳格にテストしたい」ときの再現手順。**気合いではなくリスト**で網羅する。
各回ともクロスプラットフォーム3面(iOS / Android / Supabase backend)+ 再発バグ型を必ず含める。

要点: 単発の「テストして」が漏れる構造的理由は (1)テスト層が5段ある (2)同じ機能が3面にある
(3)再発バグ型がある の3つ。だから下記 Phase 0→D を順に回す。

---

## Phase 0 — 自動テスト土台 (deterministic・私が実行)

ここが赤なら以降は無意味。最初に全部緑にして実数で確定する。証拠(本数)を必ず貼る。

### iOS ユニット (期待: 400 passed / 0 failed)
```bash
ROOT=/Users/jun/Developer/serial_training
cd "$ROOT/app/GOExercise" && xcodegen generate      # pbxproj は gitignore(生成物)
# 新規シミュレータを作る(既存sim破損での "hung before establishing connection" 回避)
RT=$(xcrun simctl list runtimes | grep -i ios | tail -1 | grep -oE 'com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]+')
SIM=$(xcrun simctl create "QA-iPhone17Pro" "iPhone 17 Pro" "$RT")
xcodebuild test -project "$ROOT/app/GOExercise/GOExercise.xcodeproj" -scheme GOExercise \
  -destination "platform=iOS Simulator,id=$SIM" -only-testing:GOExerciseTests \
  -derivedDataPath /tmp/GOExercise-DD -resultBundlePath /tmp/ios_unit.xcresult \
  SUPABASE_HOST="" SUPABASE_ANON_KEY="" CODE_SIGNING_ALLOWED=NO
# 正本の集計は xcresult から(tail のログは並列パーティションごとの部分集計で誤読しやすい):
xcrun xcresulttool get test-results summary --path /tmp/ios_unit.xcresult | grep -E 'passedTests|failedTests|skippedTests'
```
注意: `tail` の "Test run with N tests in M suites" は**並列ランナーの1パーティション分**。
全体本数は必ず xcresult summary の `passedTests` を見る(過去にこれで「96しか走ってない」と誤認しかけた)。

### Android ユニット (期待: ~231 passed)
```bash
ROOT=/Users/jun/Developer/serial_training
find "$ROOT/app-android/app/build" -name "* [0-9].*" -delete   # iCloud重複の掃除(これがビルドを壊す)
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  "$ROOT/app-android/gradlew" -p "$ROOT/app-android" --console=plain testDebugUnitTest
# 本数: find app-android -path "*test-results/testDebugUnitTest*" -name "*.xml" | xargs grep -ho 'tests="[0-9]*"' | grep -o '[0-9]*' | awk '{s+=$1}END{print s}'
```

### Supabase RLS / trigger 回帰 (期待: S8-S11 PASS, docker不要)
```bash
ROOT=/Users/jun/Developer/serial_training
PG=/opt/homebrew/opt/postgresql@16/bin
DATA=/tmp/pgqa_$$; rm -rf "$DATA"
"$PG/initdb" -D "$DATA" -U postgres >/dev/null 2>&1
"$PG/pg_ctl" -D "$DATA" -o "-p 54399 -k /tmp" -l "$DATA/log" start; sleep 2
"$PG/psql" -h /tmp -p 54399 -U postgres -d postgres -v ON_ERROR_STOP=1 -f "$ROOT/supabase/test_referrals_trigger.sql"
"$PG/pg_ctl" -D "$DATA" stop; rm -rf "$DATA"
```
本番への適用判断(referrals_insert / user_records / cleanup_orphans 等)はユーザー手番。
使い捨て匿名アカウントでの実弾スモークは `supabase/smoke_referrals.py` 型(本番に触れる→要承認)。

---

## Phase A — 多エージェント静的監査 (named workflow)

18ドメイン × {意思↔機能(intent-compliance) / iOS↔Android パリティ / 再発バグ型6種 / テストギャップ}
を並行監査 → 所見を敵対的に再検証(false-positive除去) → マトリクス統合。

```
Workflow({ name: "goexercise-full-audit" })
```
スクリプト: `.claude/workflows/goexercise-full-audit.js`(meta.name=goexercise-full-audit)。
ドメインや intent を足すときはこのファイルの `DOMAINS` 配列を編集。
返り値: `{ baseline, counts, confirmed[], needsInfo[], gaps[], matrixMarkdown }`。

**intent-compliance** = 各操作要素について「こう押したらこうなって欲しい(SPEC正本)」→
「コード実挙動」→ match / mismatch / dead-control(死にボタン) / unclear。
intent の正本 = `docs/SPEC_iOS.md` / `specs/requirements_v1.md`。iOSがパリティ基準。

**再発バグ型6+1**(各所で必ず確認): 口座スコープ漏れ / 月境界UTC vs local / シートdismiss未acknowledge /
rescuedDates渡し忘れ / 連続×自動休養の橋渡し / UUID大小 / RLSはBEFORE trigger。
→ 詳細は memory `gotcha_recurring_bug_classes`。

---

## Phase B — Codex 独立クロスチェック (2nd LLM)

Phase A の confirmed 所見を Codex に独立検証/反証させ、Claude と Codex が correct で一致するまで往復
(確立フロー = memory `feedback_verification_workflow`)。
```bash
# codex は CPU0% でハングし得る → 必ず背景ウォッチドッグで kill 可能に。timeout/gtimeout はこのMacに無い。
which codex   # /Users/jun/.npm-global/bin/codex (codex-cli)
```
`/second-opinion` スキルも同目的(uncommitted/branch diff/commit を Codex/Gemini にレビューさせる)。

---

## Phase C — スクリーンショット監査 (実画面)

「主張どおり画面が見えるか」を必ず目視自己検証(memory `feedback_visual_selfcheck` の教訓=粒子不可視を2度指摘)。
Phase A が出す `needs-info`(実機/動的確認要)を重点的に消化。

- **iOS**: mockビルドを sim に install → 起動シードで充実状態に →
  `xcrun simctl io <udid> screenshot out.png`。深い画面遷移は XCUITest で駆動(deep-link は確認ダイアログが
  出てプログラムから閉じられない=top画面以外はUIテスト or ユーザータップ)。
  起動シード: `--seed-demo-data --seed-scenario monthly --mock-premium --mock-seed-friends --skip-onboarding`
  (オンボ確認時は `--skip-onboarding` を外す)。mockビルド= `xcodebuild ... SUPABASE_HOST="" SUPABASE_ANON_KEY=""`。
- **Android**: emulator-5554(AVD go_test, `-no-window -gpu swiftshader_indirect` 起動)に install →
  `adb shell screencap -p > out.png` / 操作は `adb shell input tap x y`(プログラムからタップ可)。
  mockビルド = local.properties の SUPABASE_HOST を空にして assembleDebug(検証後 /tmp バックアップから復元・gitignore済)。
- 撮ったら**切り出し拡大して**意図どおり描画されているか確認してから提示する。

---

## Phase D — 正本マトリクス生成 + ギャップ閉鎖

1. Phase A の `matrixMarkdown` を マトリクス成果物に反映(機能×プラットフォーム×層、各セルに担当/証拠/最終検証コミット)。
2. confirmed 所見を修正。
3. テストギャップに iOS/Android のユニット/UIテストを追加 → Phase 0 を再実行して緑を確認。
4. 実機限定セル(IAP/Sandbox・プッシュ・QRカメラ・サインイン往復・ハプティク・iOS↔Android実機バックアップ往復)は
   `docs/DEVICE_QA_RUNBOOK.md` に集約してユーザーが順に消化。

---

## 作業環境メモ (ハマりどころ)
- iOS pbxproj は gitignore(xcodegen生成)。`xcodegen generate` が Info.plist の手動キー
  (FriendsAppleLinkEnabled / TelemetryDeckAppID 等)を落とす再発バグ→ Archive前に要検証(memory `gotcha_xcodegen_infoplist_drop`)。
- iCloud同期下のため大量リネーム後に "* 2.*" 重複が湧きビルド破壊 → `find <build> -name "* [0-9].*" -delete`。
- webp変換は PIL `Image.save(p,'WEBP')`(sips非対応)。
- supabase-kt select は `select{filter{eq/gt/isIn};order(col,Order.ASCENDING)}.decodeList<>()`・Kotlinは引数ラベル不可。
- codex/重い処理は背景ウォッチドッグで(ハング対策)。
