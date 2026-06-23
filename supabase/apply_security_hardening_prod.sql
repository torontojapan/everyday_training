-- ============================================================================
-- 本番 Supabase 適用スクリプト: セキュリティ堅牢化 (2026-06-23)
-- ============================================================================
-- 使い方: Supabase ダッシュボード → SQL Editor に貼って Run。すべて冪等
--   (create or replace / drop if exists / not valid) なので再実行しても安全。
--
-- ★★ 適用は 2 段階に分かれる。クライアント互換性のため順序が重要 ★★
--
--   PART 1 (今すぐ適用可): V3 レート制限 + 長さ CHECK + V2 discovery RPC。
--     → 現在 App Store 公開中の iOS 1.2 / 審査中の 1.3 (どちらも友達追加で
--        friendships/cheers/friend_requests を直 INSERT、profiles を eq()/ilike()
--        直読み) を **壊さない**。スパム/濫用と一括スクレイピングの主対策が即時有効化。
--
--   PART 2 (iOS/Android 1.4 が行き渡った後に適用): V1 一方的友達化トリガ +
--     profiles_select 封鎖。
--     → V1 トリガは「friendship INSERT 時点で 自分宛 friend_request か 自分が referee の
--        referral が存在」を要求する。公開中 1.2/1.3 の **招待コード経路は friendship を
--        先に作る順序**(referral は後)なので、PART 2 を今適用すると旧クライアントの
--        招待コードによる友達追加が失敗する。1.4 で順序を referral 先に修正済み。
--        よって 1.4 を min-version にしてから PART 2 を適用する。
--        (通常の「友達申請→承認」経路は request が先に存在するので V1 と互換。)
--
-- 検証: PART 1/2 の V1・V3 は supabase/test_security_triggers.sql で 10/10 PASS
--       (ローカル PG16)。RPC は本ファイル末尾の検証クエリで確認する。
-- ============================================================================


-- ════════════════════════════════════════════════════════════════════════════
-- PART 1 — 今すぐ適用 (後方互換)
-- ════════════════════════════════════════════════════════════════════════════

-- ---- [V3] cheers / friend_requests のレート制限 (スパム/嫌がらせ・濫用対策) ----
create or replace function public.cheers_rate_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare cnt int;
begin
  new.created_at := now();  -- 過去日時詐称による時間窓すり抜けを防ぐ。
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
-- NOT VALID: 既存行は検査せず新規/更新 write にのみ適用 (後方互換・既存値は短い)。
alter table public.profiles drop constraint if exists profiles_display_name_len;
alter table public.profiles add constraint profiles_display_name_len
  check (char_length(display_name) <= 40) not valid;
alter table public.profiles drop constraint if exists profiles_username_len;
alter table public.profiles add constraint profiles_username_len
  check (char_length(username) <= 24) not valid;

-- ---- [V2] profiles の discovery 用 RPC (非機微列のみ返す。追加は後方互換) ----
-- ★SECURITY DEFINER 関数は CREATE 時に EXECUTE が PUBLIC へ既定付与される。anon は schema usage を
--   持つため revoke しないと未認証(anon)呼び出しで RLS を迂回して profiles を引ける。
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


-- ════════════════════════════════════════════════════════════════════════════
-- PART 2 — iOS/Android 1.4 が行き渡った後に適用 (旧クライアント非互換)
-- ════════════════════════════════════════════════════════════════════════════
-- ↓ 下のブロックは 1.4 を min-version にしてから コメントを外して Run する。
--   今 Run すると公開中 1.2/1.3 の招待コードによる友達追加が壊れる (上記説明参照)。
/*
-- ---- [V1] 一方的な強制友達化を遮断するトリガ ----
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

-- ---- [V2] profiles_select 封鎖 (第三者の全列直読みを停止。discovery は RPC 経由) ----
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (
    auth.uid() = user_id
    or exists (select 1 from public.friendships f
               where f.status = 'active'
                 and ((f.user_a = auth.uid() and f.user_b = profiles.user_id)
                   or (f.user_b = auth.uid() and f.user_a = profiles.user_id)))
    or exists (select 1 from public.friend_requests fr
               where (fr.to_user = auth.uid() and fr.from_user = profiles.user_id)
                  or (fr.from_user = auth.uid() and fr.to_user = profiles.user_id))
    or exists (select 1 from public.referrals r
               where (r.referee_user_id = auth.uid() and r.referrer_user_id = profiles.user_id)
                  or (r.referrer_user_id = auth.uid() and r.referee_user_id = profiles.user_id))
  );
*/


-- ════════════════════════════════════════════════════════════════════════════
-- 適用後の検証クエリ (PART 1 適用後に Run して結果を確認)
-- ════════════════════════════════════════════════════════════════════════════
-- 1) トリガが存在するか:
--    select tgname from pg_trigger
--     where tgname in ('cheers_rate_limit_trg','friend_requests_rate_limit_trg');
--    → 2 行返ればOK。
--
-- 2) 長さ制約が存在するか:
--    select conname from pg_constraint
--     where conname in ('profiles_display_name_len','profiles_username_len');
--    → 2 行返ればOK。
--
-- 3) RPC の権限が anon=不可 / authenticated=可 か:
--    select p.proname, r.rolname, has_function_privilege(r.rolname, p.oid, 'execute') as can_exec
--    from pg_proc p
--    cross join (values ('anon'),('authenticated')) as r(rolname)
--    where p.proname in ('find_profile_by_code','search_profiles_by_username')
--    order by p.proname, r.rolname;
--    → anon=false / authenticated=true であればOK。
-- ============================================================================
