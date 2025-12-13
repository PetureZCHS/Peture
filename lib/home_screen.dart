import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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
import 'pages/lost_pet/lost_pet_rescue_page.dart';
import 'community_screen.dart';
import 'medical_record_screen.dart';
import 'profile_screen.dart';
import 'widgets/weight_trend_card.dart';
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
// 1. 配色与样式
// =========================================================

class AppColors {
  static const Color background = Color(0xFFF2F2F7);
  static const Color textDark = Color(0xFF1D1D1F);
  static const Color textGrey = Color(0xFF8E8E93);

  static const Color orb1 = Color(0xFFC4E0E5);
  static const Color orb2 = Color(0xFFE2D1F9);
  static const Color orb3 = Color(0xFFFFDFC4);

  static const LinearGradient navTab0 =
      LinearGradient(colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)]);
  static const LinearGradient navTab1 =
      LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]);
  static const LinearGradient navTab2 =
      LinearGradient(colors: [Color(0xFF00b09b), Color(0xFF96c93d)]);
  static const LinearGradient navTab3 =
      LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]);

  static const List<LinearGradient> navGradients = [
    navTab0,
    navTab1,
    navTab2,
    navTab3
  ];

  static const LinearGradient warmGradient =
      LinearGradient(colors: [Color(0xFFFF5E62), Color(0xFFFF9966)]);
  static const LinearGradient coolGradient =
      LinearGradient(colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)]);
  static const LinearGradient natureGradient =
      LinearGradient(colors: [Color(0xFF43E97B), Color(0xFF38F9D7)]);
  static const LinearGradient magicGradient =
      LinearGradient(colors: [Color(0xFFA18CD1), Color(0xFFFBC2EB)]);
  static const LinearGradient oceanGradient =
      LinearGradient(colors: [Color(0xFF30CFD0), Color(0xFF330867)]);
  static const LinearGradient goldGradient =
      LinearGradient(colors: [Color(0xFFF6D365), Color(0xFFFDA085)]);
}

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

  late AnimationController _orbController;
  bool _isUniverseMode = false;

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

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbController.dispose();
    _medicalScreenRefreshNotifier.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      _currentPosition = index.toDouble();
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
    }
  }

  void _toggleViewMode() {
    setState(() {
      _isUniverseMode = !_isUniverseMode;
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
      child: _isUniverseMode
          ? const _HomeUniverseContent(key: ValueKey('universe'))
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
          // 背景层
          Stack(
            children: [
              Container(color: AppColors.background),
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  return Positioned(
                    top: -100 + (_orbController.value * 40),
                    left: -50 + (_orbController.value * 20),
                    child: Container(
                      width: 500,
                      height: 500,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.orb1.withOpacity(0.5),
                      ),
                    ).blurred(sigmaX: 90, sigmaY: 90),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  return Positioned(
                    top: 300 + (math.sin(_orbController.value * math.pi) * 60),
                    right: -100,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.orb3.withOpacity(0.4),
                      ),
                    ).blurred(sigmaX: 80, sigmaY: 80),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  return Positioned(
                    bottom: -150,
                    left: -80 + (_orbController.value * 150),
                    child: Container(
                      width: 600,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.orb2.withOpacity(0.5),
                      ),
                    ).blurred(sigmaX: 100, sigmaY: 100),
                  );
                },
              ),
            ],
          ),

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
                          _isUniverseMode
                              ? Icons.grid_view_rounded
                              : Icons.hub_rounded,
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
    final double totalWidth = MediaQuery.of(context).size.width - 48;
    final double itemWidth = totalWidth / 4;
    const double indicatorWidth = 56.0;
    const double indicatorHeight = 40.0;
    const double navHeight = 68.0;

    final LinearGradient currentGradient =
        AppColors.navGradients[_currentIndex];

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final double dragItemWidth = (screenWidth - 48) / 4;
        setState(() {
          _currentPosition += details.delta.dx / dragItemWidth;
          _currentPosition = _currentPosition.clamp(0.0, 3.0);
        });
        int potentialIndex = _currentPosition.round();
        if (potentialIndex != _lastHapticIndex) {
          HapticFeedback.selectionClick();
          _lastHapticIndex = potentialIndex;
        }
      },
      onHorizontalDragEnd: (details) {
        int targetIndex = _currentPosition.round();
        setState(() {
          _currentIndex = targetIndex;
          _currentPosition = targetIndex.toDouble();
          _lastHapticIndex = targetIndex;
        });
        HapticFeedback.lightImpact();
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
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  left: (_currentPosition * itemWidth) +
                      (itemWidth / 2) -
                      (indicatorWidth / 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: indicatorWidth,
                    height: indicatorHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(indicatorHeight / 2),
                      gradient: currentGradient,
                      boxShadow: [
                        BoxShadow(
                          color: currentGradient.colors.first.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: -2,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 1,
                            offset: const Offset(0, 1),
                            spreadRadius: 0,
                            blurStyle: BlurStyle.inner),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: totalWidth,
                  height: navHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, Icons.home_rounded, Icons.home_outlined),
                      _buildNavItem(
                          1, Icons.explore_rounded, Icons.explore_outlined),
                      _buildNavItem(2, Icons.assignment_rounded,
                          Icons.assignment_outlined),
                      _buildNavItem(3, Icons.person_rounded,
                          Icons.person_outline_rounded),
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

  Widget _buildNavItem(
      int index, IconData selectedIcon, IconData unselectedIcon) {
    final double distance = (_currentPosition - index).abs();
    final double t = (1.0 - distance).clamp(0.0, 1.0);
    double scale = 1.0 + (0.1 * t);

    Color iconColor;
    if (t > 0.6) {
      iconColor = Colors.white;
    } else {
      iconColor = Color.lerp(AppColors.textGrey, AppColors.textDark, t)!;
    }

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        width: (MediaQuery.of(context).size.width - 48) / 4,
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
        ListView(
          // [关键点1] 强制开启滚动物理效果，即使内容少也能滑动
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),

          // [关键点2] 增加底部 Padding (130)，确保内容不被悬浮导航栏遮挡，且预留滑动空间
          padding: EdgeInsets.fromLTRB(20, topPadding + 60, 20, 130),
          children: [
            // 0. 搜索框
            _buildSearchBar(),
            const SizedBox(height: 16),

            // 1. AI 智能问诊 (修复版：文字完整显示)
            _buildHeroAiCard(context),

            const SizedBox(height: 16),

            // 1.5 体重趋势卡片
            const WeightTrendCard(),

            const SizedBox(height: 16),

            // 2. 功能网格
            LayoutBuilder(
              builder: (context, constraints) {
                double width = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildFeatureCard(
                        width,
                        '电子档案',
                        'Vaccine',
                        Icons.badge_rounded,
                        AppColors.coolGradient,
                        const PetPassportPage()),
                    _buildFeatureCard(
                        width,
                        '成长日记',
                        'Diary',
                        Icons.menu_book_rounded,
                        AppColors.natureGradient,
                        const PetDiaryComposePage()),
                    _buildFeatureCard(
                        width,
                        '活力健身',
                        'Fitness',
                        Icons.directions_run_rounded,
                        AppColors.oceanGradient,
                        const PartnerFitGymPage()),
                    _buildFeatureCard(
                        width,
                        '营养食谱',
                        'Food',
                        Icons.restaurant_menu_rounded,
                        AppColors.goldGradient,
                        const PetRecipeListPage()),
                    _buildFeatureCard(
                        width,
                        '训宠响片',
                        'Training',
                        Icons.touch_app_rounded,
                        AppColors.magicGradient,
                        const DogClickerScreen()),
                    _buildFeatureCard(
                        width,
                        '宠物商城',
                        'Shop',
                        Icons.shopping_bag_rounded,
                        AppColors.coolGradient,
                        const PetShopPage()),
                    _buildFeatureCard(
                        width,
                        '寻宠救援',
                        '希望您永远使用不到此功能',
                        Icons.phonelink_ring_rounded,
                        const LinearGradient(
                            colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]),
                        const LostPetRescuePage(),
                        subtitleMaxLines: 2),
                    _buildFeatureCard(
                        width,
                        '寻宠互助',
                        'Emergency',
                        Icons.campaign_rounded,
                        AppColors.navTab1,
                        const CommunityScreen()),
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
                        const SizedBox(height: 20),

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
                                letterSpacing: -0.4),
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
// 4. 模式 B: 沉浸式星球主页
// =========================================================

class _HomeUniverseContent extends StatelessWidget {
  const _HomeUniverseContent({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Center(
            child: HolographicSphereMenu(
              radius: screenWidth * 0.38,
              items: [
                SphereItemData(
                    title: 'AI 问诊',
                    icon: Icons.medical_services_rounded,
                    gradient: AppColors.warmGradient,
                    page: const ChatPageWithDatabase()),
                SphereItemData(
                    title: '电子档案',
                    icon: Icons.badge_rounded,
                    gradient: AppColors.coolGradient,
                    page: const PetPassportPage()),
                SphereItemData(
                    title: '成长日记',
                    icon: Icons.menu_book_rounded,
                    gradient: AppColors.natureGradient,
                    page: const PetDiaryComposePage()),
                SphereItemData(
                    title: '活力健身',
                    icon: Icons.directions_run_rounded,
                    gradient: AppColors.oceanGradient,
                    page: const PartnerFitGymPage()),
                SphereItemData(
                    title: '营养食谱',
                    icon: Icons.restaurant_menu_rounded,
                    gradient: AppColors.goldGradient,
                    page: const PetRecipeListPage()),
                SphereItemData(
                    title: '训宠响片',
                    icon: Icons.touch_app_rounded,
                    gradient: AppColors.magicGradient,
                    page: const DogClickerScreen()),
                SphereItemData(
                    title: '寻宠救援',
                    icon: Icons.phonelink_ring_rounded,
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]),
                    page: const LostPetRescuePage()),
                SphereItemData(
                    title: '社区话题',
                    icon: Icons.explore_rounded,
                    gradient: AppColors.warmGradient,
                    page: const CommunityScreen()),
                SphereItemData(
                    title: '商城',
                    icon: Icons.shopping_bag_rounded,
                    gradient: AppColors.coolGradient,
                    page: const PetShopPage()),
                SphereItemData(
                    title: '设置',
                    icon: Icons.settings_rounded,
                    gradient: const LinearGradient(
                        colors: [Color(0xFF606c88), Color(0xFF3f4c6b)]),
                    page: const ProfileScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// 5. 星球组件逻辑
// =========================================================

class HolographicSphereMenu extends StatefulWidget {
  final List<SphereItemData> items;
  final double radius;

  const HolographicSphereMenu({
    super.key,
    required this.items,
    this.radius = 160.0,
  });

  @override
  State<HolographicSphereMenu> createState() => _HolographicSphereMenuState();
}

class _HolographicSphereMenuState extends State<HolographicSphereMenu>
    with TickerProviderStateMixin {
  double _angleX = 0.0;
  double _angleY = 0.0;

  late AnimationController _breathingController;
  late AnimationController _inertiaController;
  double _velocityX = 0.0;
  double _velocityY = 0.0;
  final double _autoRotateSpeed = 0.0002;

  final double _touchSensitivity = 0.006;
  final double _friction = 0.96;

  @override
  void initState() {
    super.initState();
    _angleY = 0.2;

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _inertiaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_physicsLoop);

    _inertiaController.repeat();
  }

  void _physicsLoop() {
    if (!mounted) return;
    setState(() {
      _velocityX *= _friction;
      _velocityY *= _friction;

      _angleY -= _velocityX;
      _angleX += _velocityY;

      if (_velocityX.abs() < 0.0001 && _velocityY.abs() < 0.0001) {
        _angleY -= _autoRotateSpeed;
      }
    });
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _inertiaController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _inertiaController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _angleY -= details.delta.dx * _touchSensitivity;
      _angleX += details.delta.dy * _touchSensitivity;
    });
    HapticFeedback.selectionClick();
  }

  void _onPanEnd(DragEndDetails details) {
    _velocityX = details.velocity.pixelsPerSecond.dx * 0.0003;
    _velocityY = -details.velocity.pixelsPerSecond.dy * 0.0003;
    _inertiaController.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedBuilder(
          animation: _breathingController,
          builder: (context, child) {
            double breathScale = 1.0 + (_breathingController.value * 0.05);
            return Transform.scale(
              scale: breathScale,
              child: SizedBox(
                width: widget.radius * 2.8,
                height: widget.radius * 2.8,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: widget.radius * 1.0,
                      height: widget.radius * 1.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.5),
                            const Color(0xFFE0F7FA).withOpacity(0.15),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ).blurred(sigmaX: 50, sigmaY: 50),
                    ..._build3DItems(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _build3DItems() {
    final List<_ProjectedItem> projected = [];
    final int count = widget.items.length;
    final double phi = math.pi * (3.0 - math.sqrt(5.0));

    final double centerOffset = widget.radius * 1.4;

    for (int i = 0; i < count; i++) {
      final double y = 1 - (i / (count - 1)) * 2;
      final double radiusAtY = math.sqrt(1 - y * y);
      final double theta = phi * i;

      final double x = math.cos(theta) * radiusAtY;
      final double z = math.sin(theta) * radiusAtY;

      double y1 = y * math.cos(_angleX) - z * math.sin(_angleX);
      double z1 = y * math.sin(_angleX) + z * math.cos(_angleX);
      double x2 = x * math.cos(_angleY) - z1 * math.sin(_angleY);
      double z2 = x * math.sin(_angleY) + z1 * math.cos(_angleY);

      if (z2 < -0.3) continue;

      projected.add(_ProjectedItem(
        x: x2 * widget.radius,
        y: y1 * widget.radius,
        z: z2,
        data: widget.items[i],
      ));
    }

    projected.sort((a, b) => a.z.compareTo(b.z));

    return projected.map((item) {
      final double zNorm = (item.z + 1) / 2;
      final double scale = 0.4 + (0.6 * zNorm * zNorm);
      final double opacity = 0.2 + (0.8 * zNorm);
      final bool isFront = item.z > 0.88;

      const double iconSize = 72.0;
      const double halfIconSize = iconSize / 2;

      return Positioned(
        left: centerOffset + item.x - halfIconSize,
        top: centerOffset + item.y - halfIconSize,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context)
                    .push(CupertinoPageRoute(builder: (_) => item.data.page));
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: item.data.gradient,
                      boxShadow: [
                        if (isFront)
                          BoxShadow(
                              color: item.data.gradient.colors.first
                                  .withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 1),
                        BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Icon(item.data.icon, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 6),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isFront ? 1.0 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.data.title,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

class SphereItemData {
  final String title;
  final IconData icon;
  final LinearGradient gradient;
  final Widget page;

  SphereItemData(
      {required this.title,
      required this.icon,
      required this.gradient,
      required this.page});
}

class _ProjectedItem {
  final double x;
  final double y;
  final double z;
  final SphereItemData data;
  _ProjectedItem(
      {required this.x, required this.y, required this.z, required this.data});
}
