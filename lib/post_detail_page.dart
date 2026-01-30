import 'package:flutter/material.dart';
import 'community_screen.dart';
import 'services/supabase_service.dart';

class PostDetailPage extends StatefulWidget {
  final Post post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final SupabaseService _supabase = SupabaseService();
  final TextEditingController _commentController = TextEditingController();
  
  bool _isLiked = false;
  bool _isFavorited = false;
  bool _isFollowing = false;
  int _currentLikeCount = 0;
  int _currentCommentCount = 0;
  List<Map<String, dynamic>> _comments = [];
  bool _commentsLoading = true;
  String? _authorId;

  @override
  void initState() {
    super.initState();
    _currentLikeCount = widget.post.likeCount;
    _loadPostData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadPostData() async {
    // 优先使用 Post 模型中的 authorId，否则从 Supabase 查询
    _authorId = widget.post.authorId;
    final post = await _supabase.getCommunityPost(widget.post.id);
    if (!mounted) return;
    if (post != null) {
      setState(() {
        _currentLikeCount = (post['like_count'] as num?)?.toInt() ?? 0;
        _currentCommentCount = (post['comment_count'] as num?)?.toInt() ?? 0;
        _authorId = post['author_id']?.toString() ?? _authorId;
      });
    }
    // 检查是否是自己的帖子
    final currentUserId = await _supabase.currentUserId;
    if (_authorId == currentUserId) {
      print('这是自己的帖子，不显示关注按钮');
      _authorId = null; // 设置为 null，按钮将不显示
    }
    await Future.wait([
      _loadComments(),
      _checkLikeStatus(),
      _checkCollectionStatus(),
      if (_authorId != null && _authorId != currentUserId) _checkFollowStatus(),
    ]);
  }

  Future<void> _loadComments() async {
    setState(() => _commentsLoading = true);
    final list = await _supabase.getPostComments(widget.post.id);
    if (!mounted) return;
    setState(() {
      _comments = list;
      _commentsLoading = false;
    });
  }

  Future<void> _checkLikeStatus() async {
    final liked = await _supabase.isLiked(widget.post.id);
    if (!mounted) return;
    setState(() => _isLiked = liked);
  }

  Future<void> _checkCollectionStatus() async {
    final collected = await _supabase.isCollected(widget.post.id);
    if (!mounted) return;
    setState(() => _isFavorited = collected);
  }

  Future<void> _checkFollowStatus() async {
    if (_authorId == null) {
      print('_checkFollowStatus: authorId 为空');
      return;
    }
    print('检查关注状态: authorId=$_authorId');
    final following = await _supabase.isFollowing(_authorId!);
    print('关注状态结果: $following');
    if (!mounted) return;
    setState(() {
      _isFollowing = following;
      print('设置关注状态: $_isFollowing');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 顶部 AppBar（带返回按钮、头像、用户名）
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1E1E)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                // 用户头像（优先使用用户头像 URL）
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFF5F7FA),
                  backgroundImage: (widget.post.userAvatarUrl.isNotEmpty)
                      ? NetworkImage(widget.post.userAvatarUrl)
                      : null,
                  child: (widget.post.userAvatarUrl.isEmpty)
                      ? Text(
                          widget.post.username.isNotEmpty
                              ? widget.post.username[0]
                              : '宠',
                          style: const TextStyle(
                            color: Color(0xFF5A8EFA),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        )
                      : null,
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
                // 关注按钮（状态实时更新，自己的帖子不显示）
                FutureBuilder<String?>(
                  future: _supabase.currentUserId,
                  builder: (context, snapshot) {
                    final currentUserId = snapshot.data;
                    final authorId = _authorId ?? widget.post.authorId;
                    // 如果是自己的帖子，不显示关注按钮
                    if (authorId == null || authorId == currentUserId) {
                      return const SizedBox.shrink();
                    }
                    return TextButton(
                      onPressed: () async {
                        print('点击关注按钮，当前状态: $_isFollowing, authorId: $authorId');
                        final result = await _supabase.toggleFollow(authorId);
                        print('关注操作结果: $result');
                        if (!mounted) return;
                        setState(() {
                          _isFollowing = result;
                          _authorId = authorId; // 确保 _authorId 已设置
                          print('更新后状态: $_isFollowing');
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result ? '已关注 ${widget.post.username}' : '已取消关注'),
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
                        backgroundColor: _isFollowing ? Colors.grey[300] : const Color(0xFF5A8EFA),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        _isFollowing ? '已关注' : '关注',
                        style: TextStyle(
                          color: _isFollowing ? Colors.grey[700] : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
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

                // 点赞数和评论数统计
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
                      const SizedBox(width: 20),
                      Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        '$_currentCommentCount 条评论',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 评论列表
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
                      const SizedBox(height: 16),
                      if (_commentsLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_comments.isEmpty)
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
                        )
                      else
                        ..._comments.map((c) => _buildCommentItem(c)),
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
                onTap: () async {
                  final result = await _supabase.toggleLike(widget.post.id);
                  if (!mounted) return;
                  setState(() {
                    _isLiked = result;
                    _currentLikeCount += result ? 1 : -1;
                  });
                },
              ),

              const SizedBox(width: 16),

              // 收藏按钮
              _buildActionButton(
                icon: _isFavorited ? Icons.star : Icons.star_border,
                color: _isFavorited ? Colors.amber : Colors.grey[700]!,
                onTap: () async {
                  final result = await _supabase.toggleCollection(widget.post.id);
                  if (!mounted) return;
                  setState(() => _isFavorited = result);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result ? '已收藏' : '已取消收藏'),
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
    // 安全解析：如果是数字字符串则解析，否则使用默认时间差
    int hoursAgo = 1;
    try {
      // 尝试从 id 解析（旧 mock 数据可能是数字）
      if (widget.post.id.length < 10 && int.tryParse(widget.post.id) != null) {
        hoursAgo = int.parse(widget.post.id);
      } else {
        // UUID 或其他格式：使用随机时间差（1-24小时）
        hoursAgo = (widget.post.id.hashCode % 24).abs() + 1;
      }
    } catch (e) {
      hoursAgo = 1;
    }
    final postTime = now.subtract(Duration(hours: hoursAgo));
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
  void _showCommentInput(BuildContext context, {String? parentId}) {
    _commentController.clear();
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
                  controller: _commentController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: parentId == null ? '写下你的评论...' : '回复评论...',
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
                    onPressed: () async {
                      final content = _commentController.text.trim();
                      if (content.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('评论内容不能为空')),
                        );
                        return;
                      }
                      Navigator.pop(context);
                      final result = await _supabase.createComment(
                        postId: widget.post.id,
                        content: content,
                        parentId: parentId,
                      );
                      if (!mounted) return;
                      if (result != null) {
                        await _loadComments();
                        setState(() => _currentCommentCount++);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('评论成功'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('评论失败，请重试')),
                        );
                      }
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

  // 评论项
  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final authorName = comment['author_nickname']?.toString() ?? '用户';
    final content = comment['content']?.toString() ?? '';
    final createdAt = comment['created_at'];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFF5F7FA),
            child: Text(
              authorName.isNotEmpty ? authorName[0] : 'U',
              style: const TextStyle(
                color: Color(0xFF5A8EFA),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authorName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _formatCommentTime(createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _showCommentInput(context, parentId: comment['id']?.toString()),
                      child: Text(
                        '回复',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCommentTime(dynamic createdAt) {
    if (createdAt == null) return '刚刚';
    try {
      final time = DateTime.parse(createdAt.toString());
      final now = DateTime.now();
      final diff = now.difference(time);
      if (diff.inDays > 0) return '${diff.inDays}天前';
      if (diff.inHours > 0) return '${diff.inHours}小时前';
      if (diff.inMinutes > 0) return '${diff.inMinutes}分钟前';
      return '刚刚';
    } catch (e) {
      return '刚刚';
    }
  }
}
