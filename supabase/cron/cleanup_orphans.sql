-- GO エクササイズ 友達機能 — 孤児(未使用)匿名アカウントの定期削除
-- 2026-06-01 / 設計: docs/superpowers/specs/2026-06-01-friends-account-hardening-design.md
--
-- 【狙い】懸念② 孤児アカウントの蓄積を潰す。
-- lazy 化(タブ表示では匿名アカウントを作らない)後も、「友達とつながる」を押したが
-- 結局誰ともつながらずアンインストールした人の匿名ユーザー + profiles 行が残りうる。
-- これを定期的に掃除し、Supabase の MAU/容量と濫用面を抑える。
--
-- 【削除対象の条件(すべて満たす)】
--   1. auth.users.is_anonymous = true        … 連携済み(permanent)アカウントは絶対に消さない
--   2. friendships が 0 件                    … 誰ともつながっていない
--   3. friend_requests が 0 件(送受信とも)    … 申請の途中でもない
--   4. profiles.updated_at が 30 日以上前      … 直近アクティブでない
--   profiles 未作成の匿名ユーザー(=サインインだけして即離脱)も
--   created_at 30 日超で対象に含める。
--
-- friendships / friend_requests / cheers は profiles・auth.users への
-- `on delete cascade` 済みなので、auth.users を消せば連鎖削除される。
--
-- 【セットアップ】SQL Editor で本ファイルを Run(関数定義 + pg_cron スケジュール)。
--   pg_cron / pg_net が未有効なら Database → Extensions で有効化。
--   service_role 相当の権限で実行されるため auth.users を操作できる。

create extension if not exists pg_cron;

-- 孤児匿名ユーザーを削除する関数。返り値 = 削除件数(監査ログ用)。
create or replace function public.cleanup_orphan_anonymous_users(
  inactive_days int default 30
)
returns int
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  deleted_count int;
begin
  with orphans as (
    select u.id
    from auth.users u
    left join public.profiles p on p.user_id = u.id
    where u.is_anonymous = true
      -- 直近アクティブでない(profile があれば updated_at、無ければ user 作成時刻で判定)
      and coalesce(p.updated_at, u.created_at) < now() - make_interval(days => inactive_days)
      -- 友達ゼロ
      and not exists (
        select 1 from public.friendships f
        where f.user_a = u.id or f.user_b = u.id
      )
      -- 申請(送受信)ゼロ
      and not exists (
        select 1 from public.friend_requests r
        where r.from_user = u.id or r.to_user = u.id
      )
  )
  delete from auth.users u
  using orphans o
  where u.id = o.id;
  get diagnostics deleted_count = row_count;
  raise notice 'cleanup_orphan_anonymous_users: deleted % rows (inactive_days=%)', deleted_count, inactive_days;
  return deleted_count;
end;
$$;

-- 【重要】権限の封じ込め (Codex P1)。
-- public スキーマの関数は PostgREST 経由で RPC 公開され、既定で anon/authenticated にも
-- EXECUTE が付く。SECURITY DEFINER でこの関数を放置すると、クライアントが
-- `inactive_days => 0` で呼んで即時削除を強制できてしまう。
-- → 全ロールから EXECUTE を剥奪し、スケジューラ(postgres)経由のみ実行可能にする。
revoke all on function public.cleanup_orphan_anonymous_users(int) from public;
revoke all on function public.cleanup_orphan_anonymous_users(int) from anon, authenticated;

-- 日次(毎日 03:15 UTC = 12:15 JST)で実行。既存ジョブがあれば貼り直しに備え unschedule。
select cron.unschedule('cleanup-orphan-anonymous')
  where exists (select 1 from cron.job where jobname = 'cleanup-orphan-anonymous');

select cron.schedule(
  'cleanup-orphan-anonymous',
  '15 3 * * *',
  $$select public.cleanup_orphan_anonymous_users(30);$$
);
