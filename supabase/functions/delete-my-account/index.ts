import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { purgeUserBusinessData } from "../_shared/purge_user_business_data.ts";
import { createServiceRoleClient } from "../_shared/create_service_role_client.ts";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, x-client-info, content-type"
};
Deno.serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders
    });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({
      error: "Method not allowed"
    }), {
      status: 405,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({
      error: "未登录",
      code: "UNAUTHORIZED"
    }), {
      status: 401,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  const token = authHeader.replace("Bearer ", "");
  const verifyClient = createServiceRoleClient();
  const { data: { user }, error: userError } = await verifyClient.auth.getUser(token);
  if (userError || !user) {
    return new Response(JSON.stringify({
      error: "用户无效",
      code: "INVALID_USER"
    }), {
      status: 401,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  const admin = createServiceRoleClient();
  const purged = await purgeUserBusinessData(admin, user.id);
  if (!purged.ok) {
    return new Response(JSON.stringify({
      error: "删除业务数据失败",
      code: "PURGE_FAILED",
      step: purged.step,
      message: purged.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("delete auth.users failed:", deleteError);
    return new Response(JSON.stringify({
      error: "删除认证账户失败",
      code: "DELETE_AUTH_FAILED"
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  return new Response(JSON.stringify({
    success: true
  }), {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json"
    }
  });
});
