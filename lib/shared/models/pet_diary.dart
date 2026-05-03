class PetDiary {
  final String? id; // 从 int? 改为 String? 以支持 UUID
  final String? petId; // 关联的宠物ID
  final String originalText; // 用户输入的原始文本
  final String content; // AI生成的日记内容
  final String style; // 日记风格
  final DateTime timestamp;
  final String? aiImg; // AI生成配图在 ai-wallpapers 中的文件路径

  PetDiary({
    this.id,
    this.petId,
    required this.originalText,
    required this.content,
    required this.style,
    required this.timestamp,
    this.aiImg,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'pet_id': petId,
        'original_text': originalText,
        'content': content,
        'style': style,
        'timestamp': timestamp.toIso8601String(),
        'ai_img': aiImg,
      };

  factory PetDiary.fromMap(Map<String, dynamic> map) {
    // 兼容 timestamp 和 created_at
    final timeStr = map['timestamp'] ?? map['created_at'];
    return PetDiary(
      id: map['id']?.toString(),
      petId: map['pet_id']?.toString(),
      originalText: map['original_text'] as String? ?? '',
      content: map['content'] as String,
      style: map['style'] as String? ?? '小红书',
      timestamp: timeStr != null ? DateTime.parse(timeStr.toString()) : DateTime.now(),
      aiImg: map['ai_img'] as String?,
    );
  }
}
