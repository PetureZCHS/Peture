import 'dart:ui'; 
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; 
import 'package:flutter/services.dart'; 
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart'; 

// --- 你的页面引用 ---
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
// 1. 配色与样式
// =========================================================

class AppColors {
  static const Color background = Color(0xFFFDFCF8);
  static const Color textDark = Color(0xFF1A1A1A); 
  static const Color textGrey = Color(0xFF999999);
  
  static const LinearGradient warmGradient = LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]);
  static const LinearGradient coolGradient = LinearGradient(colors: [Color(0xFF1A2980), Color(0xFF26D0CE)]);
  static const LinearGradient natureGradient = LinearGradient(colors: [Color(0xFF11998e), Color(0xFF38ef7d)]);
  static const LinearGradient magicGradient = LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]);
  static const LinearGradient oceanGradient = LinearGradient(colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)]);
  static const LinearGradient goldGradient = LinearGradient(colors: [Color(0xFFF2994A), Color(0xFFF2C94C)]);
}

class AppStyles {
  static const TextStyle searchHint = TextStyle(
    fontSize: 16, color: Color(0xFFBDBDBD), fontWeight: FontWeight.w400,
  );
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

  @override
  void initState() {
    super.initState();
    // 极光呼吸效果
    _bgBreathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
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

  final List<Widget> _pages = [
    const _HomeUniverseContent(), 
    const CommunityScreen(),
    const MedicalRecordScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // --- 背景层 ---
          Stack(
            children: [
              Container(color: AppColors.background),
              AnimatedBuilder(
                animation: _bgBreathingController,
                builder: (context, child) {
                  double move = _bgBreathingController.value * 30;
                  double scale = 1.0 + (_bgBreathingController.value * 0.15);
                  return Stack(
                    children: [
                      Positioned(
                        top: -150 + move, right: -100 - move,
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 700, height: 700,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF8F00).withOpacity(0.15), 
                            ),
                          ).blurred(sigmaX: 90, sigmaY: 90),
                        ),
                      ),
                      Positioned(
                        bottom: -150 - move, left: -100 + move,
                        child: Transform.scale(
                          scale: scale * 1.1,
                          child: Container(
                            width: 800, height: 800,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF4527A0).withOpacity(0.12), 
                            ),
                          ).blurred(sigmaX: 100, sigmaY: 100),
                        ),
                      ),
                    ],
                  );
                },
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
                child: Container(color: Colors.white.withOpacity(0.1)),
              ),
            ],
          ),
          
          // --- 内容层 ---
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          
          // --- 底部导航 ---
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
          // 只有这一层液态玻璃，去除了底部的白色 Container，没有割裂感
          LiquidGlassLayer(
            settings: LiquidGlassSettings(
              thickness: 8.0, 
              blur: 15.0, 
              glassColor: Colors.white.withOpacity(0.4), 
              refractiveIndex: 1.2, 
              lightIntensity: 0.5, 
              lightAngle: 0.6
            ),
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 48, height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  LiquidGlass(shape: LiquidRoundedSuperellipse(borderRadius: 32), child: SizedBox(width: MediaQuery.of(context).size.width - 48, height: 64)),
                  Positioned(
                    left: (_currentPosition * ((MediaQuery.of(context).size.width - 48) / 4)) + (((MediaQuery.of(context).size.width - 48) / 4) / 2) - (72.0 / 2),
                    child: LiquidGlass(shape: LiquidRoundedSuperellipse(borderRadius: 24), child: Container(width: 72.0, height: 56.0, color: Colors.white.withOpacity(0.4))),
                  ),
                ],
              ),
            ),
          ),
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
            if (t > 0.5)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Opacity(
                  opacity: (t - 0.5) * 2,
                  child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                ),
              ),
          ],
        ),
      ),
    ); 
  }
}

// =========================================================
// 3. 沉浸式星球主页
// =========================================================

class _HomeUniverseContent extends StatefulWidget {
  const _HomeUniverseContent();

  @override
  State<_HomeUniverseContent> createState() => _HomeUniverseContentState();
}

class _HomeUniverseContentState extends State<_HomeUniverseContent> {
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
          // --- Layer 1: 中心的气泡云 ---
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

          // --- Layer 2: 固定搜索栏 ---
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: _buildFixedSearchBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedSearchBar() {
    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9), 
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D2626).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.search_rounded, color: AppColors.textDark, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: TextField(
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '搜索功能、症状...',
                hintStyle: AppStyles.searchHint,
                contentPadding: EdgeInsets.zero,
                isCollapsed: true,
              ),
            ),
          ),
          Container(
            width: 1, height: 20,
            color: Colors.grey.withOpacity(0.3),
          ),
          IconButton(
            icon: const Icon(Icons.mic_none_rounded, color: AppColors.textDark, size: 22),
            onPressed: (){},
          )
        ],
      ),
    );
  }
}

// =========================================================
// 4. 星球组件 (高速物理 + 震动触感)
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
  // 【物理恢复】：摩擦系数保持 0.96，保证顺滑
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
    // 【核心保留】：震动反馈，增加机械手感
    HapticFeedback.selectionClick();
  }

  void _onPanEnd(DragEndDetails details) {
    // 【物理恢复】：恢复高倍率 (0.0003)，让投掷感回来
    _velocityX = details.velocity.pixelsPerSecond.dx * 0.0003;
    _velocityY = -details.velocity.pixelsPerSecond.dy * 0.0003;
    
    // 【物理恢复】：移除严格的速度上限 (Clamp)，允许高速旋转
    
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
                  // 图标球体
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
                  
                  // 文字标签
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

// 数据类与辅助
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