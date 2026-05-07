import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { banThenPurgeThenDeleteAuth } from "../_shared/ban_purge_delete_auth.ts";
import { createServiceRoleClient } from "../_shared/create_service_role_client.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, x-client-info, content-type",
};

/**
 * 用户 JWT：若冷静期已结束（effective_at <= now），则立即执行硬删并删除 Auth。
 * 冷静期未结束时不应调用（由客户端在登录后清空字段撤回）。
 */
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

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "未登录" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const token = authHeader.replace("Bearer ", "");

  const verifyClient = createServiceRoleClient();
  const {
    data: { user },
    error: userError,
  } = await verifyClient.auth.getUser(token);

  if (userError || !user) {
    return new Response(JSON.stringify({ error: "用户无效" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const admin = createServiceRoleClient();
  const { data: profile, error: pErr } = await admin
    .from("users_profiles")
    .select("account_deletion_effective_at")
    .eq("id", user.id)
    .maybeSingle();

  if (pErr) {
    return new Response(JSON.stringify({ error: pErr.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const effective = profile?.account_deletion_effective_at as string | null | undefined;
  if (effective == null) {
    return new Response(JSON.stringify({ success: true, action: "noop" }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const due = Date.parse(effective) <= Date.now();
  if (!due) {
    return new Response(
      JSON.stringify({ success: false, code: "GRACE_STILL_ACTIVE" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const outcome = await banThenPurgeThenDeleteAuth(admin, user.id);
  if (!outcome.ok) {
    if (outcome.code === "PURGE_FAILED") {
      return new Response(
        JSON.stringify({
          error: "purge_failed",
          step: outcome.step,
          message: outcome.message,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    return new Response(
      JSON.stringify({
        error: outcome.message ?? outcome.code,
        code: outcome.code,
        step: outcome.step,
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  return new Response(JSON.stringify({ success: true, action: "deleted" }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  );
});
