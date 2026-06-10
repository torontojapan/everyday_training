-- ============================================================================
-- referrals trigger 回帰テスト (再発防止)
-- ============================================================================
-- 目的: schema.sql の referrals_guard_update trigger が「正規フローを許可しつつ
--       報酬の不正操作を阻止する」ことを実 Postgres で検証する。
--
-- 背景(2026-06-08 GPT-5.5/Claude 監査で発見・修正した型):
--   - referrer が status='confirmed' を捏造 → 初記録なしで星/フリーズ/猫解放
--   - referee が confirmed_at を後から書換えて月次フリーズボーナスを再ミント
--   - status を confirmed から戻して再確定 / 当事者ID(referrer/referee)の付替
--
-- 実行方法(docker 不要。ローカル Postgres):
--   initdb -D /tmp/pgtest -U postgres --auth=trust
--   pg_ctl -D /tmp/pgtest -o "-k /tmp/pgsock -c listen_addresses=''" start
--   psql -h /tmp/pgsock -U postgres -d postgres -f supabase/test_referrals_trigger.sql
--   → 全行 "PASS" であること(FAIL があれば trigger が壊れている)。
-- ============================================================================

-- auth スタブ (Supabase 互換: auth.uid() を session 変数から)
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid
$$;

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

-- ▼ schema.sql の trigger と同一に保つこと(変更時は両方更新)
create or replace function public.referrals_guard_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.referrer_user_id is distinct from old.referrer_user_id
     or new.referee_user_id is distinct from old.referee_user_id then
    raise exception 'referrals: cannot change parties';
  end if;
  if old.confirmed_at is not null and new.confirmed_at is distinct from old.confirmed_at then
    raise exception 'referrals: confirmed_at is write-once';
  end if;
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

-- fixtures
insert into auth.users values
  ('11111111-1111-1111-1111-111111111111'),  -- R referrer
  ('22222222-2222-2222-2222-222222222222'),  -- E referee
  ('33333333-3333-3333-3333-333333333333');  -- X 別referrer候補
insert into public.referrals (referrer_user_id, referee_user_id)
  values ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222');

create or replace function t_try(label text, sql text, expect_ok boolean) returns void language plpgsql as $$
begin
  execute sql;
  raise notice '%  %', case when expect_ok then 'PASS' else 'FAIL(should-block)' end, label;
exception when others then
  raise notice '%  % [%]', case when expect_ok then 'FAIL(should-allow)' else 'PASS' end, label, sqlerrm;
end$$;

-- シナリオ
set test.uid = '22222222-2222-2222-2222-222222222222';
select t_try('S1 referee confirm (allow)', $$update public.referrals set status='confirmed', confirmed_at=now() where referee_user_id='22222222-2222-2222-2222-222222222222'$$, true);
set test.uid = '11111111-1111-1111-1111-111111111111';
select t_try('S2 referrer seen (allow)', $$update public.referrals set seen_by_referrer=true where referee_user_id='22222222-2222-2222-2222-222222222222'$$, true);
select t_try('S3 referrer change status (block)', $$update public.referrals set status='pending' where referee_user_id='22222222-2222-2222-2222-222222222222'$$, false);
set test.uid = '22222222-2222-2222-2222-222222222222';
select t_try('S4 referee rewrite confirmed_at (block)', $$update public.referrals set confirmed_at=now()+interval '40 days' where referee_user_id='22222222-2222-2222-2222-222222222222'$$, false);
select t_try('S5 status confirmed->pending (block)', $$update public.referrals set status='pending' where referee_user_id='22222222-2222-2222-2222-222222222222'$$, false);
select t_try('S6 change parties (block)', $$update public.referrals set referrer_user_id='33333333-3333-3333-3333-333333333333' where referee_user_id='22222222-2222-2222-2222-222222222222'$$, false);
select t_try('S7 referee seen update (allow)', $$update public.referrals set seen_by_referrer=false where referee_user_id='22222222-2222-2222-2222-222222222222'$$, true);

-- ============================================================================
-- INSERT 経路の RLS ガード (2026-06-10 監査 P0): trigger は BEFORE UPDATE のみ。
-- referrals_insert に status/confirmed_at の制約が無いと、被紹介者が初手で
-- status='confirmed'+偽 confirmed_at を直接 INSERT して報酬を捏造できる。
-- → 実 RLS を有効化し、非特権ロールで INSERT ポリシーを実行検証する。
-- ============================================================================
-- RLS は table owner / superuser をバイパスするため、専用の非特権ロールで検証する。
drop role if exists test_authenticated;
create role test_authenticated nologin;
grant usage on schema public, auth to test_authenticated;
grant select, insert, update, delete on public.referrals to test_authenticated;
grant execute on function auth.uid() to test_authenticated;

alter table public.referrals enable row level security;
-- ▼ schema.sql の referrals_insert と同一に保つこと(変更時は両方更新)
drop policy if exists referrals_insert on public.referrals;
create policy referrals_insert on public.referrals
  for insert to test_authenticated with check (
    auth.uid() = referee_user_id
    and status = 'pending'
    and confirmed_at is null
    and seen_by_referrer = false
  );
drop policy if exists referrals_select on public.referrals;
create policy referrals_select on public.referrals
  for select to test_authenticated using (auth.uid() = referrer_user_id or auth.uid() = referee_user_id);

-- 被紹介者候補 E2 を追加(E は既に R に紐付くため新規 referee で INSERT を試す)
insert into auth.users values ('44444444-4444-4444-4444-444444444444');  -- E2 referee候補

-- t_try は SECURITY DEFINER 相当(関数所有者=postgres)で走ると RLS を見ないため、
-- INSERT 検証は明示的に role を切替えて実行する別ヘルパで行う。
create or replace function t_try_as(label text, role_uid uuid, sql text, expect_ok boolean) returns void language plpgsql as $$
begin
  perform set_config('test.uid', role_uid::text, true);
  execute 'set local role test_authenticated';
  execute sql;
  execute 'reset role';
  raise notice '%  %', case when expect_ok then 'PASS' else 'FAIL(should-block)' end, label;
exception when others then
  execute 'reset role';
  raise notice '%  % [%]', case when expect_ok then 'FAIL(should-allow)' else 'PASS' end, label, sqlerrm;
end$$;

-- S8: 正規の pending INSERT は許可
select t_try_as('S8 referee insert pending (allow)', '44444444-4444-4444-4444-444444444444',
  $$insert into public.referrals (referrer_user_id, referee_user_id) values ('11111111-1111-1111-1111-111111111111','44444444-4444-4444-4444-444444444444')$$, true);
-- 後始末(次テストのため削除)。owner 権限で消す。
delete from public.referrals where referee_user_id='44444444-4444-4444-4444-444444444444';
-- S9: status='confirmed' を直接 INSERT は拒否(報酬捏造を封じる核心)
select t_try_as('S9 referee insert confirmed (block)', '44444444-4444-4444-4444-444444444444',
  $$insert into public.referrals (referrer_user_id, referee_user_id, status, confirmed_at) values ('11111111-1111-1111-1111-111111111111','44444444-4444-4444-4444-444444444444','confirmed', now())$$, false);
-- S10: confirmed_at だけ偽装した INSERT も拒否
select t_try_as('S10 referee insert with confirmed_at (block)', '44444444-4444-4444-4444-444444444444',
  $$insert into public.referrals (referrer_user_id, referee_user_id, confirmed_at) values ('11111111-1111-1111-1111-111111111111','44444444-4444-4444-4444-444444444444', now())$$, false);
-- S11: 他人を referee にした INSERT は拒否(auth.uid()=referee 制約)
select t_try_as('S11 insert for someone else (block)', '44444444-4444-4444-4444-444444444444',
  $$insert into public.referrals (referrer_user_id, referee_user_id) values ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222')$$, false);
