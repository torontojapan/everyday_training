-- GO エクササイズ 友達機能 — Supabase スキーマ + RLS
-- 2026-05-31 / プラットフォーム中立BE (Apple ↔ Android 共有対応)
--
-- 【セットアップ手順】
-- 1. https://supabase.com で新規プロジェクト作成 (無料枠でOK / リージョンは Tokyo 推奨)
-- 2. Authentication → Providers → "Anonymous sign-ins" を ON
--    (ログイン不要UXを保ちつつ auth.uid() で RLS を効かせるため)
-- 2-b. CAPTCHA (Cloudflare Turnstile) で匿名サインインの量産(濫用)を遮断する (懸念②)。
--    アプリ側は token 送信に対応済 (config-gated。TurnstileCaptchaTokenProvider /
--    signInAnonymously(captchaToken:))。有効化は以下を**同時に**行う (順序を誤ると
--    サインインが実行時に失敗する):
--      (1) Cloudflare で Turnstile site key を発行し、許可ドメインに WKWebView の
--          baseURL ホスト (既定 goexercise.app) を登録。
--      (2) アプリの Secrets.xcconfig に `TURNSTILE_SITE_KEY = <site key>` を設定して配信。
--          (空の間は CAPTCHA 無効 = captchaToken なしの従来挙動)
--      (3) Supabase: Authentication → Attack Protection → "Enable CAPTCHA protection" を ON。
--    ※ (3) を (2) の配信より先に ON にすると、未対応ビルドのサインインが失敗する。
-- 3. SQL Editor にこのファイル全体を貼って Run
-- 3-b. 孤児(未使用)匿名アカウントの定期削除: supabase/cron/cleanup_orphans.sql も Run
--    (lazy 化後の残り孤児を日次で掃除。懸念②対策)。
-- 4. Project Settings → API から「Project URL」と「anon public key」を控える
--    → アプリ側 Secrets.xcconfig (gitignore) に設定 (後述)
--
-- 設計方針:
-- - 識別は Supabase Anonymous Auth の user id (= auth.uid())。アプリ生成UUID。
-- - friend_code はクライアント生成 (6桁, O/0/I/1除外) + UNIQUE 制約 + 衝突時リトライ。
-- - friendships は「双方向を1行」(user_a < user_b に正規化) → 承認後に双方が即見える。
-- - profiles は体重・体調を一切持たない (プライバシー)。

-- ============ profiles ============
create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  friend_code text unique not null,
  username text not null,
  display_name text not null,
  current_streak int not null default 0,
  total_achieved_days int not null default 0,
  today_achieved boolean not null default false,
  today_category_name text,
  today_exercise_names jsonb,
  today_exercise_details jsonb,
  decoration_tier int not null default 0,
  weekly_achievements jsonb,
  -- 日ごとの状態 (DailyStatus.rawValue: achieved/rest/rescued/missed/future/todayPending/todayAchieved)
  -- の 7 要素配列。友達詳細の「今週の達成」を本人ホームと同じ状態別表示にするための正本。
  -- weekly_achievements (Bool) では休養/フリーズ/実運動を区別できなかった不具合の解消用。
  weekly_statuses jsonb,
  weekly_total_minutes int,
  monthly_total_minutes int,
  monthly_achieved_days int,
  my_cat_breed text,
  updated_at timestamptz not null default now()
);
-- 既存DB (create table if not exists が既存テーブルを変更しない) 向けに後付けで列を足す。
alter table public.profiles add column if not exists weekly_statuses jsonb;
create index if not exists profiles_friend_code_idx on public.profiles (friend_code);
create index if not exists profiles_username_idx on public.profiles (lower(username));

-- updated_at を「最終活動シグナル」として信頼できるようにする (Codex P2)。
-- クライアントの upsert は updated_at を明示送信しないため、トリガで更新時に必ず now() を打つ。
-- これにより孤児削除 cron (supabase/cron/cleanup_orphans.sql) の inactive 判定が
-- アカウント年齢ではなく実際の最終更新で効く (profile 再 publish のたびに更新)。
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ============ friend_requests ============
create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references auth.users(id) on delete cascade,
  to_user uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending',  -- pending / accepted / declined
  created_at timestamptz not null default now(),
  unique (from_user, to_user)
);
create index if not exists fr_to_user_idx on public.friend_requests (to_user, status);

-- ============ friendships (双方向1行) ============
create table if not exists public.friendships (
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active',   -- active / removed / blocked
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)                  -- 順序対で重複排除
);
create index if not exists friendships_a_idx on public.friendships (user_a) where status = 'active';
create index if not exists friendships_b_idx on public.friendships (user_b) where status = 'active';

-- ============ cheers ============
create table if not exists public.cheers (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references auth.users(id) on delete cascade,
  to_user uuid not null references auth.users(id) on delete cascade,
  kind text not null,                      -- fight / wontlose / protein / catpunch / custom (旧: great/clap/fire)
  created_at timestamptz not null default now()
);
-- 応援の一言コメント(任意・2026-06-12)。クライアントは 30 字制限、DB は 60 字で最終ガード。
-- 既存環境への適用も兼ねて alter で追加(本番は SQL Editor で再 Run)。
alter table public.cheers add column if not exists message text
  check (message is null or char_length(message) <= 60);
create index if not exists cheers_to_user_idx on public.cheers (to_user, created_at desc);

-- ============ referrals (友達紹介。referee 主キー = 1人1紹介者) ============
create table if not exists public.referrals (
  referrer_user_id uuid not null references auth.users(id) on delete cascade,
  referee_user_id  uuid not null references auth.users(id) on delete cascade,
  status           text not null default 'pending',  -- pending / confirmed
  created_at       timestamptz not null default now(),
  confirmed_at     timestamptz,
  seen_by_referrer boolean not null default false,    -- 紹介者ポップ表示済みフラグ
  primary key (referee_user_id),                       -- 1人1紹介者 (ユニーク)
  check (referrer_user_id <> referee_user_id)          -- 自己紹介不可
);
create index if not exists referrals_referrer_idx on public.referrals (referrer_user_id, status);

-- ============ 権限 (Data API ロールへ明示付与) ============
-- 「Automatically expose new tables」が OFF でも動くよう明示 GRANT。
-- 匿名認証ユーザーは authenticated ロール。行の保護は下の RLS が担う。
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on
  public.profiles, public.friend_requests, public.friendships, public.cheers, public.referrals
  to authenticated;

-- ============ RLS ============
alter table public.profiles enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.cheers enable row level security;
alter table public.referrals enable row level security;

-- profiles: 検索・友達表示のため全認証ユーザーが SELECT 可 (機微データは持たない)。
--           書き込みは自分の行のみ。
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (true);
drop policy if exists profiles_upsert on public.profiles;
create policy profiles_upsert on public.profiles
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists profiles_delete on public.profiles;
create policy profiles_delete on public.profiles
  for delete to authenticated using (auth.uid() = user_id);

-- friend_requests: 当事者のみ閲覧。送信は自分が from。状態更新/削除は当事者。
drop policy if exists fr_select on public.friend_requests;
create policy fr_select on public.friend_requests
  for select to authenticated using (auth.uid() = from_user or auth.uid() = to_user);
drop policy if exists fr_insert on public.friend_requests;
create policy fr_insert on public.friend_requests
  for insert to authenticated with check (auth.uid() = from_user);
drop policy if exists fr_update on public.friend_requests;
create policy fr_update on public.friend_requests
  for update to authenticated using (auth.uid() = from_user or auth.uid() = to_user);
drop policy if exists fr_delete on public.friend_requests;
create policy fr_delete on public.friend_requests
  for delete to authenticated using (auth.uid() = from_user or auth.uid() = to_user);

-- friendships: 当事者のみ全操作可。
drop policy if exists fs_select on public.friendships;
create policy fs_select on public.friendships
  for select to authenticated using (auth.uid() = user_a or auth.uid() = user_b);
drop policy if exists fs_insert on public.friendships;
create policy fs_insert on public.friendships
  for insert to authenticated with check (auth.uid() = user_a or auth.uid() = user_b);
drop policy if exists fs_update on public.friendships;
create policy fs_update on public.friendships
  for update to authenticated using (auth.uid() = user_a or auth.uid() = user_b);
drop policy if exists fs_delete on public.friendships;
create policy fs_delete on public.friendships
  for delete to authenticated using (auth.uid() = user_a or auth.uid() = user_b);

-- cheers: 送信は「友達である」ことを必須化。受信/送信当事者のみ閲覧。
drop policy if exists cheers_insert on public.cheers;
create policy cheers_insert on public.cheers
  for insert to authenticated with check (
    auth.uid() = from_user and exists (
      select 1 from public.friendships f
      where f.status = 'active' and (
        (f.user_a = auth.uid() and f.user_b = to_user) or
        (f.user_b = auth.uid() and f.user_a = to_user)
      )
    )
  );
drop policy if exists cheers_select on public.cheers;
create policy cheers_select on public.cheers
  for select to authenticated using (auth.uid() = from_user or auth.uid() = to_user);
-- アカウント削除導線 (審査 5.1.1(v)) のため、当事者は自分の cheer 行を削除できる。
-- これが無いと RLS により client の delete が 0 行へ静かにフィルタされる。
-- (auth.users 行を service_role で消せば cascade で消えるが、クライアント主導の
--  明示削除も担保する。)
drop policy if exists cheers_delete on public.cheers;
create policy cheers_delete on public.cheers
  for delete to authenticated using (auth.uid() = from_user or auth.uid() = to_user);

-- referrals:
--  - insert: 自分が referee の行のみ作成可 (招待コードを入力した新規本人)。
--  - select: 当事者 (referrer / referee) のみ。
--  - update: referee は自分の行を confirm 可 / referrer は自分が紹介した行の
--    seen_by_referrer を更新可。当事者以外は不可。
--  - delete: 当事者のみ (アカウント削除導線で本人行を消すため)。
-- insert は必ず pending で始める (status/confirmed_at/seen を被紹介者が初手で捏造させない)。
-- referrals_guard は BEFORE UPDATE のみなので、INSERT 時に status='confirmed'+偽 confirmed_at を
-- 直接書かれると trigger を素通りして報酬 (被紹介者の今月フリーズ / 任意 referrer への星) を
-- 捏造できてしまう (GPT-5.5/Claude 監査 P0)。確定は必ず UPDATE 経路 (trigger 配下) を通す。
drop policy if exists referrals_insert on public.referrals;
create policy referrals_insert on public.referrals
  for insert to authenticated with check (
    auth.uid() = referee_user_id
    and status = 'pending'
    and confirmed_at is null
    and seen_by_referrer = false
  );
drop policy if exists referrals_select on public.referrals;
create policy referrals_select on public.referrals
  for select to authenticated using (auth.uid() = referrer_user_id or auth.uid() = referee_user_id);
drop policy if exists referrals_update on public.referrals;
create policy referrals_update on public.referrals
  for update to authenticated
  using (auth.uid() = referrer_user_id or auth.uid() = referee_user_id)
  with check (auth.uid() = referrer_user_id or auth.uid() = referee_user_id);
drop policy if exists referrals_delete on public.referrals;
create policy referrals_delete on public.referrals
  for delete to authenticated using (auth.uid() = referrer_user_id or auth.uid() = referee_user_id);

-- referrals 列ガード (GPT-5.5 監査 P0): RLS は行単位で OLD を見られないため、
-- confirm の昇格を trigger で制限する。
--  - 当事者ID列 (referrer/referee) は誰も書き換え不可。
--  - referrer は seen_by_referrer のみ変更可 = status/confirmed_at を触れない
--    (被紹介者の初記録なしに自分で status='confirmed' にして星/今月フリーズ/⭐10猫解放を
--     捏造するのを防ぐ)。confirm (status/confirmed_at) は被紹介者のみ。
create or replace function public.referrals_guard_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.referrer_user_id is distinct from old.referrer_user_id
     or new.referee_user_id is distinct from old.referee_user_id then
    raise exception 'referrals: cannot change parties';
  end if;
  -- confirmed_at は確定時に一度だけ書ける(write-once)。後から月を跨いで書き換えて
  -- 今月フリーズボーナス(referee 自身の +1)を毎月再ミントするのを防ぐ(GPT-5.5 監査)。
  if old.confirmed_at is not null and new.confirmed_at is distinct from old.confirmed_at then
    raise exception 'referrals: confirmed_at is write-once';
  end if;
  -- status は pending -> confirmed の一方向のみ。confirmed から戻して再確定させない。
  if old.status = 'confirmed' and new.status is distinct from old.status then
    raise exception 'referrals: status cannot change once confirmed';
  end if;
  if auth.uid() = old.referrer_user_id and auth.uid() <> old.referee_user_id then
    if new.status is distinct from old.status
       or new.confirmed_at is distinct from old.confirmed_at then
      raise exception 'referrals: referrer may only update seen_by_referrer';
    end if;
  end if;
  return new;
end$$;
drop trigger if exists referrals_guard on public.referrals;
create trigger referrals_guard before update on public.referrals
  for each row execute function public.referrals_guard_update();

-- ============ user_records (記録のクラウドバックアップ。iOS/Android 共通) ============
-- 運動・体重・体調(生理)・フリーズ救済日を「本人だけが読み書きできる」形で保存し、
-- 機種変更(OS 跨ぎ含む)・再インストール時に復元する。Duolingo 型のアカウント紐付け。
--  - オプトイン: クライアント側の「記録をクラウドにバックアップ」設定が ON の時だけ書く。
--  - record_id はクライアント生成の安定キー(workout/weight/menstrual は UUID 文字列、
--    rescued_day は "rescued-YYYY-MM-DD")。同一レコードの再 upsert は冪等。
--  - payload は kind ごとの JSON(スキーマはクライアント側の RecordBackup DTO が正本)。
--    サーバ側で中身は解釈しない(同期ストアに徹する)。体重・体調を含むため
--    SELECT は本人のみ(profiles のような全認証ユーザー公開とは異なる)。
--  - deleted: 論理削除(tombstone)。クライアントの削除を他端末へ伝播するため、物理削除
--    ではなく deleted=true + payload='{}' で軽量化する。全削除(設定の「すべての記録を削除」)
--    は物理 delete(本人 RLS で許可)。
create table if not exists public.user_records (
  user_id    uuid not null references auth.users(id) on delete cascade,
  record_id  text not null,
  kind       text not null,                       -- workout / weight / menstrual / rescued_day
  payload    jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  deleted    boolean not null default false,
  primary key (user_id, record_id)
);
create index if not exists user_records_kind_idx on public.user_records (user_id, kind);
create index if not exists user_records_updated_idx on public.user_records (user_id, updated_at);

grant select, insert, update, delete on public.user_records to authenticated;

alter table public.user_records enable row level security;
-- 本人のみ全操作可。体重・生理を含む機微データのため SELECT も本人限定
-- (友達/第三者からは一切見えない)。
drop policy if exists user_records_select on public.user_records;
create policy user_records_select on public.user_records
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists user_records_insert on public.user_records;
create policy user_records_insert on public.user_records
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists user_records_update on public.user_records;
create policy user_records_update on public.user_records
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists user_records_delete on public.user_records;
create policy user_records_delete on public.user_records
  for delete to authenticated using (auth.uid() = user_id);

-- ============================================================================
-- セキュリティ堅牢化 2026-06-22 (脆弱性評価の所見 V1/V3/V2 対応)
-- docs/SECURITY_HARDENING_2026-06-22.md 参照。**この区画は後方互換**:
--  - V1/V3 のトリガは不正な write のみ拒否し、正規の accept/referral/cheer は通る。
--  - V2 の RPC は discovery 用の追加 API（既存の eq()/ilike() クエリは温存）。
--    profiles SELECT の封鎖は配信済みクライアント互換のため**コメントで同梱**し、
--    全クライアントが新版に上がってからカットオーバーする。
-- ============================================================================

-- ---- [V1] friendships の一方的作成を遮断 (同意バイパス/嫌がらせ対策) ----
-- 所見: friendships の insert ポリシーは「当事者の片方であること」しか要求せず、
--   被害者の承認なしに friendship 行を直接挿入 → cheers(メッセージ) を送りつけられた。
-- 対策: BEFORE INSERT で「自分宛の friend_request」か「自分が referee の referral」が
--   存在する時のみ INSERT を許可する。
--   - accept 経路: client は friendship を upsert した直後に request を delete するため、
--     insert 時点では request(from=相手, to=自分) が必ず存在する → 許可。
--   - referral 経路: client を **referral 先・friendship 後** に並べ替え済み
--     (iOS/Android とも)。insert 時点で referral(referee=自分, referrer=相手) が存在 → 許可。
--   既存の friend を remove→再追加する場合も新たな request/referral が必要 (正しい挙動)。
-- SECURITY DEFINER: RLS をバイパスして request/referral の存在を確実に判定する。
--   auth.uid() は JWT クレーム由来でロールに依存しないため DEFINER 下でも呼び出し本人を指す。
create or replace function public.friendships_insert_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  other uuid;
begin
  if auth.uid() = new.user_a then
    other := new.user_b;
  elsif auth.uid() = new.user_b then
    other := new.user_a;
  else
    raise exception 'friendships: inserter must be a party';
  end if;

  if exists (
    select 1 from public.friend_requests fr
     where fr.to_user = auth.uid() and fr.from_user = other
  ) then
    return new;
  end if;
  if exists (
    select 1 from public.referrals r
     where r.referee_user_id = auth.uid() and r.referrer_user_id = other
  ) then
    return new;
  end if;
  raise exception 'friendships: requires an incoming friend_request or referral (no unilateral friend)';
end$$;
drop trigger if exists friendships_insert_guard_trg on public.friendships;
create trigger friendships_insert_guard_trg before insert on public.friendships
  for each row execute function public.friendships_insert_guard();

-- ---- [V3] cheers / friend_requests のレート制限 (スパム/嫌がらせ・濫用対策) ----
-- 自分が送信する cheers / friend_requests を直近1時間で上限件数に制限する。
-- 正規利用には十分な余裕 (cheers 60/h, requests 30/h) を取りつつ、自動化スパムを遮断。
-- SECURITY DEFINER で自分の全行を数える (RLS 上は自分の行は見えるが DEFINER で確実に)。
create or replace function public.cheers_rate_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare cnt int;
begin
  -- created_at をサーバ時刻で上書き (クライアントが過去日時を詐称して時間窓カウントを
  -- すり抜ける回避を防ぐ)。
  new.created_at := now();
  select count(*) into cnt from public.cheers
   where from_user = auth.uid() and created_at > now() - interval '1 hour';
  if cnt >= 60 then
    raise exception 'cheers: hourly rate limit exceeded';
  end if;
  return new;
end$$;
drop trigger if exists cheers_rate_limit_trg on public.cheers;
create trigger cheers_rate_limit_trg before insert on public.cheers
  for each row execute function public.cheers_rate_limit();

create or replace function public.friend_requests_rate_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare cnt int;
begin
  new.created_at := now();  -- 過去日時詐称による時間窓すり抜けを防ぐ。
  select count(*) into cnt from public.friend_requests
   where from_user = auth.uid() and created_at > now() - interval '1 hour';
  if cnt >= 30 then
    raise exception 'friend_requests: hourly rate limit exceeded';
  end if;
  return new;
end$$;
drop trigger if exists friend_requests_rate_limit_trg on public.friend_requests;
create trigger friend_requests_rate_limit_trg before insert on public.friend_requests
  for each row execute function public.friend_requests_rate_limit();

-- ---- [入力 DB CHECK] display_name / username の長さ上限 (防御多層) ----
-- クライアントでも clamp 済 (iOS/Android)。DB 側でも最終ガード。
-- NOT VALID: 既存行は検査せず、新規/更新の write にのみ適用 (後方互換・既存値は短い)。
alter table public.profiles drop constraint if exists profiles_display_name_len;
alter table public.profiles add constraint profiles_display_name_len
  check (char_length(display_name) <= 40) not valid;
alter table public.profiles drop constraint if exists profiles_username_len;
alter table public.profiles add constraint profiles_username_len
  check (char_length(username) <= 24) not valid;

-- ---- [V2] profiles の discovery 用 RPC (一括スクレイピング縮小の段階移行) ----
-- 所見: profiles_select using(true) で全認証ユーザーが全プロフィール(表示名・当日の運動種目
--   詳細・連続日数等)を一括取得できた。
-- 段階移行: discovery (friend_code 完全一致 / username 部分一致) を **非機微列のみ返す**
--   SECURITY DEFINER RPC に寄せる。新クライアントはこれを使い、本番の profiles_select を
--   下記コメントの「自分 or 友達 or 当事者」版に封鎖すれば、第三者は活動詳細を読めなくなる。
--   ※ today_exercise_names/details・weekly/monthly minutes・weekly_statuses 等は返さない。
-- ★SECURITY DEFINER 関数は CREATE 時に EXECUTE が PUBLIC へ既定付与される。anon は schema usage を
--   持つため、revoke しないと未認証(anon)呼び出しで RLS を迂回して profiles を引ける(GPT-5.5 監査 High)。
--   PUBLIC/anon から剥奪し authenticated のみへ付与。関数内でも auth.uid() 必須を多層防御で課す。
create or replace function public.find_profile_by_code(p_code text)
returns table(
  user_id uuid, friend_code text, username text, display_name text,
  current_streak int, total_achieved_days int, decoration_tier int, my_cat_breed text
) language sql security definer set search_path = public stable as $$
  select p.user_id, p.friend_code, p.username, p.display_name,
         p.current_streak, p.total_achieved_days, p.decoration_tier, p.my_cat_breed
  from public.profiles p
  where p.friend_code = p_code and auth.uid() is not null
  limit 1;
$$;
revoke all on function public.find_profile_by_code(text) from public, anon;
grant execute on function public.find_profile_by_code(text) to authenticated;

create or replace function public.search_profiles_by_username(p_query text)
returns table(
  user_id uuid, friend_code text, username text, display_name text,
  current_streak int, total_achieved_days int, decoration_tier int, my_cat_breed text
) language sql security definer set search_path = public stable as $$
  -- LIKE メタ文字 (\ % _) をエスケープしてから部分一致 (ワイルドカード注入防止)。
  select p.user_id, p.friend_code, p.username, p.display_name,
         p.current_streak, p.total_achieved_days, p.decoration_tier, p.my_cat_breed
  from public.profiles p
  where auth.uid() is not null
    and p.username ilike '%' ||
        replace(replace(replace(p_query, '\', '\\'), '%', '\%'), '_', '\_') || '%'
  limit 25;
$$;
revoke all on function public.search_profiles_by_username(text) from public, anon;
grant execute on function public.search_profiles_by_username(text) to authenticated;

-- ▼▼▼ カットオーバー用 (全クライアントが RPC 対応版へ更新された後に適用) ▼▼▼
-- これを適用すると、第三者は profiles の全列直読みができなくなり (discovery は上記 RPC 経由)、
-- 当日の運動種目詳細などの活動データが友達以外から見えなくなる。
-- 配信済み(旧)クライアントは eq()/ilike() 直読みに依存するため、min-version ゲート後に有効化する。
--
-- drop policy if exists profiles_select on public.profiles;
-- create policy profiles_select on public.profiles
--   for select to authenticated using (
--     auth.uid() = user_id
--     or exists (select 1 from public.friendships f
--                where f.status = 'active'
--                  and ((f.user_a = auth.uid() and f.user_b = profiles.user_id)
--                    or (f.user_b = auth.uid() and f.user_a = profiles.user_id)))
--     or exists (select 1 from public.friend_requests fr
--                where (fr.to_user = auth.uid() and fr.from_user = profiles.user_id)
--                   or (fr.from_user = auth.uid() and fr.to_user = profiles.user_id))
--     or exists (select 1 from public.referrals r
--                where (r.referee_user_id = auth.uid() and r.referrer_user_id = profiles.user_id)
--                   or (r.referrer_user_id = auth.uid() and r.referee_user_id = profiles.user_id))
--   );
-- ▲▲▲ カットオーバー用ここまで ▲▲▲
