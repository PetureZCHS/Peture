import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../image_generation/presentation/preparation_page.dart'
    hide AppColors;
import '../../diary/presentation/pet_diary_compose_page.dart';
import '../../pet_passport/presentation/pet_passport_page.dart';
import '../../dog_clicker/presentation/dog_clicker_screen.dart';
import '../../expense/presentation/unified_expense_home_page.dart';
import '../../medical/presentation/medical_record_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../../shared/design_system/peture_design_system.dart';
import '../../../shared/utils/ui_helpers.dart';
import '../../../shared/utils/data_change_notifier.dart';

// =========================================================
// 主页面骨架（3 tab：首页 / 医疗 / 个人，去社区）
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

  /// 用于通知 MedicalRecordScreen 刷新数据的通知器
  final ValueNotifier<int> _medicalScreenRefreshNotifier =
      ValueNotifier<int>(0);

  /// 标记是否需要刷新健康记录页面
  bool _needsMedicalScreenRefresh = true;

  /// 3 tab 的渐变列表
  static final List<LinearGradient> _navGradients = [
    PetureGradients.brand,
    PetureGradients.mint,
    PetureGradients.tech,
  ];

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
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _medicalScreenRefreshNotifier.dispose();
    super.dispose();
  }

  void _animateToPage(int page, {double velocity = 0.0}) {
    final SpringDescription spring = SpringDescription(
      mass: 0.6,
      stiffness: 140.0,
      damping: 12.0,
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

    // 当切换到 MedicalRecordScreen (index 1) 时，检查是否需要刷新
    if (index == 1) {
      if (_needsMedicalScreenRefresh || DataChangeNotifier.checkAndReset()) {
        _medicalScreenRefreshNotifier.value++;
        _needsMedicalScreenRefresh = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const _HomeDashboardContent(key: ValueKey('dashboard')),
      MedicalRecordScreen(refreshNotifier: _medicalScreenRefreshNotifier),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,

      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: pages,
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
  // 底部导航栏（3 tab）
  // =========================================================

  Widget _buildFloatingGlassNavBar() {
    final double rawWidth = MediaQuery.of(context).size.width;
    final double safeWidth = (rawWidth - 48).clamp(0.0, double.infinity);
    if (safeWidth <= 0) {
      return const SizedBox.shrink();
    }

    final double totalWidth = safeWidth;
    final double itemWidth = totalWidth / 3;
    const double indicatorWidth = 56.0;
    const double indicatorHeight = 40.0;
    const double navHeight = 68.0;

    final LinearGradient currentGradient =
        _navGradients[_currentIndex];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final double width = MediaQuery.of(context).size.width - 48;
        final double itemWidth = width / 3;
        final int index =
            (details.localPosition.dx / itemWidth).floor().clamp(0, 2);
        _onTabTapped(index);
      },
      onHorizontalDragStart: (details) {
        _tabController.stop();
      },
      onHorizontalDragUpdate: (details) {
        final double width = MediaQuery.of(context).size.width - 48;
        final double itemWidth = width / 3;
        double newPosition = (details.localPosition.dx / itemWidth) - 0.5;

        setState(() {
          _currentPosition = newPosition.clamp(0.0, 2.0);
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
        final double dragItemWidth = (screenWidth - 48) / 3;

        final double velocity =
            details.velocity.pixelsPerSecond.dx / dragItemWidth;

        int targetIndex = _currentPosition.round();

        if (velocity.abs() > 0.3) {
          if (velocity > 0) {
            targetIndex = _currentPosition.floor() + 1;
          } else {
            targetIndex = _currentPosition.ceil() - 1;
          }
        }

        targetIndex = targetIndex.clamp(0, 2);

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
                  left: (_currentPosition * itemWidth) +
                      (itemWidth / 2) -
                      (indicatorWidth / 2),
                  child: Builder(builder: (context) {
                    double velocity = 0.0;
                    if (_tabController.isAnimating) {
                      velocity = _tabController.velocity;
                    }

                    double absVelocity = velocity.abs();
                    double stretchFactor = (absVelocity * 0.08).clamp(0.0, 0.6);
                    double currentWidth = indicatorWidth * (1 + stretchFactor);
                    double currentHeight =
                        indicatorHeight * (1 - stretchFactor * 0.35);

                    return Container(
                      width: currentWidth,
                      height: currentHeight,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(currentHeight / 2),
                        gradient: currentGradient,
                        boxShadow: [
                          BoxShadow(
                            color: currentGradient.colors.first.withOpacity(
                                0.4 + (stretchFactor * 0.2)),
                            blurRadius: 12 + (stretchFactor * 10),
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
                    );
                  }),
                ),
                SizedBox(
                  width: totalWidth,
                  height: navHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, Icons.home_rounded, Icons.home_outlined),
                      _buildNavItem(
                          1, Icons.assignment_rounded, Icons.assignment_outlined),
                      _buildNavItem(2, Icons.person_rounded,
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

    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 3,
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
// 仪表盘内容
// =========================================================

class _HomeDashboardContent extends StatefulWidget {
  const _HomeDashboardContent({super.key});

  @override
  State<_HomeDashboardContent> createState() => _HomeDashboardContentState();
}

class _HomeDashboardContentState extends State<_HomeDashboardContent> {
  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    const double featureSpacing = 12;

    return Stack(
      children: [
        const _AmbientBackground(),

        ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: EdgeInsets.fromLTRB(20, topPadding + 60, 20, 130),
          children: [
            const PetureSectionHeader(
              title: '今天也好好照顾它',
              subtitle: '把常用工具放在顺手的位置。',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: PetureGradients.warmSurface,
                border: Border.all(
                  color: Colors.white.withOpacity(0.9),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: PetureColors.primary.withOpacity(0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: PetureColors.primary.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.pets_rounded,
                      size: 22,
                      color: PetureColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '欢迎回来，继续陪它好好长大',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: PetureColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '消费、档案、日记、训练与创作，都在这里。',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: PetureColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = (constraints.maxWidth - featureSpacing) / 2;
                return Wrap(
                  spacing: featureSpacing,
                  runSpacing: featureSpacing,
                  children: [
                    SizedBox(
                      width: width,
                      child: PetureFeatureTile(
                        title: '宠物消费',
                        subtitle: 'Expenses',
                        icon: Icons.account_balance_wallet_rounded,
                        accentColor: PetureColors.blue,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const UnifiedExpenseHomePage(),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: PetureFeatureTile(
                        title: '电子档案',
                        subtitle: 'Vaccine',
                        icon: Icons.badge_rounded,
                        accentColor: PetureColors.mint,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const PetPassportPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: PetureFeatureTile(
                        title: '第一人称日记',
                        subtitle: 'Diary',
                        icon: Icons.menu_book_rounded,
                        accentColor: PetureColors.amber,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const PetDiaryComposePage(),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: PetureFeatureTile(
                        title: '训宠响片',
                        subtitle: 'Training',
                        icon: Icons.touch_app_rounded,
                        accentColor: PetureColors.violet,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const DogClickerScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: PetureFeatureTile(
                        title: 'AI 图像实验室',
                        subtitle: 'Image Lab',
                        icon: Icons.auto_fix_high_rounded,
                        accentColor: PetureColors.primary,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const PreparationPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),
            Center(
              child: Text(
                '更多能力正在打磨中',
                style: TextStyle(
                  color: AppColors.textGrey.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),

      ],
    );
  }
}

// =========================================================
// 时间线模式
// =========================================================
// 光弥散背景组件
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
        final t = _controller.value;

        return Stack(
          children: [
            Positioned(
              top: -100 + 40 * math.sin(t * 2 * math.pi),
              left: -80 + 30 * math.cos(t * 2 * math.pi),
              child: _buildOrb(320, AppColors.orb1),
            ),
            Positioned(
              top: 80 + 50 * math.cos(t * 2 * math.pi),
              right: -100 + 40 * math.sin(t * 2 * math.pi),
              child: _buildOrb(300, AppColors.orb2),
            ),
            Positioned(
              bottom: 100 + 60 * math.sin(t * math.pi),
              left: -50 + 20 * math.cos(t * math.pi),
              child: _buildOrb(350, AppColors.orb3),
            ),
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
