import type { SupabaseClient } from "jsr:@supabase/supabase-js";
import { purgeUserBusinessData } from "./purge_user_business_data.ts";

/** GoTrue `ban_duration`，足够长以视为注销路径下的永久封禁 */
export const ACCOUNT_DELETION_BAN_DURATION = "876000h";

export type BanPurgeDeleteResult =
  | { ok: true }
  | {
      ok: false;
      code: "BAN_FAILED" | "PURGE_FAILED" | "DELETE_AUTH_FAILED";
      step: string;
      message?: string;
    };

/**
 * 两阶段即时注销：先封禁（阻断登录）→ 清业务数据 → 删 auth.users。
 * 若最后一步失败：业务已空且账号不可用；并入队供 Cron 仅重试 deleteUser。
 */
export async function banThenPurgeThenDeleteAuth(
  admin: SupabaseClient,
  userId: string,
): Promise<BanPurgeDeleteResult> {
  const { error: banErr } = await admin.auth.admin.updateUserById(userId, {
    ban_duration: ACCOUNT_DELETION_BAN_DURATION,
  });
  if (banErr) {
    console.error("ban user failed:", banErr);
    return {
      ok: false,
      code: "BAN_FAILED",
      step: "ban_user",
      message: banErr.message,
    };
  }

  const purged = await purgeUserBusinessData(admin, userId);
  if (!purged.ok) {
    return {
      ok: false,
      code: "PURGE_FAILED",
      step: purged.step,
      message: purged.message,
    };
  }

  const { error: delErr } = await admin.auth.admin.deleteUser(userId);
  if (delErr) {
    console.error("delete auth.users failed:", delErr);
    const { error: qErr } = await admin.from("account_auth_delete_retry_queue").upsert(
      {
        user_id: userId,
        enqueued_at: new Date().toISOString(),
        last_error: delErr.message,
      },
      { onConflict: "user_id" },
    );
    if (qErr) console.error("enqueue auth delete retry failed:", qErr);
    return {
      ok: false,
      code: "DELETE_AUTH_FAILED",
      step: "delete_auth",
      message: delErr.message,
    };
  }

  return { ok: true };
}
