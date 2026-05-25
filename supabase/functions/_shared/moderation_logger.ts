import type { ModerationResult, ModerationScene } from "./moderation_contract.ts";
import { serviceClient } from "./auth.ts";

export async function writeModerationLog(params: {
  userId: string;
  scene: ModerationScene;
  traceId: string;
  result: ModerationResult;
  contentExcerpt?: string;
  resourcePath?: string;
  provider?: string;
  providerResponse?: Record<string, unknown>;
}) {
  const { userId, scene, traceId, result } = params;
  const excerpt = (params.contentExcerpt ?? "").slice(0, 500);
  await serviceClient.from("moderation_logs").insert({
    user_id: userId,
    scene,
    trace_id: traceId,
    result: result.passed ? "pass" : "block",
    risk_level: result.riskLevel,
    risk_labels: result.riskLabels,
    content_excerpt: excerpt || null,
    resource_path: params.resourcePath ?? null,
    provider: params.provider ?? "local_fallback",
    provider_response: params.providerResponse ?? null,
  });
}

export async function writeModerationError(params: {
  userId?: string;
  scene?: string;
  traceId: string;
  errorCode: string;
  errorMessage: string;
  stack?: string;
  contextJson?: Record<string, unknown>;
}) {
  await serviceClient.from("moderation_errors").insert({
    user_id: params.userId ?? null,
    scene: params.scene ?? null,
    trace_id: params.traceId,
    error_code: params.errorCode,
    error_message: params.errorMessage,
    stack: params.stack ?? null,
    context_json: params.contextJson ?? null,
  });
}

