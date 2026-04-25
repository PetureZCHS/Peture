import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // 初始化 Supabase
  await Supabase.initialize(
    url: 'https://dyxbvsnnrzvozcokhlfw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR5eGJ2c25ucnp2b3pjb2tobGZ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3NTQ2MjIsImV4cCI6MjA5MjMzMDYyMn0.8wLiYTHvqlTnlIib4Qckkb2x2OHBX8A6lTcBrtFURM4',
  );

  final supabase = Supabase.instance.client;

  debugPrint('🔍 检查社区帖子评论数据...');

  try {
    // 获取所有帖子
    final posts = await supabase
        .from('community_posts')
        .select('id, content, comment_count')
        .limit(10);

    debugPrint('📋 找到 ${posts.length} 个帖子:');
    for (final post in posts) {
      final postId = post['id'];
      final content = post['content'];
      final commentCount = post['comment_count'] ?? 0;

      debugPrint('\n📝 帖子 ID: $postId');
      debugPrint('   内容: ${content.substring(0, min(50, content.length))}...');
      debugPrint('   评论数: $commentCount');

      // 获取该帖子的评论
      final comments = await supabase
          .from('community_post_comments')
          .select('id, content, user_id, created_at')
          .eq('post_id', postId)
          .order('created_at', ascending: false)
          .limit(5);

      debugPrint('   实际评论: ${comments.length} 条');
      if (comments.isNotEmpty) {
        for (final comment in comments) {
          debugPrint('     - ${comment['content']} (用户: ${comment['user_id']})');
        }
      }
    }

    // 检查评论表结构
    debugPrint('\n🔧 检查评论表结构...');
    final commentColumns =
        await supabase.from('community_post_comments').select('*').limit(1);

    if (commentColumns.isNotEmpty) {
      debugPrint('评论表列: ${commentColumns.first.keys.join(', ')}');
    } else {
      debugPrint('评论表为空或无权限访问');
    }
  } catch (e) {
    debugPrint('❌ 错误: $e');
  }
}

int min(int a, int b) => a < b ? a : b;
