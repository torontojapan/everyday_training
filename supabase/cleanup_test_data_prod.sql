-- ============================================================================
-- 本番 Supabase テストデータ掃除(プレビュー先行・2026-06-23)
-- ============================================================================
-- 目的: E2E/スモークテストで作った使い捨て匿名アカウント・テスト友達(「おうえんねこ」等)・
--   テスト応援/申請/紹介・孤児プロフィールを本番から除去する。
--
-- ★安全運用(必ずこの順):
--   1) まず STEP 1 の SELECT だけを Run し、「消える対象」を**目視で確認**する。
--   2) 想定どおりなら STEP 2 の DELETE のコメント(/* */)を外して Run する。
--   3) 自分の本番アカウント(実際に使っている profile)が対象に含まれていないことを必ず確認。
--   テスト判定はヒューリスティック(表示名/ユーザー名のパターン+孤立)なので、過剰削除しないよう
--   STEP 1 の結果を1行ずつ確認すること。判断に迷う行は WHERE から外す。
-- ============================================================================

-- ───────────────────────────────────────────────────────────────────────────
-- STEP 1: 削除候補のプレビュー(Run して結果を確認するだけ。何も消えない)
-- ───────────────────────────────────────────────────────────────────────────

-- 1-a) テストとおぼしき profiles(表示名/ユーザー名のパターン)。
--      ※ 実在ユーザーを誤検知しないよう、パターンは保守的に。必要なら足し引きする。
select user_id, friend_code, username, display_name, current_streak, total_achieved_days
from public.profiles
where display_name ilike '%おうえんねこ%'
   or display_name ilike '%test%'   or username ilike '%test%'
   or display_name ilike '%demo%'   or username ilike '%demo%'
   or username ilike 'jun_demo%'
order by display_name;

-- 1-b) 孤児プロフィール(auth.users に対応行が無い=削除済みアカウントの残骸)。
select p.user_id, p.username, p.display_name
from public.profiles p
left join auth.users u on u.id = p.user_id
where u.id is null;

-- 1-c) 上記候補が絡む friendships / friend_requests / cheers / referrals の件数(影響範囲の把握)。
with targets as (
  select user_id from public.profiles
  where display_name ilike '%おうえんねこ%'
     or display_name ilike '%test%' or username ilike '%test%'
     or display_name ilike '%demo%' or username ilike '%demo%'
     or username ilike 'jun_demo%'
)
select
  (select count(*) from public.friendships    f where f.user_a in (select user_id from targets) or f.user_b in (select user_id from targets)) as friendships,
  (select count(*) from public.friend_requests r where r.from_user in (select user_id from targets) or r.to_user in (select user_id from targets)) as friend_requests,
  (select count(*) from public.cheers          c where c.from_user in (select user_id from targets) or c.to_user in (select user_id from targets)) as cheers,
  (select count(*) from public.referrals       x where x.referrer_user_id in (select user_id from targets) or x.referee_user_id in (select user_id from targets)) as referrals;


-- ───────────────────────────────────────────────────────────────────────────
-- STEP 2: 実削除(STEP 1 を確認後、/* */ を外して Run)
-- ───────────────────────────────────────────────────────────────────────────
-- 子テーブルを先に消し、最後に profiles を消す(FK/RLS 由来の失敗を避ける順序)。
-- targets の定義は STEP 1-a と同一。**自分の本番アカウントが入らないことを再確認してから**外す。
/*
begin;

with targets as (
  select user_id from public.profiles
  where display_name ilike '%おうえんねこ%'
     or display_name ilike '%test%' or username ilike '%test%'
     or display_name ilike '%demo%' or username ilike '%demo%'
     or username ilike 'jun_demo%'
)
, del_cheers as (
  delete from public.cheers
   where from_user in (select user_id from targets) or to_user in (select user_id from targets)
)
, del_reqs as (
  delete from public.friend_requests
   where from_user in (select user_id from targets) or to_user in (select user_id from targets)
)
, del_friend as (
  delete from public.friendships
   where user_a in (select user_id from targets) or user_b in (select user_id from targets)
)
, del_ref as (
  delete from public.referrals
   where referrer_user_id in (select user_id from targets) or referee_user_id in (select user_id from targets)
)
, del_records as (
  delete from public.user_records
   where user_id in (select user_id from targets)
)
delete from public.profiles
 where user_id in (select user_id from targets);

-- 孤児プロフィール(STEP 1-b)も掃除する場合は次行も実行:
-- delete from public.profiles p where not exists (select 1 from auth.users u where u.id = p.user_id);

commit;
*/

-- 補足: 匿名 auth.users 行そのものの削除は service_role / ダッシュボードの Authentication 画面、
--   または Edge Function(delete-account)経由で行う(SQL Editor の anon/authenticated 権限では不可)。
--   上記は公開データ(profiles/friends/cheers/records)の掃除まで。
-- ============================================================================
