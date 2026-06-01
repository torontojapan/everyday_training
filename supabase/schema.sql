-- GO エクササイズ 友達機能 — Supabase スキーマ + RLS
-- 2026-05-31 / プラットフォーム中立BE (Apple ↔ Android 共有対応)
--
-- 【セットアップ手順】
-- 1. https://supabase.com で新規プロジェクト作成 (無料枠でOK / リージョンは Tokyo 推奨)
-- 2. Authentication → Providers → "Anonymous sign-ins" を ON
--    (ログイン不要UXを保ちつつ auth.uid() で RLS を効かせるため)
-- 2-b. 【クライアント対応とセットでのみ ON】Authentication → Attack Protection →
--    "Enable CAPTCHA protection" (Cloudflare Turnstile)。匿名サインインの量産(濫用)を
--    遮断する (懸念②)。※ ON にするとサーバが captcha token を必須化するため、先に
--    アプリ側で Turnstile token を取得し signInAnonymously に渡す実装が必要。
--    クライアント未対応のまま ON にすると「友達とつながる」/deep link の
--    サインインが実行時に失敗する (Codex P3)。
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
  weekly_total_minutes int,
  monthly_total_minutes int,
  monthly_achieved_days int,
  my_cat_breed text,
  updated_at timestamptz not null default now()
);
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
  kind text not null,                      -- fight / great / clap / fire
  created_at timestamptz not null default now()
);
create index if not exists cheers_to_user_idx on public.cheers (to_user, created_at desc);

-- ============ 権限 (Data API ロールへ明示付与) ============
-- 「Automatically expose new tables」が OFF でも動くよう明示 GRANT。
-- 匿名認証ユーザーは authenticated ロール。行の保護は下の RLS が担う。
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on
  public.profiles, public.friend_requests, public.friendships, public.cheers
  to authenticated;

-- ============ RLS ============
alter table public.profiles enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.cheers enable row level security;

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
