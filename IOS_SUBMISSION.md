# iOS 提出準備シート(App Store Connect 転記用)

> 内部メモ(非公開)。iOS 先行ローンチ([[release-strategy-dual-launch]] 2026-06-04 転換)の提出材料。
> **B-2 復元E2E green が提出の前提**(本シートは B-2 以外を先行準備)。最終確認 2026-06-04。

## 0. 基本情報
- **App 名**: GO エクササイズ(GO Exercise) / **Bundle**: `com.goexercise.app`(+ widget `com.goexercise.app.widget`)
- **App Store 数値ID**: `6774551663` / **バージョン**: 1.0 / **配信地域**: 日本のみ
- **カテゴリ**: ヘルスケア/フィットネス / **年齢制限**: 4+
- **サブスク商品(ASC 設定済)**: `premium_monthly`(¥500/月)/ `premium_yearly`(¥3,800/年)・14日無料トライアル
- **公開URL(live)**: プライバシー `https://torontojapan.github.io/everyday_training/privacy/` / アカウント削除 `https://torontojapan.github.io/everyday_training/account-deletion/` / サポート `.../support/`
- **デベロッパー連絡先(Apple側も統一推奨)**: `neko.neko.network01@gmail.com`
- **分析**: iOS v1 は **オフ**(Info.plist `TelemetryDeckAppID`=空=収集なし)。iOS の匿名分析+opt-out は v1.1 fast-follow。

---

## 1. App Review Notes(審査メモ)— ASC「App Review 情報」に貼る

### 日本語
```
■ ログイン不要
本アプリは運動習慣化アプリです。運動・体重などの記録は端末内のみに保存し、ログイン不要で全機能の基本部分を利用できます。

■ 友達機能(任意・匿名)
「友達」タブ →「友達とつながる」で、匿名アカウント(メール/パスワード不要)が作成され、6桁の友達コードが表示されます。友達コードまたはQRを相手と交換して申請・承認すると、おたがいの連続記録を見て応援(スタンプ)し合えます。Apple/Android 双方の端末から同じ友達としてつながる設計です。

■ Sign in with Apple は「任意のバックアップ/復元」専用
本アプリのSign in with Appleは、機種変更時に友達データを引き継ぐための任意のバックアップ/復元にのみ使用します(ログイン必須ではありません)。

■ アカウント削除(ガイドライン 5.1.1(v))
「友達」タブ →「アカウントを削除」→ 確認ダイアログで「削除」。これでサーバー上の共有プロフィール・友達関係・応援履歴・認証アカウント・全セッションが即時に完全削除されます。Webからの削除案内: https://torontojapan.github.io/everyday_training/account-deletion/

■ サブスクリプション
プレミアム(体重グラフ・周期・レポート等)は月額¥500/年額¥3,800、14日無料トライアル。自動更新・解約はApp Storeの定期購入管理から。ペイウォールに価格/周期/自動更新/トライアル後課金/解約方法を明記。

■ 友達フローの確認方法
2台目の端末(または2つ目の匿名アカウント)で表示される友達コードを相手側に入力すると申請→承認の流れを確認できます。テスト用の常設友達コードが必要な場合はお知らせください。
```

### English (reviewer may not read JP)
```
■ No login required
A workout-habit app. Workout/weight data is stored on-device only; the core app works without any login.

■ Friends (optional, anonymous)
Friends tab → "Connect with friends" creates an ANONYMOUS account (no email/password) and shows a 6-digit friend code. Exchanging codes/QR and accepting requests lets friends see each other's streaks and send cheer stickers. Works across iOS and Android as the same friend.

■ Sign in with Apple = optional backup/restore only
Sign in with Apple is used ONLY for optional backup/restore of friend data on device change. It is NOT required to use the app.

■ Account deletion (Guideline 5.1.1(v))
Friends tab → "Delete account" → confirm. This immediately and permanently deletes the server-side shared profile, friendships, cheers, the auth account, and all sessions. Web info: https://torontojapan.github.io/everyday_training/account-deletion/

■ Subscriptions
Premium (weight charts, cycle overlay, reports) is ¥500/mo or ¥3,800/yr with a 14-day free trial. Auto-renew; cancel via App Store subscriptions. The paywall discloses price/period/auto-renew/post-trial billing/how to cancel.
```

---

## 2. App Privacy(ASC「App のプライバシー」)回答 — iOS v1(分析オフ)

ゲート: **「データを収集しています」**(友達利用時のみ)。トラッキングは **なし**。

| Apple カテゴリ | 項目 | トラッキング | リンク(本人紐付) | 目的 |
|---|---|---|---|---|
| User Content → その他のユーザーコンテンツ | 表示名・ユーザー名・共有プロフィール(連続記録/週次達成/今日のカテゴリ/相棒(猫・犬)の種類/応援) | しない | する | App 機能 |
| Identifiers → ユーザーID | 匿名認証ID /(連携時)Apple識別子 | しない | する | App 機能 / アカウント |

- **Used to Track You: なし**。
- 健康データ(体重・体調・運動詳細)は端末内のみ=**収集に含めない**。
- 「メールを非公開」利用時もメールは収集・共有しない。
- **分析(Usage Data)は iOS v1 では申告不要**(App ID 未設定=収集ゼロ)。v1.1 で分析を入れる際に「Usage Data → Product Interaction(リンクなし/トラッキングなし)」を追加。

---

## 3. ASC 提出チェックリスト
- [ ] **B-2 復元(Sign in with Apple)実機E2E green**(出荷ブロッカー)+ 削除導線の実機確認
- [ ] B-1: 実フィックス(entitlements/Info.plist)commit + LINKDBG デバッグ4ファイル revert(B-2後)
- [ ] App Privacy ラベル(上記§2)を ASC に入力
- [ ] プライバシーポリシーURL = `.../privacy/`(live)を ASC に登録
- [ ] App Review 情報に §1 の審査メモ(JP+EN)+ 必要なら連絡先・テスト手順
- [ ] サブスク(`premium_monthly`/`yearly`)が「提出可能」状態 + 価格/トライアル設定確認
- [ ] スクリーンショット(6.7"/6.5"/5.5" 等の必須サイズ。ホーム/友達/週間ランキング/体重/シェア 等)
- [ ] 掲載文(`docs/index.md` の特長を基に)・キーワード・サポートURL(`.../support/`)
- [ ] ビルド(B-2 検証済の番号)を ASC にアップロード → バージョン1.0に紐付け → 審査提出
