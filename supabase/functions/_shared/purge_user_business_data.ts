import type { SupabaseClient } from "jsr:@supabase/supabase-js";

/**
 * 通过数据库 SECURITY DEFINER RPC 删除业务数据（绕过 RLS），顺序与 App 端一致。
 * 须部署 purge_user_business_data 相关迁移（含保留 users_profiles 至 Auth 删除成功之后的版本）。
 * 不删除 users_profiles（冷静期标记 / Auth 删除失败补偿）；不含 auth.users 删除。
 * 即时注销路径由 banThenPurgeThenDeleteAuth 先封禁再调用本 RPC。
 */
export async function purgeUserBusinessData(
  sb: SupabaseClient,
  userId: string,
): Promise<{ ok: true } | { ok: false; step: string; message: string }> {
  const { error } = await sb.rpc("purge_user_business_data", {
    p_target_user_id: userId,
  });

  if (error) {
    console.error("purgeUserBusinessData[rpc]", error);
    return {
      ok: false,
      step: "purge_user_business_data_rpc",
      message: error.message,
    };
  }

  return { ok: true };
}
