# Organization アカウント化（販売者名から個人名「Jun fujioka」を消す）

> 目的: App Store 公開ページの **販売元 / デベロッパ名**が個人の法的氏名「Jun fujioka」になっているのを、
> ブランド名（例: torontojapan）に置き換える。**メタデータ編集では不可**=Apple Developer の
> アカウント種別（個人 Individual → 組織 Organization）の変更が唯一の正攻法。
> 作成: 2026-06-15。1.2 の提出はこの作業と独立に先行して進める（氏名表示があっても審査は通る）。

## 何が公開表示されているか（2026-06-15 実機確認）
- 情報セクション「**販売元: Jun fujioka**」
- App プライバシー「デベロッパである "**Jun fujioka103290123341**"」
- デベロッパページ名「**Jun fujioka103290123341**」（末尾はチームID）
- ※「著作権 © 2026 torontojapan」は編集可能欄で、すでにブランド名（対応不要）。

## 前提・注意
- Organization 登録には **D-U-N-S 番号**（事業体の識別番号）が必要。**登記された事業体**が前提
  （法人。個人の屋号だけでは原則不可。会社が無ければ法人設立 or 個人事業の扱いを Apple/D&B に要確認）。
- 個人アカウントのまま **別名（DBA/屋号）を公開表示する正式手段は現在 Apple に無い**（旧機能は廃止）。
- 切替後、**既存アプリ・レビュー・ランキング・購入履歴は引き継がれる**。販売者名・デベロッパページ名が法人名に置換される。
- 所要: D-U-N-S 発行 数日〜2週間 + Apple 審査 数日〜。

## 手順
1. **D-U-N-S 番号を確認/取得**
   - Apple の D-U-N-S ルックアップ: https://developer.apple.com/enroll/duns-lookup/
   - 既に事業体があれば既存番号がヒットする場合あり。無ければ無料申請（D&B）。
   - 事業体の正式名称・住所・代表者・電話が必要。ここで登録する**法人名がそのまま販売者名候補**になる。
2. **アカウント種別の変更を申請**
   - 方法A: Apple Developer サポートに「個人→Organization へのアカウント種別変更」を依頼（下記テンプレ）。
   - 方法B: Organization アカウントを新規開設し、既存アプリを **App 転送（App Transfer）** で移管。
   - 一般には方法A（種別変更）が、アプリ/レビューを保ったまま済むので簡単。
3. 切替完了後、App Store の販売者名・デベロッパページが法人名に置換されるのを確認。

## Apple Developer サポート 申請文（コピペ用）

### 日本語
```
件名: アカウント種別の変更依頼（個人 → Organization）

お世話になります。Apple Developer Program の登録種別を「個人(Individual)」から
「組織(Organization)」へ変更したく、依頼いたします。

理由: App Store の製品ページに販売者名として個人の法的氏名が公開表示されており、
ブランド名（事業体名）での表示に変更したいためです。

- チームID: 29YX3L7B47
- 現在の登録: 個人(Individual)
- 希望する組織名（販売者名）: <事業体の正式名称>
- D-U-N-S番号: <取得済みの番号>
- 既存アプリ「GO エクササイズ（com.goexercise.app / App ID 6774551663）」と
  そのレビュー・購入履歴は引き継ぎたいです。

必要な追加書類があればご案内ください。よろしくお願いいたします。
```

### English
```
Subject: Request to change account type (Individual → Organization)

Hello, I would like to change my Apple Developer Program membership from
Individual to Organization.

Reason: My personal legal name is shown publicly as the seller name on the App Store
product page, and I want it displayed as our business/brand name instead.

- Team ID: 29YX3L7B47
- Current enrollment: Individual
- Desired organization (seller) name: <legal entity name>
- D-U-N-S number: <obtained number>
- Please retain the existing app "GO Exercise" (com.goexercise.app / App ID 6774551663),
  including its reviews and purchase history.

Let me know if any additional documents are required. Thank you.
```

## チェックリスト
- [ ] 事業体（法人）の有無を確認。無ければ設立/届出を検討
- [ ] D-U-N-S ルックアップで番号を確認/申請
- [ ] 希望する公開販売者名を確定（例: torontojapan / 正式法人名）
- [ ] Apple Developer サポートへ種別変更を申請（上記テンプレ）
- [ ] 切替後、App Store の販売元・デベロッパページ名がブランド名に変わったか確認
- [ ] App Review 連絡先（非公開だが個人情報）も必要なら事業体の連絡先に更新
