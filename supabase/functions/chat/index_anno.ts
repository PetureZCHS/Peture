// Setup type definitions for built-in Supabase Runtime APIs
// 设置 Supabase Runtime API 的类型定义
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// Dify API configuration / Dify API 配置
const DIFY_API_KEY = Deno.env.get('DIFY_API_KEY');
const DIFY_BASE_URL = 'https://api.dify.ai/v1';

Deno.serve(async (req) => {
  // CORS headers / CORS 头部配置
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  // Handle CORS preflight requests / 处理 CORS 预检请求
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // ✅ 允许匿名访问 - 不验证 JWT
    // 记录请求信息（用于调试）
    const authHeader = req.headers.get('authorization');
    console.log('Request received:', {
      hasAuth: !!authHeader,
      method: req.method,
      url: req.url
    });

    // Parse request body / 解析请求体
    const requestBody = await req.json();
    
    // Validate required fields / 验证必填字段
    if (!requestBody.query || !requestBody.user) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: query and user are required' 
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Default to streaming mode / 默认使用流式模式
    const responseMode = requestBody.response_mode || 'streaming';

    // 记录调用 Dify API 的信息
    console.log('Calling Dify API:', {
      query: requestBody.query.substring(0, 50) + '...',
      user: requestBody.user,
      mode: responseMode,
      hasConversationId: !!requestBody.conversation_id
    });

    // Prepare request to Dify API / 准备发送到 Dify API 的请求
    const difyResponse = await fetch(`${DIFY_BASE_URL}/chat-messages`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${DIFY_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        ...requestBody,
        response_mode: responseMode,
      })
    });

    // Handle API errors / 处理 API 错误
    if (!difyResponse.ok) {
      const errorData = await difyResponse.json();
      console.error('Dify API error:', errorData);
      return new Response(
        JSON.stringify({
          error: errorData.message || 'Dify API request failed',
          status: difyResponse.status,
          code: errorData.code
        }),
        {
          status: difyResponse.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Handle streaming response / 处理流式响应
    // SSE (Server-Sent Events) format for real-time output
    // SSE（服务器推送事件）格式，用于实时输出
    if (responseMode === 'streaming') {
      console.log('Returning streaming response');
      const stream = difyResponse.body;

      return new Response(stream, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/event-stream', // SSE content type / SSE 内容类型
          'Cache-Control': 'no-cache', // Disable caching / 禁用缓存
          'Connection': 'keep-alive', // Keep connection alive / 保持连接
        }
      });
    }

    // Handle blocking response / 处理阻塞模式响应
    // Returns complete result after execution / 等待执行完毕后返回完整结果
    const data = await difyResponse.json();
    console.log('Returning blocking response');
    return new Response(
      JSON.stringify(data),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        }
      }
    );

  } catch (error) {
    // Error handling and logging / 错误处理和日志记录
    console.error('Edge Function error:', error);
    return new Response(
      JSON.stringify({
        error: error.message || 'Internal server error',
        details: error.toString()
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    );
  }
});