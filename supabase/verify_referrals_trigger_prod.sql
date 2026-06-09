-- ============================================================================
-- referrals trigger 本番 適用後 検証 (非破壊 / 読み取り専用)
-- ============================================================================
-- 目的: schema.sql の referrals_guard_update trigger が本番に適用されたことを、
--       実データを一切変更せずに確認する。
--
-- ⚠️ test_referrals_trigger.sql は `drop table public.referrals` を含むため
--    本番では絶対に実行しないこと(本番データが消える)。本番ではこのファイルを使う。
--
-- 実行: Supabase ダッシュボード → SQL Editor にこのファイル全体を貼って Run。
--       全チェックが期待値どおりであることを確認する。
-- ============================================================================

-- 1) 関数が存在するか (security definer / search_path=public で作られているか)
select 'check_function' as check,
       proname,
       prosecdef as is_security_definer,        -- true 期待
       proconfig as config                       -- {search_path=public} 期待
from pg_proc
where proname = 'referrals_guard_update';
-- → 1 行返り、is_security_definer = true であること。0 行なら未適用。

-- 2) トリガが referrals に before update で張られているか
select 'check_trigger' as check,
       t.tgname,
       c.relname as table,
       case t.tgtype & 2 when 2 then 'BEFORE' else 'AFTER' end as timing,
       case t.tgtype & 16 when 16 then 'UPDATE' else 'other' end as event,
       t.tgenabled                                -- 'O'(enabled) 期待
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
where t.tgname = 'referrals_guard' and c.relname = 'referrals';
-- → 1 行返り、timing=BEFORE / event=UPDATE / tgenabled='O' であること。

-- 3) referrals テーブルの RLS が有効か (参考)
select 'check_rls' as check, relname, relrowsecurity as rls_enabled
from pg_class where relname = 'referrals';
-- → rls_enabled = true 期待。

-- 4) referrals のポリシー一覧 (参考: insert/select/update/delete の4本)
select 'check_policies' as check, polname, polcmd
from pg_policy where polrelid = 'public.referrals'::regclass
order by polname;
-- → referrals_insert / referrals_select / referrals_update / referrals_delete の4本期待。
