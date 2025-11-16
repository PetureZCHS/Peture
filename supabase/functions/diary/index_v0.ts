import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const apiKey = Deno.env.get("DIFY_DIARY_API_KEY");
const DIFY_API = "https://api.dify.ai/v1/workflows/run";
Deno.serve(async (req)=>{
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", {
      status: 405
    });
  }
  let body;
  try {
    body = await req.json();
  } catch  {
    return new Response("Bad Request", {
      status: 400
    });
  }
  const { inputs, userId, response_mode } = body ?? {};
  const mode = response_mode === "streaming" ? "streaming" : "blocking";
  if (!apiKey) {
    return new Response("Missing DIFY_DIARY_API_KEY", {
      status: 500
    });
  }
  const baseHeaders = {
    "Authorization": `Bearer ${apiKey}`,
    "Content-Type": "application/json"
  };
  const payload = {
    inputs,
    response_mode: mode,
    user: userId || "anon"
  };
  if (mode === "streaming") {
    // 上游以 SSE 返回，函数作为反向代理原样转发事件流
    const upstream = await fetch(DIFY_API, {
      method: "POST",
      headers: {
        ...baseHeaders,
        "Accept": "text/event-stream"
      },
      body: JSON.stringify(payload)
    });
    if (!upstream.body) {
      return new Response("Upstream unavailable", {
        status: 502
      });
    }
    const sseHeaders = new Headers({
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      "Connection": "keep-alive"
    });
    // 通过 TransformStream 将上游 ReadableStream 原样回传
    const { readable, writable } = new TransformStream();
    upstream.body.pipeTo(writable);
    return new Response(readable, {
      status: upstream.status,
      headers: sseHeaders
    });
  } else {
    // 阻塞模式：等待完整结果后再返回
    const resp = await fetch(DIFY_API, {
      method: "POST",
      headers: baseHeaders,
      body: JSON.stringify(payload)
    });
    return new Response(await resp.text(), {
      status: resp.status,
      headers: {
        "Content-Type": resp.headers.get("Content-Type") ?? "application/json"
      }
    });
  }
});
