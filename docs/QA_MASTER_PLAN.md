# QA マスター計画(GOExercise iOS / Android / Supabase)— 全機能・漏れなし

> 目的: パリティ収束後に**アプリ全機能を厳密 QA**する。「気合い」でなく**全機能インベントリ×テスト次元の網羅マトリクス**で漏れを構造的に防ぐ。
> 実行手順の詳細(自動テスト土台・3面・再発バグ型)= `docs/AUDIT_RUNBOOK.md`(Phase 0→D)/ 端末手順 = `docs/DEVICE_QA_RUNBOOK.md` / 再現ハーネス = memory [[audit_harness]]。
> パリティ専用ゲート = `PARITY_100_PLAN.md` + `tools/parity/parity_guard.py`。
> 最終更新: 2026-06-21。

## 使い方
- 下の **A. 機能インベントリ**の各行 × **テスト次元(機能/エッジ/堅牢/パリティ/バックエンド)** を1セルずつ消化し、各セルに「結果 + 証跡(本数/スクショ/ログ)」を残す。
- 証跡無しに ✅ を付けない(CLAUDE.md ★7)。パリティセルは density393 + iOS golden + **要素値突合**(目視でなく size/weight/色/文言)。
- 各機能で必ず **正常系 / 空状態 / エラー系 / 境界値** の4区分を確認。

---
## Phase 0 — 自動テスト土台(ここが緑でなければ以降無意味)
- [ ] iOS unit(`GOExerciseTests`)全 green・本数を xcresult summary で確定(`AUDIT_RUNBOOK` Phase 0)。
- [ ] Android unit(`:app:testDebugUnitTest`)全 green・本数確定(`AppTypeParityTest` 含む)。
- [ ] `tools/parity/parity_guard.py`(新規ドリフト 0)/ 目標 `--strict`(生値 0)。
- [ ] iOS Release 署名コンパイル成功(Archive 安全・`CLAUDE.md §3`)/ xcodegen 後 Info.plist 手動キー不変。
- [ ] Supabase 本番スキーマに必要列が存在(weekly_statuses 等・`CLAUDE.md §4`)。

## A. 機能インベントリ(画面×状態 — 全数。各行を全テスト次元で)
### 1. オンボーディング
- [ ] 猫ピッカー(11種・ロック/解放ゲート・大プレビュー・選択リング)/ 招待コード入力 / バックアップ step(Apple / Google / あとで)/ もどる導線。
### 2. ホーム
- [ ] 週ストリップ 6状態(達成◎/休/×/未来-/今日・/救済○)/ 連続バッジ「昨日まで」基準 / 称号バッジ(全11段)/ 今日の状態チップ(達成済/回復日/残り時間)。
- [ ] 演出: 節目祝福(記録後のみ)/ revive オーバーレイ+復活ポップ / rankup チップ / 紙吹雪 / 紹介スター行 / ⭐10 breed-unlock。
- [ ] CTA(記録する/もう一種目/ただいま記録[復帰日])/ 復帰ウェルカムカード / 猫メッセージプール。
### 3. 記録入力 → 記録完了
- [ ] カテゴリ(筋トレ/有酸素/ヨガ/ストレッチ)/ 種目名+サジェスト / 時間・回数・セット picker / 種目メモ / 種目追加・セット追加 / 今日の体重 inline / メモ / 「今日は生理日」(周期ON時)。
- [ ] 保存 → 完了画面(ヒーロー連続 / praise / 今日のサマリー / もう一種目 / ホームへ戻る / 装飾)/ 保存で節目発火。
### 4. 履歴
- [ ] 月カレンダー(状態色+今日+未来淡色)/ 凡例 / 月ナビ / 保険チケット節(展開・使用フロー)。
- [ ] Weekly ハイライト / Monthly レビュー / All-time 統計(各シェアシート)/ 生理日入力(周期ON)。
- [ ] 日詳細シート 6状態(記録/空/休/救済/未来/達成)。
### 5. 体重
- [ ] 非課金 paywall/teaser + 自動提示シート + 6h cooldown / プレミアム HeroCard(最新+日付+今週差+達成リング+猫)。
- [ ] 目標設定 / BMI ストリップ(身長)/ 記録(対象日 今日/昨日/カスタム)/ レポート(今週・平均)。
- [ ] 推移チャート(期間セグメント1週/1月/3月/半年/全期間・折れ線+破線トレンド+Y/X軸・周期オーバーレイ)/ 履歴リスト / 数値入力ダイアログ。
### 6. 友達
- [ ] welcome(未サインイン)/ connecting「準備しています…」/ コード画面(ヘッダ/コード/コピー/シェア/QR)/ 表示名プロンプト / アプリ共有カード。
- [ ] 申請受信(承認/拒否)/ 友達公園グリッド(今日達成=大)/ 友達詳細(ヒーロー/今日の運動/週ストリップ/統計タイル/応援送信+プリセット/解除)。
- [ ] 応援 受信トースト / 追加シート(コード/QR読取/ユーザー名検索)/ ランキング(今週・今月セグメント・順位ルール・自分順位・行・メダル)。
- [ ] アカウント連携(Apple/Google・切替衝突・復元)/ バックアップカード / アカウント削除 / エラーバナー / 通知権限バナー。
### 7. 設定
- [ ] メイン(アカウント&バックアップ / プレミアム&特典 / アプリ設定)。
- [ ] サブ: カスタマイズ(テーマ/猫ピッカー/振動)/ 記録と共有(周期/休養ルール/友達共有)/ 通知(3分割 OFF/1日1回/2回・時刻・性格・権限・保存)/ データ&プライバシー(書出/全削除/分析opt-out)/ 情報(意見/版/サブスク管理/プライバシー/規約/サポート)/ プレミアム特典+称号一覧。
- [ ] 紹介(招待/星数/後入力コード)/ サインインボタン。
### 8. ウィジェット / 通知 / 課金
- [ ] StreakWidget(small)3状態 + medium / Live Activity(あれば)。
- [ ] 通知スケジュール(1回/2回)・性格バリアント・権限フロー・発火時刻。
- [ ] 課金: paywall(weight/general 文脈)・月額/年額購入・復元・トライアル・cooldown。

## B. 横断ロジック・境界値(再発バグ型は memory [[gotcha_recurring_bug_classes]] と必ず照合)
- [ ] 連続: 「昨日まで」基準 / 自動休養(週2)/ 保険チケット(無料月1・プレミアム月4・紹介ボーナス・**当月allowance**・月境界)/ ×リセット / never-miss-twice。
- [ ] 月境界 UTC↔ローカル / 口座スコープ / UUID 大小(friendships_check)/ rescuedDates 受け渡し。
- [ ] 紹介: confirm pop / freeze ボーナス / ⭐10 解放 / seen 追跡 / RLS trigger。
- [ ] 週次・月次集計の OS 間一致(distinct 記録日)/ 演出は記録後のみ。
- [ ] データ: 破損シード耐性 / SwiftData↔Room マイグレーション / decode フォールバック。

## C. 堅牢性(実機/エミュ)
- [ ] プロセス死→復元 / 回転(縦↔横)/ ネット断→welcome・error degrade / 低速・タイムアウト / オフライン→オンライン復帰。
- [ ] 空状態(0記録/0友達/体重なし)/ 大量データ(365日)/ 権限拒否(通知・カメラQR)/ 低ストレージ / ロケール ja_JP・時計変更。

## D. クロスプラットフォーム・パリティ(本命=semantic 差分)
- [ ] 全画面×状態を density393 + iOS golden で **要素値突合**(size/weight/色トークン/文言/順序/アイコン種別/空状態)。
- [ ] semantic UIツリー差分ハーネス(iOS snapshot ツリー × Android semantics ツリー)を全画面 CI ゲート化。SSIM は補助(構造/レイアウトのみ・微小タイポは検出不可と明記)。
- [ ] `parity_guard.py --strict`(生 fontSize/Color/Black ゼロ)。

## E. バックエンド(Supabase)
- [ ] RLS 各表(profiles/friendships/friend_requests/cheers/referrals/user_records/weekly_statuses)/ 匿名サインイン / on delete cascade / orphan cron / 必要列存在 / upsert(updated_at は送らない=DB default)。

## F. リリース / ストア
- [ ] iOS: Archive(xcodegen Info.plist 手動キー保持)/ ASC ビルド番号 / 署名 Release コンパイル / プライバシーマニフェスト / 暗号化申告。
- [ ] Android: Play 署名 / 最低 SDK / 課金プロダクト / データ安全性フォーム。
- [ ] 分析(TelemetryDeck 匿名・opt-out)/ クラッシュ(Apple 標準のみ)。

## 合格基準(Definition of Done)
1. Phase 0 全緑(本数提示)。
2. A 全機能セルが 正常/空/エラー/境界 の4区分で確認済み・証跡添付。
3. D で全画面 semantic 差分 0(要素値完全一致)+ `parity_guard --strict` 緑。
4. B の再発バグ型を全件 grep 照合し回帰テスト追加。
5. 2LLM(Claude 並列 + Codex)で**差分画像とログ**に対し敵対監査 → correct 収束。
