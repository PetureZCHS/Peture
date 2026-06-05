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

const REQUIRED_INPUT_FIELDS = ["query", "style", "nickname", "species", "breed", "owner_title"] as const;

Deno.serve(async (req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: corsHeaders,
    });
  }

  const traceId = createTraceId();
  let requestUserId = "";
  let body: unknown;
  try {
    body = await req.json();
  } catch {
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

  const { inputs, response_mode } = (body ?? {}) as {
    inputs?: Record<string, unknown>;
    response_mode?: string;
  };

  if (!inputs || typeof inputs !== "object") {
    return new Response(JSON.stringify({ error: "Missing required 'inputs' object in request body." }), {
      status: 400,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  }

  const missingFields = REQUIRED_INPUT_FIELDS.filter((field) => {
    const value = inputs[field];
    return value === undefined || value === null;
  });
  if (missingFields.length > 0) {
    return new Response(
      JSON.stringify({
        error: `Missing required parameters in inputs: ${missingFields.join(", ")}`,
      }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }

  const inputQuery = (inputs.query ?? "").toString();
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
    Authorization: `Bearer ${apiKey}`,
    "Content-Type": "application/json",
  };
  const payload = {
    inputs,
    response_mode: mode,
    user: requestUserId,
  };

  if (mode === "streaming") {
    const upstream = await fetch(DIFY_API, {
      method: "POST",
      headers: {
        ...baseHeaders,
        Accept: "text/event-stream",
      },
      body: JSON.stringify(payload),
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
      Connection: "keep-alive",
    });

    let visibleOutputBuffer = "";
    let pendingSegment = "";
    let lastAuditAt = Date.now();
    let sseBuffer = "";
    let blocked = false;
    const allowedEvents = new Set(["text_chunk", "workflow_finished", "error"]);

    const moderatedStream = upstream.body.pipeThrough(
      new TransformStream({
        async transform(chunk, controller) {
          if (blocked) return;
          sseBuffer += new TextDecoder().decode(chunk);
          while (sseBuffer.includes("\n\n")) {
            const endIndex = sseBuffer.indexOf("\n\n");
            const message = sseBuffer.slice(0, endIndex);
            sseBuffer = sseBuffer.slice(endIndex + 2);
            const line = message.trim();
            if (!line.startsWith("data:")) {
              continue;
            }
            const dataString = line.slice(5).trim();
            if (!dataString || dataString === "[DONE]") {
              controller.enqueue(new TextEncoder().encode(`${message}\n\n`));
              continue;
            }
            try {
              const eventData = JSON.parse(dataString) as Record<string, unknown>;
              const eventName = eventData?.event?.toString?.() ?? "";
              if (!allowedEvents.has(eventName)) {
                continue;
              }
              if (eventName === "text_chunk") {
                const piece = (eventData?.data as Record<string, unknown> | undefined)?.text?.toString?.() ?? "";
                if (piece) {
                  visibleOutputBuffer += piece;
                  pendingSegment += piece;
                  if (shouldTriggerOutputAudit(pendingSegment, lastAuditAt)) {
                    const prefixLength = visibleOutputBuffer.length - pendingSegment.length;
                    const contextPrefix = prefixLength > 0
                      ? visibleOutputBuffer.slice(0, prefixLength).slice(-OUTPUT_AUDIT_TAIL_CONTEXT)
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
                        contentExcerpt: visibleOutputBuffer,
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
                  (eventData as { data?: Record<string, unknown> }).data = {
                    ...((eventData.data as Record<string, unknown> | undefined) ?? {}),
                    text: piece,
                  };
                }
              }
              const outText = ((eventData?.data as Record<string, unknown> | undefined)?.text?.toString?.() ?? "");
              if (eventName !== "text_chunk" || outText.length > 0) {
                controller.enqueue(new TextEncoder().encode(`data: ${JSON.stringify(eventData)}\n\n`));
              }
            } catch {
              // ignore malformed json event
            }
          }
        },
        async flush() {
          if (!blocked && visibleOutputBuffer) {
            const outputModerationExec = await executeTextModeration("diary_output", visibleOutputBuffer, traceId);
            const outputModeration = outputModerationExec.result;
            await writeModerationLog({
              userId: requestUserId,
              scene: "diary_output",
              traceId,
              result: outputModeration,
              contentExcerpt: visibleOutputBuffer,
              provider: outputModerationExec.provider,
              providerResponse: outputModerationExec.providerResponse,
            });
          }
        },
      }),
    );

    return new Response(moderatedStream, {
      status: upstream.status,
      headers: sseHeaders,
    });
  }

  const resp = await fetch(DIFY_API, {
    method: "POST",
    headers: baseHeaders,
    body: JSON.stringify(payload),
  });
  const respText = await resp.text();
  let respJson: Record<string, unknown> | null = null;
  try {
    respJson = JSON.parse(respText) as Record<string, unknown>;
  } catch {
    // noop
  }

  const outputText =
    ((respJson?.data as Record<string, unknown> | undefined)?.outputs as Record<string, unknown> | undefined)?.text
      ?.toString?.() ?? "";

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
        },
      });
    }
  }

  return new Response(respText, {
    status: resp.status,
    headers: {
      ...corsHeaders,
      "Content-Type": resp.headers.get("Content-Type") ?? "application/json",
    },
  });
});
