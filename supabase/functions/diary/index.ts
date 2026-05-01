import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createTraceId } from "../_shared/trace.ts";
import { executeTextModeration } from "../_shared/moderation_provider.ts";
import { writeModerationLog } from "../_shared/moderation_logger.ts";
import { requireUserFromRequest } from "../_shared/auth.ts";

const apiKey =
  Deno.env.get("DIFY_DIARY_V4_API_KEY") ??
  Deno.env.get("DIFY_DIARY_API_KEY");
const DIFY_API = "https://api.dify.ai/v1/workflows/run";
const OUTPUT_AUDIT_MIN_CHARS = Number(Deno.env.get("OUTPUT_AUDIT_MIN_CHARS") ?? "100");
const OUTPUT_AUDIT_MAX_INTERVAL_MS = Number(Deno.env.get("OUTPUT_AUDIT_MAX_INTERVAL_MS") ?? "800");
const OUTPUT_AUDIT_TAIL_CONTEXT = Number(Deno.env.get("OUTPUT_AUDIT_TAIL_CONTEXT") ?? "40");
const OUTPUT_AUDIT_PUNCTUATION_MIN_CHARS = Number(Deno.env.get("OUTPUT_AUDIT_PUNCTUATION_MIN_CHARS") ?? "30");

function shouldTriggerOutputAudit(pendingSegment: string, lastAuditAt: number): boolean {
  if (!pendingSegment) return false;
  if (pendingSegment.length >= OUTPUT_AUDIT_MIN_CHARS) return true;
  if (Date.now() - lastAuditAt >= OUTPUT_AUDIT_MAX_INTERVAL_MS) return true;
  const lastChar = pendingSegment[pendingSegment.length - 1] ?? "";
  if (/[\n。！？!?；;]/.test(lastChar) && pendingSegment.length >= OUTPUT_AUDIT_PUNCTUATION_MIN_CHARS) {
    return true;
  }
  return false;
}

Deno.serve(async (req)=>{
  // CORS headers 配置
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  // Handle CORS preflight requests / 处理 CORS 预检请求
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: corsHeaders,
    });
  }
  const traceId = createTraceId();
  let requestUserId = "";
  let body;
  try {
    body = await req.json();
  } catch  {
    return new Response("Bad Request", {
      status: 400,
      headers: corsHeaders,
    });
  }
  const auth = await requireUserFromRequest(req);
  if ("error" in auth) {
    return auth.error;
  }
  requestUserId = auth.userId;

  const { inputs, response_mode } = body ?? {};
  const inputQuery = (inputs?.query ?? "").toString();
  const inputModerationExec = await executeTextModeration("diary_input", inputQuery, traceId);
  const inputModeration = inputModerationExec.result;
  await writeModerationLog({
    userId: requestUserId,
    scene: "diary_input",
    traceId,
    result: inputModeration,
    contentExcerpt: inputQuery,
    provider: inputModerationExec.provider,
    providerResponse: inputModerationExec.providerResponse,
  });
  if (!inputModeration.passed) {
    return new Response(JSON.stringify(inputModeration), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  }

  const mode = response_mode === "streaming" ? "streaming" : "blocking";
  if (!apiKey) {
    return new Response("Missing DIFY_DIARY_V4_API_KEY", {
      status: 500,
      headers: corsHeaders,
    });
  }
  const baseHeaders = {
    "Authorization": `Bearer ${apiKey}`,
    "Content-Type": "application/json"
  };
  const payload = {
    inputs,
    response_mode: mode,
    user: requestUserId
  };
  if (mode === "streaming") {
    // 上游以 SSE 返回，函数作为反向代理原样转发事件流
    const upstream = await fetch(DIFY_API, {
      method: "POST",
      headers: {
        ...baseHeaders,
        "Accept": "text/event-stream"
      },
      body: JSON.stringify(payload)
    });
    if (!upstream.body) {
      return new Response("Upstream unavailable", {
        status: 502,
        headers: corsHeaders,
      });
    }
    const sseHeaders = new Headers({
      ...corsHeaders,
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      "Connection": "keep-alive"
    });
    let outputBuffer = "";
    let pendingSegment = "";
    let lastAuditAt = Date.now();
    let blocked = false;
    const moderatedStream = upstream.body.pipeThrough(new TransformStream({
      async transform(chunk, controller) {
        if (blocked) return;
        const text = new TextDecoder().decode(chunk);
        const lines = text.split("\n");
        for (const rawLine of lines) {
          const line = rawLine.trim();
          if (!line.startsWith("data:")) continue;
          try {
            const eventData = JSON.parse(line.slice(5).trim());
            const piece = eventData?.event === "text_chunk"
              ? eventData?.data?.text?.toString?.() ?? ""
              : "";
            if (piece) {
              outputBuffer += piece;
              pendingSegment += piece;
              if (shouldTriggerOutputAudit(pendingSegment, lastAuditAt)) {
                const prefixLength = outputBuffer.length - pendingSegment.length;
                const contextPrefix = prefixLength > 0
                  ? outputBuffer.slice(0, prefixLength).slice(-OUTPUT_AUDIT_TAIL_CONTEXT)
                  : "";
                const sampleForAudit = `${contextPrefix}${pendingSegment}`;
                const outputModerationExec = await executeTextModeration("diary_output", sampleForAudit, traceId);
                const outputModeration = outputModerationExec.result;
                lastAuditAt = Date.now();
                if (!outputModeration.passed) {
                  blocked = true;
                  await writeModerationLog({
                    userId: requestUserId,
                    scene: "diary_output",
                    traceId,
                    result: outputModeration,
                    contentExcerpt: outputBuffer,
                    provider: outputModerationExec.provider,
                    providerResponse: outputModerationExec.providerResponse,
                  });
                  const safePayload =
                    `data: ${JSON.stringify({ event: "text_chunk", data: { text: `该内容未通过审核（traceId: ${traceId}）` } })}\n\n` +
                    `data: ${JSON.stringify({ event: "workflow_finished", data: {} })}\n\n`;
                  controller.enqueue(new TextEncoder().encode(safePayload));
                  return;
                }
                pendingSegment = "";
              }
            }
          } catch {
            // noop
          }
        }
        controller.enqueue(chunk);
      },
      async flush() {
        if (!blocked && outputBuffer) {
          const outputModerationExec = await executeTextModeration("diary_output", outputBuffer, traceId);
          const outputModeration = outputModerationExec.result;
          await writeModerationLog({
            userId: requestUserId,
            scene: "diary_output",
            traceId,
            result: outputModeration,
            contentExcerpt: outputBuffer,
            provider: outputModerationExec.provider,
            providerResponse: outputModerationExec.providerResponse,
          });
        }
      },
    }));
    return new Response(moderatedStream, {
      status: upstream.status,
      headers: sseHeaders
    });
  } else {
    // 阻塞模式：等待完整结果后再返回
    const resp = await fetch(DIFY_API, {
      method: "POST",
      headers: baseHeaders,
      body: JSON.stringify(payload)
    });
    const respText = await resp.text();
    let respJson: Record<string, unknown> | null = null;
    try {
      respJson = JSON.parse(respText);
    } catch {
      // noop
    }
    const outputText = ((respJson?.data as Record<string, unknown> | undefined)?.outputs as Record<string, unknown> | undefined)?.text?.toString?.() ?? "";
    if (outputText) {
      const outputModerationExec = await executeTextModeration("diary_output", outputText, traceId);
      const outputModeration = outputModerationExec.result;
      await writeModerationLog({
        userId: requestUserId,
        scene: "diary_output",
        traceId,
        result: outputModeration,
        contentExcerpt: outputText,
        provider: outputModerationExec.provider,
        providerResponse: outputModerationExec.providerResponse,
      });
      if (!outputModeration.passed && respJson) {
        const data = (respJson.data as Record<string, unknown> | undefined) ?? {};
        const outputs = (data.outputs as Record<string, unknown> | undefined) ?? {};
        outputs.text = `该内容未通过审核（traceId: ${traceId}）`;
        data.outputs = outputs;
        respJson.data = data;
        return new Response(JSON.stringify(respJson), {
          status: resp.status,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          }
        });
      }
    }
    return new Response(respText, {
      status: resp.status,
      headers: {
        ...corsHeaders,
        "Content-Type": resp.headers.get("Content-Type") ?? "application/json"
      }
    });
  }
});
