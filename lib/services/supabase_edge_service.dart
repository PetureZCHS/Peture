import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import 'analytics_service.dart';

// ============================================================================
// chat 事件类
// ============================================================================

/// Chat 流式事件基类
abstract class ChatStreamEvent {}

/// 内容事件 - 包含 AI 回复的文本片段
/// 对应 Dify 的 "message" 或 "agent_message" 事件
class ContentEvent implements ChatStreamEvent {
  final String content;

  ContentEvent(this.content);
}

/// 完成事件 - 对话完成
/// 对应 Dify 的 "message_end" 事件
class DoneEvent implements ChatStreamEvent {
  final String? conversationId;
  final String? messageId;

  DoneEvent({this.conversationId, this.messageId});
}

/// 错误事件 - 发生错误时触发
class ErrorEvent implements ChatStreamEvent {
  final String error;

  ErrorEvent(this.error);
}

class ModerationInterceptEvent implements ChatStreamEvent {
  final String message;

  ModerationInterceptEvent(this.message);
}

/// Supabase Edge Function 服务
/// 通过 Supabase Edge Function 调用 chat API
class SupabaseEdgeFunctionService {
  String _tokenSummary(String token) {
    if (token.length <= 16) return 'len=${token.length}';
    return '${token.substring(0, 8)}...${token.substring(token.length - 8)} (len=${token.length})';
  }

  String? _extractProjectRefFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      final iss = payload['iss']?.toString();
      if (iss == null || iss.isEmpty) return null;
      final host = Uri.parse(iss).host;
      final seg = host.split('.');
      if (seg.isEmpty) return null;
      return seg.first;
    } catch (_) {
      return null;
    }
  }

  String _projectRefFromProjectUrl() {
    final host = Uri.parse(SupabaseConfig.projectUrl).host;
    return host.split('.').first;
  }

  Future<String?> _getAccessToken({bool forceRefresh = false}) async {
    final auth = Supabase.instance.client.auth;
    if (forceRefresh) {
      try {
        await auth.refreshSession();
      } catch (e) {
        debugPrint('⚠️ 刷新会话失败: $e');
      }
    }
    return auth.currentSession?.accessToken;
  }

  /// 调用 chat 流式对话
  ///
  /// 参数说明：
  /// - query: 用户输入的问题（必填）
  /// - user: 用户标识（必填）
  /// - conversationId: 会话ID，用于继续之前的对话（可选）
  ///
  /// 返回一个流，包含 ContentEvent（内容）、DoneEvent（完成）、ErrorEvent（错误）
  Stream<ChatStreamEvent> callDifyChat({
    required String query,
    required String user,
    String? conversationId,
    bool doctorMode = false,
    bool agentMode = false,
    String? petContext,
    List<Map<String, String>> images = const [],
  }) async* {
    try {
      // ✅ 根据 Dify API 文档构建请求体
      // 必填字段：query, inputs, response_mode, user
      final body = {
        'query': query, // 用户输入
        'user': user, // 用户标识
        'response_mode': 'streaming', // 流式模式
        'inputs': {}, // 必填字段（可以是空对象）
        'doctor_mode': doctorMode,
        'agent_mode': agentMode,
        if (petContext != null && petContext.trim().isNotEmpty)
          'pet_context': petContext.trim(),
        if (images.isNotEmpty) 'images': images,
        // 可选字段
        if (conversationId != null) 'conversation_id': conversationId,
      };

      debugPrint('📤 调用 Edge Function: ${SupabaseConfig.difyChatFunctionName}');
      debugPrint('📦 必填参数:');
      debugPrint(
          '   - query: ${query.substring(0, 50.clamp(0, query.length))}...');
      debugPrint('   - user: $user');
      debugPrint('   - response_mode: streaming');
      debugPrint('   - inputs: {}');
      if (conversationId != null) {
        debugPrint('📎 可选参数: conversation_id=$conversationId');
      }

      final url = Uri.parse(SupabaseConfig.difyChatUrl);
      final accessToken = await _getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        yield ErrorEvent('当前登录状态已失效，请重新登录后再试');
        return;
      }
      final tokenRef = _extractProjectRefFromToken(accessToken);
      final projectRef = _projectRefFromProjectUrl();
      debugPrint('🔐 accessToken: ${_tokenSummary(accessToken)}');
      if (tokenRef != null && tokenRef != projectRef) {
        debugPrint(
            '⚠️ token project ref 不匹配: token=$tokenRef, app=$projectRef');
      }

      // 构建 HTTP 请求
      final request = http.Request('POST', url)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer $accessToken',
        })
        ..body = jsonEncode(body);

      var response = await request.send();
      debugPrint('📥 响应状态: ${response.statusCode}');

      if (response.statusCode == 401) {
        debugPrint('⚠️ 收到 401，尝试刷新会话后重试一次');
        final refreshedToken = await _getAccessToken(forceRefresh: true);
        if (refreshedToken != null && refreshedToken.isNotEmpty) {
          final retryRequest = http.Request('POST', url)
            ..headers.addAll({
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.anonKey,
              'Authorization': 'Bearer $refreshedToken',
            })
            ..body = jsonEncode(body);
          response = await retryRequest.send();
          debugPrint('🔁 重试后响应状态: ${response.statusCode}');
        }
      }

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        debugPrint('❌ Edge Function 错误: $errorBody');
        if (response.statusCode == 401) {
          final lower = errorBody.toLowerCase();
          if (lower.contains('access token is invalid') &&
              lower.contains('unauthorized')) {
            yield ErrorEvent('DIFY_AUTH_INVALID');
          } else if (lower.contains('jwt') ||
              lower.contains('invalid token') ||
              lower.contains('auth')) {
            yield ErrorEvent('AUTH_INVALID');
          } else {
            yield ErrorEvent('请求失败 (401): $errorBody');
          }
        } else {
          yield ErrorEvent('请求失败 (${response.statusCode}): $errorBody');
        }
        return;
      }

      // ✅ 处理流式响应（SSE 格式）
      // 格式说明：每行以 "data: " 开头，后跟完整的 JSON 对象
      // 例如：
      // data: {"event":"message","answer":"你好","conversation_id":"xxx","message_id":"xxx"}
      // data: {"event":"message_end","conversation_id":"xxx","id":"xxx"}

      String? finalConversationId;
      String? finalMessageId;
      String buffer = '';

      debugPrint('✅ 开始接收流式数据...\n');

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // 按行分割
        final lines = buffer.split('\n');

        // 最后一行可能不完整，保留在 buffer 中
        buffer = lines.last;

        // 处理完整的行
        for (int i = 0; i < lines.length - 1; i++) {
          var line = lines[i].trim();
          if (line.isEmpty) continue;

          try {
            // SSE 心跳/注释行，直接跳过
            if (line.startsWith('event:') || line.startsWith(':')) {
              continue;
            }

            // ✅ SSE 格式处理：移除 "data: " 前缀
            if (line.startsWith('data:')) {
              line = line.substring(5).trim();
            }

            if (line.isEmpty) continue;
            if (line == '[DONE]') continue;

            // 解析 JSON
            final json = jsonDecode(line) as Map<String, dynamic>;
            final event = json['event'] as String?;

            switch (event) {
              case 'message':
                // 流式消息事件（可能被多次调用）
                // 每次发送答案的一部分
                final answer = json['answer'] as String?;
                if (answer != null && answer.isNotEmpty) {
                  debugPrint('📨 message 事件: ${answer.length} 字符');
                  yield ContentEvent(answer);
                }

                // 保存会话相关信息
                final convId = json['conversation_id'] as String?;
                final msgId = json['message_id'] as String?;
                if (convId != null) finalConversationId = convId;
                if (msgId != null) finalMessageId = msgId;
                break;

              case 'message_end':
                // 消息完全结束事件
                final convId = json['conversation_id'] as String?;
                final msgId = json['id'] as String?;
                if (convId != null) finalConversationId = convId;
                if (msgId != null) finalMessageId = msgId;
                debugPrint('📨 message_end 事件: ✅ 消息完成');
                break;

              case 'moderation_intercept':
                final msg = json['message'] as String? ?? '该回复因内容审核未通过，已被拦截。';
                debugPrint('📨 moderation_intercept: 流式输出被服务端拦截');
                yield ModerationInterceptEvent(msg);
                break;

              case 'error':
                // 错误事件
                var message = json['message'] as String? ?? '未知错误';
                if (message.toLowerCase().contains('model is not configured')) {
                  message = 'AI 模型未配置：请在 Dify 控制台为该应用绑定模型后重试';
                }
                debugPrint('📨 error 事件: $message');
                yield ErrorEvent(message);
                return;

              case 'workflow_started':
              case 'workflow_finished':
              case 'node_started':
              case 'node_finished':
              case 'tts_message':
              case 'tts_message_end':
                // 工作流事件和其他事件（暂不处理）
                debugPrint('📨 $event 事件（跳过）');
                break;

              default:
                // 其他未知事件
                debugPrint('📨 未知事件: $event');
            }
          } catch (e) {
            debugPrint('⚠️ 解析失败: $e');
            debugPrint(
                '   行内容: ${line.substring(0, 100.clamp(0, line.length))}...');
          }
        }
      }

      // 流结束，发送 DoneEvent
      debugPrint('\n✅ 流式响应完成');
      if (finalConversationId != null) {
        debugPrint('   📎 conversation_id: $finalConversationId');
      }
      if (finalMessageId != null) {
        debugPrint('   📎 message_id: $finalMessageId');
      }

      yield DoneEvent(
        conversationId: finalConversationId,
        messageId: finalMessageId,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Edge Function 调用异常: $e');
      debugPrint('Stack trace: $stackTrace');
      yield ErrorEvent('调用失败: $e');
    }
  }

  /// 阻塞模式调用（可选）
  /// 返回完整的 Dify API 响应
  Future<Map<String, dynamic>?> callDifyChatBlocking({
    required String query,
    required String user,
    String? conversationId,
    bool doctorMode = false,
    bool agentMode = false,
    String? petContext,
    List<Map<String, String>> images = const [],
  }) async {
    try {
      final body = {
        'query': query,
        'user': user,
        'response_mode': 'blocking',
        'inputs': {}, // 必填字段
        'doctor_mode': doctorMode,
        'agent_mode': agentMode,
        if (petContext != null && petContext.trim().isNotEmpty)
          'pet_context': petContext.trim(),
        if (images.isNotEmpty) 'images': images,
        if (conversationId != null) 'conversation_id': conversationId,
      };

      debugPrint('📤 阻塞模式调用 Edge Function');
      debugPrint('📦 请求体: ${jsonEncode(body)}');

      final url = Uri.parse(SupabaseConfig.difyChatUrl);
      final accessToken = await _getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('❌ 当前登录状态已失效，无法调用 Edge Function');
        return null;
      }
      final tokenRef = _extractProjectRefFromToken(accessToken);
      final projectRef = _projectRefFromProjectUrl();
      debugPrint('🔐 accessToken: ${_tokenSummary(accessToken)}');
      if (tokenRef != null && tokenRef != projectRef) {
        debugPrint(
            '⚠️ token project ref 不匹配: token=$tokenRef, app=$projectRef');
      }
      var response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 401) {
        debugPrint('⚠️ 阻塞模式收到 401，尝试刷新会话后重试一次');
        final refreshedToken = await _getAccessToken(forceRefresh: true);
        if (refreshedToken != null && refreshedToken.isNotEmpty) {
          response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.anonKey,
              'Authorization': 'Bearer $refreshedToken',
            },
            body: jsonEncode(body),
          );
          debugPrint('🔁 阻塞模式重试后响应状态: ${response.statusCode}');
        }
      }

      debugPrint('📥 响应状态: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ 响应成功');
        final answer = data['answer']?.toString() ?? '';
        if (answer.isNotEmpty) {
          final preview =
              answer.length > 50 ? '${answer.substring(0, 50)}...' : answer;
          debugPrint('   answer: $preview');
        }
        debugPrint('   conversation_id: ${data['conversation_id']}');
        return data;
      } else {
        debugPrint('❌ 请求失败: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 异常: $e');
      return null;
    }
  }
}

// ============================================================================
// Pet Diary 事件类
// ============================================================================

/// 宠物日记流式事件基类
abstract class DiaryStreamEvent {}

/// 日记内容事件 - AI 生成的文本片段
class DiaryContentEvent implements DiaryStreamEvent {
  final String delta; // 新增的文本片段
  final String fullText; // 到目前为止的完整文本

  DiaryContentEvent({required this.delta, required this.fullText});
}

/// 日记完成事件
class DiaryDoneEvent implements DiaryStreamEvent {
  final String finalText; // 最终完整文本

  DiaryDoneEvent(this.finalText);
}

/// 日记错误事件
class DiaryErrorEvent implements DiaryStreamEvent {
  final String error;

  DiaryErrorEvent(this.error);
}

// ============================================================================
// Pet Diary Edge Function 服务
// ============================================================================

/// 宠物日记 Edge Function 服务
/// 通过 Supabase Edge Function 调用 Dify Workflow API 生成宠物日记
class PetDiaryEdgeService {
  String? _extractDiaryText(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final text = value.trim();
      return text.isEmpty ? null : value;
    }
    if (value is List) {
      final parts = value
          .map(_extractDiaryText)
          .whereType<String>()
          .where((text) => text.trim().isNotEmpty)
          .toList();
      return parts.isEmpty ? null : parts.join('\n');
    }
    if (value is Map) {
      const preferredKeys = [
        'text',
        'output',
        'answer',
        'result',
        'content',
        'diary',
        'diary_content',
      ];
      for (final key in preferredKeys) {
        if (value.containsKey(key)) {
          final text = _extractDiaryText(value[key]);
          if (text != null && text.trim().isNotEmpty) return text;
        }
      }
      for (final entry in value.entries) {
        final text = _extractDiaryText(entry.value);
        if (text != null && text.trim().isNotEmpty) return text;
      }
    }
    return null;
  }

  String _deltaFromText(String nextText, String currentText) {
    if (nextText == currentText) return '';
    if (nextText.startsWith(currentText)) {
      return nextText.substring(currentText.length);
    }
    return nextText;
  }

  /// 生成宠物日记（流式输出）
  ///
  /// 参数说明：
  /// - query: 用户输入的原始内容（必填）
  /// - style: 日记风格（必填）
  /// - nickname: 宠物主人昵称（可选）
  /// - breed: 宠物品种（可选）
  ///
  /// 返回一个流，包含 DiaryContentEvent、DiaryDoneEvent、DiaryErrorEvent
  Stream<DiaryStreamEvent> generatePetDiary({
    required String query,
    required String style,
    String? nickname,
    String? breed,
    String? petName,
    String? gender,
    String? petType,
  }) async* {
    try {
      // ✅ 获取当前用户的 Session Token
      final session = supabase.auth.currentSession;
      if (session == null) {
        yield DiaryErrorEvent('用户未登录，请先登录');
        return;
      }

      final accessToken = session.accessToken;
      final startedAt = DateTime.now().toUtc();
      var didReportSuccess = false;
      final userId = supabase.auth.currentUser?.id ?? 'anon';
      final ownerTitle =
          nickname != null && nickname.trim().isNotEmpty ? nickname.trim() : '主人';
      final species =
          petType != null && petType.trim().isNotEmpty ? petType.trim() : '宠物';

      final inputs = {
        'query': query,
        'style': style,
        'owner_title': ownerTitle,
        'species': species,
        if (nickname != null && nickname.trim().isNotEmpty)
          'nickname': nickname.trim(),
        if (breed != null && breed.trim().isNotEmpty) 'breed': breed.trim(),
        if (petName != null && petName.trim().isNotEmpty)
          'pet_name': petName.trim(),
        if (gender != null && gender.trim().isNotEmpty)
          'gender': gender.trim(),
        if (petType != null && petType.trim().isNotEmpty)
          'type': petType.trim(),
      };

      final body = {
        'inputs': inputs,
        'user': userId,
        'response_mode': 'streaming',
      };

      debugPrint('📝 调用 Diary-v4 Edge Function');
      debugPrint('📦 参数:');
      debugPrint(
        '   - inputs.query: ${query.substring(0, 30.clamp(0, query.length))}...',
      );
      debugPrint('   - inputs.style: $style');
      debugPrint('   - user: $userId');
      debugPrint('   - inputs.owner_title: $ownerTitle');
      debugPrint('   - inputs.species: $species');
      if (nickname != null) debugPrint('   - inputs.nickname: $nickname');
      if (breed != null) debugPrint('   - inputs.breed: $breed');
      if (petName != null) debugPrint('   - inputs.pet_name: $petName');
      if (gender != null) debugPrint('   - inputs.gender: $gender');
      if (petType != null) debugPrint('   - inputs.type: $petType');
      debugPrint('   - response_mode: streaming');
      AnalyticsService.track(
        'diary_generate_start',
        module: 'diary',
        properties: {
          'entry_page': 'pet_diary_edge_service',
          'style': style,
          'pet_type': petType,
        },
      );

      final url = Uri.parse(SupabaseConfig.diaryUrl);

      // ✅ 使用用户的 JWT Token 而不是 Anon Key
      final request = http.Request('POST', url)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer $accessToken',
        })
        ..body = jsonEncode(body);

      final response = await request.send();
      debugPrint('📥 Diary 响应状态: ${response.statusCode}');

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        debugPrint('❌ Diary Edge Function 错误: $errorBody');
        AnalyticsService.track(
          'diary_generate_error',
          module: 'diary',
          durationMs: DateTime.now().toUtc().difference(startedAt).inMilliseconds,
          properties: {
            'entry_page': 'pet_diary_edge_service',
            'style': style,
            'error_code': 'http_${response.statusCode}',
          },
        );
        yield DiaryErrorEvent('请求失败 (${response.statusCode}): $errorBody');
        return;
      }

      // 处理流式响应（SSE 格式）
      String buffer = '';
      String accumulatedText = ''; // 累积的完整文本

      debugPrint('✅ 开始接收 Diary 流式数据...\n');

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // 处理 SSE 消息（双换行符分隔）
        while (buffer.contains('\n\n')) {
          final messageEndIndex = buffer.indexOf('\n\n');
          final message = buffer.substring(0, messageEndIndex);
          buffer = buffer.substring(messageEndIndex + 2);

          if (message.startsWith('data:')) {
            final dataString = message.substring(5).trim();

            if (dataString.isEmpty || dataString == '[DONE]') {
              debugPrint('📨 Diary [DONE] 事件');
              if (!didReportSuccess) {
                didReportSuccess = true;
                AnalyticsService.track(
                  'diary_generate_success',
                  module: 'diary',
                  durationMs:
                      DateTime.now().toUtc().difference(startedAt).inMilliseconds,
                  properties: {
                    'entry_page': 'pet_diary_edge_service',
                    'style': style,
                  },
                );
              }
              yield DiaryDoneEvent(accumulatedText);
              continue;
            }

            try {
              final json = jsonDecode(dataString) as Map<String, dynamic>;
              final event = json['event'] as String?;

              debugPrint('📨 Diary 事件: $event');

              switch (event) {
                case 'text_chunk':
                  // Workflow API 的流式文本块事件
                  final data = json['data'] as Map<String, dynamic>?;
                  if (data != null && data.containsKey('text')) {
                    final delta = _extractDiaryText(data['text']);
                    if (delta != null && delta.isNotEmpty) {
                      accumulatedText += delta;
                      debugPrint('   ✍️ text_chunk: ${delta.length} 字符');
                      yield DiaryContentEvent(
                        delta: delta,
                        fullText: accumulatedText,
                      );
                    }
                  }
                  break;

                case 'workflow_finished':
                  // 工作流完成，获取最终文本
                  final data = json['data'] as Map<String, dynamic>?;
                  if (data != null && data.containsKey('outputs')) {
                    final text = _extractDiaryText(data['outputs']);

                    if (text != null && text != accumulatedText) {
                      final delta = _deltaFromText(text, accumulatedText);
                      if (delta.isNotEmpty) {
                        accumulatedText = text;
                        debugPrint('   ✍️ 完整文本: ${text.length} 字符');
                        yield DiaryContentEvent(
                          delta: delta,
                          fullText: accumulatedText,
                        );
                      }
                    }
                  }
                  if (!didReportSuccess) {
                    didReportSuccess = true;
                    AnalyticsService.track(
                      'diary_generate_success',
                      module: 'diary',
                      durationMs: DateTime.now()
                          .toUtc()
                          .difference(startedAt)
                          .inMilliseconds,
                      properties: {
                        'entry_page': 'pet_diary_edge_service',
                        'style': style,
                      },
                    );
                  }
                  yield DiaryDoneEvent(accumulatedText);
                  break;

                case 'node_finished':
                  // 节点完成，可能包含部分输出
                  // 如果已经通过 text_chunk 接收了内容，则跳过（避免重复）
                  final data = json['data'] as Map<String, dynamic>?;
                  if (data != null && data.containsKey('outputs')) {
                    final text = _extractDiaryText(data['outputs']);

                      // 只有当 node_finished 的文本比已累积的文本更长时才处理
                      // 这样可以避免与 text_chunk 重复
                    if (text != null && text.length > accumulatedText.length) {
                      final delta = _deltaFromText(text, accumulatedText);
                      if (delta.isNotEmpty) {
                        accumulatedText = text;
                        debugPrint('   ✍️ 增量文本: ${delta.length} 字符');
                        yield DiaryContentEvent(
                          delta: delta,
                          fullText: accumulatedText,
                        );
                      }
                    }
                  }
                  break;

                case 'error':
                  final message = json['message'] as String? ?? '未知错误';
                  debugPrint('   ❌ Dify 错误: $message');
                  AnalyticsService.track(
                    'diary_generate_error',
                    module: 'diary',
                    durationMs:
                        DateTime.now().toUtc().difference(startedAt).inMilliseconds,
                    properties: {
                      'entry_page': 'pet_diary_edge_service',
                      'style': style,
                      'error_code': 'dify_error',
                    },
                  );
                  yield DiaryErrorEvent(message);
                  return;

                case 'workflow_started':
                case 'node_started':
                  // 工作流/节点启动事件（跳过）
                  debugPrint('   ℹ️ $event（跳过）');
                  break;

                default:
                  debugPrint('   ℹ️ 未知事件: $event');
              }
            } catch (e) {
              debugPrint('⚠️ 解析 Diary JSON 失败: $e');
              debugPrint(
                '   原始内容: ${dataString.substring(0, 100.clamp(0, dataString.length))}...',
              );
            }
          }
        }
      }

      // 流结束
      debugPrint('\n✅ Diary 流式响应完成');
      debugPrint('   最终文本长度: ${accumulatedText.length} 字符');

      if (accumulatedText.isNotEmpty) {
        if (!didReportSuccess) {
          AnalyticsService.track(
            'diary_generate_success',
            module: 'diary',
            durationMs:
                DateTime.now().toUtc().difference(startedAt).inMilliseconds,
            properties: {
              'entry_page': 'pet_diary_edge_service',
              'style': style,
            },
          );
        }
        yield DiaryDoneEvent(accumulatedText);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Diary Edge Function 调用异常: $e');
      debugPrint('Stack trace: $stackTrace');
      AnalyticsService.track(
        'diary_generate_error',
        module: 'diary',
        properties: {
          'entry_page': 'pet_diary_edge_service',
          'style': style,
          'error_code': e.runtimeType.toString(),
        },
      );
      yield DiaryErrorEvent('生成日记失败: $e');
    }
  }

  /// 阻塞模式生成宠物日记（可选）
  /// 返回完整的生成结果
  Future<String?> generatePetDiaryBlocking({
    required String query,
    required String style,
    String? nickname,
    String? breed,
    String? petName,
    String? gender,
    String? petType,
  }) async {
    try {
      // ✅ 获取当前用户的 Session Token
      final session = supabase.auth.currentSession;
      if (session == null) {
        debugPrint('❌ 用户未登录');
        return null;
      }

      final accessToken = session.accessToken;
      final userId = supabase.auth.currentUser?.id ?? 'anon';
      final ownerTitle =
          nickname != null && nickname.trim().isNotEmpty ? nickname.trim() : '主人';
      final species =
          petType != null && petType.trim().isNotEmpty ? petType.trim() : '宠物';

      final inputs = {
        'query': query,
        'style': style,
        'owner_title': ownerTitle,
        'species': species,
        if (nickname != null && nickname.trim().isNotEmpty)
          'nickname': nickname.trim(),
        if (breed != null && breed.trim().isNotEmpty) 'breed': breed.trim(),
        if (petName != null && petName.trim().isNotEmpty)
          'pet_name': petName.trim(),
        if (gender != null && gender.trim().isNotEmpty)
          'gender': gender.trim(),
        if (petType != null && petType.trim().isNotEmpty)
          'type': petType.trim(),
      };

      final body = {
        'inputs': inputs,
        'user': userId,
        'response_mode': 'blocking',
      };

      debugPrint('📝 阻塞模式调用 Diary-v4 Edge Function');
      debugPrint('📦 请求体: ${jsonEncode(body)}');

      final url = Uri.parse(SupabaseConfig.diaryUrl);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConfig.anonKey,
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );

      debugPrint('📥 响应状态: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Diary 响应成功');

        // Extract diary text from v4 outputs without assuming a fixed key.
        final responseData = data['data'];
        final outputs = responseData is Map ? responseData['outputs'] : null;
        final text = _extractDiaryText(outputs);

        if (text != null && text.isNotEmpty) {
          final preview =
              text.length > 50 ? '${text.substring(0, 50)}...' : text;
          debugPrint('   生成文本: $preview');
          return text;
        } else {
          debugPrint('   ⚠️ 响应中未找到文本内容');
          return null;
        }
      } else {
        debugPrint('❌ 请求失败: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 异常: $e');
      return null;
    }
  }
}
