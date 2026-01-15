/// Dify Chat 相关数据模型
/// Dify Chat related data models
library;

/// Dify 响应模型
/// Dify response model
class DifyResponse {
  final String? event; // 事件类型 / Event type
  final String? taskId; // 任务ID / Task ID
  final String? messageId; // 消息ID / Message ID
  final String? conversationId; // 会话ID / Conversation ID
  final String? answer; // AI回答内容 / AI answer content
  final Map<String, dynamic>? metadata; // 元数据 / Metadata
  final String? createdAt; // 创建时间 / Created time

  DifyResponse({
    this.event,
    this.taskId,
    this.messageId,
    this.conversationId,
    this.answer,
    this.metadata,
    this.createdAt,
  });

  factory DifyResponse.fromJson(Map<String, dynamic> json) {
    return DifyResponse(
      event: json['event'] as String?,
      taskId: json['task_id'] as String?,
      messageId: json['message_id'] as String?,
      conversationId: json['conversation_id'] as String?,
      answer: json['answer'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (event != null) 'event': event,
      if (taskId != null) 'task_id': taskId,
      if (messageId != null) 'message_id': messageId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (answer != null) 'answer': answer,
      if (metadata != null) 'metadata': metadata,
      if (createdAt != null) 'created_at': createdAt,
    };
  }
}

/// 聊天消息模型
/// Chat message model
class ChatMessage {
  final String id;
  final String conversationId;
  final String content;
  final MessageRole role;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.role,
    required this.createdAt,
    this.metadata,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      content: json['content'] as String,
      role: MessageRole.fromString(json['role'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'content': content,
      'role': role.value,
      'created_at': createdAt.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// 创建用户消息
  /// Create user message
  factory ChatMessage.user({
    required String id,
    required String conversationId,
    required String content,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      content: content,
      role: MessageRole.user,
      createdAt: DateTime.now(),
      metadata: metadata,
    );
  }

  /// 创建助手消息
  /// Create assistant message
  factory ChatMessage.assistant({
    required String id,
    required String conversationId,
    required String content,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      content: content,
      role: MessageRole.assistant,
      createdAt: DateTime.now(),
      metadata: metadata,
    );
  }
}

/// 消息角色枚举
/// Message role enum
enum MessageRole {
  user('user'),
  assistant('assistant'),
  system('system');

  final String value;
  const MessageRole(this.value);

  static MessageRole fromString(String value) {
    return MessageRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => MessageRole.user,
    );
  }
}

/// 对话会话模型
/// Conversation model
class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      messageCount: json['message_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'message_count': messageCount,
    };
  }
}
