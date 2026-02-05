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
  final Set<String> _expandedComments = {}; // 记录展开的评论

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
    // 构建评论树：将回复挂载到对应的主评论下
    final commentsWithReplies = _buildCommentTree(list);
    setState(() {
      _comments = commentsWithReplies;
      _commentsLoading = false;
    });
  }

  /// 构建评论层级结构
  List<Map<String, dynamic>> _buildCommentTree(
      List<Map<String, dynamic>> flatComments) {
    // 先收集所有评论的 ID
    final allIds = <String>{};
    for (final comment in flatComments) {
      final id = comment['id']?.toString();
      if (id != null && id.isNotEmpty) {
        allIds.add(id);
      }
    }

    // 分离主评论和回复
    final mainComments = <Map<String, dynamic>>[];
    final repliesMap = <String, List<Map<String, dynamic>>>{};

    for (final comment in flatComments) {
      final parentId = comment['parent_id']?.toString();
      // 如果没有 parent_id，或者 parent_id 对应的评论不存在，则作为主评论
      if (parentId == null ||
          parentId.isEmpty ||
          parentId == 'null' ||
          !allIds.contains(parentId)) {
        // 主评论（或孤儿回复提升为主评论）
        mainComments.add(Map<String, dynamic>.from(comment));
      } else {
        // 回复
        repliesMap.putIfAbsent(parentId, () => []);
        repliesMap[parentId]!.add(comment);
      }
    }

    // 将回复挂载到主评论
    for (final comment in mainComments) {
      final commentId = comment['id']?.toString() ?? '';
      comment['replies'] = repliesMap[commentId] ?? [];
    }

    return mainComments;
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
                        print(
                            '点击关注按钮，当前状态: $_isFollowing, authorId: $authorId');
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
                            content: Text(result
                                ? '已关注 ${widget.post.username}'
                                : '已取消关注'),
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
                        backgroundColor: _isFollowing
                            ? Colors.grey[300]
                            : const Color(0xFF5A8EFA),
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

                // 帖子的完整文字内容（支持话题高亮）
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildContentWithHashtags(widget.post.content),
                ),

                // 话题标签（显示选择的话题）
                if (widget.post.topicIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.post.topicIds.map((topic) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5A8EFA).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '#$topic',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF5A8EFA),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

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
                      Icon(Icons.chat_bubble_outline,
                          size: 18, color: Colors.grey[600]),
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
                  final result =
                      await _supabase.toggleCollection(widget.post.id);
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

  // 获取发布时间
  String _getPublishTime() {
    // 优先使用真实的创建时间
    if (widget.post.createdAt != null) {
      final now = DateTime.now();
      final difference = now.difference(widget.post.createdAt!);

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

    // 备用方案：mock 数据使用 id 模拟时间
    final now = DateTime.now();
    int hoursAgo = 1;
    try {
      if (widget.post.id.length < 10 && int.tryParse(widget.post.id) != null) {
        hoursAgo = int.parse(widget.post.id);
      } else {
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

  /// 构建带话题高亮的内容文本
  Widget _buildContentWithHashtags(String content) {
    // 匹配 #话题 格式（支持中英文、数字、下划线）
    final regex = RegExp(r'#[\w\u4e00-\u9fa5]+');
    final matches = regex.allMatches(content);

    if (matches.isEmpty) {
      return Text(
        content,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF1E1E1E),
          height: 1.6,
          letterSpacing: 0.3,
        ),
      );
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // 添加普通文本
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1E1E1E),
            height: 1.6,
            letterSpacing: 0.3,
          ),
        ));
      }
      // 添加高亮的话题
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF5A8EFA), // 蓝色高亮
          height: 1.6,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w500,
        ),
      ));
      lastEnd = match.end;
    }

    // 添加剩余的普通文本
    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF1E1E1E),
          height: 1.6,
          letterSpacing: 0.3,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  // 显示图片查看器（全屏查看，支持下滑和点击返回）
  void _showImageViewer(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenImageViewer(
            imageUrl: widget.post.imageUrl,
            heroTag: 'post-image-${widget.post.id}',
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // 显示评论输入框
  void _showCommentInput(BuildContext context,
      {String? parentId, String? replyToName}) {
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
                    hintText:
                        replyToName != null ? '回复 $replyToName' : '说点什么...',
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

  // 评论项（小红书风格：主评论 + 扁平化回复列表）
  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final authorName = comment['author_nickname']?.toString() ?? '用户';
    final avatarUrl = comment['author_avatar_url']?.toString() ?? '';
    final content = comment['content']?.toString() ?? '';
    final createdAt = comment['created_at'];
    final replies = comment['replies'] as List<dynamic>? ?? [];
    final commentId = comment['id']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主评论
          _buildSingleComment(
            avatarUrl: avatarUrl,
            authorName: authorName,
            content: content,
            createdAt: createdAt,
            replyToName: null, // 主评论不显示"回复 xxx"
            onReply: () => _showCommentInput(
              context,
              parentId: commentId,
              replyToName: authorName,
            ),
          ),
          // 回复列表（扁平显示在主评论下方，左侧缩进）
          if (replies.isNotEmpty) ...[
            ...replies
                .take(
                    _expandedComments.contains(commentId) ? replies.length : 3)
                .map((reply) {
              final replyMap = reply as Map<String, dynamic>;
              final replyAuthor =
                  replyMap['author_nickname']?.toString() ?? '用户';
              final replyAvatarUrl =
                  replyMap['author_avatar_url']?.toString() ?? '';
              final replyContent = replyMap['content']?.toString() ?? '';
              final replyTime = replyMap['created_at'];
              final replyToNickname = null; // 暂时不支持回复昵称显示

              return Padding(
                padding: const EdgeInsets.only(left: 48, top: 16),
                child: _buildSingleComment(
                  avatarUrl: replyAvatarUrl,
                  authorName: replyAuthor,
                  content: replyContent,
                  createdAt: replyTime,
                  replyToName: replyToNickname, // 显示"回复 xxx: "
                  onReply: () => _showCommentInput(
                    context,
                    parentId: commentId, // 所有回复都挂在主评论下
                    replyToName: replyAuthor,
                  ),
                ),
              );
            }),
            // 展开/收起更多回复
            if (replies.length > 3)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_expandedComments.contains(commentId)) {
                        _expandedComments.remove(commentId);
                      } else {
                        _expandedComments.add(commentId!);
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 1,
                        color: const Color(0xFFCCCCCC),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _expandedComments.contains(commentId)
                            ? '收起回复'
                            : '展开${replies.length - 3}条回复',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// 单条评论/回复组件
  Widget _buildSingleComment({
    required String avatarUrl,
    required String authorName,
    required String content,
    required dynamic createdAt,
    required String? replyToName,
    required VoidCallback onReply,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 头像
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFF5F7FA),
          backgroundImage:
              avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          child: avatarUrl.isEmpty
              ? Text(
                  authorName.isNotEmpty ? authorName[0] : 'U',
                  style: const TextStyle(
                    color: Color(0xFF5A8EFA),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 用户名
              Text(
                authorName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 4),
              // 评论内容（如果是回复，显示"回复 xxx: "）
              if (replyToName != null && replyToName.isNotEmpty)
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 15, height: 1.5, color: Color(0xFF1E1E1E)),
                    children: [
                      const TextSpan(text: '回复 '),
                      TextSpan(
                        text: replyToName,
                        style: const TextStyle(color: Color(0xFF5A8EFA)),
                      ),
                      const TextSpan(text: ': '),
                      TextSpan(text: content),
                    ],
                  ),
                )
              else
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1E1E1E),
                    height: 1.5,
                  ),
                ),
              const SizedBox(height: 8),
              // 时间和操作
              Row(
                children: [
                  Text(
                    _formatCommentTime(createdAt),
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: onReply,
                    child: const Text(
                      '回复',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 点赞
                  Icon(Icons.favorite_border,
                      size: 16, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
        ),
      ],
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

/// 全屏图片查看器（支持下滑和点击返回）
class _FullscreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String heroTag;

  const _FullscreenImageViewer({
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer>
    with SingleTickerProviderStateMixin {
  double _dragOffsetY = 0;
  late AnimationController _controller;
  late Animation<double> _reboundAnimation;

  static const double _dismissThreshold = 150;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runReboundAnimation() {
    _reboundAnimation =
        Tween<double>(begin: _dragOffsetY, end: 0).animate(_controller)
          ..addListener(() {
            setState(() {
              _dragOffsetY = _reboundAnimation.value;
            });
          });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dragPercent = (_dragOffsetY / screenHeight).clamp(0.0, 1.0);
    final scale = 1.0 - dragPercent * 0.4;
    final bgOpacity = (1.0 - dragPercent).clamp(0.0, 1.0);

    return Stack(
      children: [
        // 背景
        Opacity(
          opacity: bgOpacity,
          child: Container(color: Colors.black),
        ),

        // 交互层
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            onVerticalDragUpdate: (details) {
              setState(() {
                _dragOffsetY += details.delta.dy;
                if (_dragOffsetY < 0) _dragOffsetY = 0;
              });
            },
            onVerticalDragEnd: (_) {
              if (_dragOffsetY > _dismissThreshold) {
                Navigator.pop(context);
              } else {
                _runReboundAnimation();
              }
            },
            child: Transform.translate(
              offset: Offset(0, _dragOffsetY),
              child: Transform.scale(
                scale: scale,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: Hero(
                      tag: widget.heroTag,
                      child: Image.network(
                        widget.imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: Colors.white,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 50, color: Colors.white),
                              SizedBox(height: 16),
                              Text('图片加载失败',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white)),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
