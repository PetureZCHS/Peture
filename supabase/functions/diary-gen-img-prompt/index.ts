// supabase/functions/diary-gen-img-prompt/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// ==========================================
// 1. 顶层读取环境变量
// ==========================================
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const siliconFlowApiKey = Deno.env.get("SILICONFLOW_API_KEY") ?? "";

if (!supabaseUrl || !supabaseServiceRoleKey) {
  const missing = [
    !supabaseUrl ? "SUPABASE_URL" : null,
    !supabaseServiceRoleKey ? "SUPABASE_SERVICE_ROLE_KEY" : null,
  ].filter((v): v is string => v !== null);

  const message = `Missing required environment variable(s): ${missing.join(", ")}. Please check your function configuration.`;
  console.error("[diary-gen-img-prompt] Configuration error:", message);
  throw new Error(message);
}

// ==========================================
// 2. 常量与 Prompt 定义
// ==========================================
const getCorsHeaders = (origin: string | null) => ({
  "Access-Control-Allow-Origin": origin ?? "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
});

// 将固定的规则定义在 System Prompt 中（已移除风格融合规则）
const SYSTEM_PROMPT = `你是一位精通摄影美学与 AI 绘画大模型（如 Qwen-Image-Edit、Midjourney）的提示词专家。你的任务是阅读用户的「宠物日记」，提取其中的视觉元素，并将其转化为一段高质量、画面感强且安全的英文生图提示词（Prompt）。

# Rules
请严格遵循以下规则处理信息并生成 Prompt：

1. 主角绝对聚焦与参考图绑定（Main Subject Focus & Reference Binding）：
   - 根据提供的【主角宠物信息】明确核心主体（如 a Border Collie, a British Shorthair cat）。
   - 为了让生图模型将其与用户上传的参考图强绑定，请务必在主体名词前加上指示代词，格式为："The specific [品种] from the reference image"（例如：The specific Border Collie from the reference image）。
   - 强制将其放置在画面前景（in the foreground），并从【宠物日记内容】中提取主体的核心动作或状态（如 running fast, sleeping peacefully, catching a flying disc）。

2. 未知实体的语义泛化（Semantic Generalization）：
   - 泛化地点：将日记中具体的专有名词或商户地点（如"朝阳公园"、"某某小区"）翻译为通用的优美场景。
   - 弱化次要角色：将日记中出现的其他次要宠物或人类翻译为泛化词汇，并强制将其推向背景。如果人类不是核心互动对象，请勿在提示词中体现，以免画面杂乱。
   - 泛化特定物品：将具体的品牌或 IP 专属物品提取为通用的视觉特征描述（如将"星黛露玩偶"翻译为 a purple plush bunny toy）。

3. 氛围与光影（Atmosphere & Lighting）：
   - 提取日记中的天气、季节、情绪词汇，并转化为对应的英文视觉光影描述（如 spring breeze, warm sunlight, cinematic lighting）。

4. 构图与“藏拙”指令（Composition & Flaw Hiding）：
   - 为了防止背景和次要角色生成崩坏或抢戏，必须在提示词中加入以下摄影术语，强制虚化背景：
     "shallow depth of field, sharp focus on the main subject in the foreground, blurred background, beautiful bokeh"

# Output Format
- 仅输出纯正的英文提示词，多个词组或短句使用英文逗号分隔。
- 绝对不要输出任何解释性文字、问候语或代码块符号（不要包含 \`\`\` ），以确保输出可以直接作为 API 参数被后端的 Edge Function 读取并调用。`;

// ==========================================
// 3. 处理请求
// ==========================================
serve(async (req: Request) => {
  const origin = req.headers.get("origin");

  // 处理 CORS 预检请求
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: getCorsHeaders(origin), status: 204 });
  }

  try {
    if (!siliconFlowApiKey) {
      throw new Error("Server configuration error: UPSTREAM_API_KEY is missing.");
    }

    // 解析前端参数
    let body: any;
    try {
      body = await req.json();
    } catch (_parseErr) {
      return new Response(
        JSON.stringify({ error: "Invalid JSON in request body." }),
        { status: 400, headers: { "Content-Type": "application/json", ...getCorsHeaders(origin) } }
      );
    }

    // 移除了 preset_id
    const { pet_id, diary_content } = body;
    if (!pet_id || !diary_content) {
      return new Response(
        JSON.stringify({ error: "Missing pet_id or diary_content in request body." }),
        { status: 400, headers: { "Content-Type": "application/json", ...getCorsHeaders(origin) } }
      );
    }

    // 校验 Authorization Header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header." }),
        { status: 401, headers: { "Content-Type": "application/json", ...getCorsHeaders(origin) } }
      );
    }

    const jwt = authHeader.startsWith("Bearer ") ? authHeader.replace("Bearer ", "") : authHeader;
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);
    
    const { data: { user }, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid token or user not found.", detail: userError?.message }),
        { status: 401, headers: { "Content-Type": "application/json", ...getCorsHeaders(origin) } }
      );
    }
    const userId = user.id;

    // 1. 查询宠物信息（同时校验数据归属权，防止越权查询）
    const { data: petData, error: petError } = await supabase
      .rpc("get_pet_for_diary", {
        p_pet_id: pet_id,
        p_user_id: userId,
      })
      .single();

    if (petError || !petData) {
      return new Response(
        JSON.stringify({ error: "Pet not found or you don't have permission to access it." }),
        { status: 404, headers: { "Content-Type": "application/json", ...getCorsHeaders(origin) } }
      );
    }

    // 组装宠物信息字符串
    const petInfoStr = `类型：${petData.type}，品种：${petData.breed}，昵称：${petData.name}，性别：${petData.gender}`;

    // 组装用户输入的消息内容（去除了视觉风格预设）
    const userPromptContent = `
# Inputs
- 主角宠物信息：${petInfoStr}
- 宠物日记内容：${diary_content}

请根据以上输入，直接输出纯正的英文提示词（Prompt）：`;

    // 准备 SiliconFlow API 的 Payload
    const payload = {
      model: "Qwen/Qwen3.6-35B-A3B", 
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userPromptContent }
      ],
      temperature: 0.7,
      max_tokens: 500 // 提示词一般不会太长，500足够
    };

    // 发起调用
    const sfResponse = await fetch("https://api.siliconflow.cn/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${siliconFlowApiKey}`,
      },
      body: JSON.stringify(payload),
    });

    if (!sfResponse.ok) {
      const errorText = await sfResponse.text();
      console.error("SiliconFlow API Error:", sfResponse.status, errorText);
      throw new Error(`SiliconFlow API returned status ${sfResponse.status}`);
    }

    const sfData = await sfResponse.json();
    let resultPrompt = sfData.choices?.[0]?.message?.content || "";

    // 清理大模型可能不小心带上的 markdown 格式或首尾的空格引号
    resultPrompt = resultPrompt.replace(/```[a-zA-Z]*\n?/g, "").replace(/```/g, "").trim();

    // 返回生成的 Prompt 给前端
    return new Response(
      JSON.stringify({ prompt: resultPrompt }),
      { status: 200, headers: { "Content-Type": "application/json", ...getCorsHeaders(origin) } }
    );

  } catch (err: any) {
    console.error("Edge Function Error:", err.message);
    return new Response(
      JSON.stringify({ error: err.message || "Internal Server Error" }),
      { status: 500, headers: { "Content-Type": "application/json", ...getCorsHeaders(origin) } }
    );
  }
});