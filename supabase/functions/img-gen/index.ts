// supabase/functions/img-gen/index.ts

import { createClient } from "jsr:@supabase/supabase-js@2";

const DASHSCOPE_API_URL =
  "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation";
const dashscopeApiKey = Deno.env.get("DASHSCOPE_API_KEY");

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, serviceRoleKey);

interface RequestBody {
  file_name: string;
  style: string;
}

interface GuardResult {
  allowed: boolean;
  retry_after_ms: number;
  last_img_gen_check_at: string;
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(),
    },
  });
}

function isSafeFileName(name: string) {
  return (
    !!name &&
    !name.includes("..") &&
    !name.includes("/") &&
    !name.includes("\\") &&
    name.length <= 200
  );
}

function resolveImageSize(aspectRatio: string) {
  switch (aspectRatio) {
    case "1:1":
      return "1328*1328";
    case "9:16":
      return "928*1664";
    case "16:9":
      return "2048*1152";
    default:
      return "1328*1328";
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!dashscopeApiKey) {
    return jsonResponse(
      { error: "Upstream API key (DASHSCOPE_API_KEY) is not set" },
      500,
    );
  }

  try {
    const { file_name, style } = (await req.json()) as RequestBody;

    if (!file_name || !style) {
      return jsonResponse({ error: "file_name and style are required" }, 400);
    }

    if (!isSafeFileName(file_name)) {
      return jsonResponse({ error: "Invalid file_name" }, 400);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.startsWith("Bearer ")
      ? authHeader.replace("Bearer ", "")
      : authHeader;

    if (!jwt) {
      return jsonResponse({ error: "Missing Authorization header" }, 401);
    }

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser(jwt);

    if (userError || !user) {
      return jsonResponse(
        { error: "Invalid user", detail: userError?.message },
        401,
      );
    }

    const userId = user.id;

    const { data: guard, error: guardError } = await supabase
      .rpc("img_gen_check_guard", { p_user_id: userId })
      .single<GuardResult>();

    if (guardError || !guard) {
      return jsonResponse(
        { error: "Rate-limit guard failed", detail: guardError?.message },
        500,
      );
    }

    if (!guard.allowed) {
      return jsonResponse(
        {
          status: "TOO_FREQUENT",
          retry_after_ms: guard.retry_after_ms,
          last_img_gen_check_at: guard.last_img_gen_check_at,
        },
        429,
      );
    }

    const { data: presetData, error: presetError } = await supabase
      .from("ai_image_presets")
      .select("prompt, aspect_ratio")
      .eq("id", style)
      .single();

    if (presetError || !presetData) {
      return jsonResponse(
        {
          error: `Unsupported or missing style: ${style}`,
          detail: presetError?.message,
        },
        400,
      );
    }

    const { prompt, aspect_ratio } = presetData;
    const imageSize = resolveImageSize(aspect_ratio);

    const originalFolder = `${userId}/original`;
    const targetFilePath = `${originalFolder}/${file_name}`;
    const maxAttempts = 10;
    const pollInterval = 500;
    let fileExists = false;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      await new Promise((resolve) => setTimeout(resolve, pollInterval));

      const { data: files, error: listError } = await supabase.storage
        .from("ai-wallpapers")
        .list(originalFolder, { limit: 10, search: file_name });

      if (listError) {
        return jsonResponse(
          { error: "Failed to check uploaded file", detail: listError.message },
          500,
        );
      }

      if (files && files.some((file) => file.name === file_name)) {
        fileExists = true;
        break;
      }
    }

    if (!fileExists) {
      return jsonResponse(
        { error: "Upload file not ready after polling", attempts: maxAttempts },
        400,
      );
    }

    const { data: signedData, error: signedError } = await supabase.storage
      .from("ai-wallpapers")
      .createSignedUrl(targetFilePath, 60 * 5);

    if (signedError || !signedData?.signedUrl) {
      return jsonResponse(
        { error: "Failed to create signed url", detail: signedError?.message },
        500,
      );
    }

    const signedUrl = signedData.signedUrl;

    const requestBody = {
      model: "qwen-image-2.0-pro",
      input: {
        messages: [
          {
            role: "user",
            content: [
              { image: signedUrl },
              { text: prompt },
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
    };

    let resp: Response;
    try {
      resp = await fetch(DASHSCOPE_API_URL, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${dashscopeApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(requestBody),
        signal: AbortSignal.timeout(120000),
      });
    } catch (err) {
      if (err instanceof Error && err.name === "AbortError") {
        return jsonResponse(
          {
            error: "Upstream DashScope API timeout",
            detail: "Image generation took too long",
          },
          504,
        );
      }
      throw err;
    }

    if (!resp.ok) {
      const text = await resp.text();
      return jsonResponse(
        {
          error: "Upstream DashScope request failed",
          status: resp.status,
          detail: text,
        },
        500,
      );
    }

    const data = await resp.json();

    const generatedChoices = data.output?.choices;
    if (!generatedChoices || generatedChoices.length === 0) {
      return jsonResponse(
        { error: "No image output from upstream", detail: data },
        500,
      );
    }

    const generatedImageUrl =
      generatedChoices[0]?.message?.content?.[0]?.image;

    if (!generatedImageUrl) {
      return jsonResponse(
        { error: "Image URL not found in upstream response", detail: data },
        500,
      );
    }

    let imgResp: Response;
    try {
      imgResp = await fetch(generatedImageUrl, {
        signal: AbortSignal.timeout(30000),
      });
    } catch (err) {
      if (err instanceof Error && err.name === "AbortError") {
        return jsonResponse({ error: "Generated image download timeout" }, 504);
      }
      throw err;
    }

    if (!imgResp.ok) {
      return jsonResponse(
        {
          error: "Failed to download generated image",
          status: imgResp.status,
        },
        500,
      );
    }

    const arrayBuffer = await imgResp.arrayBuffer();
    const generatedStoragePath = `${userId}/generated/${file_name}`;

    const { error: uploadError } = await supabase.storage
      .from("ai-wallpapers")
      .upload(generatedStoragePath, arrayBuffer, {
        contentType: "image/png",
        upsert: true,
      });

    if (uploadError) {
      return jsonResponse(
        {
          error: "Failed to upload generated image to storage",
          detail: uploadError.message,
        },
        500,
      );
    }

    return jsonResponse({
      status: "SUCCEED",
      path: generatedStoragePath,
      size: imageSize,
      aspect_ratio,
    });
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500);
  }
});