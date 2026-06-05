import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, x-client-info, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
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

  const { data: { user }, error: userError } = await supabase.auth.getUser(
    authHeader.replace("Bearer ", "")
  );
  if (userError || !user) {
    return new Response(JSON.stringify({ error: "用户无效", code: "INVALID_USER" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const userId = user.id;
  let body: { code?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "请求体无效", code: "BAD_REQUEST" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const code = typeof body?.code === "string" ? body.code.trim() : "";
  if (!code || code.length < 4) {
    return new Response(JSON.stringify({ error: "邀请码无效", code: "INVALID_CODE" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { data: row, error: fetchError } = await supabase
    .from("invitation_codes")
    .select("id, used_by")
    .eq("code", code)
    .maybeSingle();

  if (fetchError) {
    console.error(fetchError);
    return new Response(JSON.stringify({ error: "服务异常", code: "SERVER_ERROR" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  if (!row) {
    return new Response(JSON.stringify({ error: "邀请码不存在或已失效", code: "CODE_NOT_FOUND" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  if (row.used_by) {
    return new Response(JSON.stringify({ error: "该邀请码已被使用", code: "CODE_ALREADY_USED" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { error: updateCodeError } = await supabase
    .from("invitation_codes")
    .update({ used_by: userId, used_at: new Date().toISOString() })
    .eq("id", row.id);

  if (updateCodeError) {
    console.error(updateCodeError);
    return new Response(JSON.stringify({ error: "兑换失败", code: "UPDATE_FAILED" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { data: updated } = await supabase
    .from("users_profiles")
    .update({ membership_type: "lifetime", updated_at: new Date().toISOString() })
    .eq("id", userId)
    .select("id")
    .maybeSingle();
  if (!updated) {
    await supabase.from("users_profiles").insert({
      id: userId,
      membership_type: "lifetime",
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
  }

  return new Response(JSON.stringify({ success: true, message: "已开通终身会员" }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
