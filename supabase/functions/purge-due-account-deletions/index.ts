import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { purgeUserBusinessData } from "../_shared/purge_user_business_data.ts";
import { createServiceRoleClient } from "../_shared/create_service_role_client.ts";

/**
 * 定时任务调用：清理「冷静期已过且未撤回」的账号。
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

  const ids = (rows ?? []).map((r: { id: string }) => r.id).filter(Boolean);
  const results: { id: string; ok: boolean; error?: string }[] = [];

  for (const id of ids) {
    const purged = await purgeUserBusinessData(supabase, id);
    if (!purged.ok) {
      results.push({ id, ok: false, error: `${purged.step}: ${purged.message}` });
      continue;
    }
    const { error: delAuth } = await supabase.auth.admin.deleteUser(id);
    if (delAuth) {
      console.error("deleteUser failed", id, delAuth);
      results.push({ id, ok: false, error: delAuth.message });
      continue;
    }
    results.push({ id, ok: true });
  }

  return new Response(
    JSON.stringify({ success: true, processed: ids.length, results }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
