import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js";

const ALLOWED_EMAIL = "739319163@qq.com";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, x-client-info, content-type",
};

function random8DigitCode(): string {
  return String(Math.floor(10000000 + Math.random() * 90000000));
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
  if (req.method !== "POST" && req.method !== "GET") {
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

  const email = (user.email ?? "").trim().toLowerCase();
  if (email !== ALLOWED_EMAIL) {
    return new Response(
      JSON.stringify({ error: "该功能暂未对小主们开放", code: "NOT_ALLOWED" }),
      { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const userId = user.id;

  const { data: existing } = await supabase
    .from("invitation_codes")
    .select("code")
    .eq("owner_id", userId)
    .maybeSingle();

  if (existing?.code) {
    return new Response(JSON.stringify({ code: existing.code }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  for (let attempt = 0; attempt < 20; attempt++) {
    const code = random8DigitCode();
    const { error: insertError } = await supabase.from("invitation_codes").insert({
      code,
      is_lifetime: true,
      owner_id: userId,
    });
    if (!insertError) {
      return new Response(JSON.stringify({ code }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (insertError.code !== "23505") {
      console.error(insertError);
      return new Response(JSON.stringify({ error: "生成失败", code: "SERVER_ERROR" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  }

  return new Response(JSON.stringify({ error: "生成邀请码失败，请重试", code: "CONFLICT" }), {
    status: 500,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
