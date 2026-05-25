import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { requireUserFromRequest } from "../_shared/auth.ts";
import {
  isValidScene,
  MODERATION_ERROR_CODES,
  type ModerationScene,
} from "../_shared/moderation_contract.ts";
import { createTraceId } from "../_shared/trace.ts";
import { executeImageModeration } from "../_shared/moderation_provider.ts";
import { writeModerationError, writeModerationLog } from "../_shared/moderation_logger.ts";

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
  let requestUserId: string | undefined;
  let requestScene = "avatar";
  try {
    const auth = await requireUserFromRequest(req);
    if ("error" in auth) {
      return new Response(
        JSON.stringify({
          passed: false,
          scene: "avatar",
          riskLevel: "unknown",
          riskLabels: [],
          action: "block",
          message: "Unauthorized",
          traceId,
          errorCode: MODERATION_ERROR_CODES.unauthorized,
        }),
        { status: 401, headers: corsHeaders() },
      );
    }
    requestUserId = auth.userId;

    const body = await req.json().catch(() => ({}));
    const scene = (body?.scene ?? "") as string;
    requestScene = scene || "avatar";
    const imageBase64 = body?.image_base64?.toString();
    const storagePath = body?.storage_path?.toString();
    if (!isValidScene(scene)) {
      return new Response(
        JSON.stringify({
          passed: false,
          scene: "avatar",
          riskLevel: "unknown",
          riskLabels: [],
          action: "block",
          message: "Invalid scene",
          traceId,
          errorCode: MODERATION_ERROR_CODES.invalidRequest,
        }),
        { status: 400, headers: corsHeaders() },
      );
    }
    if (!imageBase64 && !storagePath) {
      return new Response(
        JSON.stringify({
          passed: false,
          scene,
          riskLevel: "unknown",
          riskLabels: [],
          action: "block",
          message: "image_base64 or storage_path is required",
          traceId,
          errorCode: MODERATION_ERROR_CODES.invalidRequest,
        }),
        { status: 400, headers: corsHeaders() },
      );
    }
    if (storagePath && !storagePath.startsWith(`${auth.userId}/`)) {
      return new Response(
        JSON.stringify({
          passed: false,
          scene,
          riskLevel: "high",
          riskLabels: ["unauthorized_resource"],
          action: "block",
          message: "storage path is not owned by current user",
          traceId,
          errorCode: MODERATION_ERROR_CODES.unauthorized,
        }),
        { status: 403, headers: corsHeaders() },
      );
    }

    const moderation = await executeImageModeration(
      scene as ModerationScene,
      imageBase64,
      storagePath,
      traceId,
    );
    const result = moderation.result;
    await writeModerationLog({
      userId: auth.userId,
      scene: scene as ModerationScene,
      traceId,
      result,
      resourcePath: storagePath,
      provider: moderation.provider,
      providerResponse: moderation.providerResponse,
    });
    return new Response(JSON.stringify(result), { status: 200, headers: corsHeaders() });
  } catch (error) {
    await writeModerationError({
      traceId,
      userId: requestUserId,
      scene: requestScene,
      errorCode: MODERATION_ERROR_CODES.providerError,
      errorMessage: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });
    return new Response(
      JSON.stringify({
        passed: false,
        scene: "avatar",
        riskLevel: "unknown",
        riskLabels: [],
        action: "block",
        message: "图像审核服务异常",
        traceId,
        errorCode: MODERATION_ERROR_CODES.providerError,
      }),
      { status: 500, headers: corsHeaders() },
    );
  }
});

