// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js';

// Environment Variables
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const DIFY_API_KEY = Deno.env.get('DIFY_AIDOCTOR_API_KEY');
const DIFY_BASE_URL = Deno.env.get('DIFY_BASE_URL');

// 创建Supabase客户端实例 (使用 Service Role Key 以便执行数据库管理操作)
const supabase = createClient(supabaseUrl!, supabaseServiceKey!);

// --- 数据库操作辅助函数 ---

// 查询用户余额
async function getUserQuota(userId: string) {
    const { data, error } = await supabase.from('test').select('quota').eq('user_id', userId).single();
    if (error) {
        console.error('Error fetching user quota:', error);
        return null;
    }
    return data?.quota || 0;
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

// --- 主服务逻辑 ---

Deno.serve(async (req) => {
    // CORS headers 配置
    const corsHeaders = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
    };

    // Handle CORS preflight requests / 处理 CORS 预检请求
    if (req.method === 'OPTIONS') {
        return new Response('ok', {
            headers: corsHeaders
        });
    }

    try {
        // 1. 解析请求体
        const requestBody = await req.json();

        // 2. 验证必填字段 (query是必须的，user不再从body校验，而是从Auth头校验)
        if (!requestBody.query) {
            return new Response(JSON.stringify({
                error: 'Missing required field: query'
            }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }

        // ---------------- AUTHENTICATION START ----------------
        // 3. 身份验证：通过 Authorization Header 获取真实用户 ID
        const authHeader = req.headers.get('Authorization');
        if (!authHeader) {
            return new Response(JSON.stringify({ error: "Missing Authorization Header" }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }

        // 提取 Token (去掉 'Bearer ' 前缀)
        const token = authHeader.replace('Bearer ', '');

        // 使用 Supabase Auth 验证 Token 并获取用户信息
        const { data: { user: authUser }, error: authError } = await supabase.auth.getUser(token);

        if (authError || !authUser) {
            return new Response(JSON.stringify({ error: "Unauthorized / Invalid Token" }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }

        // 【关键】获取真实的 User ID
        const userId = authUser.id;
        // ---------------- AUTHENTICATION END ------------------

        // 4. 检查用户余额 (Pre-check)
        const quota = await getUserQuota(userId);

        if (quota === null) {
            return new Response(JSON.stringify({ error: "Error fetching user quota" }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }

        if (quota < 2000) {
            return new Response(JSON.stringify({ error: "余额不足，请充值！" }), {
                status: 402,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }

        // 5. 准备调用 Dify API
        // Default to streaming mode / 默认使用流式模式
        const responseMode = requestBody.response_mode || 'streaming';

        console.log('Calling Dify API:', {
            query: requestBody.query.substring(0, 50) + '...',
            user: userId, // Log authenticated user
            mode: responseMode
        });

        const difyResponse = await fetch(`${DIFY_BASE_URL}/chat-messages`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${DIFY_API_KEY}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                ...requestBody,
                user: userId, // 【关键】强制使用鉴权后的 userId 传递给 Dify
                response_mode: responseMode
            })
        });

        // Handle API errors / 处理 API 错误
        if (!difyResponse.ok) {
            const errorData = await difyResponse.json();
            console.error('Dify API error:', errorData);
            return new Response(JSON.stringify({
                error: errorData.message || 'Dify API request failed',
                code: errorData.code
            }), {
                status: difyResponse.status,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            });
        }

        // 6. 处理响应 (Streaming vs Blocking)

        if (responseMode === 'streaming') {
            console.log('Returning streaming response');

            if (!difyResponse.body) {
                return new Response("Upstream unavailable", { status: 502, headers: corsHeaders });
            }

            // 创建 TransformStream 来拦截流并计算 Token
            let totalTokens = 0;
            let buffer = ''; // 缓冲区用于处理跨 chunk 的数据

            const transformStream = new TransformStream({
                transform(chunk, controller) {
                    // 将 chunk 转换为字符串并添加到缓冲区
                    const text = new TextDecoder().decode(chunk);
                    buffer += text;

                    // 按行分割（SSE 以换行符分隔）
                    const lines = buffer.split('\n');

                    // 保留最后一行（可能不完整）在缓冲区中
                    buffer = lines.pop() || '';

                    // 处理完整的行
                    for (const line of lines) {
                        const trimmedLine = line.trim();

                        // 只处理以 "data: " 开头的行
                        if (trimmedLine.startsWith('data: ')) {
                            try {
                                const jsonString = trimmedLine.substring(6).trim();

                                // 跳过空数据或 [DONE] 标记
                                if (!jsonString || jsonString === '[DONE]') {
                                    continue;
                                }

                                const eventData = JSON.parse(jsonString);

                                // 检查 Dify Chat API 的 message_end 事件
                                if (eventData.event === 'message_end') {
                                    // 从 usage.total_tokens 获取 Token 消耗
                                    if (eventData.usage?.total_tokens) {
                                        totalTokens = eventData.usage.total_tokens;
                                    }
                                }
                                // 兼容 Agent 模式或 Workflow 模式
                                else if (eventData.event === 'workflow_finished' && eventData.data && eventData.data.total_tokens) {
                                    totalTokens = eventData.data.total_tokens;
                                }

                            } catch (e) {
                                // 如果解析失败，继续处理其他行（不输出日志以避免噪音）
                            }
                        }
                        // 忽略其他类型的行（如 "event: ping"、空行等）
                    }

                    // 原样转发数据给前端
                    controller.enqueue(chunk);
                },
                async flush(controller) {
                    // 处理缓冲区中剩余的数据
                    if (buffer.trim().startsWith('data: ')) {
                        try {
                            const jsonString = buffer.trim().substring(6).trim();
                            if (jsonString && jsonString !== '[DONE]') {
                                const eventData = JSON.parse(jsonString);

                                if (eventData.event === 'message_end') {
                                    // 从 usage.total_tokens 获取 Token 消耗
                                    if (eventData.usage?.total_tokens) {
                                        totalTokens = eventData.usage.total_tokens;
                                    }
                                }
                            }
                        } catch (e) {
                            // 忽略最后的解析错误
                        }
                    }

                    // 在流结束时，如果有 totalTokens 则更新用户 quota
                    if (totalTokens > 0) {
                        await updateUserQuota(userId, totalTokens);
                    }
                    controller.terminate();
                }
            });

            const sseHeaders = {
                ...corsHeaders,
                'Content-Type': 'text/event-stream; charset=utf-8',
                'Cache-Control': 'no-cache, no-transform',
                'Connection': 'keep-alive'
            };

            // 创建 TransformStream 来转发数据
            const { readable, writable } = new TransformStream();
            // 将上游 ReadableStream 通过自定义 TransformStream 处理
            difyResponse.body.pipeThrough(transformStream).pipeTo(writable);

            return new Response(readable, {
                status: difyResponse.status,
                headers: sseHeaders
            });

        } else {
            // 阻塞模式：等待完整结果后再返回
            const responseText = await difyResponse.text();
            let responseData;

            try {
                responseData = JSON.parse(responseText);
            } catch (e) {
                console.error('Error parsing response JSON:', e);
                // 如果解析失败，仍然返回原始响应
                return new Response(responseText, {
                    status: difyResponse.status,
                    headers: {
                        ...corsHeaders,
                        'Content-Type': difyResponse.headers.get('Content-Type') ?? 'application/json'
                    }
                });
            }

            // 检查是否有 total_tokens 字段
            let tokensToDeduct = 0;

            if (responseData.usage?.total_tokens) {
                tokensToDeduct = responseData.usage.total_tokens;
            }

            // 更新用户 quota
            if (tokensToDeduct > 0) {
                await updateUserQuota(userId, tokensToDeduct);
            }

            return new Response(responseText, {
                status: difyResponse.status,
                headers: {
                    ...corsHeaders,
                    'Content-Type': difyResponse.headers.get('Content-Type') ?? 'application/json'
                }
            });
        }

    } catch (error) {
        console.error('Edge Function error:', error);
        return new Response(JSON.stringify({
            error: error.message || 'Internal server error',
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
});