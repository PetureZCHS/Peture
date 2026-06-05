import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { requireUserFromRequest } from "../_shared/auth.ts";
import {
  isValidScene,
  MODERATION_ERROR_CODES,
  type ModerationScene,
} from "../_shared/moderation_contract.ts";
import { createTraceId } from "../_shared/trace.ts";
import { executeTextModeration } from "../_shared/moderation_provider.ts";
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
  try {
    const auth = await requireUserFromRequest(req);
    if ("error" in auth) {
      const data = await auth.error.json().catch(() => ({}));
      return new Response(
        JSON.stringify({
          passed: false,
          scene: "nickname",
          riskLevel: "unknown",
          riskLabels: [],
          action: "block",
          message: data.error ?? "Unauthorized",
          traceId,
          errorCode: MODERATION_ERROR_CODES.unauthorized,
        }),
        { status: 401, headers: corsHeaders() },
      );
    }
    requestUserId = auth.userId;

    const body = await req.json().catch(() => ({}));
    const scene = (body?.scene ?? "") as string;
    const content = (body?.content ?? "").toString();
    if (!isValidScene(scene)) {
      return new Response(
        JSON.stringify({
          passed: false,
          scene: "nickname",
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
    if (!content.trim()) {
      return new Response(
        JSON.stringify({
          passed: false,
          scene,
          riskLevel: "unknown",
          riskLabels: [],
          action: "block",
          message: "content is required",
          traceId,
          errorCode: MODERATION_ERROR_CODES.invalidRequest,
        }),
        { status: 400, headers: corsHeaders() },
      );
    }

    const moderation = await executeTextModeration(scene as ModerationScene, content, traceId);
    const result = moderation.result;
    await writeModerationLog({
      userId: auth.userId,
      scene: scene as ModerationScene,
      traceId,
      result,
      contentExcerpt: content,
      provider: moderation.provider,
      providerResponse: moderation.providerResponse,
    });

    return new Response(JSON.stringify(result), { status: 200, headers: corsHeaders() });
  } catch (error) {
    await writeModerationError({
      traceId,
      userId: requestUserId,
      scene: "nickname",
      errorCode: MODERATION_ERROR_CODES.providerError,
      errorMessage: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });
    return new Response(
      JSON.stringify({
        passed: false,
        scene: "nickname",
        riskLevel: "unknown",
        riskLabels: [],
        action: "block",
        message: "审核服务异常",
        traceId,
        errorCode: MODERATION_ERROR_CODES.providerError,
      }),
      { status: 500, headers: corsHeaders() },
    );
  }
});

