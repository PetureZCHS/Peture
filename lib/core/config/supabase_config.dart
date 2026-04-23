// Supabase 配置文件
//
// 使用说明:
// 1. 从 Supabase Dashboard 获取您的项目配置
// 2. 将下面的值替换为您的实际配置
// 3. 不要将此文件提交到公开的 Git 仓库（如果包含敏感信息）

class SupabaseConfig {
  // Supabase 项目 URL
  // 从 Dashboard → Settings → API → Project URL 获取
  static const String projectUrl = 'https://dyxbvsnnrzvozcokhlfw.supabase.co';

  // Supabase Anon (Public) Key
  // 从 Dashboard → Settings → API → anon public 获取
  // 注意：这是 anon key，可以安全地用在客户端
  // 已更新为正确的 JWT 格式密钥（2025-11-16）
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjZnRwY3ZjbGRmdWR6eGdlbWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2NjMzMTQsImV4cCI6MjA3NjIzOTMxNH0.uiusEWfuAw37fL6neZfK3q9NV4HZF7k-kX6hFIJQ83s';

  // Edge Function 名称
  // 这是您在 Supabase 中创建的 Edge Function 的名称
  static const String difyChatFunctionName = 'chat';
  static const String diaryFunctionName = 'diary';

  // Edge Function 完整 URL
  static String get difyChatUrl =>
      '$projectUrl/functions/v1/$difyChatFunctionName';

  static String get diaryUrl => '$projectUrl/functions/v1/$diaryFunctionName';
}

// 使用示例：
//
// import 'config/supabase_config.dart';
//
// await Supabase.initialize(
//   url: SupabaseConfig.projectUrl,
//   anonKey: SupabaseConfig.anonKey,
// );
