# 残タスク(完成度向上)— 2026-06-14 棚卸し

MEDIUM worklist 全6カテゴリ + 2LLM(Claude+Codex)監査是正まで完了後の残り。
凡例: 担当 [Me]=Claude が自走可 / [User]=実機・アカウント・本人判断が必要。優先 P0>P3。

## A. リリース/ローンチ(同時ローンチの本丸)
- [User] P0 **Android 公開ゲート**: 署名リリースAAB / Play Console 掲載 / **Data safety フォーム** / 新規個人アカは **20人×14日クローズドテスト**必須 / 価格・サブスク(月¥500・年¥3,800)登録。✅[Me] 下準備完了(2026-06-14, 18f0732)= **`ANDROID_SUBMISSION.md`**(掲載文 日本語/Data safety確定値/IARC/クローズドテスト手順/AABチェック)。⚠️§7 に出荷前の3決定(分析ON/OFF・version 0.1.0→1.0.0・フィーチャーグラフィック)。
- [User] P0 **Android 実機 E2E**: Google/Apple サインイン往復・課金購入/復元・通知の実発火/タップ遷移・QRスキャン・signOut の実サーバ削除。
- [User] P1 **iOS 1.1(5) 審査フォロー**: 承認→公開 / 指摘→対応。
- [User] P1 **iOS 実機/TF E2E**: サインイン #14/#15・カメラQR #8・課金 Sandbox(build5)。

## B. インフラ/ハイジーン
- ✅[Me] P0 **リポジトリを iCloud 同期外へ移動 完了(2026-06-14)**: 正本=`~/Developer/serial_training`(iCloud圏外)。symlink 案は iCloud が拒否し旧コピーを復活させたため断念→**~/Developer 正本化**(旧 Documents 重複は削除済・メモリキーは ~/Developer へ移行済)。**今後 Claude Code は ~/Developer/serial_training から開く**。
- ⏸️[Me] P1 **Codex 最終ゲート(R6)= 保留**: Android 後回し方針で自走 cron は取消。R6 は主に Android 変更の監査だったため不要に。B-3 リファクタは iOS 414 + Android 305 のテスト緑+Claude精読で担保。Android 再開時に必要なら実施。
- ✅[Me] P2 **通知スケジューラのテスト 完了(2026-06-14, e0c1ce6)**: `ReminderScheduler.apply` と `ReminderReceiver` 発火時抑制を `ReminderSchedulePlan`/`ReminderFireDecision` に純粋関数化し JVM テスト14本(schedule5+fire9)。Android unit 305 green。
- [Me] P2 **anti-resurrection ネットワーク経路テスト**: fake Supabase client harness を作り signOut 匿名削除 / deleteAccount EF を結合テスト(現状ロジックのみ単体化済)。
- [Me] P3 hiltViewModel 非推奨 import の移行(`androidx.hilt.lifecycle.viewmodel.compose`)。

## C. 視覚/挙動 QA(コード実装済・未目視)
- 🟡[Me/User] P2 視覚確認: **iOS シミュQA一部実施(2026-06-14)** — mockビルドを sim に install→seeded(monthly)起動で **ホーム描画を目視確認**(30日連続/がんばりネコ称号/週7日達成/猫/sparkles粒子=視認可・build+launch clean・クラッシュ無)。**残=transient(達成confetti・MilestoneBackdrop光帯)は記録完了インタラクション駆動で static seeded 起動では発火せず=実機/操作確認が確実**。通知の性格別文言は Reminder/NotificationMessageProvider のテストで担保済。写真保存も実機確実。

## D. 品質/プロダクト完成度(launch 後でも可)
- ✅[Me] P2 **iOS アクセシビリティ監査+小修正 完了(2026-06-14, 38f3ccf)**: 全View監査=既に高水準(EmptyStateView共有・chart/calendar/stat-tile に label・reduceMotion尊重)。実ギャップ3点を修正(体重リング%のVoiceOver読み上げ/StreakBadge明示label/友達コードの大Dynamic Typeクリップ防止)。iOS unit 414 green。Android(TalkBack)は Android 再開時。
- ✅[Me] P2 **iOS 空状態/エラー状態 = 既にほぼ網羅と確認(2026-06-14監査)**: 友達0/記録0/週ランキング0/体重<2件/BMI/月次レビュー 等すべて fallback 文言あり。新規対応不要(受信応援の履歴一覧化のみ将来の任意機能)。
- [Me] P3 依存更新(AGP/Compose/Kotlin/ライブラリ)と dead code 整理。
- [User] P3 ASO: スクショ刷新・説明文最適化(日本語)・キーワード。
- [User] P3 公開後モニタリング: TelemetryDeck/Apple/Play のクラッシュ・離脱ファネル確認。

## E. バックエンド(概ね完了・確認のみ)
- [User] P3 Play Data safety と privacy 文書の整合最終確認(iOS App Privacy は更新済)。

---
**次の一手の推奨**: B(iCloud移動=根治 / Codex R6 / 通知テスト)を私が自走 → A の Android 提出物を下準備 → 実機手番(A/C)。
