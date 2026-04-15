enum ModerationScene {
  nickname('nickname'),
  ownerNickname('owner_nickname'),
  petName('pet_name'),
  avatar('avatar'),
  petAvatar('pet_avatar'),
  aiInput('ai_input'),
  aiOutput('ai_output'),
  diaryInput('diary_input'),
  diaryOutput('diary_output'),
  imageInput('image_input'),
  imageOutput('image_output');

  const ModerationScene(this.value);
  final String value;
}

enum ModerationErrorCode {
  blocked('MODERATION_BLOCKED'),
  timeout('MODERATION_TIMEOUT'),
  providerError('MODERATION_PROVIDER_ERROR'),
  unauthorized('MODERATION_UNAUTHORIZED'),
  invalidRequest('MODERATION_INVALID_REQUEST'),
  unknown('MODERATION_UNKNOWN');

  const ModerationErrorCode(this.value);
  final String value;

  static ModerationErrorCode fromString(String? code) {
    if (code == null || code.isEmpty) return ModerationErrorCode.unknown;
    for (final item in ModerationErrorCode.values) {
      if (item.value == code) return item;
    }
    return ModerationErrorCode.unknown;
  }
}

