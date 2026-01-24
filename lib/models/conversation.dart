// lib/models/conversation.dart

// -----------------------------------------------------------------------------
// [保留] 用于本地数据库存储的模型
// 这个 Conversation 类是你原来写的，用于在手机本地SQLite数据库中存取聊天记录。
// 我们保留它不动，以确保你的历史记录等功能不受影响。
// -----------------------------------------------------------------------------
class Conversation {
  final String? id; // 从 int? 改为 String? 以支持 UUID
  final String title; // 对话标题（总结）
  final DateTime timestamp; // 时间戳
  final bool isPinned; // 是否置顶
  final String? difyConversationId; // Dify 的 conversation_id（用于接上上文）

  Conversation({
    this.id,
    required this.title,
    required this.timestamp,
    this.isPinned = false,
    this.difyConversationId,
  });

  // 将对象转换为Map（用于存入数据库）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      // [已更正] 这里之前写错了，应该是 toIso8601String
      'timestamp': timestamp.toIso8601String(),
      'is_pinned': isPinned ? 1 : 0,
      'dify_conversation_id': difyConversationId,
    };
  }

  // 从Map创建对象（从数据库读取）
  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id']?.toString(), // 确保转换为 String
      // 兼容旧数据：如果存在 question 字段，使用它作为 title；否则使用 title 字段
      title: map['title'] ?? map['question'] ?? '未命名对话',
      timestamp: DateTime.parse(map['timestamp'] ?? map['created_at']),
      isPinned: map['is_pinned'] == 1 || map['is_pinned'] == true,
      difyConversationId: map['dify_conversation_id'] as String?,
    );
  }

  // copyWith 方法
  Conversation copyWith({
    String? id, // 从 int? 改为 String?
    String? title,
    DateTime? timestamp,
    bool? isPinned,
    String? difyConversationId,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      timestamp: timestamp ?? this.timestamp,
      isPinned: isPinned ?? this.isPinned,
      difyConversationId: difyConversationId ?? this.difyConversationId,
    );
  }
}

// -----------------------------------------------------------------------------
// [新增] 用于解析API网络响应的模型
// 以下这些类是专门为了匹配后端API /api/chat/send 返回的JSON格式而创建的。
// 它们负责将网络数据转换成Dart对象，让我们可以方便地在App中使用。
// -----------------------------------------------------------------------------

/// 1. 最外层的API响应模型，对应整个JSON结构
class ApiResponse {
  final bool success;
  final String message;
  final ChatData? data; // data字段可能为null，所以用 ChatData?

  ApiResponse({required this.success, required this.message, this.data});

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? 'Unknown error',
      // 关键：只有在 success 为 true 且 'data' 字段不为 null 时才解析 ChatData
      data: json['success'] == true && json['data'] != null
          ? ChatData.fromJson(json['data'])
          : null,
    );
  }
}

/// 2. `data` 字段对应的模型，包含了会话的核心信息
class ChatData {
  final String conversationId;
  final ChatMessage userMessage;
  final ChatMessage assistantMessage;

  ChatData({
    required this.conversationId,
    required this.userMessage,
    required this.assistantMessage,
  });

  factory ChatData.fromJson(Map<String, dynamic> json) {
    return ChatData(
      conversationId: json['conversationId'],
      userMessage: ChatMessage.fromJson(json['userMessage']),
      assistantMessage: ChatMessage.fromJson(json['assistantMessage']),
    );
  }
}

/// 3. `userMessage` 和 `assistantMessage` 字段共用的模型
class ChatMessage {
  final String messageId;
  final String role; // "user" or "assistant"
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.messageId,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['messageId'],
      role: json['role'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
