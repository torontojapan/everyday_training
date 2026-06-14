# 残タスク(完成度向上)— 2026-06-14 棚卸し

MEDIUM worklist 全6カテゴリ + 2LLM(Claude+Codex)監査是正まで完了後の残り。
凡例: 担当 [Me]=Claude が自走可 / [User]=実機・アカウント・本人判断が必要。優先 P0>P3。

## A. リリース/ローンチ(同時ローンチの本丸)
- [User] P0 **Android 公開ゲート**: 署名リリースAAB / Play Console 掲載 / **Data safety フォーム** / 新規個人アカは **20人×14日クローズドテスト**必須 / 価格・サブスク(月¥500・年¥3,800)登録。([Me] 提出メタ・Data safety 文面・スクショ枠の下準備可)
- [User] P0 **Android 実機 E2E**: Google/Apple サインイン往復・課金購入/復元・通知の実発火/タップ遷移・QRスキャン・signOut の実サーバ削除。
- [User] P1 **iOS 1.1(5) 審査フォロー**: 承認→公開 / 指摘→対応。
- [User] P1 **iOS 実機/TF E2E**: サインイン #14/#15・カメラQR #8・課金 Sandbox(build5)。

## B. インフラ/ハイジーン
- [Me/User] P0 **リポジトリを iCloud 同期外へ移動**(`~/Developer/` 等)。git 操作毎に重複ファイルが量産され main の iOS ビルドを壊しかけた根治策([[gotcha-icloud-duplicate-files]])。移動は私が実行可・承認のみ要。
- [Me] P1 **Codex 最終ゲート(R6)**: usage limit リセット後に1パス回し「correct」確定(収束済)。
- [Me] P2 **通知スケジューラのテスト**: `ReminderScheduler.apply`(quiet=夕のみ/friendDriven=全解除/count分岐)+発火時抑制を検証可能化してテスト追加。
- [Me] P2 **anti-resurrection ネットワーク経路テスト**: fake Supabase client harness を作り signOut 匿名削除 / deleteAccount EF を結合テスト(現状ロジックのみ単体化済)。
- [Me] P3 hiltViewModel 非推奨 import の移行(`androidx.hilt.lifecycle.viewmodel.compose`)。

## C. 視覚/挙動 QA(コード実装済・未目視)
- [User/Me] P2 エミュ/実機で確認: 達成 confetti・MilestoneBackdrop 光帯アニメ・通知の性格別文言・写真保存。([Me] エミュでスクショ可・transient は実機が確実)

## D. 品質/プロダクト完成度(launch 後でも可)
- [Me] P2 アクセシビリティ: TalkBack/VoiceOver ラベル・タップ領域・Dynamic Type/フォントスケール検証。
- [Me] P2 空状態/エラー状態の網羅(友達0件・記録0件・ネットワーク断時の文言)。
- [Me] P3 依存更新(AGP/Compose/Kotlin/ライブラリ)と dead code 整理。
- [User] P3 ASO: スクショ刷新・説明文最適化(日本語)・キーワード。
- [User] P3 公開後モニタリング: TelemetryDeck/Apple/Play のクラッシュ・離脱ファネル確認。

## E. バックエンド(概ね完了・確認のみ)
- [User] P3 Play Data safety と privacy 文書の整合最終確認(iOS App Privacy は更新済)。

---
**次の一手の推奨**: B(iCloud移動=根治 / Codex R6 / 通知テスト)を私が自走 → A の Android 提出物を下準備 → 実機手番(A/C)。
