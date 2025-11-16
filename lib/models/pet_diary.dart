class PetDiary {
  final int? id;
  final String originalText; // 用户输入的原始文本
  final String content; // AI生成的日记内容
  final String style; // 日记风格
  final DateTime timestamp;

  PetDiary({
    this.id,
    required this.originalText,
    required this.content,
    required this.style,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'original_text': originalText,
    'content': content,
    'style': style,
    'timestamp': timestamp.toIso8601String(),
  };

  factory PetDiary.fromMap(Map<String, dynamic> map) => PetDiary(
    id: map['id'] as int?,
    originalText: map['original_text'] as String? ?? '',
    content: map['content'] as String,
    style: map['style'] as String? ?? '小红书',
    timestamp: DateTime.parse(map['timestamp'] as String),
  );
}
