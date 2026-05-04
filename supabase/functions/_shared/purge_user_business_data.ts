import type { SupabaseClient } from "jsr:@supabase/supabase-js";

/**
 * 通过数据库 SECURITY DEFINER RPC 删除业务数据（绕过 RLS），顺序与 App 端一致。
 * 须先部署迁移 `20260505180000_purge_user_business_data_rpc.sql`。
 * 不含 auth.users 删除。
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
