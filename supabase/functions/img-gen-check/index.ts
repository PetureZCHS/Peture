// supabase/functions/img-gen-check/index.ts

import { createClient } from "jsr:@supabase/supabase-js@2";

const UPSTREAM_BASE_URL = "https://api-inference.modelscope.cn/";
const upstreamApiKey = Deno.env.get("MODELSCOPE_API_KEY");

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(supabaseUrl, serviceRoleKey);

interface RequestBody {
  task_id: string;     // 前端传入
  file_name: string;   // 前端传入，保存到 Storage 用
}

interface TaskResult {
  task_status: "PENDING" | "RUNNING" | "SUCCEED" | "FAILED";
  output_images?: string[];
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

  if (!upstreamApiKey) {
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
    const { task_id, file_name } = (await req.json()) as RequestBody;

    if (!task_id || !file_name) {
      return new Response(
        JSON.stringify({ error: "task_id and file_name are required" }),
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

    // 轮询上游任务状态
    const commonHeaders = {
      Authorization: `Bearer ${upstreamApiKey}`,
      "Content-Type": "application/json",
      "X-ModelScope-Task-Type": "image_generation", // 上游要求的头部，名称保持不变
    };

    const maxAttempts = 60;      // 最多轮询 60 次
    const pollInterval = 1000;   // 每次间隔 1 秒

    let finalStatus: TaskResult["task_status"] = "PENDING";
    let imageUrl: string | null = null;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      const result = await fetch(`${UPSTREAM_BASE_URL}v1/tasks/${task_id}`, {
        method: "GET",
        headers: commonHeaders,
      });

      if (!result.ok) {
        const text = await result.text();
        console.log("Upstream task query failed:", result.status, text);
        return new Response(
          JSON.stringify({
            error: "Failed to query upstream task status",
            status: result.status,
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

      const data = (await result.json()) as TaskResult;

      if (data.task_status === "SUCCEED") {
        finalStatus = "SUCCEED";
        if (!data.output_images || data.output_images.length === 0) {
          return new Response(
            JSON.stringify({
              error: "No output_images returned from upstream",
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
        imageUrl = data.output_images[0];
        break;
      } else if (data.task_status === "FAILED") {
        finalStatus = "FAILED";
        break;
      } else {
        console.log(
          `Attempt ${attempt}/${maxAttempts}, upstream status: ${data.task_status}`,
        );
      }

      if (attempt < maxAttempts) {
        await new Promise((resolve) => setTimeout(resolve, pollInterval));
      }
    }

    if (finalStatus === "FAILED") {
      return new Response(
        JSON.stringify({
          error: "Upstream image generation failed",
          task_id,
          status: "failed",
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

    if (!imageUrl) {
      return new Response(
        JSON.stringify({
          error: "Upstream task did not complete in time",
          task_id,
          status: "timeout",
        }),
        {
          status: 504,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        },
      );
    }

    // 从上游下载图片二进制
    const imgResp = await fetch(imageUrl);
    if (!imgResp.ok) {
      const text = await imgResp.text();
      return new Response(
        JSON.stringify({
          error: "Failed to download generated image from upstream",
          status: imgResp.status,
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

    const arrayBuffer = await imgResp.arrayBuffer();
    const fileBytes = new Uint8Array(arrayBuffer);

    // 保存到 Supabase Storage: ai-wallpapers / <userId>/generated/<file_name>
    const storagePath = `${userId}/generated/${file_name}`;

    const { error: uploadError } = await supabase.storage
      .from("ai-wallpapers")
      .upload(storagePath, fileBytes, {
        contentType: "image/jpeg", // 或根据 file_name 判断
        upsert: true,
      });

    if (uploadError) {
      return new Response(
        JSON.stringify({
          error: "Failed to upload image to storage",
          detail: uploadError.message,
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

    // 返回给前端的内容不包含任何上游厂商信息
    return new Response(
      JSON.stringify({
        task_id,
        status: finalStatus === "SUCCEED" ? "completed" : finalStatus.toLowerCase(),
        result_url: storagePath,
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