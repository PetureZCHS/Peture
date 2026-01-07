// supabase/functions/img-gen-start/index.ts

import { createClient } from "jsr:@supabase/supabase-js@2";

const BASE_URL = "https://api-inference.modelscope.cn/";
const apiKey = Deno.env.get("MODELSCOPE_API_KEY");

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(supabaseUrl, serviceRoleKey);

type StyleKey = "run" | "explorer" | "bazaar" | "grid" | "autumn" | "cowboy";

const STYLE_PROMPTS: Record<StyleKey, string> = {
  run: "The pet running towards the viewer lively, joyful expression, detailed fur texture, dynamic motion, bright sunny day with blue sky and fluffy white clouds, vast green grass field in background, low angle perspective emphasizing speed and depth, natural soft lighting with clear layers and depth of field, suitable for 3D spatial wallpaper.",
  explorer:
    "A cute pet taking a selfie scene outdoors, wearing a brown explorer hat and gold-rimmed round sunglasses, confident and playful. The pet’s head is slightly tilted, direct eye contact with the camera, bright smile. The pet’s right front paw and phone are entirely out-of-frame and not visible in the image. All other paws rest naturally on the grass as authentic animal paws. The animal's face, ears, and head are fully visible and natural, no parts missing. Background: lush green grass, blue lake, snowy mountains, fluffy clouds. Cinematic, vibrant colors, strong 3D depth. High definition, 9:16 aspect ratio.",
  bazaar:
    "画面主体为宠物，画面上方带有“DIARY”文字。深粉色背景，宠物穿粉色条纹衬衫、系带白条纹深粉色领带，挂灰白色耳机，坐在同样是深粉色的地上，表情可爱，毛发清晰，整体呈现时尚感，画面清晰，像时尚芭莎大片。宠物形象与上传图片保持一致！",
  grid:
    "这张图片以纯白色为背景，没有任何字，纯白色背景采用九宫格排版，展示了一只宠物的九种不同表情。第一排从左到右，宠物先是吐着舌头，露出开心的模样；接着嘴巴微张，似在温和表达；然后一只爪子靠近脸部，神情略显腼腆。第二排，宠物先保持着平静的神态；随后双眼眯起，仿佛在惬意微笑；之后脑袋微侧，露出好奇的样子。第三排，宠物先是睁大眼睛，吐舌呈现出活泼的状态；接着张大嘴巴打哈欠，尽显慵懒；最后脑袋转向一侧，露出若有所思的神情。每一种表情都生动鲜活，将宠物的九种小情绪细腻展现。真实写真九宫格、一定要是九宫格。宠物形象与上传图片保持一致！",
  autumn:
    "图片主体戴棕色针织围巾，头顶橙红枫叶，周围散落各色秋叶，趴在沥青路面，写实风格，特写镜头，秋日治愈氛围。宠物形象与上传图片保持一致！",
  cowboy:
    "西部牛仔：戴着复古棕皮小牛仔帽帽檐别星星徽章，站在迷你西部风布景中有木质小栅栏，牛皮纸海报道具，背景用深棕字体写“日记”字体带皮革纹理与铆钉装饰，暖黄灯光强化复古氛围，宠物穿着復古棕皮背心，前爪搭栅栏的姿势创意十足，超写实画质。宠物形象与上传图片保持一致！",
};

interface RequestBody {
  file_name: string; // 例如 "xxx.png"
  style: StyleKey;
}

interface ImageGenerationTaskResponse {
  task_id: string;
}

Deno.serve(async (req: Request): Promise<Response> => {
  // CORS 预检
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  }

  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "Upstream API key is not set" }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      },
    );
  }

  try {
    const { file_name, style } = (await req.json()) as RequestBody;

    if (!file_name || !style) {
      return new Response(
        JSON.stringify({ error: "file_name and style are required" }),
        {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        },
      );
    }

    const prompt = STYLE_PROMPTS[style];
    if (!prompt) {
      return new Response(
        JSON.stringify({ error: `Unsupported style: ${style}` }),
        {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        },
      );
    }

    // 从请求头中获取用户 token，用于获取当前 user_id
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.startsWith("Bearer ")
      ? authHeader.replace("Bearer ", "")
      : authHeader;

    if (!jwt) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        {
          status: 401,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        },
      );
    }

    // 获取当前用户信息
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser(jwt);

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid user", detail: userError?.message }),
        {
          status: 401,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        },
      );
    }

    const userId = user.id;

    // 路径相关
    const folder_path = `${userId}/original`;
    const target_file_name = file_name;
    const file_path = `${folder_path}/${target_file_name}`;
    console.log("file_path to sign:", file_path);

    // 轮询检查文件是否存在，最多10次，每次间隔0.2s
    const maxAttempts = 10;
    const pollInterval = 200; // ms

    let fileExists = false;
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      const { data: files, error: listError } = await supabase.storage
        .from("ai-wallpapers")
        .list(folder_path, {
          limit: 100,
          search: target_file_name, // 只筛选包含该文件名的对象[web:39]
        });

      if (listError) {
        console.log(`Attempt ${attempt}: List error:`, listError.message);
      } else if (
        files &&
        files.some((file) => file.name === target_file_name)
      ) {
        console.log(
          `File found after ${attempt} attempts: ${target_file_name}`,
        );
        fileExists = true;
        break;
      } else {
        console.log(`Attempt ${attempt}/${maxAttempts}: File not ready yet`);
      }

      if (attempt < maxAttempts) {
        await new Promise((resolve) => setTimeout(resolve, pollInterval));
      }
    }

    if (!fileExists) {
      return new Response(
        JSON.stringify({
          error: "Upload file not ready after polling",
          file_path,
          attempts: maxAttempts,
        }),
        {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        },
      );
    }

    // 生成 5 分钟有效的签名 URL
    const { data: signedData, error: signedError } = await supabase.storage
      .from("ai-wallpapers")
      .createSignedUrl(file_path, 60 * 5); // 5 分钟

    if (signedError || !signedData?.signedUrl) {
      return new Response(
        JSON.stringify({
          error: "Failed to create signed url",
          detail: signedError?.message,
        }),
        {
          status: 500,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        },
      );
    }

    const image_url = signedData.signedUrl;
    const signed_url = signedData.signedUrl; // 给前端用

    // 调用 ModelScope 的 Qwen-Image-Edit 接口（异步模式）
    const url = `${BASE_URL}v1/images/generations`;

    const body = {
      model: "Qwen/Qwen-Image-Edit",
      prompt,
      image_url,
      size: "928x1664",
      steps: 35,
      guidance: 3.5,
    };

    const resp = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "X-ModelScope-Async-Mode": "true",
      },
      body: JSON.stringify(body),
    });

    if (!resp.ok) {
      const text = await resp.text();
      return new Response(
        JSON.stringify({
          error: "Upstream request failed",
          status: resp.status,
          detail: text,
        }),
        {
          status: 500,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        },
      );
    }

    const data = (await resp.json()) as ImageGenerationTaskResponse;

    // 把 task_id 和 signed_url 一并返回
    return new Response(
      JSON.stringify({
        ...data,
        signed_url,
      }),
      {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        },
    });
  }
});