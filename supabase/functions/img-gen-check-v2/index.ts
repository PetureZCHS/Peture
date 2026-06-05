// supabase/functions/img-gen-check/index.ts

import { createClient } from "jsr:@supabase/supabase-js@2";

const UPSTREAM_BASE_URL = "https://api-inference.modelscope.cn/";
const upstreamApiKey = Deno.env.get("MODELSCOPE_API_KEY");

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, serviceRoleKey);

interface RequestBody {
  task_id: string;
  file_name: string;
}

interface TaskResult {
  task_status: string;
  output_images?: string[];
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  }

  if (!upstreamApiKey) {
    return new Response(JSON.stringify({ error: "Upstream API key is not set" }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  }

  try {
    const { task_id, file_name } = (await req.json()) as RequestBody;

    if (!task_id || !file_name) {
      return new Response(
        JSON.stringify({ error: "task_id and file_name are required" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.startsWith("Bearer ")
      ? authHeader.replace("Bearer ", "")
      : authHeader;

    if (!jwt) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders() },
      });
    }

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser(jwt);

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid user", detail: userError?.message }),
        {
          status: 401,
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
    }

    const userId = user.id;

    const commonHeaders = {
      Authorization: `Bearer ${upstreamApiKey}`,
      "Content-Type": "application/json",
      "X-ModelScope-Task-Type": "image_generation",
    };

    // 查询任务状态，添加 10 秒超时
    let result;
    try {
      result = await fetch(`${UPSTREAM_BASE_URL}v1/tasks/${task_id}`, {
        method: "GET",
        headers: commonHeaders,
        signal: AbortSignal.timeout(10000), // 10秒超时
      });
    } catch (err) {
      if (err.name === "AbortError") {
        return new Response(
          JSON.stringify({
            error: "Upstream API timeout",
            detail: "Task status query took too long",
          }),
          {
            status: 504,
            headers: { "Content-Type": "application/json", ...corsHeaders() },
          },
        );
      }
      throw err;
    }

    if (!result.ok) {
      const text = await result.text();
      return new Response(
        JSON.stringify({
          error: "Failed to query upstream task status",
          status: result.status,
          detail: text,
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
    }

    const data = (await result.json()) as TaskResult;

    const IN_PROGRESS = new Set(["PENDING", "RUNNING", "PROCESSING"]);

    if (IN_PROGRESS.has(data.task_status)) {
      return new Response(
        JSON.stringify({
          task_id,
          status: data.task_status,
          upstream_task_status: data.task_status,
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
    }

    if (data.task_status === "FAILED") {
      return new Response(
        JSON.stringify({
          task_id,
          status: "FAILED",
          error: "Upstream image generation failed",
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
    }

    if (data.task_status !== "SUCCEED") {
      return new Response(
        JSON.stringify({
          error: "Unknown upstream task_status",
          task_id,
          upstream_task_status: data.task_status,
          detail: data,
        }),
        {
          status: 500,
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
    }

    if (!data.output_images || data.output_images.length === 0) {
      return new Response(
        JSON.stringify({ error: "No output_images returned from upstream", task_id }),
        {
          status: 500,
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
    }

    const imageUrl = data.output_images[0];

    // 下载图片，添加 30 秒超时
    let imgResp;
    try {
      imgResp = await fetch(imageUrl, {
        signal: AbortSignal.timeout(30000), // 30秒超时
      });
    } catch (err) {
      if (err.name === "AbortError") {
        return new Response(
          JSON.stringify({
            error: "Image download timeout",
            detail: "Generated image took too long to download",
          }),
          {
            status: 504,
            headers: { "Content-Type": "application/json", ...corsHeaders() },
          },
        );
      }
      throw err;
    }

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
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
    }

    const arrayBuffer = await imgResp.arrayBuffer();

    const storagePath = `${userId}/generated/${file_name}`;

    const { error: uploadError } = await supabase.storage
      .from("ai-wallpapers")
      .upload(storagePath, arrayBuffer, {
        contentType: "image/jpeg",
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
          headers: { "Content-Type": "application/json", ...corsHeaders() },
        },
      );
    }

    return new Response(
      JSON.stringify({
        task_id,
        status: "SUCCEED",
        path: storagePath,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json", ...corsHeaders() },
      },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  }
});
