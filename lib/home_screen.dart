import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/physics.dart';
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
import 'pages/lost_pet/lost_pet_rescue_page.dart';
import 'community_screen.dart';
import 'medical_record_screen.dart';
import 'profile_screen.dart';
import 'pages/unified_expense/unified_expense_home_page.dart';
import 'pages/reminder/intelligent_reminder_page.dart';
import 'pages/growth_log/growth_log_page.dart';
import 'widgets/weight_trend_card.dart';
import 'utils/ui_helpers.dart';

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
  bool _isUniverseMode = false;

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
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      const MedicalRecordScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
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
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1),
                      ),
                      child: Icon(
                        _isUniverseMode ? Icons.grid_view_rounded : Icons.hub_rounded, 
                        color: AppColors.textDark, 
                        size: 22 
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 底部导航
          Positioned(
            left: 24, right: 24, 
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

    final LinearGradient currentGradient = AppColors.navGradients[_currentIndex];

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
        
        // [修改] 改为绝对位置跟随，实现"指哪打哪"的丝滑跟手感
        // details.localPosition.dx 是相对于 Container 左上角的 x 坐标
        // 我们希望指示器中心跟随手指，指示器中心在 index * itemWidth + itemWidth / 2
        // 所以 position = (x - itemWidth / 2) / itemWidth = x / itemWidth - 0.5
        
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
                  top: 0, left: 20, right: 20, height: 1,
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
                    mainAxisAlignment: MainAxisAlignment.start, // [修改] 确保严格对齐
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

class _HomeDashboardContent extends StatelessWidget {
  const _HomeDashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return ListView(
      // [关键点1] 强制开启滚动物理效果，即使内容少也能滑动
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      
      // [关键点2] 增加底部 Padding (130)，确保内容不被悬浮导航栏遮挡，且预留滑动空间
      padding: EdgeInsets.fromLTRB(20, topPadding + 60, 20, 130),
      children: [
        // 1. AI 智能问诊 (修复版：文字完整显示)
        _buildHeroAiCard(context),

        const SizedBox(height: 16),
        
        // 1.2 成长日志中枢
        _buildGrowthLogCard(context),

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
                _buildFeatureCard(width, '宠物消费', 'Expenses', Icons.account_balance_wallet_rounded, const LinearGradient(colors: [Color(0xFF6A85B6), Color(0xFFBAC8E0)]), const UnifiedExpenseHomePage()),
                _buildFeatureCard(width, '智能提醒', 'Reminder', Icons.notifications_active_rounded, const LinearGradient(colors: [Color(0xFFA18CD1), Color(0xFFFBC2EB)]), const IntelligentReminderPage()),
                _buildFeatureCard(width, '电子档案', 'Vaccine', Icons.badge_rounded, AppColors.coolGradient, const PetPassportPage()),
                _buildFeatureCard(width, '第一人称日记', 'Diary', Icons.menu_book_rounded, AppColors.natureGradient, const PetDiaryComposePage()),
                _buildFeatureCard(width, '活力健身', 'Fitness', Icons.directions_run_rounded, AppColors.oceanGradient, const PartnerFitGymPage()),
                _buildFeatureCard(width, '营养食谱', 'Food', Icons.restaurant_menu_rounded, AppColors.goldGradient, const PetRecipeListPage()),
                _buildFeatureCard(width, '训宠响片', 'Training', Icons.touch_app_rounded, AppColors.magicGradient, const DogClickerScreen()),
                _buildFeatureCard(width, '寻宠救援', '希望您永远使用不到此功能', Icons.phonelink_ring_rounded, const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]), const LostPetRescuePage(), subtitleMaxLines: 2),
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
    );
  }

  // AI 大卡片 (修复布局)
  Widget _buildHeroAiCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ChatPageWithDatabase()));
      },
      child: Container(
        height: 176, // 高度给足
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: AppColors.warmGradient.colors.first.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 10)),
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
                border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.7),
                    Colors.white.withOpacity(0.3),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30, top: -30,
                    child: Container(
                      width: 140, height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ).blurred(sigmaX: 30, sigmaY: 30),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 顶部 AI VET 标签
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warmGradient.colors.first.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.warmGradient.colors.first.withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, size: 12, color: AppColors.warmGradient.colors.first),
                              const SizedBox(width: 4),
                              Text("Peture AI", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warmGradient.colors.first, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                        
                        // 使用 SizedBox 代替 Spacer，防止文字被挤到最下面
                        const SizedBox(height: 24), 
                        
                        // 大标题
                        const Text("AI 智能问诊", 
                          style: TextStyle(
                            fontSize: 24, 
                            fontWeight: FontWeight.w800, 
                            color: AppColors.textDark, 
                            letterSpacing: -0.8 
                          )
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // 副标题
                        Container(
                          padding: const EdgeInsets.only(right: 60),
                          child: const Text(
                            "24小时在线，快速分析宠物症状\n提供专业医疗建议。",
                            style: TextStyle(
                              fontSize: 13, 
                              color: Color(0xFF636366), 
                              height: 1.5, 
                              fontWeight: FontWeight.w400
                            ), 
                            maxLines: 2, 
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 右下角悬浮按钮
                  Positioned(
                    right: 20, bottom: 20,
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.warmGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: AppColors.warmGradient.colors.first.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6)),
                          BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 2, offset: const Offset(0, 2), spreadRadius: 0, blurStyle: BlurStyle.inner),
                        ],
                      ),
                      child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 24),
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

  // 成长日志卡片
  Widget _buildGrowthLogCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const GrowthLogPage()));
      },
      child: Container(
        height: 100, 
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
           boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                // 仿照 WeightTrendCard 的风格，但用清新的绿色调
                color: Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.8),
                    const Color(0xFFE0F2F1).withOpacity(0.4), // Light Teal
                  ],
                ),
              ),
              child: Stack(
                  children: [
                    Positioned(
                      right: -10, bottom: -20,
                      child: Opacity(
                        opacity: 0.05,
                        child: Icon(Icons.timeline_rounded, size: 140, color: Colors.teal),
                      )
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0), // centered cleanly
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1), // Light Teal bg
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(color: Colors.teal.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: const Icon(Icons.history_edu_rounded, color: Colors.teal, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                "成长日志",
                                style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "记录每一个重要时刻",
                                style: TextStyle(
                                  fontSize: 13, color: AppColors.secondaryText
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              shape: BoxShape.circle
                            ),
                            child: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.teal),
                          ),
                        ],
                      ),
                    ),
                  ]
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 小卡片 ---
  Widget _buildFeatureCard(double width, String title, String subtitle, IconData icon, LinearGradient gradient, Widget page, {int subtitleMaxLines = 1}) {
    return Builder(
      builder: (context) {
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
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8)),
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
                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
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
                        width: 38, height: 38,
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
                            Text(title, 
                              style: const TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.w700, 
                                color: AppColors.textDark,
                                letterSpacing: -0.4 
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(subtitle, 
                              style: TextStyle(
                                fontSize: 11, 
                                color: AppColors.textGrey, 
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3 
                              ),
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
      }
    );
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
                SphereItemData(title: 'AI 问诊', icon: Icons.medical_services_rounded, gradient: AppColors.warmGradient, page: const ChatPageWithDatabase()),
                SphereItemData(title: '电子档案', icon: Icons.badge_rounded, gradient: AppColors.coolGradient, page: const PetPassportPage()),
                SphereItemData(title: '成长日记', icon: Icons.menu_book_rounded, gradient: AppColors.natureGradient, page: const PetDiaryComposePage()),
                SphereItemData(title: '活力健身', icon: Icons.directions_run_rounded, gradient: AppColors.oceanGradient, page: const PartnerFitGymPage()),
                SphereItemData(title: '营养食谱', icon: Icons.restaurant_menu_rounded, gradient: AppColors.goldGradient, page: const PetRecipeListPage()),
                SphereItemData(title: '训宠响片', icon: Icons.touch_app_rounded, gradient: AppColors.magicGradient, page: const DogClickerScreen()),
                SphereItemData(title: '寻宠救援', icon: Icons.phonelink_ring_rounded, gradient: const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]), page: const LostPetRescuePage()),
                SphereItemData(title: '社区话题', icon: Icons.explore_rounded, gradient: AppColors.warmGradient, page: const CommunityScreen()),
                SphereItemData(title: '商城', icon: Icons.shopping_bag_rounded, gradient: AppColors.coolGradient, page: const ProfileScreen()),
                SphereItemData(title: '设置', icon: Icons.settings_rounded, gradient: const LinearGradient(colors: [Color(0xFF606c88), Color(0xFF3f4c6b)]), page: const ProfileScreen()),
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

class _HolographicSphereMenuState extends State<HolographicSphereMenu> with TickerProviderStateMixin {
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
                Navigator.of(context).push(CupertinoPageRoute(builder: (_) => item.data.page));
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: iconSize, height: iconSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: item.data.gradient,
                      boxShadow: [
                        if (isFront)
                          BoxShadow(color: item.data.gradient.colors.first.withOpacity(0.5), blurRadius: 20, spreadRadius: 1),
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Icon(item.data.icon, color: Colors.white, size: 30), 
                  ),
                  const SizedBox(height: 6),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isFront ? 1.0 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.data.title,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark),
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

  SphereItemData({required this.title, required this.icon, required this.gradient, required this.page});
}

class _ProjectedItem {
  final double x;
  final double y;
  final double z;
  final SphereItemData data;
  _ProjectedItem({required this.x, required this.y, required this.z, required this.data});
}