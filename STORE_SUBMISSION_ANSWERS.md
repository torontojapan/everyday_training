# ストア提出 回答シート(Data safety / App Privacy / URL / 掲載)

> 内部メモ(**docs/ 外＝GitHub Pages では公開されません**)。Play Console / App Store Connect の
> フォームに**そのまま転記**するための回答。根拠は `docs/privacy.md`(データフロー正本)と実コード。
> 最終確認: 2026-06-04。出荷時にバージョン等は再確認すること。

## 0. 大前提(両OS共通の事実)

- 運動記録・体重・体調(生理日)・通知設定・アプリ内設定は **端末内のみ**(iOS=SwiftData / Android=Room+DataStore)。**外部送信なし**。
- **友達機能を使った場合に限り**、共有プロフィール等が匿名認証の外部DB(Supabase)に保存・他ユーザーへ表示される(**オプトイン**。友達タブを開くだけでは保存されない)。
- 任意で Apple / Google 連携(バックアップ/復元)= プロバイダ識別子を保持(復元目的のみ・広告非利用・友達非共有)。
- **広告なし・行動トラッキングなし**。
- **分析(TelemetryDeck)= 匿名・既定ON・設定でオプトアウト可**(2026-06-04 決定)。個人特定なし・IDFA不使用・第三者販売なし。8シグナル(app_open/record_created/view_paywall 等)+ category/product のみ。**実送信は App ID 設定 + release 時のみ**(iOS Info.plist `TelemetryDeckAppID` / Android `TELEMETRYDECK_APP_ID`)。⚠️ **App ID を実際に設定して出荷する場合のみ**下記の分析申告を有効にする(未設定で出荷=ゼロ収集なら分析行は不要)。
- 課金は Google Play / App Store の標準課金。アプリ自身は決済情報を収集しない。

---

## 1. Google Play — Data safety フォーム

### ゲート質問
- **このアプリはユーザーデータを収集または共有しますか?** → **はい**(友達機能利用時のみ)。
- **転送中のデータは暗号化されますか?** → **はい**(Supabase への通信は HTTPS/TLS)。
- **ユーザーはデータ削除をリクエストできますか?** → **はい**(アプリ内「アカウントを削除」+ 削除URL。下記 §3)。
- **Play の「ファミリー」ポリシー対象(子ども向け)?** → **いいえ**。

### 収集/共有するデータ(友達機能利用時のみ・すべて任意)
「共有」= 友達(他ユーザー)に表示される項目。「収集」= Supabase に保存される項目。

| データ種別(Google分類) | 該当項目 | 収集 | 共有 | 目的 | 任意 |
|---|---|---|---|---|---|
| Personal info → Name | 表示名(ニックネーム)・ユーザー名 | ✅ | ✅ | アプリ機能(友達検索・表示) | 任意 |
| App activity → Other user-generated content | 共有プロフィール: 連続記録・累計達成日数・今日の達成/カテゴリ名/(設定ON時)種目名・週間達成状況・週/月の運動時間・装飾ランク・猫の種類 | ✅ | ✅ | アプリ機能(友達一覧・週間ランキング) | 任意 |
| App activity → App interactions | 応援(cheer)の送信 | ✅ | ✅(送信先のみ) | アプリ機能(友達への応援) | 任意 |
| Device or other IDs | 匿名認証ID / (連携時)Apple・Google の識別子 | ✅ | ❌ | アプリ機能・アカウント管理(復元) | 任意 |
| App activity → App interactions(分析) | 匿名イベント(app_open/record_created/view_paywall 等)+ category/product | ✅ | ❌(TelemetryDeck=処理者) | **分析(Analytics)** | 任意(設定でオプトアウト可) |

> **分析の「共有」扱い**: TelemetryDeck は委託処理者(processor)で、自社目的に再利用しないため Google 定義では「共有(Share)」に当たらず「収集(Collect)」のみ。匿名・IDFA不使用・既定ONだが設定でオプトアウト可。**App ID を設定せず出荷する場合はこの行を外す**(ゼロ収集)。
>
> **判断メモ(要確認)**: 共有する「連続記録/カテゴリ名」等は運動の要約だが、生の健康指標(体重・心拍・歩数)は一切共有しないため **App activity** に分類した。Google の「Health and fitness」は健康トラッカー由来の生データ想定で、本アプリの共有はゲーミフィケーション要約のため非該当と判断。審査で指摘されれば「Health and fitness → Fitness info」へ移せる(体重は依然ローカルのみ)。

### 収集**しない**(申告不要・ローカルのみ)
運動記録の詳細(回数/セット/メモ)・体重・体調(生理日)・通知設定・テーマ等。位置情報・連絡先・写真・ファイル・通話/SMS・閲覧履歴・**財務情報(決済はGoogle Play側)** はいずれも収集なし。

---

## 2. Apple — App Privacy(App Store Connect)

ラベル方針: **「データは収集されません」ではなく**、友達利用時の収集を申告。トラッキングは無し。

| Apple カテゴリ | 該当項目 | トラッキング | リンク(本人紐付) | 目的 |
|---|---|---|---|---|
| User Content → Other User Content | 表示名・ユーザー名・共有プロフィール(連続記録等)・応援 | しない | される(アカウントに紐付) | App Functionality |
| Identifiers → User ID | 匿名認証ID / (連携時)Apple・Google 識別子 | しない | される | App Functionality / Account |
| Usage Data → Product Interaction(分析) | 匿名イベント(app_open 等)+ category/product | しない | **されない(リンクなし)** | Analytics |

- **Used to Track You: なし**(他社データと突合した広告/トラッキングをしない)。
- 健康データ(体重・体調・運動詳細)は端末内のみ=**収集に含めない**。
- Apple「メールを非公開」利用時もメールは収集・共有しない。
- 分析(Usage Data)= 匿名・ユーザーID非リンク・トラッキングなし・設定でオプトアウト可。**App ID を設定せず出荷する場合はこの行を外す**。

---

## 3. アカウント削除 URL / プライバシー URL(審査必須欄)

- 内容は準備済: `docs/account-deletion.md`(アプリ内導線 + 非利用者向けフォーム + 削除/保持データ表)、`docs/privacy.md`。
- **公開手当て(あなたの操作)**: GitHub リポジトリ `torontojapan/everyday_training` の **Settings → Pages → Source = `main` ブランチ / `/docs` フォルダ** を有効化。
- 公開後 URL(permalink: pretty):
  - アカウント削除: `https://torontojapan.github.io/everyday_training/account-deletion/`
  - プライバシー: `https://torontojapan.github.io/everyday_training/privacy/`
  - サポート: `https://torontojapan.github.io/everyday_training/support/`
- これらを **Play Console(アプリのアクセス/データ削除欄・プライバシーURL)** と **ASC(App Privacy のプライバシーポリシーURL・アカウント削除導線メモ)** に登録。
- ⚠️ 公開直後に各 URL を実際に開いて 200 で表示されることを確認(Pages 反映に数分)。独自ドメイン(goexercise.app)を使う場合は docs/ に CNAME 追加 + DNS 設定。

---

## 4. ストア掲載(要点)

- **アプリ名**: GO エクササイズ(GO Exercise)。**applicationId/bundle**: `com.goexercise.app`。**配信地域**: 日本のみ。
- **カテゴリ**: 健康&フィットネス。**コンテンツレーティング**: 全年齢相当(暴力/性的表現なし)。Play は質問票、ASC は 4+。
- **短い説明 / サブタイトル**: 「猫と一緒に、毎日1分から運動を習慣化」。
- **キービジュアル/説明の素材**: `docs/index.md` の特長リスト(1分でOK / 連続記録+週間達成率 / 自動休養日 / 7状態の猫 / ウィジェット / やさしい通知)+ 友達(友達コード/QR/週間ランキング/応援)+ プレミアム(体重・周期・レポート、14日無料)。
- **審査メモ(両ストア)**: ①友達機能のデモ手順(友達コード追加→申請→承認→応援→ランキング)②**アカウント削除導線**(友達タブ→アカウントを削除)= Apple 5.1.1(v) / Google データ削除要件 ③サブスク開示(価格/自動更新/トライアル後課金/解約=各ストア定期購入)はアプリ内実装済。
- **スクリーンショット**: iOS=実機、Android=emulator 取得済の友達/ランキング/ホーム/体重画面を流用可。

---

## 5. 両ストア整合チェック(提出前)

- [ ] Data safety(Google)と App Privacy(Apple)で**同じデータ実態**を申告(上記表が単一の正本)。
- [ ] プライバシーURL・削除URL が両ストアで同一かつ live。
- [ ] `docs/index.md`/`privacy.md`/`account-deletion.md` の記述が相互に矛盾しない(2026-06-04 に index.md の旧「外部送信なし/3rd party SDKなし」を是正済)。
- [ ] **TelemetryDeck App ID を設定して出荷する**なら分析行(両表)を有効に / 設定せず出荷なら分析行を外す(ゼロ収集)。分析は匿名・既定ON・設定でオプトアウト可。
