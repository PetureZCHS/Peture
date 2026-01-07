import 'package:flutter/material.dart';
import 'community_screen.dart'; // 导入 Post 数据模型

class PostDetailPage extends StatefulWidget {
  final Post post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  bool _isLiked = false;
  bool _isFavorited = false;
  int _currentLikeCount = 0;

  @override
  void initState() {
    super.initState();
    _currentLikeCount = widget.post.likeCount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // 顶部 AppBar（带返回按钮、头像、用户名）
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1E1E)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                // 用户头像
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFF5F7FA),
                  child: Text(
                    widget.post.username[0],
                    style: const TextStyle(
                      color: Color(0xFF5A8EFA),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 用户名
                Expanded(
                  child: Text(
                    widget.post.username,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                ),
                // 关注按钮
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已关注 ${widget.post.username}'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    backgroundColor: const Color(0xFF5A8EFA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    '关注',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 内容区域
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 主要图片（可点击放大）
                GestureDetector(
                  onTap: () {
                    _showImageViewer(context);
                  },
                  child: Hero(
                    tag: 'post-image-${widget.post.id}',
                    child: Image.network(
                      widget.post.imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 300,
                          color: const Color(0xFFF8F9FB),
                          child: const Icon(
                            Icons.image_outlined,
                            color: Color(0xFFCCCCCC),
                            size: 60,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 300,
                          color: const Color(0xFFF8F9FB),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: const Color(0xFF5A8EFA),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 帖子的完整文字内容
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    widget.post.content,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1E1E1E),
                      height: 1.6,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 发布时间
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _getPublishTime(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFAAAAAA),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 分割线
                const Divider(height: 1, color: Color(0xFFF0F0F0)),

                const SizedBox(height: 20),

                // 点赞数和收藏数统计
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.favorite, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        '$_currentLikeCount 人觉得很赞',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 评论区占位
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '评论',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 60,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '还没有评论，快来抢沙发吧~',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 100), // 底部留白，避免被底栏遮挡
              ],
            ),
          ),
        ],
      ),

      // 底部操作栏
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // 评论输入框占位
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _showCommentInput(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '说点什么...',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // 点赞按钮
              _buildActionButton(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked ? Colors.red : Colors.grey[700]!,
                onTap: () {
                  setState(() {
                    _isLiked = !_isLiked;
                    _currentLikeCount += _isLiked ? 1 : -1;
                  });
                },
              ),

              const SizedBox(width: 16),

              // 收藏按钮
              _buildActionButton(
                icon: _isFavorited ? Icons.star : Icons.star_border,
                color: _isFavorited ? Colors.amber : Colors.grey[700]!,
                onTap: () {
                  setState(() {
                    _isFavorited = !_isFavorited;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isFavorited ? '已收藏' : '已取消收藏'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),

              const SizedBox(width: 16),

              // 分享按钮
              _buildActionButton(
                icon: Icons.share_outlined,
                color: Colors.grey[700]!,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('分享功能开发中...'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 26, color: color),
      ),
    );
  }

  // 获取发布时间（模拟）
  String _getPublishTime() {
    final now = DateTime.now();
    final postTime = now.subtract(Duration(hours: int.parse(widget.post.id)));
    final difference = now.difference(postTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  // 显示图片查看器（全屏查看）
  void _showImageViewer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: Hero(
                  tag: 'post-image-${widget.post.id}',
                  child: InteractiveViewer(
                    child: Image.network(
                      widget.post.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 显示评论输入框
  void _showCommentInput(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '写下你的评论...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF5A8EFA)),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('评论功能开发中...'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A8EFA),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '发布',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
