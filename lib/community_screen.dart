import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'post_detail_page.dart'; // 导入帖子详情页

// 帖子数据模型
class Post {
  final String id;
  final String imageUrl;
  final String content;
  final String userAvatarUrl;
  final String username;
  final int likeCount;
  final double imageHeight; // 用于瀑布流的图片高度

  Post({
    required this.id,
    required this.imageUrl,
    required this.content,
    required this.userAvatarUrl,
    required this.username,
    required this.likeCount,
    required this.imageHeight,
  });
}

// 生动的宠物社区模拟数据
final List<Post> mockPosts = [
  Post(
    id: '1',
    imageUrl: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=400',
    content: '今天带我的金毛去草地撒欢了，它玩得超开心！🐕',
    userAvatarUrl: '',
    username: '金毛妈妈',
    likeCount: 128,
    imageHeight: 220,
  ),
  Post(
    id: '2',
    imageUrl:
        'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=400',
    content: '我家橘猫又胖了，但还是那么可爱 😻',
    userAvatarUrl: '',
    username: '猫咪铲屎官',
    likeCount: 256,
    imageHeight: 180,
  ),
  Post(
    id: '3',
    imageUrl:
        'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=400',
    content: '小柯基第一次见到雪，激动得不行！❄️',
    userAvatarUrl: '',
    username: '柯基爸爸',
    likeCount: 189,
    imageHeight: 240,
  ),
  Post(
    id: '4',
    imageUrl:
        'https://images.unsplash.com/photo-1574158622682-e40e69881006?w=400',
    content: '猫主子今天心情不错，赏脸让我摸了 🐱',
    userAvatarUrl: '',
    username: '猫奴小王',
    likeCount: 92,
    imageHeight: 200,
  ),
  Post(
    id: '5',
    imageUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d?w=400',
    content: '哈士奇拆家现场，这次是沙发遭殃了 😅',
    userAvatarUrl: '',
    username: '二哈的主人',
    likeCount: 342,
    imageHeight: 210,
  ),
  Post(
    id: '6',
    imageUrl:
        'https://images.unsplash.com/photo-1495360010541-f48722b34f7d?w=400',
    content: '小奶猫睡觉的样子简直萌化了我的心 💕',
    userAvatarUrl: '',
    username: '奶猫救助站',
    likeCount: 567,
    imageHeight: 190,
  ),
  Post(
    id: '7',
    imageUrl: 'https://images.unsplash.com/photo-1561037404-61cd46aa615b?w=400',
    content: '边牧的智商真的太高了，学会开门了！🤯',
    userAvatarUrl: '',
    username: '边牧训练师',
    likeCount: 234,
    imageHeight: 230,
  ),
  Post(
    id: '8',
    imageUrl:
        'https://images.unsplash.com/photo-1573865526739-10c1dd7e4d7a?w=400',
    content: '布偶猫的颜值真的是天花板级别 ✨',
    userAvatarUrl: '',
    username: '布偶爱好者',
    likeCount: 445,
    imageHeight: 195,
  ),
  Post(
    id: '9',
    imageUrl:
        'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?w=400',
    content: '小泰迪做了个新造型，像个小公主 👑',
    userAvatarUrl: '',
    username: '泰迪美容师',
    likeCount: 156,
    imageHeight: 215,
  ),
  Post(
    id: '10',
    imageUrl:
        'https://images.unsplash.com/photo-1511044568932-338cba0ad803?w=400',
    content: '英短蓝猫的圆脸真的太治愈了 🥰',
    userAvatarUrl: '',
    username: '英短繁育人',
    likeCount: 278,
    imageHeight: 185,
  ),
  Post(
    id: '11',
    imageUrl:
        'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?w=400',
    content: '拉布拉多游泳健将，在水里玩疯了 🏊',
    userAvatarUrl: '',
    username: '拉布拉多训练营',
    likeCount: 198,
    imageHeight: 225,
  ),
  Post(
    id: '12',
    imageUrl:
        'https://images.unsplash.com/photo-1529778873920-4da4926a72c2?w=400',
    content: '猫咪打哈欠的瞬间，露出小虎牙啦 😸',
    userAvatarUrl: '',
    username: '摄影师小李',
    likeCount: 312,
    imageHeight: 205,
  ),
  Post(
    id: '13',
    imageUrl: 'https://images.unsplash.com/photo-1558788353-f76d92427f16?w=400',
    content: '萨摩耶的笑容太有感染力了，治愈系 😊',
    userAvatarUrl: '',
    username: '微笑天使',
    likeCount: 423,
    imageHeight: 235,
  ),
  Post(
    id: '14',
    imageUrl:
        'https://images.unsplash.com/photo-1596854407944-bf87f6fdd49e?w=400',
    content: '暹罗猫的蓝眼睛太迷人了，深邃又优雅 💙',
    userAvatarUrl: '',
    username: '暹罗猫舍',
    likeCount: 267,
    imageHeight: 175,
  ),
  Post(
    id: '15',
    imageUrl:
        'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?w=400',
    content: '今天给狗狗做了自制狗粮，它吃得特别香 🍖',
    userAvatarUrl: '',
    username: '宠物营养师',
    likeCount: 189,
    imageHeight: 220,
  ),
  Post(
    id: '16',
    imageUrl:
        'https://images.unsplash.com/photo-1571988840298-3b5301d5109b?w=400',
    content: '小猫咪第一次看到镜子里的自己，懵了 😹',
    userAvatarUrl: '',
    username: '猫咪观察员',
    likeCount: 334,
    imageHeight: 200,
  ),
  Post(
    id: '17',
    imageUrl: 'https://images.unsplash.com/photo-1548199973-03cce0bbc87b?w=400',
    content: '比熊犬洗完澡后像个棉花糖，软萌软萌的 ☁️',
    userAvatarUrl: '',
    username: '比熊爱好者',
    likeCount: 212,
    imageHeight: 190,
  ),
  Post(
    id: '18',
    imageUrl:
        'https://images.unsplash.com/photo-1533743983669-94fa5c4338ec?w=400',
    content: '猫咪趴在键盘上办公，是在帮我写代码吗？💻',
    userAvatarUrl: '',
    username: '程序员铲屎官',
    likeCount: 456,
    imageHeight: 210,
  ),
  Post(
    id: '19',
    imageUrl:
        'https://images.unsplash.com/photo-1477884213360-7e9d7dcc1e48?w=400',
    content: '德牧宝宝太帅了，小时候就有大佬气场 😎',
    userAvatarUrl: '',
    username: '德牧训导员',
    likeCount: 298,
    imageHeight: 245,
  ),
  Post(
    id: '20',
    imageUrl:
        'https://images.unsplash.com/photo-1526336024174-e58f5cdd8e13?w=400',
    content: '小猫咪在纸箱里探出小脑袋，太可爱了 📦',
    userAvatarUrl: '',
    username: '猫咪日常',
    likeCount: 389,
    imageHeight: 165,
  ),
];

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 用于跟踪每个用户的关注状态
  final Map<String, bool> _followStatus = {};

  @override
  void initState() {
    super.initState();
    // 默认显示"发现"标签（索引 1）
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // 小红书风格的顶部导航栏
        centerTitle: true,
        title: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: const Color(0xFF1E1E1E),
          unselectedLabelColor: const Color(0xFF999999),
          labelStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(width: 2.5, color: Color(0xFF1E1E1E)),
            insets: EdgeInsets.symmetric(horizontal: 24),
          ),
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: '关注'),
            Tab(text: '发现'),
            Tab(text: '附近'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF1E1E1E), size: 24),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('菜单功能开发中'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF1E1E1E), size: 24),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('搜索功能开发中'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFollowTab(), _buildRecommendTab(), _buildTopicTab()],
      ),
      // 添加小红书风格的发布按钮
      floatingActionButton: FloatingActionButton(
        onPressed: _showPublishDialog,
        backgroundColor: const Color(0xFFFF2442),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  // 显示发布选项对话框
  void _showPublishDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '发布内容',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildPublishOption(
                  icon: Icons.image_outlined,
                  iconColor: const Color(0xFFFF2442),
                  title: '发帖子',
                  subtitle: '分享图文、视频等精彩内容',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('发布功能开发中...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 70, endIndent: 20),
                _buildPublishOption(
                  icon: Icons.help_outline,
                  iconColor: const Color(0xFF8B77FF),
                  title: '提问题',
                  subtitle: '向社区求助，获取专业解答',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('提问功能开发中...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPublishOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFFCCCCCC),
            ),
          ],
        ),
      ),
    );
  }

  // 推荐标签页 - 小红书风格双栏瀑布流
  Widget _buildRecommendTab() {
    return Container(
      color: const Color(0xFFF5F5F5), // 小红书的背景色
      child: MasonryGridView.count(
        crossAxisCount: 2, // 双栏布局
        mainAxisSpacing: 8, // 垂直间距
        crossAxisSpacing: 8, // 水平间距
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        itemCount: mockPosts.length,
        itemBuilder: (context, index) {
          final post = mockPosts[index];
          return _buildWaterfallPostCard(post: post);
        },
      ),
    );
  }

  // 小红书风格的瀑布流卡片
  Widget _buildWaterfallPostCard({required Post post}) {
    return InkWell(
      onTap: () {
        // 点击进入帖子详情页
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PostDetailPage(post: post)),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          // 去除阴影，小红书风格更平面化
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：图片（主体）- 使用真实网络图片
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              child: Image.network(
                post.imageUrl,
                height: post.imageHeight,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: post.imageHeight,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      border: Border.all(
                        color: const Color(0xFFEEEEEE),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.image_outlined,
                      color: Color(0xFFCCCCCC),
                      size: 40,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: post.imageHeight,
                    width: double.infinity,
                    color: const Color(0xFFF5F5F5),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: const Color(0xFFFF2442),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 中部：标题/正文（最多2行）
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Text(
                post.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF1E1E1E),
                  height: 1.3,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            // 底部：用户信息行（紧凑设计）
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  // 小头像
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: const Color(0xFFF5F5F5),
                    child: Text(
                      post.username[0],
                      style: const TextStyle(
                        color: Color(0xFF999999),
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 用户昵称
                  Expanded(
                    child: Text(
                      post.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF999999),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 爱心图标 + 点赞数
                  Icon(
                    Icons.favorite_border,
                    size: 14,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    post.likeCount.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 关注标签页
  Widget _buildFollowTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 60),
          // 空状态提示
          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '还没有关注任何人',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _tabController.index = 0;
              });
            },
            child: const Text('去推荐页看看'),
          ),
          const SizedBox(height: 40),
          // "为你推荐"模块
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 16),
                  child: Text(
                    '为你推荐',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                ),
                // 推荐用户列表
                _buildRecommendedUser(
                  username: '萌宠达人',
                  bio: '分享养宠经验 · 已发布 128 条动态',
                  avatar: '萌',
                ),
                _buildRecommendedUser(
                  username: '宠物医生王',
                  bio: '专业宠物医师 · 已发布 256 条动态',
                  avatar: '王',
                ),
                _buildRecommendedUser(
                  username: '狗狗训练师',
                  bio: '行为训练专家 · 已发布 89 条动态',
                  avatar: '训',
                ),
                _buildRecommendedUser(
                  username: '猫咪小管家',
                  bio: '猫咪护理达人 · 已发布 167 条动态',
                  avatar: '猫',
                ),
                _buildRecommendedUser(
                  username: '宠物营养师',
                  bio: '科学喂养倡导者 · 已发布 203 条动态',
                  avatar: '营',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 推荐用户卡片（优化版）
  Widget _buildRecommendedUser({
    required String username,
    required String bio,
    required String avatar,
  }) {
    final isFollowing = _followStatus[username] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 14), // 增加间距
      padding: const EdgeInsets.all(18), // 增加内部留白
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03), // 更轻的阴影
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFF0F0F0), // 添加淡边框
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 用户头像（优化为统一柔和背景）
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFF5F7FA), // 统一的浅色背景
            child: Text(
              avatar,
              style: const TextStyle(
                color: Color(0xFF5A8EFA),
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14), // 增加间距
          // 用户信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bio,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFAAAAAA), // 更浅的颜色
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 关注按钮（改为描边样式）
          InkWell(
            onTap: () {
              setState(() {
                _followStatus[username] = !isFollowing;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isFollowing ? '已取消关注' : '已关注 $username'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                // 描边按钮样式
                color: isFollowing ? const Color(0xFFF8F8F8) : Colors.white,
                border: Border.all(
                  color: isFollowing
                      ? const Color(0xFFE0E0E0)
                      : const Color(0xFF5A8EFA),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFollowing ? Icons.check : Icons.add,
                    size: 15,
                    color: isFollowing
                        ? const Color(0xFF666666)
                        : const Color(0xFF5A8EFA),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isFollowing ? '已关注' : '关注',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isFollowing
                          ? const Color(0xFF666666)
                          : const Color(0xFF5A8EFA),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 附近标签页 - 基于地理位置的本地发现页
  Widget _buildTopicTab() {
    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        // 地图模块
        _buildMapModule(),

        const SizedBox(height: 12),

        // 地点分类标题
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            '附近的宠物友好地点',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E1E),
            ),
          ),
        ),

        // 地点分类网格
        _buildLocationCategories(),

        const SizedBox(height: 8),

        // 本地内容流标题
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.location_on, size: 18, color: Color(0xFFFF2442)),
              SizedBox(width: 6),
              Text(
                '附近的动态',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E1E1E),
                ),
              ),
            ],
          ),
        ),

        // 本地内容流（瀑布流）
        _buildNearbyPostsGrid(),
      ],
    );
  }

  // 地图模块
  Widget _buildMapModule() {
    return Container(
      height: 180,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Stack(
        children: [
          // 地图占位符
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  '地图加载中...',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  '北京市 朝阳区',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // 定位按钮
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              elevation: 2,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('正在获取位置...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.my_location,
                        size: 16,
                        color: Color(0xFF5A8EFA),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '定位',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5A8EFA),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 地点分类网格
  Widget _buildLocationCategories() {
    final categories = [
      {
        'name': '宠物打卡地',
        'icon': Icons.location_on,
        'color': const Color(0xFFFF2442),
        'count': '126',
      },
      {
        'name': '友好商店',
        'icon': Icons.store,
        'color': const Color(0xFF5A8EFA),
        'count': '89',
      },
      {
        'name': '宠物餐厅',
        'icon': Icons.restaurant,
        'color': const Color(0xFFFF9500),
        'count': '64',
      },
      {
        'name': '宠物公园',
        'icon': Icons.park,
        'color': const Color(0xFF34C759),
        'count': '52',
      },
      {
        'name': '宠物医院',
        'icon': Icons.local_hospital,
        'color': const Color(0xFF8B77FF),
        'count': '38',
      },
      {
        'name': '宠物美容',
        'icon': Icons.content_cut,
        'color': const Color(0xFFFF6B9D),
        'count': '71',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.1,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildCategoryCard(
            name: category['name'] as String,
            icon: category['icon'] as IconData,
            color: category['color'] as Color,
            count: category['count'] as String,
          );
        },
      ),
    );
  }

  // 地点分类卡片
  Widget _buildCategoryCard({
    required String name,
    required IconData icon,
    required Color color,
    required String count,
  }) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('浏览附近的$name'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0F0F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E1E1E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              '$count个地点',
              style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
            ),
          ],
        ),
      ),
    );
  }

  // 本地内容流（瀑布流）
  Widget _buildNearbyPostsGrid() {
    // 筛选附近的帖子（这里模拟选择前8个）
    final nearbyPosts = mockPosts.take(8).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: nearbyPosts.length,
        itemBuilder: (context, index) {
          final post = nearbyPosts[index];
          return _buildNearbyPostCard(post: post);
        },
      ),
    );
  }

  // 附近的帖子卡片（带位置标签）
  Widget _buildNearbyPostCard({required Post post}) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PostDetailPage(post: post)),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  child: Image.network(
                    post.imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 160,
                        color: const Color(0xFFF5F5F5),
                        child: const Icon(Icons.image_outlined, size: 40),
                      );
                    },
                  ),
                ),
                // 位置标签
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.white),
                        SizedBox(width: 2),
                        Text(
                          '1.2km',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 内容
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E1E1E),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: const Color(0xFFF5F5F5),
                        child: Text(
                          post.username[0],
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          post.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.favorite_border,
                        size: 13,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.likeCount.toString(),
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
