# Google Play データセーフティ申告 下書き(A8)

> Play Console「データセーフティ」フォームの回答下書き。実装(権限/Supabase テーブル/TelemetryDeck/
> アカウント削除)から作成。**提出は要ユーザー(B2)**。最終確認は実際のデータフローと照合のこと。

## 前提(実装事実)
- 既定は**匿名アカウント**(メール/パスワード不要)。クラウドバックアップ・友達は**任意オプトイン**。
- ローカル保存=Room(記録/体重/体調・周期)。クラウド=Supabase(`user_records`/`profiles`/`friendships`/`cheers`/`referrals`)。
- 分析=TelemetryDeck(匿名・opt-out 可)。クラッシュ=Play 標準(別途 SDK なし)。
- 通信は HTTPS、RLS で本人行のみアクセス。**アプリ内アカウント削除導線あり**(`AccountDeletionFlow`)。

## 1. データ収集の有無 → **はい(収集する)**

| データ種別 | 収集 | 共有 | 任意/必須 | 目的 | 備考 |
|---|---|---|---|---|---|
| 健康とフィットネス(運動記録・体重・体調/生理周期) | ○ | △友達のみ | 任意 | アプリ機能(記録・連続・グラフ)・バックアップ | **機微情報**。クラウド同期はオプトイン。友達共有は本人が選んだ友達にのみ(回数/時間/週達成等) |
| 個人情報: 名前(表示名)・ユーザー名 | ○ | △友達のみ | 任意 | 友達機能の表示 | 連携時のみ。匿名運用なら未収集 |
| アプリ内メッセージ(応援コメント) | ○ | △友達のみ | 任意 | 友達への応援 | |
| ID: アカウント識別子(Supabase user_id・friend code) | ○ | × | 任意 | バックアップ・友達照合 | 匿名 ID。メールは Apple/Google 連携時に provider 管理(アプリは保存しない設計) |
| アプリアクティビティ/診断: 匿名分析(TelemetryDeck) | ○ | 第三者(TelemetryDeck) | 任意(opt-out) | 利用状況の把握 | 匿名・端末横断追跡なし |
| 写真/カメラ | × 保存しない | × | 任意 | **QR 読取のみ**(画像は保存・送信しない) | CAMERA 権限は QR スキャン用途 |

## 2. セキュリティ慣行
- [x] 転送中の暗号化(HTTPS / Supabase TLS)。
- [x] ユーザーはデータ削除をリクエストできる(**アプリ内アカウント削除**)。
- [x] 行レベルセキュリティ(RLS)で本人データのみアクセス。
- 第三者共有: 友達(ユーザーが選択)+ 分析(TelemetryDeck・匿名)のみ。広告なし・データ販売なし。

## 3. データ削除
- アプリ内: 設定 → アカウント削除(`on delete cascade` で関連行も削除)+ 全記録削除。
- 孤児行は `supabase/cron/cleanup_orphans.sql` で定期掃除。

## 4. 権限と用途(マニフェスト実態)
- INTERNET / ACCESS_NETWORK_STATE: Supabase 通信。
- POST_NOTIFICATIONS: 記録リマインダー。
- CAMERA: 友達 QR コード読取(画像非保存)。
- RECEIVE_BOOT_COMPLETED / FOREGROUND_SERVICE / WAKE_LOCK: 通知スケジュール再設定。
- com.android.vending.BILLING: GO プレミアム購読。
- 注: `allowBackup=false`(健康データの Google 自動バックアップを無効化・自社オプトインバックアップに一本化)。
