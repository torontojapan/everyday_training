// Supabase Edge Function: delete-account
// =====================================================================
// 審査 Guideline 5.1.1(v) 「アプリ内アカウント削除」の **サーバ側完了処理**。
//
// クライアント (anon key) は本人 uid の profiles/friendships/friend_requests/cheers
// を RLS の範囲で削除できるが、`auth.users` 行**自体**の削除は service_role が必須。
// この関数は呼び出し元の JWT を検証して本人を特定し、service_role で
// `auth.admin.deleteUser(uid)` を実行する。auth 行削除時に各表は
// `on delete cascade` で連鎖削除されるため、データの取りこぼしも回収される。
//
// 【設計判断 (2026-06-02)】 cron 拡張ではなくこの Edge Function を採用する理由:
//   - 即時削除 (ユーザーが「削除」を押した時点で完結) が審査・UX 上望ましい。
//   - cron で連携済みアカウントを掃除するには「削除予約」テーブル等の状態が要り、
//     その行自体が PII/複雑性を増やす。Edge Function は状態を持たず単純。
//   - 孤児 cron (cleanup_orphans.sql) は引き続き **匿名** の未使用行のみを対象にする
//     (役割分担: cron=未使用匿名の自動掃除 / この関数=ユーザー主導の明示削除)。
//
// 【デプロイ (キー所有者作業)】
//   1. supabase functions deploy delete-account
//   2. service_role key は Edge Function 環境に自動注入される
//      (SUPABASE_SERVICE_ROLE_KEY / SUPABASE_URL)。手動設定不要。
//   3. 認証必須にする (verify_jwt=ON が既定)。匿名 JWT でも user は取れる。
//   4. デプロイ後、クライアントを best-effort 呼び出しに更新する follow-up は別タスク
//      (本セッションのクライアントはデータ削除 + ローカルサインアウトまで)。
//
// 動作未確認 (キー所有者が deploy + 実 JWT で検証するまでスキャフォルド扱い)。

import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "missing_authorization" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "server_misconfigured" }, 500);
  }

  // 呼び出し元の JWT から本人 uid を特定する (なりすまし防止: uid は body で受け取らない)。
  const caller = createClient(supabaseUrl, serviceRoleKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userErr } = await caller.auth.getUser();
  if (userErr || !userData?.user) {
    return json({ error: "invalid_token" }, 401);
  }
  const uid = userData.user.id;

  // service_role で auth 行を削除 (各表は cascade で連鎖削除される)。
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });
  const { error: delErr } = await admin.auth.admin.deleteUser(uid);
  if (delErr) {
    return json({ error: "delete_failed", detail: delErr.message }, 500);
  }

  return json({ ok: true }, 200);
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
