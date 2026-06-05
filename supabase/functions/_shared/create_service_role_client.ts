import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js";

/**
 * 新建仅用于服务端（service_role）的 Supabase 客户端。
 *
 * 不要在同一实例上先 `auth.getUser(userJwt)` 再执行 `.from().delete()`：
 * 部分运行环境下会话会“粘”在用户 JWT 上，PostgREST 会按 authenticated + RLS 执行，
 * 业务表若仅有「本人可删」策略会出现 `permission_denied`。
 *
 * 校验用户 JWT 请用单独短生命周期 client；清库 / admin 操作用本函数新建的另一个 client。
 */
export function createServiceRoleClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  return createClient(url, key, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
    global: {
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
      },
    },
  });
}
