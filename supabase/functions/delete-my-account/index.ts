import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { banThenPurgeThenDeleteAuth } from "../_shared/ban_purge_delete_auth.ts";
import { createServiceRoleClient } from "../_shared/create_service_role_client.ts";

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

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "未登录", code: "UNAUTHORIZED" }), {
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
    return new Response(JSON.stringify({ error: "用户无效", code: "INVALID_USER" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const admin = createServiceRoleClient();
  const outcome = await banThenPurgeThenDeleteAuth(admin, user.id);
  if (!outcome.ok) {
    if (outcome.code === "BAN_FAILED") {
      return new Response(
        JSON.stringify({
          error: "无法阻断账号登录，请稍后重试",
          code: outcome.code,
          step: outcome.step,
          message: outcome.message,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    if (outcome.code === "PURGE_FAILED") {
      return new Response(
        JSON.stringify({
          error: "删除业务数据失败",
          code: "PURGE_FAILED",
          step: outcome.step,
          message: outcome.message,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    return new Response(
      JSON.stringify({
        error: "删除认证账户失败（已加入自动重试）",
        code: "DELETE_AUTH_FAILED",
        step: outcome.step,
        message: outcome.message,
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
