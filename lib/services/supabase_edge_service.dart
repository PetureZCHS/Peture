import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../shared/utils/supabase_constants.dart';

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

/// Supabase Edge Function 服务
/// 通过 Supabase Edge Function 调用 chat API
class SupabaseEdgeFunctionService {
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
  }) async* {
    try {
      // ✅ 根据 Dify API 文档构建请求体
      // 必填字段：query, inputs, response_mode, user
      final body = {
        'query': query, // 用户输入
        'user': user, // 用户标识
        'response_mode': 'streaming', // 流式模式
        'inputs': {}, // 必填字段（可以是空对象）
        // 可选字段
        if (conversationId != null) 'conversation_id': conversationId,
      };

      debugPrint('📤 调用 Edge Function: ${SupabaseConstants.difyChatFunction}');
      debugPrint('📦 必填参数:');
      debugPrint('   - query: ${query.substring(0, 50.clamp(0, query.length))}...');
      debugPrint('   - user: $user');
      debugPrint('   - response_mode: streaming');
      debugPrint('   - inputs: {}');
      if (conversationId != null) {
        debugPrint('📎 可选参数: conversation_id=$conversationId');
      }

      final url = Uri.parse(SupabaseConstants.difyChatUrl);

      // 构建 HTTP 请求
      final request = http.Request('POST', url)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'apikey': SupabaseConstants.anonKey,
          'Authorization': 'Bearer ${SupabaseConstants.anonKey}',
        })
        ..body = jsonEncode(body);

      final response = await request.send();
      debugPrint('📥 响应状态: ${response.statusCode}');

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        debugPrint('❌ Edge Function 错误: $errorBody');
        yield ErrorEvent('请求失败 (${response.statusCode}): $errorBody');
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
            // ✅ SSE 格式处理：移除 "data: " 前缀
            if (line.startsWith('data:')) {
              line = line.substring(5).trim();
            }

            if (line.isEmpty) continue;

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

              case 'error':
                // 错误事件
                final message = json['message'] as String? ?? '未知错误';
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
            debugPrint('   行内容: ${line.substring(0, 100.clamp(0, line.length))}...');
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
  }) async {
    try {
      final body = {
        'query': query,
        'user': user,
        'response_mode': 'blocking',
        'inputs': {}, // 必填字段
        if (conversationId != null) 'conversation_id': conversationId,
      };

      debugPrint('📤 阻塞模式调用 Edge Function');
      debugPrint('📦 请求体: ${jsonEncode(body)}');

      final url = Uri.parse(SupabaseConstants.difyChatUrl);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': SupabaseConstants.anonKey,
          'Authorization': 'Bearer ${SupabaseConstants.anonKey}',
        },
        body: jsonEncode(body),
      );

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

      // ✅ 根据 diary-v4 Edge Function 要求构建请求体
      final inputs = {
        'query': query,
        'style': style,
        // v4 参数映射: 
        if (nickname != null) 'owner_title': nickname, // 主人称呼 (API参数名: owner_title)
        if (petName != null) 'nickname': petName,      // 宠物名字 (API参数名: nickname)
        if (petType != null) 'species': petType,       // 宠物物种 (API参数名: species)
        if (breed != null) 'breed': breed,             // 宠物品种
        // 保留其他可能用到的字段
        if (gender != null) 'gender': gender,
      };

      final body = {
        'inputs': inputs,
        'response_mode': 'streaming',
        'user': session.user.id, // 添加 user 字段，确保与 Dify 一致
      };

      debugPrint('📝 调用 Diary-v4 Edge Function');
      debugPrint('📦 参数:');
      debugPrint(
        '   - inputs.query: ${query.substring(0, 30.clamp(0, query.length))}...',
      );
      debugPrint('   - inputs.style: $style');
      if (nickname != null) debugPrint('   - inputs.owner_title: $nickname');
      if (petName != null) debugPrint('   - inputs.nickname: $petName');
      if (petType != null) debugPrint('   - inputs.species: $petType');
      if (breed != null) debugPrint('   - inputs.breed: $breed');
      debugPrint('   - response_mode: streaming');

      final url = Uri.parse(SupabaseConstants.diaryUrl);

      // ✅ 使用用户的 JWT Token 而不是 Anon Key
      final request = http.Request('POST', url)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'apikey': SupabaseConstants.anonKey, // 必须携带 Anon Key
          'Authorization': 'Bearer $accessToken', // ✅ 使用用户 Token
        })
        ..body = jsonEncode(body);

      final response = await request.send();
      debugPrint('📥 Diary 响应状态: ${response.statusCode}');

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        debugPrint('❌ Diary Edge Function 错误: $errorBody');
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
                    final delta = data['text'] as String;
                    if (delta.isNotEmpty) {
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
                    final outputs = data['outputs'] as Map<String, dynamic>?;
                    if (outputs != null && outputs.containsKey('text')) {
                      final text = outputs['text'] as String;

                      if (text != accumulatedText) {
                        final delta = text.substring(accumulatedText.length);
                        accumulatedText = text;
                        debugPrint('   ✍️ 完整文本: ${text.length} 字符');
                        yield DiaryContentEvent(
                          delta: delta,
                          fullText: accumulatedText,
                        );
                      }
                    }
                  }
                  yield DiaryDoneEvent(accumulatedText);
                  break;

                case 'node_finished':
                  // 节点完成，可能包含部分输出
                  // 如果已经通过 text_chunk 接收了内容，则跳过（避免重复）
                  final data = json['data'] as Map<String, dynamic>?;
                  if (data != null && data.containsKey('outputs')) {
                    final outputs = data['outputs'] as Map<String, dynamic>?;
                    if (outputs != null && outputs.containsKey('text')) {
                      final text = outputs['text'] as String;

                      // 只有当 node_finished 的文本比已累积的文本更长时才处理
                      // 这样可以避免与 text_chunk 重复
                      if (text.length > accumulatedText.length) {
                        final delta = text.substring(accumulatedText.length);
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

      // 无论如何，在流结束时都发送一个 DoneEvent，确保 UI 状态能够终止
      // 即使之前已经发过 DoneEvent，多发一次也无害（UI层应该处理幂等性）
      yield DiaryDoneEvent(accumulatedText);
    } catch (e, stackTrace) {
      debugPrint('❌ Diary Edge Function 调用异常: $e');
      debugPrint('Stack trace: $stackTrace');
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
  }) async {
    try {
      // ✅ 获取当前用户的 Session Token
      final session = supabase.auth.currentSession;
      if (session == null) {
        debugPrint('❌ 用户未登录');
        return null;
      }

      final accessToken = session.accessToken;

      // ✅ 根据 diary-v3 Edge Function 要求构建请求体
      final inputs = {
        'query': query,
        'style': style,
        if (nickname != null) 'nickname': nickname,
        if (breed != null) 'breed': breed,
      };

      final body = {
        'inputs': inputs,
        'response_mode': 'blocking',
      };

      debugPrint('📝 阻塞模式调用 Diary-v3 Edge Function');
      debugPrint('📦 请求体: ${jsonEncode(body)}');

      final url = Uri.parse(SupabaseConstants.diaryUrl);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken', // ✅ 使用用户 Token
        },
        body: jsonEncode(body),
      );

      debugPrint('📥 响应状态: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Diary 响应成功');

        // 从 Dify Workflow 响应中提取文本
        String? text;
        if (data['data'] != null && data['data']['outputs'] != null) {
          text = data['data']['outputs']['text'] as String?;
        }

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
