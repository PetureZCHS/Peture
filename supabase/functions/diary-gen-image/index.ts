// supabase/functions/diary-gen-image/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// ==========================================
// 1. 顶层读取环境变量
// ==========================================
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const siliconFlowApiKey = Deno.env.get("SILICONFLOW_API_KEY") ?? "";
const dashscopeApiKey = Deno.env.get("DASHSCOPE_API_KEY") ?? "";
const DASHSCOPE_API_URL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation";

if (!supabaseUrl || !supabaseServiceRoleKey || !siliconFlowApiKey || !dashscopeApiKey) {
  const missing = [
    !supabaseUrl ? "SUPABASE_URL" : null,
    !supabaseServiceRoleKey ? "SUPABASE_SERVICE_ROLE_KEY" : null,
    !siliconFlowApiKey ? "SILICONFLOW_API_KEY" : null,
    !dashscopeApiKey ? "DASHSCOPE_API_KEY" : null,
  ].filter((v): v is string => v !== null);

  const message = `Missing required environment variable(s): ${missing.join(", ")}. Please check your function configuration.`;
  console.error("[diary-gen-image] Configuration error:", message);
  throw new Error(message);
}

// ==========================================
// 2. 常量、辅助函数与 Prompt 定义
// ==========================================
const getCorsHeaders = (origin: string | null) => ({
  "Access-Control-Allow-Origin": origin ?? "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
});

function jsonResponse(body: unknown, status = 200, origin: string | null = "*") {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...getCorsHeaders(origin),
    },
  });
}

const SYSTEM_PROMPT = `你是一位精通摄影美学与 AI 绘画大模型（如 Qwen-Image-Edit、Midjourney）的提示词专家。你的任务是阅读用户的「宠物日记」，提取其中的视觉元素，并将其转化为一段高质量、画面感强且安全的英文生图提示词（Prompt）。

# Rules
请严格遵循以下规则处理信息并生成 Prompt：

1. 主角绝对聚焦与参考图绑定（Main Subject Focus & Reference Binding）：
   - 根据提供的【主角宠物信息】明确核心主体（如 a Border Collie, a British Shorthair cat）。
   - 为了让生图模型将其与用户上传的参考图强绑定，请务必在主体名词前加上指示代词，格式为："The specific [品种] from the reference image"（例如：The specific Border Collie from the reference image）。
   - 强制将其放置在画面前景（in the foreground），并从【宠物日记内容】中提取主体的核心动作或状态。

2. 未知实体的语义泛化（Semantic Generalization）：
   - 泛化地点：将具体的专有名词翻译为通用的优美场景。
   - 弱化次要角色：将次要宠物或人类翻译为泛化词汇，并强制将其推向背景。如果人类不是核心互动对象，请勿在提示词中体现。
   - 泛化特定物品：将具体的品牌或 IP 专属物品提取为通用的视觉特征描述。

3. 氛围与光影（Atmosphere & Lighting）：
   - 提取日记中的天气、季节、情绪词汇，并转化为对应的英文视觉光影描述。

4. 构图与“藏拙”指令（Composition & Flaw Hiding）：
   - 强制虚化背景：
     "shallow depth of field, sharp focus on the main subject in the foreground, blurred background, beautiful bokeh"

# Output Format
- 仅输出纯正的英文提示词，多个词组或短句使用英文逗号分隔。
- 绝对不要输出任何解释性文字、问候语或代码块符号。`;

// ==========================================
// 3. 处理请求
// ==========================================
serve(async (req: Request) => {
  const origin = req.headers.get("origin");

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: getCorsHeaders(origin) });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405, origin);
  }

  try {
    // 1. 解析与校验前端参数
    let body: { pet_id?: string; diary_content?: string };
    try {
      body = await req.json();
    } catch (_parseErr) {
      return jsonResponse({ error: "Invalid JSON in request body." }, 400, origin);
    }

    const { pet_id, diary_content } = body;
    if (!pet_id || !diary_content) {
      return jsonResponse({ error: "Missing pet_id or diary_content." }, 400, origin);
    }

    // 2. 校验权限与用户身份
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.startsWith("Bearer ") ? authHeader.replace("Bearer ", "") : authHeader;
    if (!jwt) return jsonResponse({ error: "Missing Authorization header." }, 401, origin);

    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);
    const { data: { user }, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !user) {
      return jsonResponse({ error: "Invalid token or user not found.", detail: userError?.message }, 401, origin);
    }
    const userId = user.id;
    console.log('[diary-gen-image] resolved userId=%s from JWT', userId);

    // 3. 频控守卫校验
    const { data: guard, error: guardError } = await supabase
      .rpc("img_gen_check_guard", { p_user_id: userId })
      .single<{ allowed: boolean; retry_after_ms: number; last_img_gen_check_at: string }>();

    if (guardError || !guard) {
      return jsonResponse({ error: "Rate-limit guard failed", detail: guardError?.message }, 500, origin);
    }
    if (!guard.allowed) {
      return jsonResponse({
        status: "TOO_FREQUENT",
        retry_after_ms: guard.retry_after_ms,
        last_img_gen_check_at: guard.last_img_gen_check_at,
      }, 429, origin);
    }

    // 4. 查询宠物信息，取出 life_photo
    const { data: petData, error: petError } = await supabase
      .rpc("get_pet_for_diary", {
        p_pet_id: pet_id,
        p_user_id: userId,
      })
      .single<{ type: string; breed: string; name: string; gender: string; age: number; life_photo: string }>();

    if (petError) {
      console.error('[diary-gen-image] pet query error:', petError.message || petError);
    }
    console.log('[diary-gen-image] petQuery -> pet_id=%s userId=%s petFound=%s', pet_id, userId, !!petData);

    if (petError || !petData) {
      return jsonResponse({ error: "Pet not found or permission denied." }, 404, origin);
    }
    if (!petData.life_photo) {
      return jsonResponse({ error: "Pet does not have a life_photo set." }, 400, origin);
    }

    // 5. 智能提取 Bucket 和 Path，并生成 5 分钟的 Signed URL
    let sourceBucket = "ai-wallpapers";
    let sourcePath = petData.life_photo;

    if (petData.life_photo.includes("/storage/v1/object/public/")) {
      const parts = petData.life_photo.split("/storage/v1/object/public/")[1].split("/");
      sourceBucket = parts[0];
      sourcePath = parts.slice(1).join("/");
    }

    const { data: signedData, error: signedError } = await supabase.storage
      .from(sourceBucket)
      .createSignedUrl(sourcePath, 60 * 5);

    if (signedError || !signedData?.signedUrl) {
      return jsonResponse({ error: "Failed to create signed url for life_photo", detail: signedError?.message }, 500, origin);
    }

    // 6. 调用大语言模型生成 Prompt
    const petInfoStr = `类型：${petData.type}，品种：${petData.breed}，昵称：${petData.name}，性别：${petData.gender}`;
    const userPromptContent = `
# Inputs
- 主角宠物信息：${petInfoStr}
- 宠物日记内容：${diary_content}

请根据以上输入，直接输出纯正的英文提示词（Prompt）：`;

    const sfResponse = await fetch("https://api.siliconflow.cn/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${siliconFlowApiKey}`,
      },
      body: JSON.stringify({
        model: "Qwen/Qwen3.5-35B-A3B",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: userPromptContent }
        ],
        temperature: 0.7,
        max_tokens: 1024,
        enable_thinking: false
      }),
    });

    if (!sfResponse.ok) {
      const errText = await sfResponse.text();
      console.error("[diary-gen-image] SiliconFlow API HTTP error:", sfResponse.status, errText);
      throw new Error(`SiliconFlow API returned status ${sfResponse.status}`);
    }

    const sfData = await sfResponse.json();
    let generatedPrompt = sfData.choices?.[0]?.message?.content || "";

    if (!generatedPrompt) {
      console.error("[diary-gen-image] LLM returned empty prompt. Full response:", JSON.stringify(sfData));
      return jsonResponse({ error: "Failed to generate prompt from diary.", detail: "Check Supabase logs for SiliconFlow response details." }, 500, origin);
    }

    // 修复换行符正则，使用真正的换行符匹配 \n 而非字符串的 \\n
    generatedPrompt = generatedPrompt.replace(/```[a-zA-Z]*\n?/g, "").replace(/```/g, "").trim();

    if (!generatedPrompt) {
      console.error("[diary-gen-image] Prompt became empty after regex cleanup.");
      return jsonResponse({ error: "Failed to generate prompt from diary (cleaned up as empty)." }, 500, origin);
    }

    // 7. 调用 DashScope 视觉模型生图
    const imageSize = "2048*1152";
    let dashscopeResp: Response;
    try {
      dashscopeResp = await fetch(DASHSCOPE_API_URL, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${dashscopeApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "qwen-image-2.0",
          input: {
            messages: [
              {
                role: "user",
                content: [
                  { image: signedData.signedUrl },
                  { text: generatedPrompt },
                ],
              },
            ],
          },
          parameters: {
            n: 1,
            negative_prompt: " ",
            prompt_extend: true,
            watermark: false,
            size: imageSize,
          },
        }),
        signal: AbortSignal.timeout(120000), 
      });
    } catch (err) {
      if (err instanceof Error && err.name === "AbortError") {
        return jsonResponse({ error: "Upstream DashScope API timeout" }, 504, origin);
      }
      throw err;
    }

    if (!dashscopeResp.ok) {
      return jsonResponse({ error: "DashScope request failed", detail: await dashscopeResp.text() }, 500, origin);
    }

    const dsData = await dashscopeResp.json();
    const generatedImageUrl = dsData.output?.choices?.[0]?.message?.content?.[0]?.image;

    if (!generatedImageUrl) {
      return jsonResponse({ error: "Image URL not found in DashScope response" }, 500, origin);
    }

    // 8. 下载生成好的图片并保存至 Supabase Storage
    let imgResp: Response;
    try {
      imgResp = await fetch(generatedImageUrl, { signal: AbortSignal.timeout(30000) });
    } catch (err) {
      if (err instanceof Error && err.name === "AbortError") {
        return jsonResponse({ error: "Generated image download timeout" }, 504, origin);
      }
      throw err;
    }

    const arrayBuffer = await imgResp.arrayBuffer();
    
    const timestamp = Date.now();
    const generatedStoragePath = `${userId}/generated/diary_${timestamp}.png`;

    const { error: uploadError } = await supabase.storage
      .from("ai-wallpapers")
      .upload(generatedStoragePath, arrayBuffer, {
        contentType: "image/png",
        upsert: true,
      });

    if (uploadError) {
      return jsonResponse({ error: "Failed to upload generated image", detail: uploadError.message }, 500, origin);
    }

    // 9. 统一返回结构
    return jsonResponse({
      status: "SUCCEED",
      prompt: generatedPrompt,
      path: generatedStoragePath,
      size: imageSize,
      aspect_ratio: "16:9",
    }, 200, origin);

  } catch (err) {
    const message = err instanceof Error ? err.message : "Internal Server Error";
    console.error("Edge Function Error:", message);
    return jsonResponse({ error: message }, 500, origin);
  }
});