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
