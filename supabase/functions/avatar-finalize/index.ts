import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { requireUserFromRequest, serviceClient } from "../_shared/auth.ts";
import { createTraceId } from "../_shared/trace.ts";
import { executeImageModeration } from "../_shared/moderation_provider.ts";
import { writeModerationError, writeModerationLog } from "../_shared/moderation_logger.ts";

const AVATARS_TEMP_BUCKET = "user-avatars-temp";
const AVATARS_BUCKET = "user-avatars";

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Content-Type": "application/json",
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method Not Allowed" }), {
      status: 405,
      headers: corsHeaders(),
    });
  }

  const traceId = createTraceId();
  let userId = "";
  let tempPath = "";
  try {
    const auth = await requireUserFromRequest(req);
    if ("error" in auth) {
      return auth.error;
    }
    userId = auth.userId;
    const body = await req.json().catch(() => ({}));
    tempPath = (body?.temp_path ?? "").toString();
    if (!tempPath || !tempPath.startsWith(`${userId}/`)) {
      return new Response(JSON.stringify({
        passed: false,
        scene: "avatar",
        riskLevel: "unknown",
        riskLabels: ["unauthorized_resource"],
        action: "block",
        message: "非法头像路径",
        traceId,
        errorCode: "MODERATION_UNAUTHORIZED",
      }), { status: 403, headers: corsHeaders() });
    }

    const moderationExec = await executeImageModeration("avatar", undefined, tempPath, traceId);
    const moderationResult = moderationExec.result;
    await writeModerationLog({
      userId,
      scene: "avatar",
      traceId,
      result: moderationResult,
      resourcePath: tempPath,
      provider: moderationExec.provider,
      providerResponse: moderationExec.providerResponse,
    });
    if (!moderationResult.passed) {
      return new Response(JSON.stringify(moderationResult), {
        status: 200,
        headers: corsHeaders(),
      });
    }

    const { data: fileBytes, error: downloadError } = await serviceClient.storage
      .from(AVATARS_TEMP_BUCKET)
      .download(tempPath);
    if (downloadError || !fileBytes) {
      throw new Error(downloadError?.message ?? "头像下载失败");
    }

    const finalPath = `${userId}/avatar.jpg`;
    const { error: uploadError } = await serviceClient.storage
      .from(AVATARS_BUCKET)
      .upload(finalPath, fileBytes, {
        contentType: "image/jpeg",
        upsert: true,
      });
    if (uploadError) {
      throw new Error(uploadError.message);
    }

    await serviceClient.storage.from(AVATARS_TEMP_BUCKET).remove([tempPath]);
    const avatarUrl = serviceClient.storage.from(AVATARS_BUCKET).getPublicUrl(finalPath).data.publicUrl;
    await serviceClient.from("users_profiles").upsert({
      id: userId,
      avatar_url: avatarUrl,
      updated_at: new Date().toISOString(),
    });

    return new Response(JSON.stringify({
      passed: true,
      scene: "avatar",
      riskLevel: "none",
      riskLabels: [],
      action: "allow",
      message: "ok",
      traceId,
      avatar_url: avatarUrl,
      path: finalPath,
    }), { status: 200, headers: corsHeaders() });
  } catch (error) {
    await writeModerationError({
      traceId,
      userId: userId || undefined,
      scene: "avatar",
      errorCode: "MODERATION_PROVIDER_ERROR",
      errorMessage: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
      contextJson: tempPath ? { tempPath } : undefined,
    });
    return new Response(JSON.stringify({
      passed: false,
      scene: "avatar",
      riskLevel: "unknown",
      riskLabels: [],
      action: "block",
      message: "头像处理失败",
      traceId,
      errorCode: "MODERATION_PROVIDER_ERROR",
    }), { status: 500, headers: corsHeaders() });
  }
});

