# 友達紹介(リファラル)機能 設計

- 作成日: 2026-06-05
- 対象: GOエクササイズ(iOS / Android 共通設計、友達バックエンド=Supabase)
- 目的: 既存の friend_code を「招待コード」に流用し、双方向特典で**新規インストール(拡散)**を促す
- 関連: 友達機能([[friends_phase2_hardening]] / supabase/schema.sql)。**達成マイルストーン装飾は別スペック**(本書のスコープ外)

## 1. ゴールと非ゴール
- ゴール: 新規ユーザー獲得を、既存ユーザーの招待で促進する。外部アトリビューションSDKを使わず、プライバシー方針(最小収集・opt-in)を維持する。
- 非ゴール: ディープリンク/インストール計測SDK(Branch等)の導入。無料プレミアム日数の付与(サーバ側entitlement機構が無いため v1 では扱わない)。達成連動の装飾報酬(別機能)。

## 2. 成立モデル(ハイブリッド = A-2 アトリビューション + 新規初記録ゲート)
1. 既存ユーザーが**自分の friend_code を「招待」としてシェア**(共有シート + 一言メッセージ)。
2. 新規ユーザーがアプリをインストール → **オンボーディングで招待コードを入力(任意)**。
   - 検証: コードが実在 / 自分自身でない / 入力者が**新規アカウント**であること。
   - 記録: `referrals` に (referrer, referee, status=pending) を作成。
   - 副作用: **自動で双方を友達にする**(friendships を生成 = モデルBのネットワーク効果もここで発生)。
3. 新規ユーザーが**初めて運動を記録** → 紹介が **confirmed** に遷移。
4. 確定時に双方へ特典を付与し、**両者にポップ表示**(§5)。

## 3. 特典(Option 1 = 全部月次リセット)
フリーズ(連続記録フリーズ/旧 保険チケット)の月次上限を全員 **5枚**に統一する。

| 対象 | 特典 |
|---|---|
| 紹介者(する側) | フリーズ **+1**(今月枠・上限5)/ **星バッジ +1**(累計・無制限) |
| 新規(される側) | **ウェルカム・フリーズ +1**(今月枠・上限5) |

会計ルール:
- 月次フリーズ上限 = **5(全員共通)**。基本付与(無料=1 / プレミアム=4)は現行どおり**月次・使い切り**で不変。
- 紹介ボーナス = **今月 confirmed になった紹介数**を今月の allowance に加算(合計5を上限にクリップ)。**翌月リセット**。
- 星バッジ数 = `referrals(status=confirmed)` の件数から算出(非正規化しない)。継続紹介の唯一の永続インセンティブ。
- プレミアム保護: 紹介しなくても楽に4枚=プレミアムの価値。5枚目は紹介で稼ぐ住み分け。フリーズが月5で頭打ちのため青天井の食い合いは起きない。

## 4. データモデル(Supabase)
新テーブル `referrals`:
```
referrer_user_id uuid not null references auth.users(id) on delete cascade
referee_user_id  uuid not null references auth.users(id) on delete cascade
status           text not null default 'pending'  -- pending / confirmed
created_at       timestamptz not null default now()
confirmed_at     timestamptz
seen_by_referrer boolean not null default false   -- 紹介者ポップ表示済みフラグ(§5)
primary key (referee_user_id)                      -- 1人1紹介者(ユニーク)
```
- RLS: referee は自分が referee の行を insert 可(referrer は入力コードの所有者)。referrer/referee は自分が関与する行を select 可。confirmed への更新は §4.1 の経路でのみ。
- 星バッジは件数算出のため別カラム不要。

### 4.1 確定(confirm)判定 = 既存の profile 公開経路に相乗り
- 運動記録はローカル(SwiftData/App Group)だが、友達機能が `profiles.total_achieved_days` 等を**既に Supabase に公開**している。
- 新規ユーザーの publish で `total_achieved_days >= 1` を初めて満たした時点で、その新規の**クライアントが自分の pending 紹介を confirmed に更新**(自己の referee 行のみ更新するRLSで安全)。同時に自分のウェルカム・フリーズを反映。
- 代替/堅牢化: Edge Function or DB トリガーでサーバ確定も可能だが、v1 はクライアント確定で十分(RLSで referee 本人に限定)。

## 5. 通知(両者ポップ・push不使用)
- **新規(される側)**: 初記録の瞬間にアプリ内にいる → **その場で即ポップ**(「友達と繋がりました!ウェルカム・フリーズ +1」)。
- **紹介者(する側)**: 確定の瞬間は不在の可能性 → **次回アプリ起動時にポップ**。クライアントが起動時に `referrals where referrer=self and status=confirmed and seen_by_referrer=false` をポーリング → 表示後 `seen_by_referrer=true` に更新(「〇〇さんが参加!フリーズ +1 / 星 +1」)。
- 本アプリは friends で push 未使用の方針 → ポーリング方式が整合的(プライバシー方針にも合致)。

## 6. 不正対策
- 1人1紹介者(`referrals` の referee 主キーでユニーク)。
- 自己紹介不可(referrer ≠ referee)。
- referee は**新規アカウントのみ**(オンボーディング入力に限定。入力忘れ救済の猶予窓は §8 で検討)。
- 確定は**新規の初運動記録**が必要(幽霊インストール除外 + 質の担保)。
- 紹介者フリーズは**月5で頭打ち**(報酬の青天井を防止)。星バッジは無害なバニティのため無制限。

## 7. UI
- オンボーディング: 「招待コードをお持ちですか?」任意入力欄(スキップ可)。
- 友達/設定: 「友達を招待」共有ボタン(friend_code + 文面を共有シートへ)。自分の**星バッジ数**を表示。
- 確定ポップ: §5 の2種。

## 8. オープン事項(実装計画で詰める)
- 入力忘れ救済: オンボーディング以外(設定)で登録〇日以内ならコード入力可とするか。
- iOS/Android 双方の onboarding 既存実装への差し込み箇所。
- フリーズ allowance 計算の単一ソース化(`RescueTicketAllowance.current` を「base + 今月紹介ボーナス(clip 5)」へ拡張)。
- friendships 自動生成と既存の申請/承認フローの整合(自動承認扱い)。

## 9. ストア規約
- 特典は**アプリ内価値(フリーズ/バッジ)・現金でない・核心機能を強制ゲートしない** → App Store / Google Play とも適合(インセンティブ付き紹介は許容範囲)。
