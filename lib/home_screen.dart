import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

// --- 您的页面引用 ---
import 'chat_page.dart';
import 'pages/pet_diary/pet_diary_compose_page.dart';
import 'pages/pet_passport/pet_passport_page.dart';
import 'pages/pet_recipe/pet_recipe_list_page.dart';
import 'pages/partner_fit/partner_fit_gym_page.dart';
import 'pages/dog_clicker/dog_clicker_screen.dart';
import 'community_screen.dart';
import 'medical_record_screen.dart';
import 'profile_screen.dart';

// =========================================================
// 1. 配色与样式 (增加了一些更高级的低饱和度颜色)
// =========================================================

class AppColors {
  static const Color background = Color(0xFFF5F5F7); // iOS 风格浅灰底色
  static const Color textDark = Color(0xFF1D1D1F); // 更接近黑色的深灰
  static const Color textGrey = Color(0xFF86868B);

  // 更加柔和高级的渐变
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFFF5E62), Color(0xFFFF9966)],
  );
  static const LinearGradient coolGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
  );
  static const LinearGradient natureGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
  );
  static const LinearGradient magicGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
  );
  static const LinearGradient oceanGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF30CFD0), Color(0xFF330867)],
  );
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFF6D365), Color(0xFFFDA085)],
  );
  
  // 玻璃卡片背景色
  static Color glassWhite = Colors.white.withOpacity(0.85);
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
  late AnimationController _bgBreathingController;

  // 默认 false (实用模式)，true 为星球模式
  bool _isUniverseMode = false;

  @override
  void initState() {
    super.initState();
    _bgBreathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15), // 呼吸更慢，更高级
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgBreathingController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      _currentPosition = index.toDouble();
    });
    HapticFeedback.lightImpact();
  }

  void _toggleViewMode() {
    setState(() {
      _isUniverseMode = !_isUniverseMode;
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final Widget homePageContent = _isUniverseMode
        ? _HomeUniverseContent(onToggleMode: _toggleViewMode)
        : _HomeDashboardContent(onToggleMode: _toggleViewMode);

    final List<Widget> pages = [
      homePageContent,
      const CommunityScreen(),
      const MedicalRecordScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // --- 背景层 (微弱的极光) ---
          Stack(
            children: [
              Container(color: AppColors.background),
              AnimatedBuilder(
                animation: _bgBreathingController,
                builder: (context, child) {
                  double move = _bgBreathingController.value * 20;
                  return Stack(
                    children: [
                      // 顶部柔光
                      Positioned(
                        top: -100 + move, right: -50,
                        child: Container(
                          width: 400, height: 400,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFE2D9).withOpacity(0.4), 
                          ),
                        ).blurred(sigmaX: 80, sigmaY: 80),
                      ),
                      // 底部柔光
                      Positioned(
                        bottom: 100 - move, left: -50,
                        child: Container(
                          width: 300, height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE0EAFF).withOpacity(0.4), 
                          ),
                        ).blurred(sigmaX: 80, sigmaY: 80),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),

          // --- 内容层 ---
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),

          // --- 底部导航 (悬浮玻璃) ---
          Positioned(
            left: 24, right: 24, bottom: 34, height: 80,
            child: _buildFloatingGlassNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingGlassNavBar() {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final double itemWidth = (screenWidth - 48) / 4;
        setState(() {
          _currentPosition += details.delta.dx / itemWidth;
          _currentPosition = _currentPosition.clamp(0.0, 3.0);
        });
      },
      onHorizontalDragEnd: (details) {
        int targetIndex = _currentPosition.round();
        setState(() {
          _currentIndex = targetIndex;
          _currentPosition = targetIndex.toDouble();
        });
        HapticFeedback.selectionClick();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 纯净的磨砂玻璃背景
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: MediaQuery.of(context).size.width - 48, 
                height: 80,
                color: Colors.white.withOpacity(0.65),
              ),
            ),
          ),
          
          // 选中态指示器 (白色方块)
          Positioned(
            left: (_currentPosition * ((MediaQuery.of(context).size.width - 48) / 4)) + (((MediaQuery.of(context).size.width - 48) / 4) / 2) - (60.0 / 2),
            child: Container(
              width: 60.0, height: 48.0, 
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
            ),
          ),
          
          // 图标层
          SizedBox(
            width: MediaQuery.of(context).size.width - 48, height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, '首页'),
                _buildNavItem(1, Icons.explore_rounded, '社区'),
                _buildNavItem(2, Icons.assignment_rounded, '病历'),
                _buildNavItem(3, Icons.person_rounded, '我的'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final double distance = (_currentPosition - index).abs();
    final double t = (1.0 - distance).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        width: (MediaQuery.of(context).size.width - 48) / 4,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Color.lerp(AppColors.textGrey, AppColors.textDark, t), size: 24 + (4 * t)),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// 3. 模式 A: 实用仪表盘 (Bento Grid 现代风格)
// =========================================================

class _HomeDashboardContent extends StatelessWidget {
  final VoidCallback onToggleMode;

  const _HomeDashboardContent({required this.onToggleMode});

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 130),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. 顶部 Header (问候语 + 切换按钮)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("晚上好,", style: TextStyle(fontSize: 16, color: AppColors.textGrey)),
                Text("糯米", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              ],
            ),
            _buildViewToggleButton(),
          ],
        ),

        const SizedBox(height: 24),

        // 2. AI 智能问诊 (Bento Hero Card) - 修复了高度 Overflow
        _buildHeroAiCard(context),

        const SizedBox(height: 16),

        // 3. 常用功能标题
        // const Text("常用功能", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        // const SizedBox(height: 12),

        // 4. 功能网格 (Bento Grid)
        LayoutBuilder(
          builder: (context, constraints) {
            double width = (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildFeatureCard(width, '电子档案', 'Vaccine', Icons.badge_rounded, AppColors.coolGradient, const PetPassportPage()),
                _buildFeatureCard(width, '成长日记', 'Diary', Icons.menu_book_rounded, AppColors.natureGradient, const PetDiaryComposePage()),
                _buildFeatureCard(width, '活力健身', 'Fitness', Icons.directions_run_rounded, AppColors.oceanGradient, const PartnerFitGymPage()),
                _buildFeatureCard(width, '营养食谱', 'Food', Icons.restaurant_menu_rounded, AppColors.goldGradient, const PetRecipeListPage()),
                _buildFeatureCard(width, '训宠响片', 'Training', Icons.touch_app_rounded, AppColors.magicGradient, const DogClickerScreen()),
              ],
            );
          },
        ),
      ],
    );
  }

  // 顶部切换按钮 (磨砂质感)
  Widget _buildViewToggleButton() {
    return GestureDetector(
      onTap: onToggleMode,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.8), width: 1),
            ),
            child: const Icon(Icons.hub_rounded, color: AppColors.textDark, size: 24),
          ),
        ),
      ),
    );
  }

  // AI 核心大卡片 (修复高度问题，增加高级感)
  Widget _buildHeroAiCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ChatPageWithDatabase()));
      },
      child: Container(
        height: 190, // 【关键修复】高度增加到 190，防止溢出
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white, // 纯白底色
          borderRadius: BorderRadius.circular(32), // 更大的圆角 (现代感)
          boxShadow: [
            BoxShadow(color: AppColors.warmGradient.colors.first.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 10)),
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              // 背景装饰 (非常淡的渐变光)
              Positioned(
                right: -40, top: -40,
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [AppColors.warmGradient.colors.first.withOpacity(0.15), Colors.transparent]),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 图标容器
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.warmGradient.colors.first.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 16, color: AppColors.warmGradient.colors.first),
                              const SizedBox(width: 6),
                              Text("AI VET", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warmGradient.colors.first)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_outward_rounded, color: AppColors.textGrey, size: 20),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text("AI 智能问诊", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    // 使用 Flexible 防止文字溢出
                    const Flexible(
                      child: Text(
                        "24小时在线，快速分析宠物症状\n提供专业医疗建议。",
                        style: TextStyle(fontSize: 15, color: AppColors.textGrey, height: 1.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // 底部大按钮
              Positioned(
                right: 24, bottom: 24,
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.warmGradient,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.warmGradient.colors.first.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 28),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // 功能小方块 (更方正，更现代)
  Widget _buildFeatureCard(double width, String title, String subtitle, IconData icon, LinearGradient gradient, Widget page) {
    return Builder(
      builder: (context) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(CupertinoPageRoute(builder: (_) => page));
          },
          child: Container(
            width: width,
            height: width * 0.75, // 使其略微扁平或方正
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 图标
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: gradient.colors.first.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: gradient.colors.first, size: 20),
                ),
                // 文字
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textGrey.withOpacity(0.8), fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}

// =========================================================
// 4. 模式 B: 沉浸式星球主页 (Universe Mode)
// =========================================================

class _HomeUniverseContent extends StatelessWidget {
  final VoidCallback onToggleMode;

  const _HomeUniverseContent({required this.onToggleMode});

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
              radius: screenWidth * 0.40,
              items: [
                SphereItemData(title: 'AI 问诊', icon: Icons.medical_services_rounded, gradient: AppColors.warmGradient, page: const ChatPageWithDatabase()),
                SphereItemData(title: '电子档案', icon: Icons.badge_rounded, gradient: AppColors.coolGradient, page: const PetPassportPage()),
                SphereItemData(title: '成长日记', icon: Icons.menu_book_rounded, gradient: AppColors.natureGradient, page: const PetDiaryComposePage()),
                SphereItemData(title: '活力健身', icon: Icons.directions_run_rounded, gradient: AppColors.oceanGradient, page: const PartnerFitGymPage()),
                SphereItemData(title: '营养食谱', icon: Icons.restaurant_menu_rounded, gradient: AppColors.goldGradient, page: const PetRecipeListPage()),
                SphereItemData(title: '训宠响片', icon: Icons.touch_app_rounded, gradient: AppColors.magicGradient, page: const DogClickerScreen()),
                SphereItemData(title: '社区话题', icon: Icons.explore_rounded, gradient: AppColors.warmGradient, page: const CommunityScreen()),
                SphereItemData(title: '商城', icon: Icons.shopping_bag_rounded, gradient: AppColors.coolGradient, page: const ProfileScreen()),
                SphereItemData(title: '设置', icon: Icons.settings_rounded, gradient: const LinearGradient(colors: [Color(0xFF606c88), Color(0xFF3f4c6b)]), page: const ProfileScreen()),
              ],
            ),
          ),
          
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 24,
            child: GestureDetector(
              onTap: onToggleMode,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 48, height: 48,
                    color: Colors.white.withOpacity(0.4),
                    child: const Icon(Icons.grid_view_rounded, color: AppColors.textDark, size: 24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// 5. 星球组件逻辑 (保持不变)
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
                width: widget.radius * 2.5,
                height: widget.radius * 2.5,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. 星核
                    Container(
                      width: widget.radius * 1.2,
                      height: widget.radius * 1.2,
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
                    ).blurred(sigmaX: 60, sigmaY: 60),

                    // 2. 3D 节点
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

    final double centerOffset = widget.radius * 1.25;

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

      final double scale = 0.3 + (0.9 * zNorm * zNorm);
      final double opacity = 0.2 + (0.8 * zNorm);
      final bool isFront = item.z > 0.88;

      const double iconSize = 74.0;
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
                          BoxShadow(color: item.data.gradient.colors.first.withOpacity(0.6), blurRadius: 30, spreadRadius: 2),
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Icon(item.data.icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 8),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isFront ? 1.0 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
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

// 辅助类
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

extension WidgetBlur on Widget {
  Widget blurred({double sigmaX = 10.0, double sigmaY = 10.0}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
      child: this,
    );
  }
}