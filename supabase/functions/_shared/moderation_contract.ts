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
  "image_output"
];
export const MODERATION_ERROR_CODES = {
  blocked: "MODERATION_BLOCKED",
  timeout: "MODERATION_TIMEOUT",
  providerError: "MODERATION_PROVIDER_ERROR",
  unauthorized: "MODERATION_UNAUTHORIZED",
  invalidRequest: "MODERATION_INVALID_REQUEST",
  unknown: "MODERATION_UNKNOWN"
};
export function isValidScene(scene) {
  return MODERATION_SCENES.includes(scene);
}
export function blockedResult(scene, traceId, message = "内容包含敏感信息", riskLabels = []) {
  return {
    passed: false,
    scene,
    riskLevel: "high",
    riskLabels,
    action: "block",
    message,
    traceId,
    errorCode: MODERATION_ERROR_CODES.blocked
  };
}
export function reviewResult(scene, traceId, message = "内容存在风险嫌疑，请修改后重试", riskLabels = []) {
  return {
    passed: false,
    scene,
    riskLevel: "medium",
    riskLabels,
    action: "review",
    message,
    traceId,
    errorCode: MODERATION_ERROR_CODES.blocked
  };
}
export function passedResult(scene, traceId) {
  return {
    passed: true,
    scene,
    riskLevel: "none",
    riskLabels: [],
    action: "allow",
    message: "ok",
    traceId
  };
}
export function providerErrorResult(scene, traceId, message = "审核服务暂时不可用") {
  return {
    passed: false,
    scene,
    riskLevel: "unknown",
    riskLabels: [],
    action: "block",
    message,
    traceId,
    errorCode: MODERATION_ERROR_CODES.providerError
  };
}
