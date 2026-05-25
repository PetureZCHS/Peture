/**
 * 网易易盾内容安全 v5 文本/图片同步检测（官方 form-urlencoded + MD5 签名）。
 * 签名规则与官方 Go 示例一致：https://github.com/yidun/antispam-go-demo
 */
import md5 from "npm:md5@2.3.0";
import type { ModerationResult, ModerationScene } from "./moderation_contract.ts";
import { blockedResult, passedResult, providerErrorResult, reviewResult } from "./moderation_contract.ts";

export type TreatSuspectAs = "block" | "review" | "pass";

export interface YidunEnvConfig {
  secretId: string;
  secretKey: string;
  textBusinessId: string;
  imageBusinessId: string;
  apiOrigin: string;
  textVersion: string;
  imageVersion: string;
  treatSuspectAs: TreatSuspectAs;
}

export function loadYidunConfigFromEnv(): YidunEnvConfig | null {
  const secretId = Deno.env.get("YIDUN_SECRET_ID")?.trim() || Deno.env.get("YIDUN_APP_KEY")?.trim();
  const secretKey = Deno.env.get("YIDUN_SECRET_KEY")?.trim();
  if (!secretId || !secretKey) return null;

  let apiOrigin = (Deno.env.get("YIDUN_API_HOST")?.trim() || "https://as.dun.163.com").replace(/\/$/, "");
  if (!/^https?:\/\//i.test(apiOrigin)) {
    apiOrigin = `https://${apiOrigin}`;
  }

  const treatRaw = (Deno.env.get("YIDUN_TREAT_SUSPECT_AS")?.trim().toLowerCase() || "block") as TreatSuspectAs;
  const treatSuspectAs: TreatSuspectAs =
    treatRaw === "review" || treatRaw === "pass" ? treatRaw : "block";

  return {
    secretId,
    secretKey,
    textBusinessId: Deno.env.get("YIDUN_TEXT_BUSINESS_ID")?.trim() || "",
    imageBusinessId: Deno.env.get("YIDUN_IMAGE_BUSINESS_ID")?.trim() || "",
    apiOrigin,
    textVersion: Deno.env.get("YIDUN_TEXT_VERSION")?.trim() || "v5.2",
    imageVersion: Deno.env.get("YIDUN_IMAGE_VERSION")?.trim() || "v5.1",
    treatSuspectAs,
  };
}

/** 生成签名：参数名 ASCII 升序，拼接 key+value，末尾追加 secretKey，再 MD5(hex) */
export function yidunGenSignature(params: Record<string, string>, secretKey: string): string {
  const keys = Object.keys(params).filter((k) => k !== "signature").sort();
  let paramStr = "";
  for (const key of keys) {
    paramStr += key + params[key];
  }
  paramStr += secretKey;
  return md5(paramStr) as string;
}

function buildSignedFormBody(
  businessParams: Record<string, string>,
  opts: { secretId: string; secretKey: string; businessId: string },
): string {
  const params: Record<string, string> = {
    ...businessParams,
    secretId: opts.secretId,
    businessId: opts.businessId,
    timestamp: String(Date.now()),
    nonce: String(Math.floor(Math.random() * 1e10)),
  };
  const sig = yidunGenSignature(params, opts.secretKey);
  params.signature = sig;
  return new URLSearchParams(params).toString();
}

export function stripBase64DataUrlPrefix(data: string): string {
  const t = data.trim();
  const m = /^data:[^;]+;base64,(.+)$/i.exec(t);
  return m ? m[1]! : t.replace(/\s/g, "");
}

export function truncateYidunDataId(traceId: string, scene: ModerationScene): string {
  const base = `${scene}_${traceId}`.replace(/[^\w\-_.]/g, "_");
  return base.length <= 128 ? base : base.slice(0, 128);
}

export function truncateYidunContent(content: string): string {
  const max = 10000;
  if (content.length <= max) return content;
  return content.slice(0, max);
}

function extractLabelStrings(antispam: Record<string, unknown>): string[] {
  const labels = antispam.labels;
  if (!Array.isArray(labels)) return [];
  const out: string[] = [];
  for (const item of labels) {
    if (item && typeof item === "object" && "label" in item) {
      out.push(String((item as { label: unknown }).label));
    }
  }
  return out;
}

function mapSuggestionToResult(
  scene: ModerationScene,
  traceId: string,
  suggestion: number,
  riskLabels: string[],
  treatSuspectAs: TreatSuspectAs,
  imageMessage: boolean,
): ModerationResult {
  if (suggestion === 0) {
    return passedResult(scene, traceId);
  }
  const blockMsg = imageMessage ? "图像内容不符合规范" : "内容包含敏感信息";
  if (suggestion === 2) {
    return blockedResult(scene, traceId, blockMsg, riskLabels);
  }
  if (suggestion === 1) {
    if (treatSuspectAs === "pass") return passedResult(scene, traceId);
    if (treatSuspectAs === "review") {
      return reviewResult(scene, traceId, "内容存在风险嫌疑，请修改后重试", riskLabels);
    }
    return blockedResult(scene, traceId, blockMsg, riskLabels);
  }
  return providerErrorResult(scene, traceId, "审核结果格式异常");
}

async function postYidun(
  path: string,
  body: string,
  timeoutMs: number,
): Promise<{ ok: true; json: Record<string, unknown> } | { ok: false; error: string }> {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const resp = await fetch(path, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
      signal: controller.signal,
    });
    const text = await resp.text();
    let json: Record<string, unknown>;
    try {
      json = JSON.parse(text) as Record<string, unknown>;
    } catch {
      return { ok: false, error: `invalid_json: ${text.slice(0, 200)}` };
    }
    return { ok: true, json };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return { ok: false, error: msg };
  } finally {
    clearTimeout(id);
  }
}

export async function yidunTextCheck(
  cfg: YidunEnvConfig,
  scene: ModerationScene,
  content: string,
  traceId: string,
): Promise<
  { ok: true; result: ModerationResult; providerResponse: Record<string, unknown> } | {
    ok: false;
    result: ModerationResult;
    providerResponse?: Record<string, unknown>;
  }
> {
  if (!cfg.textBusinessId) {
    return {
      ok: false,
      result: providerErrorResult(scene, traceId, "未配置 YIDUN_TEXT_BUSINESS_ID"),
    };
  }
  const dataId = truncateYidunDataId(traceId, scene);
  const business: Record<string, string> = {
    dataId,
    content: truncateYidunContent(content),
    version: cfg.textVersion,
    category: scene,
    callback: JSON.stringify({ scene, traceId }),
  };
  const body = buildSignedFormBody(business, {
    secretId: cfg.secretId,
    secretKey: cfg.secretKey,
    businessId: cfg.textBusinessId,
  });

  const url = `${cfg.apiOrigin}/v5/text/check`;
  const posted = await postYidun(url, body, 8000);
  if (!posted.ok) {
    return {
      ok: false,
      result: providerErrorResult(scene, traceId, "易盾文本检测请求失败"),
    };
  }
  const json = posted.json;
  const code = Number(json.code);
  if (code !== 200) {
    return {
      ok: false,
      result: providerErrorResult(scene, traceId, `易盾文本检测失败: ${json.msg ?? code}`),
      providerResponse: json,
    };
  }
  const resultObj = json.result as Record<string, unknown> | undefined;
  const antispam = resultObj?.antispam as Record<string, unknown> | undefined;
  if (!antispam || typeof antispam.suggestion !== "number") {
    return {
      ok: false,
      result: providerErrorResult(scene, traceId, "易盾文本响应缺少 antispam"),
      providerResponse: json,
    };
  }
  const suggestion = antispam.suggestion as number;
  const labels = extractLabelStrings(antispam);
  const modResult = mapSuggestionToResult(scene, traceId, suggestion, labels, cfg.treatSuspectAs, false);
  return { ok: true, result: modResult, providerResponse: json };
}

export async function yidunImageCheck(
  cfg: YidunEnvConfig,
  scene: ModerationScene,
  imageBase64: string,
  traceId: string,
): Promise<
  { ok: true; result: ModerationResult; providerResponse: Record<string, unknown> } | {
    ok: false;
    result: ModerationResult;
    providerResponse?: Record<string, unknown>;
  }
> {
  if (!cfg.imageBusinessId) {
    return {
      ok: false,
      result: providerErrorResult(scene, traceId, "未配置 YIDUN_IMAGE_BUSINESS_ID"),
      providerResponse: {
        branch: "missing_image_business_id",
        scene,
        traceId,
        message: "未配置 YIDUN_IMAGE_BUSINESS_ID",
      },
    };
  }
  const dataId = truncateYidunDataId(traceId, scene);
  const cleanB64 = stripBase64DataUrlPrefix(imageBase64);
  // type=2 表示 BASE64；易盾要求 Base64 必须请求 base64Check，不可用 /v5/image/check
  const imageItem = {
    name: dataId,
    type: 2,
    data: cleanB64,
    dataId,
  };
  const imagesJson = JSON.stringify([imageItem]);
  const business: Record<string, string> = {
    images: imagesJson,
    version: cfg.imageVersion,
    category: scene,
    callback: JSON.stringify({ scene, traceId }),
  };
  const body = buildSignedFormBody(business, {
    secretId: cfg.secretId,
    secretKey: cfg.secretKey,
    businessId: cfg.imageBusinessId,
  });

  const url = `${cfg.apiOrigin}/v5/image/base64Check`;
  const posted = await postYidun(url, body, 15000);
  if (!posted.ok) {
    return {
      ok: false,
      result: providerErrorResult(scene, traceId, "易盾图片检测请求失败"),
      providerResponse: {
        branch: "posted_not_ok",
        scene,
        traceId,
        endpoint: url,
        message: "易盾图片检测请求失败",
      },
    };
  }
  const json = posted.json;
  const code = Number(json.code);
  if (code !== 200) {
    return {
      ok: false,
      result: providerErrorResult(scene, traceId, `易盾图片检测失败: ${json.msg ?? code}`),
      providerResponse: json,
    };
  }
  const resultArr = json.result;
  if (!Array.isArray(resultArr) || resultArr.length === 0) {
    return {
      ok: false,
      result: providerErrorResult(scene, traceId, "易盾图片响应格式异常"),
      providerResponse: json,
    };
  }
  const first = resultArr[0] as Record<string, unknown>;
  const antispam = first.antispam as Record<string, unknown> | undefined;
  if (!antispam) {
    return {
      ok: false,
      result: providerErrorResult(scene, traceId, "易盾图片响应缺少 antispam"),
      providerResponse: json,
    };
  }
  const status = Number(antispam.status);
  if (status === 3) {
    const fr = antispam.failureReason;
    return {
      ok: false,
      result: providerErrorResult(scene, traceId, `图片检测失败(${fr ?? "unknown"})`),
      providerResponse: json,
    };
  }
  if (status !== 2) {
    return {
      ok: false,
      result: providerErrorResult(scene, traceId, "图片检测状态异常"),
      providerResponse: json,
    };
  }
  if (typeof antispam.suggestion !== "number") {
    return {
      ok: false,
      result: providerErrorResult(scene, traceId, "易盾图片结果缺少 suggestion"),
      providerResponse: json,
    };
  }
  const suggestion = antispam.suggestion as number;
  const labels = extractLabelStrings(antispam);
  const modResult = mapSuggestionToResult(scene, traceId, suggestion, labels, cfg.treatSuspectAs, true);
  return { ok: true, result: modResult, providerResponse: json };
}
