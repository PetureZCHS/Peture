// lib/profile_screen_upgraded.dart

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'services/supabase_service.dart';
import 'models/pet.dart';
import 'settings_page.dart';
import 'pages/unified_expense/unified_expense_home_page.dart';
import 'pages/reminder/intelligent_reminder_page.dart';
import 'pages/pet_profile_form_page.dart';

// =========================================================
// 全局设计系统 - 美学升级版
// =========================================================
class AppColors {
  static const Color background = Color(0xFFF5F5F7);
  static const Color primary = Color(0xFF5D5FEF);
  // 🎨 与首页AI智能问诊相同的渐变色
  static const Color primaryGradientStart = Color(0xFF5A8EFA); // primaryBlue
  static const Color primaryGradientEnd = Color(0xFF8B77FF); // primaryPurple
  static const Color primaryText = Color(0xFF1A1A1A);
  static const Color secondaryText = Color(0xFF8E8E93);
  static const Color cardBackground = Colors.white;

  // 宠物类型主题色映射
  static final Map<String, Color> petTypeColors = {
    '狗': Colors.orange[100]!,
    '猫': Colors.cyan[100]!,
    '兔': Colors.green[100]!,
    '仓鼠': Colors.pink[100]!,
    '其他': Colors.grey[100]!,
  };
}

class AppStyles {
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
  );
  static const TextStyle petName = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryText,
  );
  static const TextStyle petDetails = TextStyle(
    fontSize: 15,
    color: AppColors.secondaryText,
  );
  static const TextStyle ownerId = TextStyle(
    fontSize: 13,
    color: AppColors.secondaryText,
  );
  static const TextStyle listItemTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: AppColors.primaryText,
  );
}

class AppSpaces {
  static const double horizontalPadding = 20.0;
  static const double sectionSpacing = 24.0;
}

// =========================================================
// 主个人主页屏幕
// =========================================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🎨 美学升级：径向渐变背景，营造深度与呼吸感
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.8,
            colors: [Colors.white, Color(0xFFF5F5F7)],
            stops: [0.0, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpaces.horizontalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                _buildHeader(context),
                const SizedBox(height: AppSpaces.sectionSpacing),
                _buildMedicalRecordsSection(context),
                const SizedBox(height: AppSpaces.sectionSpacing),
                const PetProfileSection(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // TODO: 从用户数据库或SharedPreferences中获取用户昵称
    final String userNickname = ''; // 暂时为空，需要接入数据库
    final String displayName = userNickname.isEmpty ? '点击设置昵称' : userNickname;
    final String avatarText = userNickname.isEmpty ? '?' : userNickname[0];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () {
            // TODO: 跳转到设置昵称页面
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('昵称设置功能开发中...')));
          },
          child: Row(
            children: [
              // 🎨 美学升级：动态化用户头像，个性化设计
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    avatarText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: AppStyles.ownerId.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: userNickname.isEmpty
                          ? AppColors.secondaryText.withOpacity(0.6)
                          : AppColors.primaryText,
                    ),
                  ),
                  if (userNickname.isEmpty)
                    Text(
                      '轻触设置',
                      style: AppStyles.ownerId.copyWith(
                        fontSize: 11,
                        color: AppColors.secondaryText.withOpacity(0.5),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: AppColors.secondaryText),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMedicalRecordsSection(BuildContext context) {
    return _CustomSection(
      title: '问诊/分析记录',
      children: [
        _buildActionItem(
          icon: Icons.account_balance_wallet,
          label: '宠物消费',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UnifiedExpenseHomePage(),
              ),
            );
          },
        ),
        _buildActionItem(
          icon: Icons.notifications_active,
          label: '智能提醒',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const IntelligentReminderPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        // 🎨 美学升级：自定义水波纹颜色和高亮颜色
        splashColor: Colors.white.withOpacity(0.3), // 水波纹颜色 - 白色半透明
        highlightColor: Colors.white.withOpacity(0.15), // 按压时的高亮颜色
        // 🎨 水波纹扩散半径
        radius: 80, // 增大扩散半径，让水波纹更明显
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                // 🎨 美学升级：图标尺寸增大20%，颜色改为白色
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 33.6,
                ), // 28 * 1.2 = 33.6
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🎨 美学升级：文字颜色改为白色，字重增强
                  Text(
                    label,
                    style: AppStyles.listItemTitle.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.white70,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CustomSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppStyles.sectionTitle),
        const SizedBox(height: 16),
        // 🎨 美学升级：品牌主色渐变背景 + 多层阴影 + 光泽效果
        Container(
          decoration: BoxDecoration(
            // 品牌主色线性渐变
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryGradientStart,
                AppColors.primaryGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            // 多层阴影效果
            boxShadow: [
              // 第一层：接触阴影
              BoxShadow(
                offset: const Offset(0, 2),
                blurRadius: 4.0,
                color: Colors.black.withOpacity(0.04),
              ),
              // 第二层：弥散光晕
              BoxShadow(
                offset: const Offset(0, 12),
                blurRadius: 24.0,
                color: Colors.black.withOpacity(0.06),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 光泽效果层 - 调整为更柔和的效果
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.3),
                      radius: 0.8,
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // 内容层
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =========================================================
// 宠物档案部分
// =========================================================
class PetProfileSection extends StatefulWidget {
  const PetProfileSection({super.key});

  @override
  State<PetProfileSection> createState() => _PetProfileSectionState();
}

class _PetProfileSectionState extends State<PetProfileSection> {
  final List<Pet> pets = [];
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    final List<Map<String, dynamic>> petsData =
        await _supabaseService.getAllPets();
    if (mounted) {
      setState(() {
        pets.clear();
        pets.addAll(petsData.map((petMap) => Pet.fromMap(petMap)).toList());
      });
    }
  }

  void _addPet(Pet newPet) {
    _supabaseService.insertPet(newPet.toMap()).then((generatedId) {
      if (generatedId != null) {
        final petWithId = Pet(
          id: generatedId, // generatedId 已经是 String 类型
          type: newPet.type,
          name: newPet.name,
          age: newPet.age,
          gender: newPet.gender,
          breed: newPet.breed,
          avatar: newPet.avatar,
          birthDate: newPet.birthDate,
          neuterStatus: newPet.neuterStatus,
          weight: newPet.weight,
        );

        if (mounted) {
          setState(() {
            pets.add(petWithId);
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('宠物档案添加成功')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('宠物档案添加失败，请检查网络连接')));
        }
      }
    }).catchError((error, stackTrace) {
      // 使用 debugPrint 替代 print
      debugPrint('--- 宠物档案添加失败 ---');
      debugPrint('错误详情 (Error): $error');
      debugPrint('错误类型: ${error.runtimeType}');
      debugPrint('堆栈跟踪 (Stack Trace): $stackTrace');

      // 检查是否是数据库约束错误（可能是 user_id 类型不匹配）
      final errorStr = error.toString().toLowerCase();
      String errorMessage = '添加失败，请检查终端日志';

      if (errorStr.contains('foreign key') || errorStr.contains('user_id')) {
        errorMessage = '添加失败：用户ID格式错误，请重新登录';
      } else if (errorStr.contains('null') || errorStr.contains('not null')) {
        errorMessage = '添加失败：缺少必要字段';
      } else if (errorStr.contains('network') ||
          errorStr.contains('connection')) {
        errorMessage = '添加失败，请检查网络连接';
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    });
  }

  void _deletePet(Pet petToDelete) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('您确定要删除 ${petToDelete.name} 的档案吗？'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                setState(() {});
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('删除'),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  if (petToDelete.id != null) {
                    final success = await _supabaseService.deletePet(
                      petToDelete.id.toString(),
                    );
                    if (!success) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('删除失败，请检查网络连接')),
                        );
                      }
                      return;
                    }
                    if (mounted) {
                      setState(() {
                        pets.removeWhere((pet) => pet.id == petToDelete.id);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${petToDelete.name} 的档案已删除')),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('宠物档案', style: AppStyles.sectionTitle),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PetProfileFormPage(),
                  ),
                );

                if (result != null && mounted) {
                  // 从表单页面返回的数据
                  final petData = result as Map<String, dynamic>;

                  // 计算年龄（根据出生日期）
                  String age = '1岁0个月';
                  if (petData['birth_date'] != null) {
                    final birthDate = DateTime.tryParse(petData['birth_date']);
                    if (birthDate != null) {
                      final now = DateTime.now();
                      int years = now.year - birthDate.year;
                      int months = now.month - birthDate.month;
                      // Adjust for month and day
                      if (months < 0 || (months == 0 && now.day < birthDate.day)) {
                        years--;
                        months += 12;
                      }
                      if (now.day < birthDate.day && months > 0) {
                        months--;
                      }
                      age = '${years}岁${months}个月';
                    }
                  }

                  // 创建Pet对象，包含所有表单字段
                  final newPet = Pet(
                    type: petData['type'] ?? '狗', // 宠物类型
                    name: petData['name'] ?? '',
                    age: age, // 根据出生日期计算
                    gender: petData['gender'] ?? '哥哥',
                    breed: petData['breed'] ?? '', // 品种
                    avatar: petData['avatar'], // 头像路径
                    birthDate: petData['birth_date'], // 出生日期
                    neuterStatus: petData['neuter_status'], // 绝育状态
                    weight: petData['weight'] != null
                        ? (petData['weight'] as num).toDouble()
                        : null, // 体重
                  );

                  _addPet(newPet);
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加宠物'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        pets.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: Text('暂无宠物档案', style: AppStyles.petDetails),
                ),
              )
            // 🎨 美学升级：交错入场动画
            : AnimationLimiter(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pets.length,
                  itemBuilder: (context, index) {
                    final pet = pets[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: Dismissible(
                            key: ValueKey(pet.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              _deletePet(pet);
                              return false;
                            },
                            child: PetProfileCard(
                              pet: pet,
                              onView: () async {
                                await Navigator.push<Pet>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PetProfileDetailsPage(pet: pet),
                                  ),
                                );
                                _loadPets();
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                ),
              ),
      ],
    );
  }
}

// =========================================================
// 单个宠物档案卡片 - 美学升级版
// =========================================================
class PetProfileCard extends StatefulWidget {
  final Pet pet;
  final VoidCallback onView;

  const PetProfileCard({super.key, required this.pet, required this.onView});

  @override
  State<PetProfileCard> createState() => _PetProfileCardState();
}

class _PetProfileCardState extends State<PetProfileCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // 🎨 美学升级：点击动效控制器
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98, // 轻微缩小2%
    ).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
    widget.onView();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              // 🎨 美学升级：多层阴影效果
              boxShadow: [
                // 第一层：接触阴影
                BoxShadow(
                  offset: const Offset(0, 2),
                  blurRadius: 4.0,
                  color: Colors.black.withOpacity(0.04),
                ),
                // 第二层：弥散光晕
                BoxShadow(
                  offset: const Offset(0, 12),
                  blurRadius: 24.0,
                  color: Colors.black.withOpacity(0.06),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                // 🎨 美学升级：添加 Material Design 水波纹效果，形状与卡片圆角保持一致
                borderRadius: BorderRadius.circular(12),
                // 🎨 增强水波纹效果：更明显的颜色和扩散半径
                splashColor: AppColors.primary.withOpacity(
                  0.2,
                ), // 增加不透明度从0.1到0.2
                highlightColor: AppColors.primary.withOpacity(
                  0.08,
                ), // 增加不透明度从0.05到0.08
                // 增加水波纹扩散半径
                radius: 150,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 🎨 美学升级：根据宠物类型的主题色背景
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.petTypeColors[widget.pet.type] ??
                              AppColors.petTypeColors['其他'],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            'https://loremflickr.com/150/150/animal,${widget.pet.breed.toLowerCase()}',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              return progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator(),
                                    );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors
                                          .petTypeColors[widget.pet.type] ??
                                      AppColors.petTypeColors['其他'],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.pets,
                                  color: AppColors.primary.withOpacity(0.6),
                                  size: 28,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🎨 美学升级：宠物名字用品牌主色并加粗
                            Text(
                              widget.pet.name,
                              style: AppStyles.petName.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.pet.age} | ${widget.pet.gender} | ${widget.pet.breed}',
                              style: AppStyles.petDetails,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.secondaryText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =========================================================
// 宠物档案详情页
// =========================================================
class PetProfileDetailsPage extends StatefulWidget {
  final Pet pet;

  const PetProfileDetailsPage({super.key, required this.pet});

  @override
  State<PetProfileDetailsPage> createState() => _PetProfileDetailsPageState();
}

class _PetProfileDetailsPageState extends State<PetProfileDetailsPage> {
  late Pet _currentPet;
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _currentPet = widget.pet;
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        // 🎨 美学升级：多层阴影效果
        boxShadow: [
          // 第一层：接触阴影
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 4.0,
            color: Colors.black.withOpacity(0.04),
          ),
          // 第二层：弥散光晕
          BoxShadow(
            offset: const Offset(0, 12),
            blurRadius: 24.0,
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.secondaryText,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // 🎨 美学升级：详情页也使用径向渐变背景
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.8,
          colors: [Colors.white, Color(0xFFF5F5F7)],
          stops: [0.0, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            '${_currentPet.name} 的档案',
            style: AppStyles.sectionTitle.copyWith(fontSize: 20),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: AppColors.primaryText,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: () async {
                final updatedPet = await showDialog<Pet>(
                  context: context,
                  builder: (context) => EditPetDialog(pet: _currentPet),
                );

                if (updatedPet != null && mounted) {
                  try {
                    final success = await _supabaseService.updatePet(
                      updatedPet.toMap(),
                    );
                    if (!success) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('更新失败，请检查网络连接')),
                        );
                      }
                      return;
                    }
                    setState(() {
                      _currentPet = updatedPet;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('档案已更新')));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('更新失败，请重试')));
                    }
                  }
                }
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpaces.horizontalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                ClipOval(
                  child: Image.network(
                    'https://loremflickr.com/240/240/animal,${_currentPet.breed.toLowerCase()}',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      return progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.pets,
                          color: Colors.grey,
                          size: 50,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(_currentPet.name, style: AppStyles.sectionTitle),
                const SizedBox(height: 32),
                _buildInfoCard('类型', _currentPet.type),
                const SizedBox(height: 12),
                _buildInfoCard('品种', _currentPet.breed),
                const SizedBox(height: 12),
                _buildInfoCard('性别', _currentPet.gender),
                const SizedBox(height: 12),
                _buildInfoCard('年龄', _currentPet.age),
                const SizedBox(height: 12),
                if (_currentPet.birthDate != null)
                  _buildInfoCard('出生日期', _currentPet.birthDate!),
                if (_currentPet.birthDate != null) const SizedBox(height: 12),
                if (_currentPet.neuterStatus != null)
                  _buildInfoCard('绝育状态', _currentPet.neuterStatus!),
                if (_currentPet.neuterStatus != null)
                  const SizedBox(height: 12),
                if (_currentPet.weight != null)
                  _buildInfoCard(
                      '体重', '${_currentPet.weight!.toStringAsFixed(1)} kg'),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================
// 编辑宠物档案对话框
// =========================================================
class EditPetDialog extends StatefulWidget {
  final Pet pet;

  const EditPetDialog({super.key, required this.pet});

  @override
  State<EditPetDialog> createState() => _EditPetDialogState();
}

class _EditPetDialogState extends State<EditPetDialog> {
  late final TextEditingController _nameController;
  late String _selectedGender;
  late String _selectedPetType;
  late String _selectedBreed;
  late int _selectedYears;
  late int _selectedMonths;

  final Map<String, List<String>> _petBreeds = {
    '狗': ['拉布拉多', '金毛寻回犬', '法国斗牛犬', '贵宾犬', '比熊', '柯基', '柴犬', '哈士奇'],
    '猫': ['英国短毛猫', '美国短毛猫', '布偶猫', '暹罗猫', '波斯猫', '缅因猫', '苏格兰折耳猫'],
    '兔': ['垂耳兔', '荷兰兔', '安哥拉兔', '侏儒兔', '新西兰兔'],
    '仓鼠': ['金丝熊', '三线仓鼠', '银狐', '布丁', '奶茶'],
    '其他': ['未知品种'],
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pet.name);
    _selectedGender = widget.pet.gender;
    _selectedPetType = widget.pet.type;
    _selectedBreed = widget.pet.breed;
    _parseAge(widget.pet.age);
  }

  void _parseAge(String age) {
    _selectedYears = 0;
    _selectedMonths = 0;
    final yearsMatch = RegExp(r'(\d+)岁').firstMatch(age);
    if (yearsMatch != null) {
      _selectedYears = int.tryParse(yearsMatch.group(1) ?? '0') ?? 0;
    }
    final monthsMatch = RegExp(r'(\d+)个月').firstMatch(age);
    if (monthsMatch != null) {
      _selectedMonths = int.tryParse(monthsMatch.group(1) ?? '0') ?? 0;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改宠物档案'),
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '昵称'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: '性别'),
              value: _selectedGender,
              items: const ['哥哥', '妹妹'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedGender = newValue!;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: '年龄(岁)'),
                    value: _selectedYears,
                    items: List.generate(20, (index) => index).map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      setState(() {
                        _selectedYears = newValue!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: '年龄(月)'),
                    value: _selectedMonths,
                    items: List.generate(12, (index) => index).map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      setState(() {
                        _selectedMonths = newValue!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: '宠物类型'),
              value: _selectedPetType,
              items: _petBreeds.keys.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedPetType = newValue!;
                  if (!_petBreeds[newValue]!.contains(_selectedBreed)) {
                    _selectedBreed = _petBreeds[newValue]!.first;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: '品种'),
              value: _selectedBreed,
              items: _petBreeds[_selectedPetType]!.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedBreed = newValue!;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              final String ageString = '$_selectedYears岁$_selectedMonths个月';

              Navigator.of(context).pop(
                Pet(
                  id: widget.pet.id,
                  type: _selectedPetType,
                  name: _nameController.text,
                  age: ageString,
                  gender: _selectedGender,
                  breed: _selectedBreed,
                ),
              );
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
