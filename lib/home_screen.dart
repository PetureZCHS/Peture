import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

// 导入聊天页面（使用 chat_page.dart 中的版本）
import 'chat_page.dart';
// 导入登录页面
import 'login_page.dart';
// 导入设置页面
import 'settings_page.dart';
import 'pages/pet_diary/pet_diary_compose_page.dart';
import 'pages/pet_passport/pet_passport_page.dart';
import 'pages/pet_recipe/pet_recipe_list_page.dart';
import 'pages/partner_fit/partner_fit_gym_page.dart';
import 'pages/dog_clicker/dog_clicker_screen.dart';

// =========================================================
// 1. 颜色与样式常量（抽离出来，便于管理）
// =========================================================

class AppColors {
  static const Color background = Color(0xFFF8F8F8); // 柔和的背景色
  static const Color primaryBlue = Color(0xFF5A8EFA);
  static const Color primaryPurple = Color(0xFF8B77FF);
  static const Color darkText = Color(0xFF1E1E1E);
  static const Color mediumText = Color(0xFF424242);
  static const Color lightGrey = Color(0xFFF0F2F5);
}

class AppStrings {
  static const String appTitle = '萌星球';
  static const String primaryCardTitle = 'AI 智能问诊';
  static const String primaryCardSubtitle = '24小时在线极速诊断病症';
  static const String petToolsSectionTitle = '宠物工具';
  static const String imageRecognitionSectionTitle = '一图识别';
  static const String functionNotAvailableToast = '功能未开放：\$title，敬请期待！';
  static const String userCenterTitle = '用户中心';
  static const String accountSettingsTitle = '账户设置';
  static const String logoutTitle = '退出登录';
}

class AppStyles {
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: AppColors.darkText,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.darkText,
  );
  static const TextStyle cardTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 16,
    color: Colors.white70,
  );
  static const TextStyle gridItemTitle = TextStyle(
    fontSize: 12,
    color: AppColors.mediumText,
    fontWeight: FontWeight.w500,
  );
}

// =========================================================
// 2. 主页面
// =========================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        title: const SizedBox.shrink(), // 不显示标题
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: AppColors.mediumText),
            onPressed: () {
              _showUserProfileBottomSheet(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 核心功能卡片
              _PrimaryCard(
                title: AppStrings.primaryCardTitle,
                subtitle: AppStrings.primaryCardSubtitle,
                icon: Icons.lightbulb_outline,
                onTap: () {
                  Navigator.of(context).push(
                    // 使用 CupertinoPageRoute 替代 MaterialPageRoute
                    CupertinoPageRoute(
                      builder: (context) => const ChatPageWithDatabase(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              _buildSectionTitle(AppStrings.petToolsSectionTitle),
              const SizedBox(height: 16),
              _buildGrid(context, [
                // 2x4（共8项），将"疾病咨询"替换为"宠物日记"
                _GridItem(title: '品种识别', icon: Icons.camera_alt_outlined),
                _GridItem(
                  title: '训宠响片',
                  icon: Icons.notifications_active,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DogClickerScreen(),
                      ),
                    );
                  },
                ),
                _GridItem(
                  title: '宠物日记',
                  icon: Icons.menu_book_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PetDiaryComposePage(),
                      ),
                    );
                  },
                ),
                _GridItem(
                  title: '活力伙伴',
                  icon: Icons.fitness_center,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PartnerFitGymPage(),
                      ),
                    );
                  },
                ),
                _GridItem(
                  title: '宠物身份证',
                  icon: Icons.card_membership,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PetPassportPage(),
                      ),
                    );
                  },
                ),
                _GridItem(title: '疫苗指导', icon: Icons.vaccines),
                _GridItem(
                  title: '宠物食谱',
                  icon: Icons.restaurant,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PetRecipeListPage(),
                      ),
                    );
                  },
                ),
                _GridItem(title: '皮肤检查', icon: Icons.spa),
              ]),
              const SizedBox(height: 32),
              _buildSectionTitle(AppStrings.imageRecognitionSectionTitle),
              const SizedBox(height: 16),
              _buildGrid(context, [
                _GridItem(title: '口腔评估', icon: Icons.monitor_heart),
                _GridItem(title: '耳道检查', icon: Icons.hearing),
                _GridItem(title: '眼睛检查', icon: Icons.visibility),
                _GridItem(title: '呕吐物检查', icon: Icons.sick),
                _GridItem(title: '排泄物检查', icon: Icons.eco),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppStyles.sectionTitle);
  }

  Widget _buildGrid(
    BuildContext context,
    List<Widget> children, {
    int crossAxisCount = 4,
  }) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 24, // 增加垂直间距，让UI更宽松
      childAspectRatio: 0.8,
      children: children,
    );
  }
}

// =========================================================
// 3. 可复用的UI组件（独立组件化）
// =========================================================

// 主卡片组件，增加了按压动效
class _PrimaryCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_PrimaryCard> createState() => _PrimaryCardState();
}

class _PrimaryCardState extends State<_PrimaryCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryBlue, AppColors.primaryPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, size: 48, color: Colors.white),
              const SizedBox(height: 16),
              Text(widget.title, style: AppStyles.cardTitle),
              const SizedBox(height: 4),
              Text(widget.subtitle, style: AppStyles.cardSubtitle),
            ],
          ),
        ),
      ),
    );
  }
}

// 网格项组件，增加了点击反馈
class _GridItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  const _GridItem({required this.title, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:
          onTap ??
          () => _showCustomToast(
            context,
            AppStrings.functionNotAvailableToast.replaceAll('\$title', title),
          ),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 32, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppStyles.gridItemTitle,
          ),
        ],
      ),
    );
  }
}

// =========================================================
// 4. 用户交互反馈（更精致的提示）
// =========================================================

// 更具设计感的自定义Toast
void _showCustomToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: MediaQuery.of(context).size.height * 0.1,
      left: 20,
      right: 20,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: ModalRoute.of(context)!.animation!,
            curve: Curves.easeOut,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);

  Future.delayed(const Duration(seconds: 2), () {
    overlayEntry.remove();
  });
}

// 用户中心底部弹窗
void _showUserProfileBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.userCenterTitle,
              style: AppStyles.sectionTitle,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.settings, color: AppColors.mediumText),
              title: const Text(AppStrings.accountSettingsTitle),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(AppStrings.logoutTitle),
              onTap: () {
                // 关闭底部弹窗
                Navigator.pop(context);
                // 清空所有页面堆栈并跳转到登录页面
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false, // 清空所有页面
                );
              },
            ),
          ],
        ),
      );
    },
  );
}
