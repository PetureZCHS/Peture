import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js';
import { createTraceId } from "../_shared/trace.ts";
import { executeTextModeration } from "../_shared/moderation_provider.ts";
import { writeModerationError, writeModerationLog } from "../_shared/moderation_logger.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const apiKey = Deno.env.get("DIFY_DIARY_V3_API_KEY");
const DIFY_API = "https://api.dify.ai/v1/workflows/run";

// 创建Supabase客户端实例 (使用 Service Role Key 以便执行数据库管理操作)
const supabase = createClient(supabaseUrl, supabaseServiceKey);

/** 无 test 表或未建额度行时的默认额度（需 >= 下方余额门槛 2000） */
const DEFAULT_DIARY_QUOTA = 1_000_000;

// 查询用户余额（历史上使用开发表 `test`；若表不存在或无行，不应阻断日记生成）
async function getUserQuota(userId: string): Promise<number | null> {
    const { data, error } = await supabase
        .from("test")
        .select("quota")
        .eq("user_id", userId)
        .maybeSingle();

    if (error) {
        const msg = (error.message ?? "").toLowerCase();
        const code = (error as { code?: string }).code;
        // 表未创建、未进迁移、或 PostgREST 缓存中无该表
        if (
            msg.includes("does not exist") ||
            msg.includes("schema cache") ||
            msg.includes("could not find the table") ||
            code === "42P01" ||
            code === "PGRST205"
        ) {
            console.warn(
                "[diary-v3] quota table `test` unavailable; using default quota",
                { userId, code, message: error.message },
            );
            return DEFAULT_DIARY_QUOTA;
        }
        console.error("Error fetching user quota:", error);
        return null;
    }
    if (data == null || data.quota == null) {
        return DEFAULT_DIARY_QUOTA;
    }
    return Number(data.quota) || 0;
}

// 更新用户余额
async function updateUserQuota(userId: string, quotaDecrease: number) {
    const { error } = await supabase.rpc('decrease_quota', {
        uid: userId,
        decr: quotaDecrease
    });
    if (error) {
        console.error('Error updating user quota:', error);
        return false;
    }
    return true;
}

Deno.serve(async (req) => {
    // CORS headers 配置
    const corsHeaders = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Authorization, x-client-info, content-type"
    };

    // Handle CORS preflight requests / 处理 CORS 预检请求
    if (req.method === "OPTIONS") {
        return new Response("ok", {
            headers: corsHeaders
        });
    }

    if (req.method !== "POST") {
        return new Response("Method Not Allowed", {
            status: 405,
            headers: corsHeaders
        });
    }

    let body;
    try {
        body = await req.json();
    } catch {
        return new Response("Bad Request", {
            status: 400,
            headers: corsHeaders
        });
    }

    const traceId = createTraceId();
    // 从 body 中只提取 inputs 和 response_mode，不再信任 user
    let { inputs, response_mode } = body ?? {};

    // ---------------- SECURITY CHANGE START ----------------
    // 安全修改：通过 Authorization Header 获取真实用户 ID
    // 通过 Supabase 的 Auth Token（JWT）解析出当前登录的用户 ID

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
        return new Response("Missing Authorization Header", {
            status: 401,
            headers: corsHeaders
        });
    }

    // 提取 Token (去掉 'Bearer ' 前缀)
    const token = authHeader.replace('Bearer ', '');

    // 使用 Supabase Auth 验证 Token 并获取用户信息
    const { data: { user: authUser }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !authUser) {
        return new Response("Unauthorized / Invalid Token", {
            status: 401,
            headers: corsHeaders
        });
    }

    // 【关键】强制覆盖 user 变量，使用鉴权后的真实 ID
    const user = authUser.id;

    // ---------------- SECURITY CHANGE END ------------------
    const rawQuery = (inputs?.query ?? "").toString();
    const inputModerationExec = await executeTextModeration("diary_input", rawQuery, traceId);
    const inputModeration = inputModerationExec.result;
    await writeModerationLog({
      userId: user,
      scene: "diary_input",
      traceId,
      result: inputModeration,
      contentExcerpt: rawQuery,
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

    if (inputs && !("nickname" in inputs)) {
        inputs.nickname = "主人";
    }
    if (inputs && !("breed" in inputs)) {
        inputs.breed = "未知";
    }

    const mode = response_mode === "streaming" ? "streaming" : "blocking";

    // 检查必要的参数
    if (!apiKey) {
        return new Response("Missing DIFY_DIARY_API_KEY", {
            status: 500,
            headers: corsHeaders
        });
    }

    // 这里不再需要检查 !user，因为上面鉴权失败直接返回 401 了

    // 检查用户余额
    const quota = await getUserQuota(user);

    if (quota === null) {
        return new Response("Error fetching user quota", {
            status: 500,
            headers: corsHeaders
        });
    }

    if (quota < 2000) {
        return new Response("余额不足，请充值！", {
            status: 402,
            headers: corsHeaders
        });
    }

    const baseHeaders = {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json"
    };

    const payload = {
        inputs,
        response_mode: mode,
        user: user // 这里传递给 Dify 的 user 已经是安全的真实 ID
    };

    if (mode === "streaming") {
        // 上游以 SSE 返回，函数作为反向代理原样转发事件流
        // 创建自定义TransformStream来处理SSE事件并提取total_tokens
        const upstream = await fetch(DIFY_API, {
            method: "POST",
            headers: {
                ...baseHeaders,
                Accept: "text/event-stream"
            },
            body: JSON.stringify(payload)
        });

        if (!upstream.body) {
            return new Response("Upstream unavailable", {
                status: 502,
                headers: corsHeaders
            });
        }

        // 创建TransformStream来处理SSE事件并提取total_tokens
        let totalTokens = 0;
        let outputBuffer = "";
        let blocked = false;
        const transformStream = new TransformStream({
            async transform(chunk, controller) {
                // 将chunk转换为字符串
                const text = new TextDecoder().decode(chunk);
                // 解析SSE事件
                const lines = text.split('\n');
                for (const line of lines) {
                    if (line.startsWith('data: ')) {
                        try {
                            const eventData = JSON.parse(line.substring(6));
                            // 检查是否是workflow_finished事件
                            if (eventData.event === 'workflow_finished' && eventData.data && eventData.data.total_tokens) {
                                totalTokens = eventData.data.total_tokens;
                            }
                            if (eventData.event === "text_chunk" && eventData.data?.text) {
                                outputBuffer += String(eventData.data.text);
                                const outputModerationExec = await executeTextModeration("diary_output", outputBuffer, traceId);
                                const outputModeration = outputModerationExec.result;
                                if (!outputModeration.passed && !blocked) {
                                    blocked = true;
                                    await writeModerationLog({
                                      userId: user,
                                      scene: "diary_output",
                                      traceId,
                                      result: outputModeration,
                                      contentExcerpt: outputBuffer,
                                      provider: outputModerationExec.provider,
                                      providerResponse: outputModerationExec.providerResponse,
                                    });
                                    const blockedPayload =
                                      `data: ${JSON.stringify({ event: "text_chunk", data: { text: `该内容未通过审核（traceId: ${traceId}）` } })}\n\n` +
                                      `data: ${JSON.stringify({ event: "workflow_finished", data: { total_tokens: totalTokens } })}\n\n`;
                                    controller.enqueue(new TextEncoder().encode(blockedPayload));
                                    return;
                                }
                            }
                        } catch (e) {
                            // 如果解析失败，继续处理其他行
                            console.error('Error parsing SSE event:', e);
                            await writeModerationError({
                                traceId,
                                userId: user,
                                scene: "diary_output",
                                errorCode: "MODERATION_PROVIDER_ERROR",
                                errorMessage: e instanceof Error ? e.message : String(e),
                                stack: e instanceof Error ? e.stack : undefined,
                            });
                        }
                    }
                }
                if (blocked) {
                    return;
                }
                // 转发数据
                controller.enqueue(chunk);
            },
            async flush(controller) {
                // 在流结束时，如果有totalTokens则更新用户quota
                if (totalTokens > 0) {
                    await updateUserQuota(user, totalTokens);
                }
                if (!blocked && outputBuffer) {
                    const outputModerationExec = await executeTextModeration("diary_output", outputBuffer, traceId);
                    const outputModeration = outputModerationExec.result;
                    await writeModerationLog({
                      userId: user,
                      scene: "diary_output",
                      traceId,
                      result: outputModeration,
                      contentExcerpt: outputBuffer,
                      provider: outputModerationExec.provider,
                      providerResponse: outputModerationExec.providerResponse,
                    });
                }
                controller.terminate();
            }
        });

        const sseHeaders = new Headers({
            ...corsHeaders,
            "Content-Type": "text/event-stream; charset=utf-8",
            "Cache-Control": "no-cache, no-transform",
            Connection: "keep-alive"
        });

        // 创建TransformStream来转发数据
        const { readable, writable } = new TransformStream();
        // 将上游ReadableStream通过自定义TransformStream处理
        upstream.body.pipeThrough(transformStream).pipeTo(writable);

        return new Response(readable, {
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

        // 获取响应文本和JSON数据
        const responseText = await resp.text();
        let responseData;
        try {
            responseData = JSON.parse(responseText);
        } catch (e) {
            console.error('Error parsing response JSON:', e);
            await writeModerationError({
                traceId,
                userId: user,
                scene: "diary_output",
                errorCode: "MODERATION_PROVIDER_ERROR",
                errorMessage: e instanceof Error ? e.message : String(e),
                stack: e instanceof Error ? e.stack : undefined,
            });
            // 如果解析失败，仍然返回原始响应
            return new Response(responseText, {
                status: resp.status,
                headers: {
                    ...corsHeaders,
                    "Content-Type": resp.headers.get("Content-Type") ?? "application/json"
                }
            });
        }

        // 检查是否有total_tokens字段
        if (responseData.data && responseData.data.total_tokens) {
            const totalTokens = responseData.data.total_tokens;
            // 更新用户quota
            await updateUserQuota(user, totalTokens);
        }

        const generatedText = responseData?.data?.outputs?.text?.toString?.() ?? "";
        if (generatedText) {
            const outputModerationExec = await executeTextModeration("diary_output", generatedText, traceId);
            const outputModeration = outputModerationExec.result;
            await writeModerationLog({
              userId: user,
              scene: "diary_output",
              traceId,
              result: outputModeration,
              contentExcerpt: generatedText,
              provider: outputModerationExec.provider,
              providerResponse: outputModerationExec.providerResponse,
            });
            if (!outputModeration.passed) {
              responseData.data = responseData.data ?? {};
              responseData.data.outputs = responseData.data.outputs ?? {};
              responseData.data.outputs.text = `该内容未通过审核（traceId: ${traceId}）`;
              return new Response(JSON.stringify(responseData), {
                  status: resp.status,
                  headers: {
                      ...corsHeaders,
                      "Content-Type": resp.headers.get("Content-Type") ?? "application/json"
                  }
              });
            }
        }

        return new Response(responseText, {
            status: resp.status,
            headers: {
                ...corsHeaders,
                "Content-Type": resp.headers.get("Content-Type") ?? "application/json"
            }
        });
    }
});