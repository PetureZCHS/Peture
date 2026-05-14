import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const DIFY_CHAT_API_KEY = Deno.env.get('DIFY_CHAT_API_KEY');
const DIFY_BASE_URL = 'https://api.dify.ai/v1';
const EFFECTIVE_DIFY_KEY = DIFY_CHAT_API_KEY;
function toDifyFiles(images) {
  return images.map((img)=>{
    const uploadFileId = String(img['upload_file_id'] ?? '');
    return {
      type: 'image',
      transfer_method: 'local_file',
      upload_file_id: uploadFileId
    };
  });
}
async function uploadImageToDify(params) {
  const { user, fileName, mimeType, base64 } = params;
  const bytes = Uint8Array.from(atob(base64), (c)=>c.charCodeAt(0));
  const blob = new Blob([
    bytes
  ], {
    type: mimeType
  });
  const formData = new FormData();
  formData.append('user', user);
  formData.append('file', blob, fileName);
  const res = await fetch(`${DIFY_BASE_URL}/files/upload`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${EFFECTIVE_DIFY_KEY}`
    },
    body: formData
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`上传图片失败(${res.status}): ${text}`);
  }
  const data = await res.json();
  const id = data?.id;
  if (!id) {
    throw new Error('上传图片成功但未返回文件 ID');
  }
  return id;
}
Deno.serve(async (req)=>{
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
  };
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    if (!EFFECTIVE_DIFY_KEY) {
      return new Response(JSON.stringify({
        error: '缺少 Dify API Key（DIFY_CHAT_API_KEY）'
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    const requestBody = await req.json();
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
    const responseMode = requestBody.response_mode || 'streaming';
    const query = String(requestBody.query);
    const user = String(requestBody.user);
    const petContext = String(requestBody.pet_context ?? '').trim();
    let finalQuery = query;
    // System Prompt 统一交给 Dify 管理，避免 Edge Function 与 Dify 双重注入。
    // doctor_mode / agent_mode 仅用于客户端逻辑与埋点，不在此处拼接 prompt。
    if (petContext.length > 0) {
      finalQuery = `${finalQuery}\n\n${petContext}`;
    }
    const incomingImages = Array.isArray(requestBody.images) ? requestBody.images : [];
    const uploadedImages = [];
    for (const image of incomingImages){
      const base64 = String(image['dataBase64'] ?? '');
      const fileName = String(image['fileName'] ?? `image_${Date.now()}.jpg`);
      const mimeType = String(image['mimeType'] ?? 'image/jpeg');
      if (!base64) continue;
      const uploadFileId = await uploadImageToDify({
        user,
        fileName,
        mimeType,
        base64
      });
      uploadedImages.push({
        upload_file_id: uploadFileId
      });
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
      pet_context: undefined
    };
    const difyResponse = await fetch(`${DIFY_BASE_URL}/chat-messages`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${EFFECTIVE_DIFY_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(bodyForDify)
    });
    if (!difyResponse.ok) {
      let errorData = {};
      try {
        errorData = await difyResponse.json();
      } catch (_) {
        const raw = await difyResponse.text();
        errorData = {
          message: raw
        };
      }
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
    const data = await difyResponse.json();
    return new Response(JSON.stringify(data), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
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
