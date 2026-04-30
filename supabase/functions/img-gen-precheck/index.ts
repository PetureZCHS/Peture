
// supabase/functions/img-gen-precheck/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// ==========================================
// 1. 顶层读取环境变量
// ==========================================
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
// 改用 Service Role Key，以获取绕过 RLS 的最高权限来生成 Storage 签名 URL
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const siliconFlowApiKey = Deno.env.get("SILICONFLOW_API_KEY") ?? "";

// 在进入主逻辑前校验必要的 Supabase 配置，避免后续出现难以理解的错误
if (!supabaseUrl || !supabaseServiceRoleKey) {
  const missing = [
    !supabaseUrl ? "SUPABASE_URL" : null,
    !supabaseServiceRoleKey ? "SUPABASE_SERVICE_ROLE_KEY" : null,
  ].filter((v): v is string => v !== null);

  const message =
    `Missing required environment variable(s): ${missing.join(
      ", ",
    )}. Please check your function configuration.`;

  console.error("[img-gen-precheck] Configuration error:", message);
  // 抛出错误，使函数以清晰的 500 配置错误失败，而不是在 Supabase 客户端内部报错
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

const SYSTEM_PROMPT = `你是一个严格的宠物摄影质检专家。你的任务是检查用户上传的图片是否适合用于AI生成宠物头像或手机壁纸。
请【按顺序】根据以下规则检查图片，一旦违反其中任意一条，即刻判定为不通过（pass: false），并严格以纯 JSON 格式输出结果。

检查规则与对应提示语（按优先级从高到低）：
1. 必须有猫狗：画面中必须至少包含一只猫或狗。
   -> 若违反，reason 使用："哎呀，照片里好像没有发现猫猫或狗狗的身影哦，请换一张毛孩子的照片吧～"
2. 数量限制：画面中有且仅有一只猫或狗作为绝对主体。
   -> 若违反，reason 使用："为了保证生成效果，请上传仅有一只猫猫或狗狗的照片哦～"
3. 干扰排除：画面中不能有清晰的人脸或其他动物干扰。
   -> 若违反，reason 使用："照片里有人脸或其他小动物抢镜啦，请换一张只有毛孩子自己的独照吧～"
4. 五官完整：宠物的五官（眼睛、鼻子）必须清晰可见，且没有被严重遮挡。
   -> 若违反，reason 使用："小宝贝的脸好像被挡住啦，请换一张能看清正脸或微侧脸的照片试试看～"
5. 边缘限制：宠物的头顶和耳朵必须完整，没有被画面边缘切断（出画）。
   -> 若违反，reason 使用："照片把小宝贝的头顶或耳朵裁掉啦，请换一张构图更完整的照片吧～"
6. 画质检测：光线正常且不模糊。
   -> 若违反，reason 使用："这张照片有些模糊或光线不佳，换一张明亮清晰的特写效果会更好哦～"

输出纯JSON格式要求（不要包含任何Markdown代码块，不要输出额外分析过程）：
{
  "pass": true 或 false (必须是布尔值，切勿加引号),
  "reason": "如果pass为false，请直接原样输出上述对应规则的提示语；如果为true，则为空字符串。"
}`;

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
    // 基础环境校验
    if (!siliconFlowApiKey) {
      throw new Error("Server configuration error: SILICONFLOW_API_KEY is missing.");
    }

    // 获取请求体中的 file_name，并单独捕获 JSON 解析错误
    let body: any;
    try {
      body = await req.json();
    } catch (_parseErr) {
      return new Response(
        JSON.stringify({ error: "Invalid JSON in request body." }),
        { status: 400, headers: { "Content-Type": "application/json", ...getCorsHeaders(origin) } }
      );
    }
    const { file_name } = body;
    if (!file_name) {
      return new Response(
        JSON.stringify({ error: "Missing file_name in request body." }),
        { status: 400, headers: { "Content-Type": "application/json", ...getCorsHeaders(origin) } }
      );
    }

    // 校验 file_name 格式：仅允许字母、数字、连字符、下划线和单个点（用于扩展名），
    // 且扩展名只能是 jpg/jpeg/png/webp，最大长度 200 字符，防止路径遍历攻击
    const FILE_NAME_PATTERN = /^[a-zA-Z0-9_\-]+\.(jpg|jpeg|png|webp)$/i;
    if (
      typeof file_name !== "string" ||
      file_name.length > 200 ||
      !FILE_NAME_PATTERN.test(file_name)
    ) {
      return new Response(
        JSON.stringify({ error: "Invalid file_name format. Only alphanumeric characters, hyphens, underscores, and image extensions (jpg, jpeg, png, webp) are allowed." }),
        { status: 400, headers: { "Content-Type": "application/json", ...getCorsHeaders(origin) } }
      );
    }

    // 从 Authorization Header 中提取 JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header." }),
        { status: 401, headers: { "Content-Type": "application/json", ...getCorsHeaders(origin) } }
      );
    }

    // 清理并提取纯净的 JWT (剔除 "Bearer " 前缀)
    const jwt = authHeader.startsWith("Bearer ") ? authHeader.replace("Bearer ", "") : authHeader;

    // 使用管理员权限的 Service Role Key 创建 client
    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    // 显式传入 jwt 强校验用户身份
    const { data: { user }, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid token or user not found.", detail: userError?.message }),
        { status: 401, headers: { "Content-Type": "application/json", ...getCorsHeaders(origin) } }
      );
    }
    const userId = user.id;

    // 为该图片生成一个有效期为 5 分钟的签名 URL
    const imagePath = `${userId}/original/${file_name}`;
    const { data: signedData, error: signError } = await supabase
      .storage
      .from("ai-wallpapers")
      .createSignedUrl(imagePath, 60 * 5);

    if (signError || !signedData?.signedUrl) {
      console.error("Storage Error:", signError);
      return new Response(
        JSON.stringify({ error: "Failed to generate signed URL for the image. Check if file exists." }),
        { status: 400, headers: { "Content-Type": "application/json", ...getCorsHeaders(origin) } }
      );
    }

    const imageUrl = signedData.signedUrl;

    // 修复：严格对齐测试成功的 JSON 结构
    const payload = {
      model: "THUDM/GLM-4.1V-9B-Thinking",
      messages: [
        {
          role: "system",
          content: [
            {
              type: "text",
              text: SYSTEM_PROMPT
            }
          ]
        },
        {
          role: "user",
          content: [
            {
              type: "text",
              text: ""
            },
            {
              type: "image_url",
              image_url: {
                url: imageUrl
              }
            }
          ]
        }
      ],
      temperature: 0.7, // 改回测试通过的 0.7
      max_tokens: 1000  // 改回测试通过的 1000
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
    let resultText = sfData.choices?.[0]?.message?.content || "";

    // 清理大模型可能带上的 markdown 格式
    resultText = resultText.replace(/```json/g, "").replace(/```/g, "").trim();

    let checkResult;
    try {
      checkResult = JSON.parse(resultText);
    } catch (e) {
      console.error("Failed to parse JSON from LLM:", resultText);
      return new Response(
        JSON.stringify({ pass: false, reason: "图片检测服务开小差了，请稍后再试或换一张图片～" }),
        { status: 200, headers: { "Content-Type": "application/json", ...getCorsHeaders(origin) } }
      );
    }

    // 返回检测结果给前端
    return new Response(
      JSON.stringify(checkResult),
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
