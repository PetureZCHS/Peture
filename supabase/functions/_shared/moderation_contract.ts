export const MODERATION_SCENES = [
  "nickname",
  "owner_nickname",
  "pet_name",
  "avatar",
  "pet_avatar",
  "ai_input",
  "ai_output",
  "diary_input",
  "diary_output",
  "image_input",
  "image_output",
] as const;

export type ModerationScene = (typeof MODERATION_SCENES)[number];

export const MODERATION_ERROR_CODES = {
  blocked: "MODERATION_BLOCKED",
  timeout: "MODERATION_TIMEOUT",
  providerError: "MODERATION_PROVIDER_ERROR",
  unauthorized: "MODERATION_UNAUTHORIZED",
  invalidRequest: "MODERATION_INVALID_REQUEST",
  unknown: "MODERATION_UNKNOWN",
} as const;

export interface ModerationResult {
  passed: boolean;
  scene: ModerationScene;
  riskLevel: "none" | "low" | "medium" | "high" | "unknown";
  riskLabels: string[];
  action: "allow" | "review" | "block" | "unknown";
  message: string;
  traceId: string;
  errorCode?: string;
}

export function isValidScene(scene: string): scene is ModerationScene {
  return MODERATION_SCENES.includes(scene as ModerationScene);
}

export function blockedResult(
  scene: ModerationScene,
  traceId: string,
  message = "内容包含敏感信息",
  riskLabels: string[] = [],
): ModerationResult {
  return {
    passed: false,
    scene,
    riskLevel: "high",
    riskLabels,
    action: "block",
    message,
    traceId,
    errorCode: MODERATION_ERROR_CODES.blocked,
  };
}

export function reviewResult(
  scene: ModerationScene,
  traceId: string,
  message = "内容存在风险嫌疑，请修改后重试",
  riskLabels: string[] = [],
): ModerationResult {
  return {
    passed: false,
    scene,
    riskLevel: "medium",
    riskLabels,
    action: "review",
    message,
    traceId,
    errorCode: MODERATION_ERROR_CODES.blocked,
  };
}

export function passedResult(scene: ModerationScene, traceId: string): ModerationResult {
  return {
    passed: true,
    scene,
    riskLevel: "none",
    riskLabels: [],
    action: "allow",
    message: "ok",
    traceId,
  };
}

export function providerErrorResult(
  scene: ModerationScene,
  traceId: string,
  message = "审核服务暂时不可用",
): ModerationResult {
  return {
    passed: false,
    scene,
    riskLevel: "unknown",
    riskLabels: [],
    action: "block",
    message,
    traceId,
    errorCode: MODERATION_ERROR_CODES.providerError,
  };
}

