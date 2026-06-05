import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js";
const supabase = createClient(Deno.env.get("SUPABASE_URL"), Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));
// 查询用户余额
async function getUserQuota(userId: string) {
  const { data, error } = await supabase.from('test').select('quota').eq('user_id', userId).single();
  if (error) {
    console.error('Error fetching user quota:', error);
    return null;
  }
  return data?.quota || 0;
}
Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", {
      status: 405
    });
  }
  let body;
  try {
    body = await req.json();
  } catch {
    return new Response("Bad Request", {
      status: 400
    });
  }
  const { amount } = body ?? {};
  if (!amount || isNaN(amount)) {
    return new Response("Invalid amount", {
      status: 400
    });
  }

  // CORS headers 配置
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, x-client-info, content-type"
  };
  // ---------------- SECURITY CHANGE START ----------------
  // 安全修改：通过 Authorization Header 获取真实用户 ID
  // 通过 Supabase 的 Auth Token（JWT）解析出当前登录的用户 ID

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response("Missing Authorization Header", {
      status: 401,
      headers: corsHeaders
    });
  }

  // 提取 Token (去掉 'Bearer ' 前缀)
  const token = authHeader.replace('Bearer ', '');

  // 使用 Supabase Auth 验证 Token 并获取用户信息
  const { data: { user: authUser }, error: authError } = await supabase.auth.getUser(token);

  if (authError || !authUser) {
    return new Response("Unauthorized / Invalid Token", {
      status: 401,
      headers: corsHeaders
    });
  }

  // 【关键】强制覆盖 user 变量，使用鉴权后的真实 ID
  const user = authUser.id;

  // ---------------- SECURITY CHANGE END ------------------

  let amount_to_add = Number(amount) * 100000;

  // 1. 获取当前余额
  let quota = await getUserQuota(user);

  if (quota === null) {
    // ----------------------------------------
    // 分支 A：用户不存在，新建条目 (Insert)
    // ----------------------------------------
    const { error: insertError } = await supabase
      .from('test')
      .insert({
        user_id: user,
        quota: amount_to_add
      });

    if (insertError) {
      console.error('Insert Error:', insertError);
      return new Response(JSON.stringify({ error: 'Failed to create user account' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // 逻辑同步：将内存中的 quota 更新为初始值
    quota = amount_to_add;

  } else {
    // ----------------------------------------
    // 分支 B：用户已存在，自增余额 (Update)
    // ----------------------------------------

    // 计算新的余额
    const newQuota = quota + amount_to_add;

    const { error: updateError } = await supabase
      .from('test')
      .update({ quota: newQuota })
      .eq('user_id', user); // 【重要】必须使用 .eq 锁定当前用户 ID

    if (updateError) {
      console.error('Update Error:', updateError);
      return new Response(JSON.stringify({ error: 'Failed to update quota' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // 逻辑同步：将内存中的 quota 更新为新值
    quota = newQuota;
  }

  // ----------------------------------------
  // 返回成功响应
  // ----------------------------------------
  return new Response(JSON.stringify({
    success: true,
    message: "Recharge successful",
    current_quota: quota
  }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
});
