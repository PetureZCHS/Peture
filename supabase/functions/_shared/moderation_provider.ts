import { blockedResult, passedResult, providerErrorResult } from "./moderation_contract.ts";
import { serviceClient } from "./auth.ts";
import { loadYidunConfigFromEnv, yidunImageCheck, yidunTextCheck } from "./yidun_client.ts";
const keywordRules = [
  {
    label: "political",
    pattern: /(颠覆|暴乱|恐怖组织|极端组织|反动)/i
  },
  {
    label: "violence",
    pattern: /(虐杀|碎尸|血腥|爆头|屠杀)/i
  },
  {
    label: "terror",
    pattern: /(炸弹制作|恐袭|人体炸弹|劫持)/i
  },
  {
    label: "porn",
    pattern: /(裸体|强奸|幼交|黄色网站|淫秽)/i
  }
];
export function localTextModeration(scene, content, traceId) {
  const hitLabels = keywordRules.filter((rule)=>rule.pattern.test(content)).map((rule)=>rule.label);
  if (hitLabels.length > 0) {
    return blockedResult(scene, traceId, "内容包含敏感信息", hitLabels);
  }
  return passedResult(scene, traceId);
}
export function localImageModeration(scene, imageBase64, storagePath, traceId) {
  if (!imageBase64 && !storagePath) {
    return providerErrorResult(scene, traceId, "缺少图像审核输入");
  }
  // 兜底规则：仅对路径/元信息做关键词防御；真实业务可由第三方服务替换。
  const pathToCheck = (storagePath ?? "").toLowerCase();
  if (/porn|nsfw|terror|blood|violence/.test(pathToCheck)) {
    return blockedResult(scene, traceId, "图像内容不符合规范", [
      "unsafe_image"
    ]);
  }
  return passedResult(scene, traceId);
}
function bytesToBase64(bytes) {
  let binary = "";
  const chunkSize = 0x8000;
  for(let i = 0; i < bytes.length; i += chunkSize){
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}
async function loadImageBase64(storagePath) {
  const buckets = [
    "ai-images-temp",
    "user-avatars-temp",
    "ai-images",
    "user-avatars"
  ];
  for (const bucket of buckets){
    const { data, error } = await serviceClient.storage.from(bucket).download(storagePath);
    if (!error && data) {
      const bytes = new Uint8Array(await data.arrayBuffer());
      return bytesToBase64(bytes);
    }
  }
  return null;
}
export async function executeTextModeration(scene, content, traceId) {
  const outputEnabled = (Deno.env.get("ENABLE_OUTPUT_MODERATION") ?? "true").toLowerCase() === "true";
  if (!outputEnabled && (scene === "ai_output" || scene === "diary_output" || scene === "image_output")) {
    return {
      result: passedResult(scene, traceId),
      provider: "output_disabled_by_flag"
    };
  }
  const enabled = (Deno.env.get("ENABLE_TEXT_MODERATION") ?? "true").toLowerCase() === "true";
  if (!enabled) {
    return {
      result: passedResult(scene, traceId),
      provider: "disabled_by_flag"
    };
  }
  const yidunCfg = loadYidunConfigFromEnv();
  if (!yidunCfg || !yidunCfg.textBusinessId) {
    return {
      result: localTextModeration(scene, content, traceId),
      provider: "local_fallback"
    };
  }
  try {
    const exec = await yidunTextCheck(yidunCfg, scene, content, traceId);
    if (exec.ok) {
      return {
        result: exec.result,
        provider: "yidun",
        providerResponse: exec.providerResponse
      };
    }
    return {
      result: exec.result,
      provider: "yidun",
      providerResponse: exec.providerResponse
    };
  } catch  {
    return {
      result: localTextModeration(scene, content, traceId),
      provider: "local_fallback"
    };
  }
}
export async function executeImageModeration(scene, imageBase64, storagePath, traceId) {
  const outputEnabled = (Deno.env.get("ENABLE_OUTPUT_MODERATION") ?? "true").toLowerCase() === "true";
  if (!outputEnabled && scene === "image_output") {
    return {
      result: passedResult(scene, traceId),
      provider: "output_disabled_by_flag"
    };
  }
  const enabled = (Deno.env.get("ENABLE_IMAGE_MODERATION") ?? "true").toLowerCase() === "true";
  if (!enabled) {
    return {
      result: passedResult(scene, traceId),
      provider: "disabled_by_flag"
    };
  }
  let effectiveBase64 = imageBase64;
  if (!effectiveBase64 && storagePath) {
    const loaded = await loadImageBase64(storagePath);
    if (loaded) effectiveBase64 = loaded;
  }
  if (!effectiveBase64 && !storagePath) {
    return {
      result: providerErrorResult(scene, traceId, "缺少图像审核输入"),
      provider: "local_fallback"
    };
  }
  const yidunCfg = loadYidunConfigFromEnv();
  if (!yidunCfg || !yidunCfg.imageBusinessId) {
    return {
      result: localImageModeration(scene, effectiveBase64, storagePath, traceId),
      provider: "local_fallback"
    };
  }
  try {
    const exec = await yidunImageCheck(yidunCfg, scene, effectiveBase64, traceId);
    if (exec.ok) {
      return {
        result: exec.result,
        provider: "yidun",
        providerResponse: exec.providerResponse
      };
    }
    return {
      result: exec.result,
      provider: "yidun",
      providerResponse: exec.providerResponse
    };
  } catch  {
    return {
      result: localImageModeration(scene, effectiveBase64, storagePath, traceId),
      provider: "local_fallback"
    };
  }
}
