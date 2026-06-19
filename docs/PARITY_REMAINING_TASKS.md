# Android↔iOS パリティ 残タスク・バックログ(動く正本)

> **これが同期残タスクの唯一の動く正本。** 体系立てて 1 項目ずつ消化する。
> 関連: 方針=`PARITY_100_PLAN.md` / 旧履歴=`android_ios_parity_tracker.md` / 規約=`CLAUDE.md`。
> 最終更新: 2026-06-19。

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
- [ ] **体重 premium チャート展開**(推移=Canvas 折れ線+破線トレンド+期間チップ[1週/1月/3月/半年/全期間])を golden 横並び
- [ ] **日詳細シート 全6状態**(記録/空/休/救済/未来/達成)— カレンダー日タップ。iOS=`testCaptureSubScreens`(sub_day_detail)
- [ ] **生理日入力画面**(周期 ON)— 履歴の生理日行→入力画面。iOS=sub_menstrual
- [ ] **オンボーディング step2**(バックアップ)— step1 はほぼ一致確認済、step2 未照合
- [ ] **ウィジェット StreakWidget** — instrumented render→PNG で iOS ウィジェットと照合

### 1-B. Mock-force ビルドが要る(友達/ランキング/設定サインイン)
- [x] 友達ヘッダ(@username 是正)/ 申請/リスト — `proofs/friends_*`
- [x] ランキング 今週(構造)— `proofs/ranking_*`
- [x] 設定 削除/招待行(プロフィール確立後)— `proofs/settings_*_with_profile`
- [ ] **ランキング 今月セグメント** — ranking→今月タップ。iOS=`testCaptureRankingStates`(rank_monthly)
- [ ] **友達詳細**(hero グラデアバター/名前フォント/統計タイル/cheer 送信)— `--mock-open-friend-detail`
- [ ] **友達追加シート**(見出し/申請を送る/QR/閉じる)— `--mock-open-friend-add`
- [ ] **友達 welcome / 空状態**(通常到達不可=source 照合で可)
- [ ] **設定サブページ 6種**(density393 横並び):
  - [ ] カスタマイズ(ドリルイン行=テーマ/猫ピッカー)※STRUCTURAL 残あり
  - [ ] 記録と共有(友達共有トグル `includeExerciseDetail`)
  - [ ] 通知設定(権限バナー/3分割セグメント OFF|1日1回|1日2回/時刻チップ行/性格ピッカー)※STRUCTURAL 残あり
  - [ ] データ&プライバシー(プレーン行+footer caption)※STRUCTURAL 残あり
  - [ ] 情報・サポート(外部リンク4・非ナビ)
  - [ ] プレミアム特典・称号一覧

---
## 2. ☐ 未撮影/特殊状態(専用シード or フロー)
- [x] ホーム紹介スター行(`debug-stars?n=5`)— `proofs/home_referral_*`
- [x] 節目ダイアログ(`--seed-streak 9/29 --end-offset 1`→記録→ホーム復帰)— 炎廃止確認
- [x] rescue-use 画面 — `proofs/rescue_use_*`
- [ ] **ホーム revive overlay**(`--seed-streak 17 --skip-recent 3` で×日→rescue 適用→streak 復活→RankCelebration)
- [ ] **⭐10 breed-unlock ダイアログ**(`debug-stars?n=10`)
- [ ] **rankup チップ**(称号が上がる瞬間)
- [ ] **エラーバナー**(友達=通信エラー発火時)
- [ ] **権限拒否バナー**(通知設定=権限拒否時)

---
## 3. ☐ 要判断(ユーザー確認が要る設計差)
- [ ] **初回 paywall 自動提示**: iOS=weight タブ初回に paywall シート自動提示(6h cooldown)/ Android=teaser のみ。
  Android paywall は別ルート(全画面)で自動 navigate はループ footgun → **シート型 paywall+cooldown 設計**が前提。実装可否を要判断。
- [ ] **設定 STRUCTURAL 残**(tracker §セッション7): カスタマイズ=ドリルイン化 / データ&プライバシー=プレーン行+caption 外出し /
  通知=3分割セグメント等。iOS Form 構造への寄せ。規模大。

---
## 4. ✅ 今セッション(2026-06-19)是正済の実バグ(参考・再発防止)
1. シード JSON エスケープ破損(全シード無効化)2. 週ストリップ◎マーカー字形 3. 友達@username 自動生成欠落
4. 共有カード グラデ色(2→3stop)+連続既定 ocean+ピッカー位置 5. ハイライトピッカー位置 6. crown(6箇所:paywall/設定×2/体重/履歴/節目バッジ≥100)7. 体重 HeroCard 達成リング+猫+日付の欠落 8. 達成演出の炎(ユーザー指摘)9. 絵文字スイープ(❄️🔘⚪🤝🗑)。
**根本原因の仕組み化**: density393(幅一致)+ golden 横並び を全画面で徹底(旧 411dp/コード照合が見逃しの主因)。

---
## 5. ★ パリティ完了後: Android 単独 包括 QA(ユーザー指示・前提=本書 全☑)
全パリティ ☑ 後に Android 単体の包括 QA(機能/ロジック/視覚/回帰/堅牢性)。手順=memory [[android_comprehensive_qa_checkpoint]]。
