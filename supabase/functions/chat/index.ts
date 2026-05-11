// Setup type definitions for built-in Supabase Runtime APIs
// 设置 Supabase Runtime API 的类型定义
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { executeTextModeration } from "../_shared/moderation_provider.ts";
import { createTraceId } from "../_shared/trace.ts";
import { writeModerationError, writeModerationLog } from "../_shared/moderation_logger.ts";
import { requireUserFromRequest } from "../_shared/auth.ts";

// 兼容历史命名：优先 DIFY_CHAT_API_KEY，回退 DIFY_API_KEY
const DIFY_API_KEY = Deno.env.get('DIFY_CHAT_API_KEY') ?? Deno.env.get('DIFY_API_KEY');
const DIFY_BASE_URL = 'https://api.dify.ai/v1';
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
Deno.serve(async (req) => {
  // CORS headers 配置
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
  };
  // Handle CORS preflight requests / 处理 CORS 预检请求
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  const traceId = createTraceId();
  let requestUserId = "";
  try {
    const auth = await requireUserFromRequest(req);
    if ("error" in auth) {
      return auth.error;
    }
    requestUserId = auth.userId;
    if (!DIFY_API_KEY?.trim()) {
      return new Response(
        JSON.stringify({
          error: "服务端未配置 Dify API Key，请在 Supabase Edge Functions Secrets 中设置 DIFY_CHAT_API_KEY（或兼容的 DIFY_API_KEY）",
          errorCode: "DIFY_API_KEY_MISSING",
          status: 503,
          code: "config_error",
        }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
    // Parse request body / 解析请求体
    const requestBody = await req.json();
    // Validate required fields / 验证必填字段
    if (!requestBody.query) {
      return new Response(JSON.stringify({
        error: 'Missing required field: query'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    requestBody.user = requestUserId;
    // Default to streaming mode / 默认使用流式模式
    const responseMode = requestBody.response_mode || 'streaming';
    const inputModerationExec = await executeTextModeration("ai_input", String(requestBody.query), traceId);
    const inputModeration = inputModerationExec.result;
    await writeModerationLog({
      userId: requestUserId,
      scene: "ai_input",
      traceId,
      result: inputModeration,
      contentExcerpt: String(requestBody.query),
      provider: inputModerationExec.provider,
      providerResponse: inputModerationExec.providerResponse,
    });
    if (!inputModeration.passed) {
      return new Response(JSON.stringify(inputModeration), {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Prepare request to Dify API / 准备发送到 Dify API 的请求
    const difyResponse = await fetch(`${DIFY_BASE_URL}/chat-messages`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${DIFY_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        ...requestBody,
        response_mode: responseMode
      })
    });
    // Handle API errors / 处理 API 错误
    if (!difyResponse.ok) {
      const errorData = await difyResponse.json();
      await writeModerationError({
        traceId,
        userId: requestUserId,
        scene: "ai_output",
        errorCode: "MODERATION_PROVIDER_ERROR",
        errorMessage: errorData.message || "Dify API request failed",
        contextJson: { status: difyResponse.status, code: errorData.code },
      });
      return new Response(JSON.stringify({
        error: errorData.message || 'Dify API request failed',
        status: difyResponse.status,
        code: errorData.code
      }), {
        status: difyResponse.status,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Handle streaming response / 处理流式响应
    // SSE (Server-Sent Events) format for real-time output
    // SSE（服务器推送事件）格式，用于实时输出
    if (responseMode === 'streaming') {
      const stream = difyResponse.body;
      if (!stream) {
        return new Response(JSON.stringify({
          error: "Upstream stream unavailable",
          traceId,
        }), {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      let outputBuffer = "";
      let pendingSegment = "";
      let lastAuditAt = Date.now();
      let blocked = false;
      const moderatedStream = stream.pipeThrough(new TransformStream({
        async transform(chunk, controller) {
          if (blocked) return;
          const text = new TextDecoder().decode(chunk);
          const lines = text.split("\n");
          for (const rawLine of lines) {
            const line = rawLine.trim();
            if (!line.startsWith("data:")) continue;
            try {
              const eventData = JSON.parse(line.slice(5).trim());
              const answer = eventData?.answer?.toString?.() ?? "";
              if (answer) {
                outputBuffer += answer;
                pendingSegment += answer;
                if (shouldTriggerOutputAudit(pendingSegment, lastAuditAt)) {
                  const prefixLength = outputBuffer.length - pendingSegment.length;
                  const contextPrefix = prefixLength > 0
                    ? outputBuffer.slice(0, prefixLength).slice(-OUTPUT_AUDIT_TAIL_CONTEXT)
                    : "";
                  const sampleForAudit = `${contextPrefix}${pendingSegment}`;
                  const outputModerationExec = await executeTextModeration("ai_output", sampleForAudit, traceId);
                  const outputModeration = outputModerationExec.result;
                  lastAuditAt = Date.now();
                  if (!outputModeration.passed) {
                    blocked = true;
                    await writeModerationLog({
                      userId: requestUserId,
                      scene: "ai_output",
                      traceId,
                      result: outputModeration,
                      contentExcerpt: outputBuffer,
                      provider: outputModerationExec.provider,
                      providerResponse: outputModerationExec.providerResponse,
                    });
                    // 勿伪装成 Dify 的 message/answer：客户端会把 answer 当增量拼接，导致「正常半句 + 拦截句」粘在一起
                    const safePayload =
                      `data: ${JSON.stringify({
                        event: "moderation_intercept",
                        message: `该回复因内容审核未通过，已被拦截（traceId: ${traceId}）`,
                        traceId,
                      })}\n\n` +
                      `data: ${JSON.stringify({ event: "message_end" })}\n\n`;
                    controller.enqueue(new TextEncoder().encode(safePayload));
                    return;
                  }
                  pendingSegment = "";
                }
              }
            } catch (_e) {
              // noop
            }
          }
          controller.enqueue(chunk);
        },
        async flush() {
          if (!blocked && outputBuffer) {
            const outputModerationExec = await executeTextModeration("ai_output", outputBuffer, traceId);
            const outputModeration = outputModerationExec.result;
            await writeModerationLog({
              userId: requestUserId,
              scene: "ai_output",
              traceId,
              result: outputModeration,
              contentExcerpt: outputBuffer,
              provider: outputModerationExec.provider,
              providerResponse: outputModerationExec.providerResponse,
            });
          }
        }
      }));
      return new Response(moderatedStream, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive'
        }
      });
    }
    // Handle blocking response / 处理阻塞模式响应
    // Returns complete result after execution / 等待执行完毕后返回完整结果
    const data = await difyResponse.json();
    const outputText = data?.answer?.toString?.() ?? "";
    if (outputText) {
      const outputModerationExec = await executeTextModeration("ai_output", outputText, traceId);
      const outputModeration = outputModerationExec.result;
      await writeModerationLog({
        userId: requestUserId,
        scene: "ai_output",
        traceId,
        result: outputModeration,
        contentExcerpt: outputText,
        provider: outputModerationExec.provider,
        providerResponse: outputModerationExec.providerResponse,
      });
      if (!outputModeration.passed) {
        data.answer = `该回复因内容审核未通过，已被拦截（traceId: ${traceId}）`;
      }
    }
    return new Response(JSON.stringify(data), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    // Error handling and logging / 错误处理和日志记录
    console.error('Error:', error);
    await writeModerationError({
      traceId,
      userId: requestUserId || undefined,
      scene: "ai_output",
      errorCode: "MODERATION_PROVIDER_ERROR",
      errorMessage: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });
    return new Response(JSON.stringify({
      error: error.message || 'Internal server error',
      details: error.toString()
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
/* 
 * Usage Examples / 使用示例:
 * 
 * Streaming Mode / 流式模式:
 * const response = await fetch('YOUR_SUPABASE_FUNCTION_URL', {
 *   method: 'POST',
 *   headers: { 'Content-Type': 'application/json' },
 *   body: JSON.stringify({
 *     query: "What are the specs of the iPhone 13 Pro Max?",
 *     user: "user-123",
 *     response_mode: "streaming"
 *   })
 * })
 * 
 * Blocking Mode / 阻塞模式:
 * const response = await fetch('YOUR_SUPABASE_FUNCTION_URL', {
 *   method: 'POST',
 *   headers: { 'Content-Type': 'application/json' },
 *   body: JSON.stringify({
 *     query: "What are the specs of the iPhone 13 Pro Max?",
 *     user: "user-123",
 *     response_mode: "blocking",
 *     conversation_id: "previous-conversation-id" // Optional, for continuing conversation / 可选，用于继续对话
 *   })
 * })
 * 
 * Environment Setup / 环境配置:
 * supabase secrets set DIFY_CHAT_API_KEY=your_dify_api_key
 */
