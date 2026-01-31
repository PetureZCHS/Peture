import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:my_pet/pages/image_generation/preparation_page.dart'
    hide AppColors;
// import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

// --- 您的页面引用 (保持不变) ---
import 'chat_page.dart';
import 'pages/pet_diary/pet_diary_compose_page.dart';
import 'pages/pet_passport/pet_passport_page.dart';
import 'pages/pet_recipe/pet_recipe_list_page.dart';
import 'pages/partner_fit/partner_fit_gym_page.dart';
import 'pages/dog_clicker/dog_clicker_screen.dart';
import 'pages/shop/shop_page.dart';
import 'pages/unified_expense/unified_expense_home_page.dart';
import 'pages/reminder/intelligent_reminder_page.dart';
import 'settings_page.dart';
import 'pages/invitation_code_page.dart';
import 'pages/lost_pet/lost_pet_rescue_page.dart';
import 'community_screen.dart';
import 'medical_record_screen.dart';
import 'profile_screen.dart';
import 'pages/growth_log/growth_log_page.dart'; 
import 'utils/ui_helpers.dart';
 
/// 搜索结果数据模型
class SearchResult {
  final String name;
  final String keyword;
  final IconData icon;
  final Widget Function() pageBuilder;

  SearchResult(this.name, this.keyword, this.icon, this.pageBuilder);
}

/// 全局数据变更通知器，用于跨页面通知数据刷新需求
class DataChangeNotifier {
  static bool petDataChanged = false;

  /// 标记宠物数据已变更，需要刷新
  static void markPetDataChanged() {
    petDataChanged = true;
  }

  /// 检查并重置标记
  static bool checkAndReset() {
    if (petDataChanged) {
      petDataChanged = false;
      return true;
    }
    return false;
  }
}

// =========================================================
// 1. 配色与样式(删除)
// =========================================================


// =========================================================
// 2. 主页面骨架
// =========================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  double _currentPosition = 0.0;
  int _lastHapticIndex = 0;

  late AnimationController _tabController;
  bool _showTimeline = false; // 原 _isUniverseMode，现改为时间线模式

  /// 用于通知 MedicalRecordScreen 刷新数据的通知器
  final ValueNotifier<int> _medicalScreenRefreshNotifier =
      ValueNotifier<int>(0);

  /// 标记是否需要刷新健康记录页面（首次进入或数据变更后需要刷新）
  bool _needsMedicalScreenRefresh = true;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _tabController = AnimationController(
      vsync: this,
      lowerBound: double.negativeInfinity,
      upperBound: double.infinity,
      value: 0.0,
    );
    _tabController.addListener(() {
      setState(() {
        _currentPosition = _tabController.value;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      InvitationWelcomeDialog.showIfLifetime(context);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _medicalScreenRefreshNotifier.dispose(); 
    super.dispose();
  }

  void _animateToPage(int page, {double velocity = 0.0}) {
    // [优化] 调整弹簧参数，使其更软、更弹、更像水
    final SpringDescription spring = SpringDescription(
      mass: 0.6,       // 稍微减轻质量，响应更快
      stiffness: 140.0, // 大幅降低刚度，产生柔软感 (原 250)
      damping: 12.0,    // 降低阻尼，允许更多回弹/摆动 (原 15)
    );
    
    final simulation = SpringSimulation(
      spring,
      _currentPosition,
      page.toDouble(),
      velocity,
    );
    
    _tabController.animateWith(simulation);
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    _animateToPage(index);

    setState(() {
      _currentIndex = index;
      _lastHapticIndex = index;
    });
    HapticFeedback.mediumImpact();

    // 当切换到 MedicalRecordScreen (index 2) 时，检查是否需要刷新
    if (index == 2) {
      // 检查全局数据变更标记或首次进入标记
      if (_needsMedicalScreenRefresh || DataChangeNotifier.checkAndReset()) {
        _medicalScreenRefreshNotifier.value++;
        _needsMedicalScreenRefresh = false;
      }
      // 注意：首次加载现在由 didChangeDependencies 中的 _hasLoadedData 标志控制，避免启动卡顿
    }
  }

  void _toggleViewMode() {
    setState(() {
      _showTimeline = !_showTimeline;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final Widget homePageContent = AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutQuart,
      switchOutCurve: Curves.easeInQuart,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: _showTimeline
          ? const _HomeUniverseContent(key: ValueKey('timeline')) // 重用这个类名，虽然现在是 timeline
          : const _HomeDashboardContent(key: ValueKey('dashboard')),
    );

    final List<Widget> pages = [
      homePageContent,
      const CommunityScreen(),
      MedicalRecordScreen(refreshNotifier: _medicalScreenRefreshNotifier),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 内容层
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),

          // 右上角悬浮切换按钮
          if (_currentIndex == 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 20,
              child: GestureDetector(
                onTap: _toggleViewMode,
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.8), width: 1),
                      ),
                      child: Icon(
                          _showTimeline
                              ? Icons.grid_view_rounded
                              : Icons.timeline_rounded, // 切换图标为时间线
                          color: AppColors.textDark,
                          size: 22),
                    ),
                  ),
                ),
              ),
            ),

          // 底部导航
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            height: 68,
            child: _buildFloatingGlassNavBar(),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // 底部导航栏
  // =========================================================

  Widget _buildFloatingGlassNavBar() {
    final double rawWidth = MediaQuery.of(context).size.width;
    // 避免在极窄/初始化阶段出现负宽度，导致 BoxConstraints 抛异常
    final double safeWidth = (rawWidth - 48).clamp(0.0, double.infinity);
    if (safeWidth <= 0) {
      return const SizedBox.shrink();
    }

    final double totalWidth = safeWidth;
    final double itemWidth = totalWidth / 4;
    const double indicatorWidth = 56.0;
    const double indicatorHeight = 40.0;
    const double navHeight = 68.0;

    final LinearGradient currentGradient =
        AppColors.navGradients[_currentIndex];

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // 确保整个区域都响应点击和拖拽 
      onTapUp: (details) {
        final double width = MediaQuery.of(context).size.width - 48;
        final double itemWidth = width / 4;
        // 计算点击位置对应的 index
        final int index = (details.localPosition.dx / itemWidth).floor().clamp(0, 3);
        _onTabTapped(index);
      },
      onHorizontalDragStart: (details) {
        _tabController.stop();
      },
      onHorizontalDragUpdate: (details) {
        final double width = MediaQuery.of(context).size.width - 48;
        final double itemWidth = width / 4;
        double newPosition = (details.localPosition.dx / itemWidth) - 0.5; 

        setState(() {
          _currentPosition = newPosition.clamp(0.0, 3.0);
          _tabController.value = _currentPosition;
        });
        int potentialIndex = _currentPosition.round();
        if (potentialIndex != _lastHapticIndex) {
          HapticFeedback.selectionClick();
          _lastHapticIndex = potentialIndex;
        }
      },
      onHorizontalDragEnd: (details) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final double dragItemWidth = (screenWidth - 48) / 4;
        
        // Calculate velocity in "pages per second"
        final double velocity = details.velocity.pixelsPerSecond.dx / dragItemWidth;

        int targetIndex = _currentPosition.round();
        
        // [优化] 增加速度阈值判断，让快速滑动更容易触发翻页
        if (velocity.abs() > 0.3) { // 降低阈值 (原 0.5)
          if (velocity > 0) {
            targetIndex = _currentPosition.floor() + 1;
          } else {
            targetIndex = _currentPosition.ceil() - 1;
          }
        } else {
          // 如果速度很慢，就看位置是否超过一半
          // _currentPosition.round() 已经处理了这个逻辑
        }
        
        targetIndex = targetIndex.clamp(0, 3);
        
        // [优化] 传递更强的初始速度给弹簧，制造"冲过头"再回弹的效果
        _animateToPage(targetIndex, velocity: velocity * 1.2);

        setState(() {
          _currentIndex = targetIndex;
          _currentPosition = targetIndex.toDouble();
          _lastHapticIndex = targetIndex;
        });
        HapticFeedback.lightImpact();
      },
      onHorizontalDragCancel: () {
        _animateToPage(_currentIndex); 
      },
      child: Container(
        height: navHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: currentGradient.colors.first.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 8),
              spreadRadius: -8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  width: totalWidth,
                  height: navHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1.0,
                    ),
                    gradient: RadialGradient(
                      radius: 2.0,
                      center: Alignment.topCenter,
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.6),
                        Colors.white.withOpacity(0.8),
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  height: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.9),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: (_currentPosition * itemWidth) + (itemWidth / 2) - (indicatorWidth / 2),
                  child: Builder(
                    builder: (context) {
                      // [优化] 动态形变算法：增强液态拉伸感
                      double velocity = 0.0;
                      if (_tabController.isAnimating) {
                         velocity = _tabController.velocity; // 保留符号以判断方向
                      }
                      
                      double absVelocity = velocity.abs();
                      
                      // 拉伸因子：速度越快，拉伸越明显。使用非线性曲线让微小移动也有反馈。
                      // 限制最大拉伸为 60%
                      double stretchFactor = (absVelocity * 0.08).clamp(0.0, 0.6);
                      
                      double currentWidth = indicatorWidth * (1 + stretchFactor);
                      // 挤压高度：保持一定的体积感，但不要完全扁平
                      double currentHeight = indicatorHeight * (1 - stretchFactor * 0.35);

                      // [新增] 动态倾斜：根据速度方向微调角度，模拟惯性
                      // 速度为正（向右），向左倾斜（头部在前，尾部拖后）-> 实际上旋转是整体旋转
                      // 简单的旋转可能看起来像车轮。液态通常是头部变大尾部变小（水滴型）。
                      // 这里用简单的 Scale 模拟拉伸即可，旋转可能导致图标错位。
                      
                      return Container(
                        width: currentWidth,
                        height: currentHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(currentHeight / 2), // 保持胶囊形状
                          gradient: currentGradient,
                          boxShadow: [
                            BoxShadow(
                              color: currentGradient.colors.first.withOpacity(0.4 + (stretchFactor * 0.2)), // 速度越快，光晕越强
                              blurRadius: 12 + (stretchFactor * 10), // 运动时模糊拖尾增加
                              spreadRadius: -2,
                              offset: const Offset(0, 2),
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: 1,
                              offset: const Offset(0, 1),
                              spreadRadius: 0,
                              blurStyle: BlurStyle.inner
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                ),
                SizedBox(
                  width: totalWidth,
                  height: navHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, Icons.home_rounded, Icons.home_outlined),
                      _buildNavItem(1, Icons.explore_rounded, Icons.explore_outlined),
                      _buildNavItem(2, Icons.assignment_rounded, Icons.assignment_outlined),
                      _buildNavItem(3, Icons.person_rounded, Icons.person_outline_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData selectedIcon, IconData unselectedIcon) {
    final double distance = (_currentPosition - index).abs();
    final double t = (1.0 - distance).clamp(0.0, 1.0);
    double scale = 1.0 + (0.1 * t);

    Color iconColor;
    if (t > 0.6) {
      iconColor = Colors.white;
    } else {
      iconColor = Color.lerp(AppColors.textGrey, AppColors.textDark, t)!;
    }

    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 4, // [修复] 宽度必须是 / 4，与指示器逻辑一致
      height: 68, 
      child: Transform.scale(
        scale: scale,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              t > 0.6 ? selectedIcon : unselectedIcon,
              color: iconColor,
              size: 24, 
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// 3. 模式 A: 实用仪表盘 (修复滚动 & 布局)
// =========================================================

class _HomeDashboardContent extends StatefulWidget {
  const _HomeDashboardContent({super.key});

  @override
  State<_HomeDashboardContent> createState() => _HomeDashboardContentState();
}

class _HomeDashboardContentState extends State<_HomeDashboardContent> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SearchResult> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {}); // 更新状态以显示/隐藏清除按钮
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// 搜索功能列表
  static final List<SearchResult> _allSearchItems = [
    SearchResult('AI智能问诊', 'chat', Icons.chat_bubble_outline,
        () => const ChatPageWithDatabase()),
    SearchResult(
        '电子档案', 'passport', Icons.badge_rounded, () => const PetPassportPage()),
    SearchResult('成长日记', 'diary', Icons.menu_book_rounded,
        () => const PetDiaryComposePage()),
    SearchResult('活力健身', 'fitness', Icons.directions_run_rounded,
        () => const PartnerFitGymPage()),
    SearchResult('营养食谱', 'recipe', Icons.restaurant_menu_rounded,
        () => const PetRecipeListPage()),
    SearchResult('训宠响片', 'clicker', Icons.touch_app_rounded,
        () => const DogClickerScreen()),
    SearchResult(
        '宠物商城', 'shop', Icons.shopping_bag_rounded, () => const PetShopPage()),
    SearchResult('医疗记录', 'medical', Icons.medical_services_outlined,
        () => MedicalRecordScreen(refreshNotifier: ValueNotifier<int>(0))),
    SearchResult('宠物消费', 'expense', Icons.account_balance_wallet,
        () => const UnifiedExpenseHomePage()),
    SearchResult('智能提醒', 'reminder', Icons.notifications_active,
        () => const IntelligentReminderPage()),
    SearchResult('宠物档案', 'profile', Icons.pets, () => const ProfileScreen()),
    SearchResult('社区话题', 'community', Icons.forum_outlined,
        () => const CommunityScreen()),
    SearchResult('设置', 'settings', Icons.settings, () => const SettingsPage()),
  ];

  /// 执行搜索
  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    final results = _allSearchItems.where((item) {
      return item.name.toLowerCase().contains(lowerQuery) ||
          item.keyword.toLowerCase().contains(lowerQuery);
    }).toList();

    setState(() {
      _searchResults = results;
      _showSearchResults = true;
    });
  }

  /// 跳转到搜索结果页面
  void _navigateToResult(SearchResult result) {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _showSearchResults = false;
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => result.pageBuilder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [ 
        // 背景光弥散效果
        const _AmbientBackground(),

        ListView(
      // [关键点1] 强制开启滚动物理效果，即使内容少也能滑动
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      
      // [关键点2] 增加底部 Padding (130)，确保内容不被悬浮导航栏遮挡，且预留滑动空间
      padding: EdgeInsets.fromLTRB(20, topPadding + 60, 20, 130),
      children: [
        // 0. 搜索框
        _buildSearchBar(),

        const SizedBox(height: 16),

        // 1. AI 智能问诊 (修复版：文字完整显示)
        _buildHeroAiCard(context),

        const SizedBox(height: 16),
        


        // 2. 功能网格
        LayoutBuilder(
          builder: (context, constraints) { 
            double width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildFeatureCard(width, '宠物消费', 'Expenses', Icons.account_balance_wallet_rounded, const LinearGradient(colors: [Color(0xFF6A85B6), Color(0xFFBAC8E0)]), const UnifiedExpenseHomePage()),
                _buildFeatureCard(width, '智能提醒', 'Reminder', Icons.notifications_active_rounded, const LinearGradient(colors: [Color(0xFFA18CD1), Color(0xFFFBC2EB)]), const IntelligentReminderPage()),
                _buildFeatureCard(width, '电子档案', 'Vaccine', Icons.badge_rounded, AppColors.coolGradient, const PetPassportPage()),
                _buildFeatureCard(width, '第一人称日记', 'Diary', Icons.menu_book_rounded, AppColors.natureGradient, const PetDiaryComposePage()),
                _buildFeatureCard(width, '活力健身', 'Fitness', Icons.directions_run_rounded, AppColors.oceanGradient, const PartnerFitGymPage()),
                _buildFeatureCard(width, '营养食谱', 'Food', Icons.restaurant_menu_rounded, AppColors.goldGradient, const PetRecipeListPage()),
                _buildFeatureCard(width, '训宠响片', 'Training', Icons.touch_app_rounded, AppColors.magicGradient, const DogClickerScreen()),
                _buildFeatureCard(width, '寻宠救援', '希望您永远使用不到此功能', Icons.phonelink_ring_rounded, const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]), const LostPetRescuePage(), subtitleMaxLines: 2),
                _buildFeatureCard(width, 'AI 图像实验室', 'Image Lab', Icons.auto_fix_high_rounded, AppColors.natureGradient, const PreparationPage()),
              ],
                );
              },
            ),

            // 3. 底部占位演示 (表明可滑动)
            const SizedBox(height: 30), 
            Center(
              child: Text(
                "更多功能敬请期待...",
                style: TextStyle(
                  color: AppColors.textGrey.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20), // 额外留白
          ],
        ),
        // 搜索结果列表（覆盖在内容上方）
      if (_showSearchResults && _searchResults.isNotEmpty)
        Positioned(
          top: topPadding + 60 + 60, // 搜索框下方
          left: 20,
          right: 20,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    leading:
                        Icon(result.icon, color: const Color(0xFF5D5FEF)),
                    title: Text(result.name),
                    onTap: () => _navigateToResult(result),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建搜索框
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 8.0,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _performSearch,
        decoration: InputDecoration(
          hintText: '搜索功能...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF8E8E93)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF8E8E93)),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _performSearch('');
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // AI 大卡片 (修复布局)
  Widget _buildHeroAiCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => const ChatPageWithDatabase()));
      },
      child: Container(
        height: 176, // 高度给足
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: AppColors.warmGradient.colors.first.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F0).withOpacity(0.6),
                borderRadius: BorderRadius.circular(28),
                border:
                    Border.all(color: Colors.white.withOpacity(0.6), width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.7),
                    Colors.white.withOpacity(0.3),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ).blurred(sigmaX: 30, sigmaY: 30),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 顶部 AI VET 标签
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warmGradient.colors.first
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.warmGradient.colors.first
                                    .withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 12,
                                  color: AppColors.warmGradient.colors.first),
                              const SizedBox(width: 4),
                              Text("Peture AI",
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          AppColors.warmGradient.colors.first,
                                      letterSpacing: 0.5)),
                            ],
                          ),
                        ),

                        // 使用 SizedBox 代替 Spacer，防止文字被挤到最下面
                        const SizedBox(height: 22), 
                         
                        // 大标题
                        const Text("AI 智能问诊",
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                                letterSpacing: -0.8)),

                        const SizedBox(height: 6),

                        // 副标题
                        Container(
                          padding: const EdgeInsets.only(right: 60),
                          child: const Text(
                            "24小时在线，快速分析宠物症状\n提供专业医疗建议。",
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF636366),
                                height: 1.4,
                                fontWeight: FontWeight.w400),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 右下角悬浮按钮
                  Positioned(
                    right: 20,
                    bottom: 20,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.warmGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.warmGradient.colors.first
                                  .withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6)),
                          BoxShadow(
                              color: Colors.white.withOpacity(0.5),
                              blurRadius: 2,
                              offset: const Offset(0, 2),
                              spreadRadius: 0,
                              blurStyle: BlurStyle.inner),
                        ],
                      ),
                      child: const Icon(Icons.medical_services_rounded,
                          color: Colors.white, size: 24),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



  // --- 小卡片 ---
  Widget _buildFeatureCard(double width, String title, String subtitle,
      IconData icon, LinearGradient gradient, Widget page,
      {int subtitleMaxLines = 1}) {
    return Builder(builder: (context) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(CupertinoPageRoute(builder: (_) => page));
        },
        child: Container(
          width: width,
          height: width * 0.82,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.6), width: 1),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.8),
                      Colors.white.withOpacity(0.4),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: gradient.colors.first.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: gradient.colors.first, size: 20),
                    ),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textGrey,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3),
                            maxLines: subtitleMaxLines,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

}

// =========================================================

// =========================================================
// 4. 模式 B: 成长日志时间线
// =========================================================

class _HomeUniverseContent extends StatelessWidget {
  const _HomeUniverseContent({super.key});

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
             // 直接嵌入成长日志，并标记为 embedded
             const GrowthLogPage(isEmbedded: true),
        ],
      ),
    );
  }
}


// =========================================================
// 6. 光弥散背景组件
// =========================================================

class _AmbientBackground extends StatefulWidget {
  const _AmbientBackground();

  @override
  State<_AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<_AmbientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 使用正弦波生成平滑的位移
        final t = _controller.value;
        
        return Stack(
          children: [
            // 左上角 - 蓝青色光晕
            Positioned(
              top: -100 + 40 * math.sin(t * 2 * math.pi),
              left: -80 + 30 * math.cos(t * 2 * math.pi),
              child: _buildOrb(320, AppColors.orb1),
            ),
            
            // 右上方 - 紫色光晕
            Positioned(
              top: 80 + 50 * math.cos(t * 2 * math.pi),
              right: -100 + 40 * math.sin(t * 2 * math.pi),
              child: _buildOrb(300, AppColors.orb2),
            ),
            
            // 底部 - 暖橙色光晕
            Positioned(
              bottom: 100 + 60 * math.sin(t * math.pi),
              left: -50 + 20 * math.cos(t * math.pi),
              child: _buildOrb(350, AppColors.orb3),
            ),
            
            // 加入一个全屏的磨砂层，让光晕更加柔和漫射
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.transparent),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.45),
        shape: BoxShape.circle,
        // 使用非常大的 blur radius 模拟弥散光
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.45),
            blurRadius: 100,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}

