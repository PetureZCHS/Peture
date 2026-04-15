import '../domain/moderation_scene.dart';

String mapModerationErrorMessage(ModerationErrorCode code) {
  switch (code) {
    case ModerationErrorCode.blocked:
      return '内容不符合社区规范，请修改后重试';
    case ModerationErrorCode.timeout:
      return '审核超时，请稍后重试';
    case ModerationErrorCode.providerError:
      return '审核服务暂时不可用，请稍后再试';
    case ModerationErrorCode.unauthorized:
      return '登录状态异常，请重新登录后重试';
    case ModerationErrorCode.invalidRequest:
      return '提交内容格式异常，请检查后重试';
    case ModerationErrorCode.unknown:
      return '审核失败，请稍后重试';
  }
}

