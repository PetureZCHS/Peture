import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client - 全局单例
/// 参考 flutter-chat-main demo 的最佳实践
final supabase = Supabase.instance.client;

/// Supabase Edge Function 配置
class SupabaseConstants {
  // Supabase 项目配置
  static const String projectUrl = 'https://tcftpcvcldfudzxgemdh.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjZnRwY3ZjbGRmdWR6eGdlbWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2NjMzMTQsImV4cCI6MjA3NjIzOTMxNH0.uiusEWfuAw37fL6neZfK3q9NV4HZF7k-kX6hFIJQ83s';

  // Edge Function 名称
  static const String difyChatFunction = 'chat';
  static const String diaryFunction = 'diary-v2';

  // 完整的 Edge Function URL
  static String get difyChatUrl => '$projectUrl/functions/v1/$difyChatFunction';
  static String get diaryUrl => '$projectUrl/functions/v1/$diaryFunction';
}

/// 简单的加载指示器
const preloader = Center(child: CircularProgressIndicator(color: Colors.blue));

/// 表单间距
const formSpacer = SizedBox(width: 16, height: 16);

/// 表单内边距
const formPadding = EdgeInsets.symmetric(vertical: 20, horizontal: 16);

/// 通用错误消息
const unexpectedErrorMessage = '发生了意外错误';

/// 显示错误提示的扩展方法
extension ShowSnackBar on BuildContext {
  void showSnackBar({
    required String message,
    Color backgroundColor = Colors.red,
  }) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  void showErrorSnackBar({required String message}) {
    showSnackBar(message: message, backgroundColor: Colors.red);
  }

  void showSuccessSnackBar({required String message}) {
    showSnackBar(message: message, backgroundColor: Colors.green);
  }
}
