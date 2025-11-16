// Setup type definitions for built-in Supabase Runtime APIs
// 设置 Supabase Runtime API 的类型定义
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
// Dify API configuration / Dify API 配置
const DIFY_API_KEY = Deno.env.get('DIFY_API_KEY');
const DIFY_BASE_URL = 'https://api.dify.ai/v1';
Deno.serve(async (req)=>{
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
  try {
    // Parse request body / 解析请求体
    const requestBody = await req.json();
    // Validate required fields / 验证必填字段
    if (!requestBody.query || !requestBody.user) {
      return new Response(JSON.stringify({
        error: 'Missing required fields: query and user are required'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Default to streaming mode / 默认使用流式模式
    const responseMode = requestBody.response_mode || 'streaming';
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
      return new Response(stream, {
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
    return new Response(JSON.stringify(data), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    // Error handling and logging / 错误处理和日志记录
    console.error('Error:', error);
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
 * supabase secrets set DIFY_API_KEY=your_dify_api_key
 */
