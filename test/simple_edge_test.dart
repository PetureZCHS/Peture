// test/simple_edge_test.dart
// 命令行测试脚本 - 最简单的测试方式
//
// 使用方法:
// 1. 替换下面的 YOUR_ANON_KEY
// 2. 运行: dart test/simple_edge_test.dart

import 'dart:io';
import 'dart:convert';

// ⚠️ 替换为您的实际 anon key
const String ANON_KEY =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjZnRwY3ZjbGRmdWR6eGdlbWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2NjMzMTQsImV4cCI6MjA3NjIzOTMxNH0.uiusEWfuAw37fL6neZfK3q9NV4HZF7k-kX6hFIJQ83s';
const String FUNCTION_URL =
    'https://tcftpcvcldfudzxgemdh.supabase.co/functions/v1/chat';

void main() async {
  print('🚀 开始测试 Supabase Edge Function...\n');

  // 检查是否配置了 key
  if (ANON_KEY == 'YOUR_ANON_KEY_HERE') {
    print('❌ 错误: 请先配置 ANON_KEY!');
    print('   打开 test/simple_edge_test.dart 并替换 ANON_KEY 的值');
    exit(1);
  }

  await testBlocking();
  print('\n' + '=' * 60 + '\n');
  await testStreaming();
}

/// 测试阻塞模式
Future<void> testBlocking() async {
  print('📦 测试 1: 阻塞模式 (Blocking)');
  print('-' * 60);

  try {
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse(FUNCTION_URL));

    // 设置请求头
    request.headers.set('Authorization', 'Bearer $ANON_KEY');
    request.headers.set('apikey', ANON_KEY);
    request.headers.set('Content-Type', 'application/json');

    // 设置请求体
    final body = jsonEncode({
      'query': 'Hello, please introduce yourself briefly',
      'user': 'test-user-${DateTime.now().millisecondsSinceEpoch}',
      'response_mode': 'blocking',
    });
    request.write(body);

    print('📤 发送请求...');
    print('   URL: $FUNCTION_URL');
    print('   Body: $body');

    // 发送请求
    final response = await request.close();
    print('📥 收到响应: HTTP ${response.statusCode}');

    // 读取响应体
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {
      print('✅ 成功!');
      print('\n响应内容:');
      print('-' * 60);

      try {
        final data = jsonDecode(responseBody);
        final prettyJson = JsonEncoder.withIndent('  ').convert(data);
        print(prettyJson);

        print('\n📝 解析结果:');
        print('   Answer: ${data['answer']?.substring(0, 100) ?? 'N/A'}...');
        print('   Conversation ID: ${data['conversation_id'] ?? 'N/A'}');
        print('   Message ID: ${data['message_id'] ?? 'N/A'}');
      } catch (e) {
        print('⚠️ 无法解析 JSON: $e');
        print('原始响应: $responseBody');
      }
    } else {
      print('❌ 失败: HTTP ${response.statusCode}');
      print('错误信息: $responseBody');
    }

    client.close();
  } catch (e) {
    print('❌ 错误: $e');
  }
}

/// 测试流式模式
Future<void> testStreaming() async {
  print('📡 测试 2: 流式模式 (Streaming)');
  print('-' * 60);

  try {
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse(FUNCTION_URL));

    // 设置请求头
    request.headers.set('Authorization', 'Bearer $ANON_KEY');
    request.headers.set('apikey', ANON_KEY);
    request.headers.set('Content-Type', 'application/json');

    // 设置请求体
    final body = jsonEncode({
      'query': 'Hello, introduce yourself in one sentence',
      'user': 'test-user-${DateTime.now().millisecondsSinceEpoch}',
      'response_mode': 'streaming',
    });
    request.write(body);

    print('📤 发送请求...');

    // 发送请求
    final response = await request.close();
    print('📥 收到响应: HTTP ${response.statusCode}');

    if (response.statusCode == 200) {
      print('✅ 开始接收流式数据...\n');

      int chunkCount = 0;
      String fullAnswer = '';

      await for (final chunk
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          final data = chunk.substring(6).trim();

          if (data.isEmpty || data == '[DONE]') {
            continue;
          }

          chunkCount++;

          try {
            final jsonData = jsonDecode(data);
            final event = jsonData['event'];
            final answer = jsonData['answer'] ?? '';

            if (answer.isNotEmpty) {
              fullAnswer += answer;
              stdout.write(answer); // 实时输出
            }

            if (event == 'message_end') {
              print('\n\n✅ 流式响应完成!');
              print('   总共收到 $chunkCount 个数据块');
              print('   完整答案长度: ${fullAnswer.length} 字符');
            }
          } catch (e) {
            print('\n⚠️ 解析数据块出错: $e');
          }
        }
      }
    } else {
      final errorBody = await response.transform(utf8.decoder).join();
      print('❌ 失败: HTTP ${response.statusCode}');
      print('错误信息: $errorBody');
    }

    client.close();
  } catch (e) {
    print('❌ 错误: $e');
  }
}
