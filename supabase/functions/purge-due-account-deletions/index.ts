import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { banThenPurgeThenDeleteAuth } from "../_shared/ban_purge_delete_auth.ts";
import { createServiceRoleClient } from "../_shared/create_service_role_client.ts";

/**
 * 定时任务调用：
 * 1) 清理「冷静期已过且未撤回」的账号（封禁 → purge → deleteUser）；
 * 2) 重试 `account_auth_delete_retry_queue` 中仅缺 Auth 删除的用户。
 * 请在 Supabase Dashboard → Edge Functions → 配置 Cron / 外部调度，请求头携带：
 *   Authorization: Bearer <CRON_SECRET>
 * 并在项目 Secrets 中设置 CRON_SECRET（与 Dashboard 里配置的 Bearer 一致）。
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, x-client-info, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const secret = Deno.env.get("CRON_SECRET");
  const auth = req.headers.get("Authorization")?.replace("Bearer ", "") ?? "";
  if (!secret || auth !== secret) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createServiceRoleClient();

  const { data: retryRows, error: retryListErr } = await supabase
    .from("account_auth_delete_retry_queue")
    .select("user_id");

  if (retryListErr) {
    console.error("retry queue list failed", retryListErr);
  }

  const queuedIds = new Set(
    retryListErr ? [] : (retryRows ?? []).map((r) => r.user_id as string),
  );

  const nowIso = new Date().toISOString();
  const { data: rows, error: listErr } = await supabase
    .from("users_profiles")
    .select("id")
    .not("account_deletion_effective_at", "is", null)
    .lte("account_deletion_effective_at", nowIso);

  if (listErr) {
    console.error(listErr);
    return new Response(JSON.stringify({ error: listErr.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const ids = (rows ?? [])
    .map((r: { id: string }) => r.id)
    .filter(Boolean)
    .filter((id) => !queuedIds.has(id));

  const results: { id: string; ok: boolean; error?: string }[] = [];

  for (const id of ids) {
    const outcome = await banThenPurgeThenDeleteAuth(supabase, id);
    if (!outcome.ok) {
      results.push({
        id,
        ok: false,
        error: `${outcome.code}: ${outcome.message ?? outcome.step}`,
      });
      continue;
    }
    results.push({ id, ok: true });
  }

  if (!retryListErr) {
    for (const uid of queuedIds) {
      const { error: delAuth } = await supabase.auth.admin.deleteUser(uid);
      if (delAuth) {
        console.error("retry deleteUser failed", uid, delAuth);
        await supabase
          .from("account_auth_delete_retry_queue")
          .update({ last_error: delAuth.message })
          .eq("user_id", uid);
        results.push({
          id: uid,
          ok: false,
          error: `retry_delete_auth: ${delAuth.message}`,
        });
      } else {
        results.push({ id: uid, ok: true });
      }
    }
  }

  return new Response(
    JSON.stringify({
      success: true,
      processed: ids.length,
      retry_auth_delete_attempted: retryListErr ? -1 : queuedIds.size,
      results,
    }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
