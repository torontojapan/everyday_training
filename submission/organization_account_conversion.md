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

## ★ 法人化しない方法（個人事業主＋屋号）= 日本での現実解
**結論: 法人(会社)を作らなくても、個人事業主の「屋号」で販売者名を出せる。**(日本の開発者の実例多数・2026/1事例含む)

手順:
1. **開業届を提出して屋号を登録** — 税務署に「個人事業の開業・廃業等届出書」を提出。**屋号欄**に公開したい名前を記載。
   これは**法人設立ではない**(無料・e-Tax可・登記不要)。既に開業届済みで屋号未記載なら屋号入りで再提出/変更。
2. **屋号で D-U-N-S 番号を取得** — 個人事業主でも取得可。**開業届の控えが登記簿の代わりの証明**として使える。
3. **Apple を Individual → Organization に変更申請** — 組織名＝屋号。書類は**開業届の控え**を提出。
   申請中「法人として確認できない」と一旦出ても、開業届で進められる実績が多い。
4. 完了後、**販売者名・デベロッパページ名が屋号に置換**される。

注意/リスク:
- Apple 公式(英語)は「legal entity・DBA不可」と書いており**建前はグレー**。ただし日本では開業届+屋号+D-U-N-S で
  通している実例が多数。地域/審査担当でブレる可能性・将来ポリシー変更の可能性はある。
- まれに「Organization 化したのに販売者名が個人名のまま」報告あり→ Apple サポートへ再依頼。
- D-U-N-S の登録情報(屋号/住所/電話)が Apple 審査と一致している必要。
- ソース: Zenn「App Storeを個人名→屋号にした話」/ けだまラボ(2026-01)/ Qiita 等。

## 前提・注意（法人で行く場合）
- Organization 登録には **D-U-N-S 番号**が必要。法人なら登記簿で証明。
- 個人アカウントのまま別名(DBA/屋号)を出す手段は無い → 上記いずれか(個人事業主 or 法人)で Organization 化が必要。
- 切替後、**既存アプリ・レビュー・ランキング・購入履歴は引き継がれる**。販売者名・デベロッパページ名が屋号/法人名に置換される。
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
