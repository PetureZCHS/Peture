import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// 流式响应事件
sealed class DifyStreamEvent {}

/// 增量内容事件（逐字符追加）
class DifyContentEvent extends DifyStreamEvent {
  final String delta; // 新增的文本片段
  final String fullText; // 到目前为止的完整文本
  DifyContentEvent({required this.delta, required this.fullText});
}

/// 完成事件
class DifyDoneEvent extends DifyStreamEvent {
  final String finalText; // 最终完整文本
  DifyDoneEvent(this.finalText);
}

/// 错误事件
class DifyErrorEvent extends DifyStreamEvent {
  final String error;
  DifyErrorEvent(this.error);
}

/// Dify API 服务
/// 用于调用 Dify 的 workflow API 来生成宠物日记
class DifyService {
  static const String _baseUrl = 'https://api.dify.ai/v1/workflows/run';
  static const String _apiKey = 'app-DUjrpJvfQBxY4gpkq6dMoCST';

  final http.Client _client;

  DifyService({http.Client? client}) : _client = client ?? http.Client();

  /// 生成宠物日记（流式输出）
  ///
  /// [query] 用户输入的原始内容
  /// [style] 日记风格
  /// [userId] 用户标识
  ///
  /// 返回流式事件流
  Stream<DifyStreamEvent> generatePetDiaryStream({
    required String query,
    required String style,
    String userId = 'zhu-test',
  }) async* {
    try {
      final headers = {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      };

      final body = jsonEncode({
        'inputs': {'query': query, 'style': style},
        'response_mode': 'streaming',
        'user': userId,
      });

      final request = http.Request('POST', Uri.parse(_baseUrl));
      request.headers.addAll(headers);
      request.body = body;

      final response = await _client.send(request);

      if (response.statusCode == 200) {
        String buffer = '';
        String accumulatedText = ''; // 累积的完整文本
        String lastText = ''; // 上一次的文本，用于计算增量

        await for (final chunk in response.stream.transform(utf8.decoder)) {
          buffer += chunk;

          // 处理 SSE 消息
          while (buffer.contains('\n\n')) {
            final messageEndIndex = buffer.indexOf('\n\n');
            final message = buffer.substring(0, messageEndIndex);
            buffer = buffer.substring(messageEndIndex + 2);

            if (message.startsWith('data:')) {
              final dataString = message.substring(5).trim();

              if (dataString.isEmpty || dataString == '[DONE]') {
                yield DifyDoneEvent(accumulatedText);
                continue;
              }

              try {
                final jsonData = jsonDecode(dataString) as Map<String, dynamic>;
                final event = jsonData['event'] as String?;

                if (event == 'workflow_finished') {
                  // 工作流完成，获取最终文本
                  final data = jsonData['data'] as Map<String, dynamic>?;
                  if (data != null && data.containsKey('outputs')) {
                    final outputs = data['outputs'] as Map<String, dynamic>?;
                    if (outputs != null && outputs.containsKey('text')) {
                      final text = outputs['text'] as String;

                      // 直接发送完整文本，让前端控制打字效果
                      if (text != accumulatedText) {
                        final delta = text.substring(accumulatedText.length);
                        accumulatedText = text;
                        yield DifyContentEvent(
                          delta: delta,
                          fullText: accumulatedText,
                        );
                      }
                    }
                  }
                  yield DifyDoneEvent(accumulatedText);
                } else if (event == 'node_finished') {
                  // 节点完成，可能包含部分输出
                  final data = jsonData['data'] as Map<String, dynamic>?;
                  if (data != null && data.containsKey('outputs')) {
                    final outputs = data['outputs'] as Map<String, dynamic>?;
                    if (outputs != null && outputs.containsKey('text')) {
                      final text = outputs['text'] as String;

                      // 直接发送增量文本，让前端控制打字效果
                      if (text.length > lastText.length) {
                        final delta = text.substring(lastText.length);
                        accumulatedText += delta;
                        yield DifyContentEvent(
                          delta: delta,
                          fullText: accumulatedText,
                        );
                        lastText = text;
                      }
                    }
                  }
                } else if (event == 'error') {
                  final message = jsonData['message'] as String? ?? '未知错误';
                  yield DifyErrorEvent(message);
                }
              } catch (e) {
                // JSON 解析失败，忽略该消息
                continue;
              }
            }
          }
        }
      } else {
        final errorBody = await response.stream.bytesToString();
        yield DifyErrorEvent('API 请求失败: ${response.statusCode}, $errorBody');
      }
    } catch (e) {
      yield DifyErrorEvent('生成宠物日记失败: $e');
    }
  }

  /// 生成宠物日记（阻塞模式，用于兼容）
  ///
  /// [query] 用户输入的原始内容
  /// [style] 日记风格
  /// [userId] 用户标识
  ///
  /// 返回生成的日记内容
  Future<String> generatePetDiary({
    required String query,
    required String style,
    String userId = 'zhu-test',
  }) async {
    try {
      final headers = {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'inputs': {'query': query, 'style': style},
        'response_mode': 'blocking',
        'user': userId,
      });

      final response = await _client.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        // Dify API 的响应格式: {data: {outputs: {text: "生成的内容"}}}
        if (data.containsKey('data')) {
          final dataMap = data['data'] as Map<String, dynamic>?;
          if (dataMap != null && dataMap.containsKey('outputs')) {
            final outputs = dataMap['outputs'] as Map<String, dynamic>?;
            if (outputs != null && outputs.containsKey('text')) {
              return outputs['text'] as String;
            }
          }
        }

        throw Exception('响应格式不符合预期，无法找到 text 字段');
      } else {
        throw Exception('API 请求失败: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      throw Exception('生成宠物日记失败: $e');
    }
  }

  /// 释放资源
  void dispose() {
    _client.close();
  }
}
