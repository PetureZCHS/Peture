import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const DIFY_CHAT_API_KEY = Deno.env.get('DIFY_CHAT_API_KEY');
const DIFY_BASE_URL = 'https://api.dify.ai/v1';
const EFFECTIVE_DIFY_KEY = DIFY_CHAT_API_KEY;

const DOCTOR_PROMPT = `
# System Prompt for Peture AI (Doctor Mode)
你现在是 Peture AI 的首席兽医专家。通过多轮对话收集信息后，再给出结构化结论。
核心规则：
1. 第一次描述时不要直接下结论；
2. 每次只追问 1 个关键问题；
3. 使用温暖、专业中文；
4. 信息充分或情况危急时，输出诊断 JSON。
输出状态：
- 问诊中：输出普通文本。
- 诊断完成：仅输出 JSON：
{
  "type": "report",
  "data": {
    "diagnosis": "xxx",
    "urgency_level": 1-5,
    "urgency_color": "green|yellow|red",
    "possible_causes": ["..."],
    "advice_summary": "..."
  }
}`.trim();

const AGENT_PROMPT = `
# System Prompt for Peture AI (Agent Mode)
你是 Peture AI 的购物决策 Agent，给出明确的最佳推荐，不给模糊选项。
要求：
1. 展示清晰推理步骤；
2. 输出专业、简洁结论；
3. 若信息不足，先追问关键项。
推荐完成时输出 JSON：
{
  "type": "recommendation",
  "data": {
    "reason": "...",
    "productName": "...",
    "price": "...",
    "rating": "...",
    "safetyCheck": "...",
    "reasoningSteps": ["..."]
  }
}`.trim();

function toDifyFiles(images: Array<Record<string, unknown>>) {
  return images.map((img) => {
    const uploadFileId = String(img['upload_file_id'] ?? '');
    return {
      type: 'image',
      transfer_method: 'local_file',
      upload_file_id: uploadFileId,
    };
  });
}

async function uploadImageToDify(params: {
  user: string;
  fileName: string;
  mimeType: string;
  base64: string;
}) {
  const { user, fileName, mimeType, base64 } = params;
  const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
  const blob = new Blob([bytes], { type: mimeType });

  const formData = new FormData();
  formData.append('user', user);
  formData.append('file', blob, fileName);

  const res = await fetch(`${DIFY_BASE_URL}/files/upload`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${EFFECTIVE_DIFY_KEY}`,
    },
    body: formData,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`上传图片失败(${res.status}): ${text}`);
  }

  const data = await res.json();
  const id = data?.id as string | undefined;
  if (!id) {
    throw new Error('上传图片成功但未返回文件 ID');
  }
  return id;
}

Deno.serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (!EFFECTIVE_DIFY_KEY) {
      return new Response(JSON.stringify({
        error: '缺少 Dify API Key（DIFY_CHAT_API_KEY）',
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      });
    }

    const requestBody = await req.json();
    if (!requestBody.query || !requestBody.user) {
      return new Response(JSON.stringify({
        error: 'Missing required fields: query and user are required',
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      });
    }

    const responseMode = requestBody.response_mode || 'streaming';
    const query = String(requestBody.query);
    const user = String(requestBody.user);
    const doctorMode = Boolean(requestBody.doctor_mode);
    const agentMode = Boolean(requestBody.agent_mode);
    const petContext = String(requestBody.pet_context ?? '').trim();
    const hasConversation = Boolean(requestBody.conversation_id);

    let finalQuery = query;
    if (!hasConversation) {
      if (agentMode) {
        finalQuery = `${AGENT_PROMPT}\n\n用户问题：${finalQuery}`;
      } else if (doctorMode) {
        finalQuery = `${DOCTOR_PROMPT}\n\n用户问题：${finalQuery}`;
      }
    }
    if (petContext.length > 0) {
      finalQuery = `${finalQuery}\n\n${petContext}`;
    }

    const incomingImages = Array.isArray(requestBody.images)
      ? requestBody.images as Array<Record<string, unknown>>
      : [];
    const uploadedImages: Array<Record<string, unknown>> = [];
    for (const image of incomingImages) {
      const base64 = String(image['dataBase64'] ?? '');
      const fileName = String(image['fileName'] ?? `image_${Date.now()}.jpg`);
      const mimeType = String(image['mimeType'] ?? 'image/jpeg');
      if (!base64) continue;
      const uploadFileId = await uploadImageToDify({
        user,
        fileName,
        mimeType,
        base64,
      });
      uploadedImages.push({ upload_file_id: uploadFileId });
    }

    const bodyForDify = {
      ...requestBody,
      query: finalQuery,
      user,
      response_mode: responseMode,
      files: uploadedImages.length > 0 ? toDifyFiles(uploadedImages) : undefined,
      images: undefined,
      doctor_mode: undefined,
      agent_mode: undefined,
      pet_context: undefined,
    };

    const difyResponse = await fetch(`${DIFY_BASE_URL}/chat-messages`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${EFFECTIVE_DIFY_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(bodyForDify),
    });

    if (!difyResponse.ok) {
      let errorData: Record<string, unknown> = {};
      try {
        errorData = await difyResponse.json();
      } catch (_) {
        const raw = await difyResponse.text();
        errorData = { message: raw };
      }
      return new Response(JSON.stringify({
        error: (errorData.message as string) || 'Dify API request failed',
        status: difyResponse.status,
        code: errorData.code,
      }), {
        status: difyResponse.status,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      });
    }

    if (responseMode === 'streaming') {
      const stream = difyResponse.body;
      return new Response(stream, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        },
      });
    }

    const data = await difyResponse.json();
    return new Response(JSON.stringify(data), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    });
  } catch (error) {
    console.error('Error:', error);
    return new Response(JSON.stringify({
      error: error.message || 'Internal server error',
      details: error.toString(),
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    });
  }
});
