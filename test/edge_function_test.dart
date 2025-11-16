// test/edge_function_test.dart
// 最小测试代码 - 测试 Supabase Edge Function 是否正常工作

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 简单的测试页面
/// 
/// 使用方法：
/// 1. 替换下面的 YOUR_ANON_KEY
/// 2. 运行这个页面
/// 3. 点击"测试阻塞模式"或"测试流式模式"按钮
class EdgeFunctionTestPage extends StatefulWidget {
  const EdgeFunctionTestPage({super.key});

  @override
  State<EdgeFunctionTestPage> createState() => _EdgeFunctionTestPageState();
}

class _EdgeFunctionTestPageState extends State<EdgeFunctionTestPage> {
  String _result = '准备测试...';
  bool _isLoading = false;

  // ⚠️ 替换为您的实际 anon key
  static const String _anonKey = 'YOUR_ANON_KEY_HERE';
  static const String _functionUrl =
      'https://tcftpcvcldfudzxgemdh.supabase.co/functions/v1/chat';

  /// 测试阻塞模式（blocking）
  Future<void> _testBlocking() async {
    setState(() {
      _isLoading = true;
      _result = '正在测试阻塞模式...\n';
    });

    try {
      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {
          'Authorization': 'Bearer $_anonKey',
          'apikey': _anonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'query': '你好',
          'user': 'test-user-${DateTime.now().millisecondsSinceEpoch}',
          'response_mode': 'blocking',
        }),
      );

      setState(() {
        _result = '阻塞模式测试结果:\n\n'
            '状态码: ${response.statusCode}\n'
            '响应头: ${response.headers}\n\n'
            '响应体:\n${response.body}\n\n';

        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body);
            _result += '✅ 成功!\n';
            _result += 'Answer: ${data['answer']}\n';
            _result += 'Conversation ID: ${data['conversation_id']}\n';
          } catch (e) {
            _result += '⚠️ 响应不是有效的 JSON: $e\n';
          }
        } else {
          _result += '❌ 失败: HTTP ${response.statusCode}\n';
        }
      });
    } catch (e) {
      setState(() {
        _result = '❌ 错误: $e\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 测试流式模式（streaming）
  Future<void> _testStreaming() async {
    setState(() {
      _isLoading = true;
      _result = '正在测试流式模式...\n\n';
    });

    try {
      final request = http.Request('POST', Uri.parse(_functionUrl));
      request.headers.addAll({
        'Authorization': 'Bearer $_anonKey',
        'apikey': _anonKey,
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode({
        'query': '你好',
        'user': 'test-user-${DateTime.now().millisecondsSinceEpoch}',
        'response_mode': 'streaming',
      });

      final streamedResponse = await request.send();

      setState(() {
        _result += '状态码: ${streamedResponse.statusCode}\n';
        _result += '响应头: ${streamedResponse.headers}\n\n';
      });

      if (streamedResponse.statusCode == 200) {
        int chunkCount = 0;
        String fullAnswer = '';

        await for (final chunk in streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          if (chunk.startsWith('data: ')) {
            final data = chunk.substring(6).trim();
            if (data.isNotEmpty && data != '[DONE]') {
              chunkCount++;
              setState(() {
                _result += '收到数据块 $chunkCount:\n$data\n\n';
              });

              try {
                final jsonData = jsonDecode(data);
                if (jsonData['answer'] != null) {
                  fullAnswer += jsonData['answer'];
                }
              } catch (e) {
                // 忽略解析错误
              }
            }
          }
        }

        setState(() {
          _result += '\n✅ 流式响应完成!\n';
          _result += '总共收到 $chunkCount 个数据块\n';
          _result += '完整答案: $fullAnswer\n';
        });
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        setState(() {
          _result += '❌ 失败: HTTP ${streamedResponse.statusCode}\n';
          _result += '错误信息: $errorBody\n';
        });
      }
    } catch (e) {
      setState(() {
        _result += '❌ 错误: $e\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edge Function 测试'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 说明文字
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          '使用前请先配置',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. 打开 test/edge_function_test.dart\n'
                      '2. 将 _anonKey 替换为您的 Supabase anon key\n'
                      '3. 确保 Edge Function 已部署到 Supabase',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 测试按钮
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testBlocking,
              icon: const Icon(Icons.play_arrow),
              label: const Text('测试阻塞模式 (Blocking)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testStreaming,
              icon: const Icon(Icons.stream),
              label: const Text('测试流式模式 (Streaming)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // 加载指示器
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),

            // 结果显示
            Expanded(
              child: Card(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _result,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 如果想单独运行这个测试页面，取消下面的注释
/*
void main() {
  runApp(const MaterialApp(
    home: EdgeFunctionTestPage(),
    debugShowCheckedModeBanner: false,
  ));
}
*/
