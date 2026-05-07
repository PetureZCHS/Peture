class PetDiary {
  final String? id; // 从 int? 改为 String? 以支持 UUID
  final String? petId; // 关联的宠物ID
  final String originalText; // 用户输入的原始文本
  final String content; // AI生成的日记内容
  final String style; // 日记风格
  final DateTime timestamp;
  final String? aiImg; // AI生成配图在 ai-wallpapers 中的文件路径
  final String? petType; // 关联宠物的类型（狗/猫等）

  PetDiary({
    this.id,
    this.petId,
    required this.originalText,
    required this.content,
    required this.style,
    required this.timestamp,
    this.aiImg,
    this.petType,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'pet_id': petId,
        'original_text': originalText,
        'content': content,
        'style': style,
        'timestamp': timestamp.toIso8601String(),
        'ai_img': aiImg,
        'pet_type': petType,
      };

  factory PetDiary.fromMap(Map<String, dynamic> map) {
    // 兼容 timestamp 和 created_at
    final timeStr = map['timestamp'] ?? map['created_at'];
    // 从关联的 pets 表获取 type（如果有的话）
    String? petType;
    final petsData = map['pets'];
    if (petsData is Map) {
      petType = petsData['type']?.toString();
    } else if (petsData is List && petsData.isNotEmpty) {
      petType = petsData.first['type']?.toString();
    }
    return PetDiary(
      id: map['id']?.toString(),
      petId: map['pet_id']?.toString(),
      originalText: map['original_text'] as String? ?? '',
      content: map['content'] as String,
      style: map['style'] as String? ?? '小红书',
      timestamp: timeStr != null ? DateTime.parse(timeStr.toString()) : DateTime.now(),
      aiImg: map['ai_img'] as String?,
      petType: petType,
    );
  }
}
