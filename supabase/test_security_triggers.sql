-- ============================================================================
-- セキュリティ堅牢化トリガ 回帰テスト (2026-06-22 / V1・V3)
-- ============================================================================
-- 目的: schema.sql の以下を実 Postgres で検証する。
--   [V1] friendships_insert_guard : 自分宛 friend_request か 自分が referee の referral が
--        ある時のみ friendship INSERT を許可 (一方的な強制友達化を遮断)。
--   [V3] cheers_rate_limit / friend_requests_rate_limit : 直近1時間の自分発の件数上限。
--
-- 実行 (docker 不要・ローカル Postgres):
--   rm -rf /tmp/pgsec && initdb -D /tmp/pgsec -U postgres --auth=trust >/dev/null
--   pg_ctl -D /tmp/pgsec -o "-k /tmp/pgsec -c listen_addresses=''" -l /tmp/pgsec/log start
--   psql -h /tmp/pgsec -U postgres -d postgres -f supabase/test_security_triggers.sql
--   pg_ctl -D /tmp/pgsec stop
--   → 全行 "PASS" であること。
-- ============================================================================

create schema if not exists auth;
create table if not exists auth.users (id uuid primary key);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid
$$;

-- ---- schema.sql と同一に保つ (テーブル) ----
drop table if exists public.friendships cascade;
create table public.friendships (
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);
drop table if exists public.friend_requests cascade;
create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references auth.users(id) on delete cascade,
  to_user uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  unique (from_user, to_user)
);
drop table if exists public.referrals cascade;
create table public.referrals (
  referrer_user_id uuid not null references auth.users(id) on delete cascade,
  referee_user_id  uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  seen_by_referrer boolean not null default false,
  primary key (referee_user_id),
  check (referrer_user_id <> referee_user_id)
);
drop table if exists public.cheers cascade;
create table public.cheers (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references auth.users(id) on delete cascade,
  to_user uuid not null references auth.users(id) on delete cascade,
  kind text not null,
  created_at timestamptz not null default now()
);

-- ---- schema.sql と同一に保つ (トリガ関数) ----
create or replace function public.friendships_insert_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare other uuid;
begin
  if auth.uid() = new.user_a then other := new.user_b;
  elsif auth.uid() = new.user_b then other := new.user_a;
  else raise exception 'friendships: inserter must be a party';
  end if;
  if exists (select 1 from public.friend_requests fr
             where fr.to_user = auth.uid() and fr.from_user = other) then return new; end if;
  if exists (select 1 from public.referrals r
             where r.referee_user_id = auth.uid() and r.referrer_user_id = other) then return new; end if;
  raise exception 'friendships: requires an incoming friend_request or referral (no unilateral friend)';
end$$;
drop trigger if exists friendships_insert_guard_trg on public.friendships;
create trigger friendships_insert_guard_trg before insert on public.friendships
  for each row execute function public.friendships_insert_guard();

create or replace function public.cheers_rate_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare cnt int;
begin
  new.created_at := now();  -- 過去日時詐称による時間窓すり抜けを防ぐ。
  select count(*) into cnt from public.cheers
   where from_user = auth.uid() and created_at > now() - interval '1 hour';
  if cnt >= 60 then raise exception 'cheers: hourly rate limit exceeded'; end if;
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
  if cnt >= 30 then raise exception 'friend_requests: hourly rate limit exceeded'; end if;
  return new;
end$$;
drop trigger if exists friend_requests_rate_limit_trg on public.friend_requests;
create trigger friend_requests_rate_limit_trg before insert on public.friend_requests
  for each row execute function public.friend_requests_rate_limit();

-- fixtures: A<B<C<D (uuid 文字列順) になるよう先頭文字で制御
insert into auth.users values
  ('aaaaaaaa-0000-0000-0000-000000000000'),  -- A
  ('bbbbbbbb-0000-0000-0000-000000000000'),  -- B
  ('cccccccc-0000-0000-0000-000000000000'),  -- C (attacker)
  ('dddddddd-0000-0000-0000-000000000000'),  -- D (victim)
  ('eeeeeeee-0000-0000-0000-000000000000'),  -- E (referee)
  ('ffffffff-0000-0000-0000-000000000000');  -- R (referrer)

create or replace function t_try(label text, sql text, expect_ok boolean) returns void language plpgsql as $$
begin
  execute sql;
  raise notice '%  %', case when expect_ok then 'PASS' else 'FAIL(should-block)' end, label;
exception when others then
  raise notice '%  % [%]', case when expect_ok then 'FAIL(should-allow)' else 'PASS' end, label, sqlerrm;
end$$;

-- ========== [V1] friendships_insert_guard ==========
-- 正規 accept: B が A 宛にリクエスト → A が friendship(A,B) を作成 → 許可
insert into public.friend_requests (from_user, to_user)
  values ('bbbbbbbb-0000-0000-0000-000000000000','aaaaaaaa-0000-0000-0000-000000000000');
set test.uid = 'aaaaaaaa-0000-0000-0000-000000000000';
select t_try('V1-S1 accept incoming request (allow)',
  $$insert into public.friendships(user_a,user_b) values ('aaaaaaaa-0000-0000-0000-000000000000','bbbbbbbb-0000-0000-0000-000000000000')$$, true);

-- 攻撃: C が承認/紹介なしに victim D と friendship を直挿し → 拒否
set test.uid = 'cccccccc-0000-0000-0000-000000000000';
select t_try('V1-S2 unilateral forced friend (block)',
  $$insert into public.friendships(user_a,user_b) values ('cccccccc-0000-0000-0000-000000000000','dddddddd-0000-0000-0000-000000000000')$$, false);

-- 攻撃の変種: C が自分発(outgoing)の request を作ってから friendship 直挿し → 拒否
--   (guard は to_user=自分 の incoming のみ許可。outgoing では満たせない)
insert into public.friend_requests (from_user, to_user)
  values ('cccccccc-0000-0000-0000-000000000000','dddddddd-0000-0000-0000-000000000000');
select t_try('V1-S3 outgoing request does not authorize (block)',
  $$insert into public.friendships(user_a,user_b) values ('cccccccc-0000-0000-0000-000000000000','dddddddd-0000-0000-0000-000000000000')$$, false);

-- 正規 referral: referral(referrer=R, referee=E) を先に作成 → E が friendship(E,R) を作成 → 許可
insert into public.referrals (referrer_user_id, referee_user_id)
  values ('ffffffff-0000-0000-0000-000000000000','eeeeeeee-0000-0000-0000-000000000000');
set test.uid = 'eeeeeeee-0000-0000-0000-000000000000';
select t_try('V1-S4 referral-first then friendship (allow)',
  $$insert into public.friendships(user_a,user_b) values ('eeeeeeee-0000-0000-0000-000000000000','ffffffff-0000-0000-0000-000000000000')$$, true);

-- 当事者でない uid の挿入 → 拒否
set test.uid = 'cccccccc-0000-0000-0000-000000000000';
select t_try('V1-S5 non-party insert (block)',
  $$insert into public.friendships(user_a,user_b) values ('aaaaaaaa-0000-0000-0000-000000000000','dddddddd-0000-0000-0000-000000000000')$$, false);

-- ========== [V3] rate limits ==========
set test.uid = 'cccccccc-0000-0000-0000-000000000000';
-- cheers: 59件まで投入 (trigger は >=60 で拒否) → 60件目まで許可・61件目で拒否
insert into public.cheers (from_user, to_user, kind)
  select 'cccccccc-0000-0000-0000-000000000000','dddddddd-0000-0000-0000-000000000000','fight'
  from generate_series(1,59);
select t_try('V3-S6 cheer #60 within limit (allow)',
  $$insert into public.cheers(from_user,to_user,kind) values ('cccccccc-0000-0000-0000-000000000000','dddddddd-0000-0000-0000-000000000000','fight')$$, true);
select t_try('V3-S7 cheer #61 over limit (block)',
  $$insert into public.cheers(from_user,to_user,kind) values ('cccccccc-0000-0000-0000-000000000000','dddddddd-0000-0000-0000-000000000000','fight')$$, false);

-- friend_requests: C は V1-S3 で既に1件送信済みのため、ここでは 28 件追加し計29件にする
-- (>=30 で拒否)。to_user は毎回別人にするため新規 users を作る。
do $$
declare i int; u uuid;
begin
  for i in 1..28 loop
    u := gen_random_uuid();
    insert into auth.users values (u);
    insert into public.friend_requests(from_user,to_user) values ('cccccccc-0000-0000-0000-000000000000', u);
  end loop;
end$$;
insert into auth.users values ('99999999-0000-0000-0000-000000000000');
insert into auth.users values ('99999999-0000-0000-0000-000000000001');
select t_try('V3-S8 request #30 within limit (allow)',
  $$insert into public.friend_requests(from_user,to_user) values ('cccccccc-0000-0000-0000-000000000000','99999999-0000-0000-0000-000000000000')$$, true);
select t_try('V3-S9 request #31 over limit (block)',
  $$insert into public.friend_requests(from_user,to_user) values ('cccccccc-0000-0000-0000-000000000000','99999999-0000-0000-0000-000000000001')$$, false);

-- V3-S10: created_at を過去に詐称しても回避できない (trigger が now() で上書き)。
-- G が 60件を「2時間前」の created_at で投入 → trigger が now() に上書き → 61件目は拒否。
insert into auth.users values ('99999999-0000-0000-0000-0000000000aa');  -- G
set test.uid = '99999999-0000-0000-0000-0000000000aa';
insert into public.cheers (from_user, to_user, kind, created_at)
  select '99999999-0000-0000-0000-0000000000aa','dddddddd-0000-0000-0000-000000000000','fight', now() - interval '2 hours'
  from generate_series(1,60);
select t_try('V3-S10 backdated created_at does not evade limit (block)',
  $$insert into public.cheers(from_user,to_user,kind,created_at) values ('99999999-0000-0000-0000-0000000000aa','dddddddd-0000-0000-0000-000000000000','fight', now() - interval '2 hours')$$, false);
