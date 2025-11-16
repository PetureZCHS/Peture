// 用于存储完整聊天历史的模型
class ChatHistory {
  final int id; // 数据库ID
  final String conversationId; // 对话ID
  final List<ChatMessage> messages; // 消息列表
  final DateTime timestamp; // 时间戳

  ChatHistory({
    required this.id,
    required this.conversationId,
    required this.messages,
    required this.timestamp,
  });

  // 将对象转换为Map（用于存入数据库）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // 从Map创建对象（从数据库读取）
  factory ChatHistory.fromMap(Map<String, dynamic> map) {
    return ChatHistory(
      id: map['id'],
      conversationId: map['conversation_id'],
      messages: [], // 消息列表将在后续步骤中填充
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  // copyWith 方法
  ChatHistory copyWith({
    int? id,
    String? conversationId,
    List<ChatMessage>? messages,
    DateTime? timestamp,
  }) {
    return ChatHistory(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

// 用于存储单条消息的模型
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  // 将对象转换为Map（用于存入数据库）
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'is_user': isUser ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // 从Map创建对象（从数据库读取）
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'],
      isUser: map['is_user'] == 1,
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  // copyWith 方法
  ChatMessage copyWith({String? text, bool? isUser, DateTime? timestamp}) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
