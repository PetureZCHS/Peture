/// 与表 [user_content_feedback.feedback_type] 一致
enum ContentFeedbackType {
  report('report'),
  notInterested('not_interested');

  const ContentFeedbackType(this.value);
  final String value;
}

/// 与表 [user_content_feedback.surface] 一致
enum ContentSurface {
  petDiary('pet_diary'),
  petDiaryDetail('pet_diary_detail'),
  aiImage('ai_image'),
  chatAi('chat_ai');

  const ContentSurface(this.value);
  final String value;
}

/// 举报原因 code，写入 reason_code
class ContentReportReason {
  static const illegal = 'illegal';
  static const misleading = 'misleading';
  static const harmful = 'harmful';
  static const other = 'other';

  static const labels = <String, String>{
    illegal: '违法违规',
    misleading: '不实信息',
    harmful: '有害或令人不适',
    other: '其他',
  };
}
