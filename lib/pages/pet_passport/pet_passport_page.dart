import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:io';
import '../../models/pet.dart';
import '../../models/pet_passport.dart';
import '../../database/medical_record_helper.dart';
import '../../database/pet_passport_helper.dart';
import 'edit_pet_passport_page.dart';

/// 宠物身份证（护照风格）页面
class PetPassportPage extends StatefulWidget {
  const PetPassportPage({super.key});

  @override
  State<PetPassportPage> createState() => _PetPassportPageState();
}

class _PetPassportPageState extends State<PetPassportPage>
    with SingleTickerProviderStateMixin {
  List<Pet> _pets = [];
  final Map<String, PetPassport?> _passports = {};
  bool _isLoading = true;
  int _selectedPetIndex = 0;
  late AnimationController _flipController;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadPets();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _loadPets() async {
    setState(() => _isLoading = true);
    try {
      final pets = await MedicalRecordHelper.instance.getAllPets();
      setState(() {
        _pets = pets.map((p) => Pet.fromMap(p)).toList();
      });

      // 从数据库加载每个宠物的护照信息
      for (var pet in _pets) {
        if (pet.id != null) {
          // 先尝试从数据库加载
          var passport = await PetPassportHelper.instance.getPassportByPetId(
            pet.id!,
          );

          // 如果数据库中没有，生成默认数据并保存
          if (passport == null) {
            passport = _generateDefaultPassport(pet);
            await PetPassportHelper.instance.savePassport(passport);
          }

          _passports[pet.id!] = passport;
        }
      }
    } catch (e) {
      debugPrint('加载宠物信息失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 生成默认护照数据（仅用于首次创建）
  PetPassport _generateDefaultPassport(Pet pet) {
    final random = math.Random();
    final mbtiKeys = MBTITypes.types.keys.toList();
    final randomMbti = mbtiKeys[random.nextInt(mbtiKeys.length)];
    final mbtiInfo = MBTITypes.getTypeInfo(randomMbti)!;

    // 随机选择3-5个兴趣标签
    final tags = List<String>.from(InterestTags.allTags)..shuffle(random);
    final selectedTags = tags.take(3 + random.nextInt(3)).toList();

    // 随机选择2-4个成就
    final achievements = List<Achievement>.from(
      PredefinedAchievements.achievements,
    )..shuffle(random);
    final selectedAchievements = achievements
        .take(2 + random.nextInt(3))
        .toList();

    return PetPassport(
      petId: pet.id!,
      ownerName: '铲屎官',
      adoptionDate: DateTime.now().subtract(
        Duration(days: random.nextInt(1000)),
      ),
      mbtiType: randomMbti,
      mbtiDescription: mbtiInfo['description'],
      interestTags: selectedTags,
      achievements: selectedAchievements,
      bio:
          '这是一只可爱的${pet.breed}，性格${mbtiInfo['traits']}，喜欢${selectedTags.first}。',
      friendCount: random.nextInt(50),
    );
  }

  void _flipCard() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1E1E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '宠物身份证',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_pets.isNotEmpty && _pets[_selectedPetIndex].id != null)
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF5A8EFA)),
              onPressed: () => _navigateToEdit(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pets.isEmpty
          ? _buildEmptyState()
          : _buildPassportView(),
      // 添加底部安全区域，避免内容被液态导航栏遮挡
      bottomNavigationBar: const SizedBox(height: 20),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '还没有宠物信息',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请先添加宠物',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildPassportView() {
    return Column(
      children: [
        // 宠物选择器
        if (_pets.length > 1) _buildPetSelector(),

        // 护照卡片
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: _flipCard,
              child: AnimatedBuilder(
                animation: _flipController,
                builder: (context, child) {
                  final angle = _flipController.value * math.pi;
                  final transform = Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle);

                  return Transform(
                    transform: transform,
                    alignment: Alignment.center,
                    child: angle < math.pi / 2
                        ? _buildPassportFront()
                        : Transform(
                            transform: Matrix4.identity()..rotateY(math.pi),
                            alignment: Alignment.center,
                            child: _buildPassportBack(),
                          ),
                  );
                },
              ),
            ),
          ),
        ),

        // 提示文字
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '点击卡片查看背面',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }

  Widget _buildPetSelector() {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _pets.length,
        itemBuilder: (context, index) {
          final pet = _pets[index];
          final passport = _passports[pet.id];
          final isSelected = index == _selectedPetIndex;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPetIndex = index;
                if (_isFlipped) _flipCard(); // 切换宠物时重置翻转状态
              });
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF5A8EFA)
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF5A8EFA).withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      child: _buildPetSelectorPhoto(passport, pet, isSelected),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建宠物选择器中的照片
  Widget _buildPetSelectorPhoto(
    PetPassport? passport,
    Pet pet,
    bool isSelected,
  ) {
    // 如果有照片路径，显示照片
    if (passport?.photoPath != null && passport!.photoPath!.isNotEmpty) {
      final file = File(passport.photoPath!);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: 60,
            height: 60,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.pets,
                color: isSelected ? const Color(0xFF5A8EFA) : Colors.grey[400],
                size: 30,
              );
            },
          ),
        );
      }
    }

    // 没有照片时显示默认图标
    return Icon(
      pet.type == '猫' ? Icons.pets : Icons.pets,
      color: isSelected ? const Color(0xFF5A8EFA) : Colors.grey[400],
      size: 30,
    );
  }

  Widget _buildPassportFront() {
    final pet = _pets[_selectedPetIndex];
    final passport = _passports[pet.id];

    return Container(
      width: 360,
      height: 540,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 背景装饰图案
          Positioned.fill(
            child: CustomPaint(painter: PassportPatternPainter()),
          ),

          // 内容
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    Icon(
                      Icons.pets,
                      color: Colors.white.withOpacity(0.9),
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'PET PASSPORT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 宠物照片和基本信息
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 照片
                    Container(
                      width: 100,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: _buildPetPhoto(passport),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // 基本信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('姓名', pet.name),
                          const SizedBox(height: 8),
                          _buildInfoRow('品种', pet.breed),
                          const SizedBox(height: 8),
                          _buildInfoRow('性别', pet.gender),
                          const SizedBox(height: 8),
                          _buildInfoRow('年龄', pet.age),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(color: Colors.white30, thickness: 1),
                const SizedBox(height: 16),

                // MBTI类型
                if (passport?.mbtiType != null) ...[
                  _buildSectionTitle('性格类型'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                passport!.mbtiType!,
                                style: const TextStyle(
                                  color: Color(0xFF667eea),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                MBTITypes.getTypeInfo(
                                  passport.mbtiType!,
                                )!['name']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          passport.mbtiDescription ?? '',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // 底部信息
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '主人',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          passport?.ownerName ?? '铲屎官',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '领养日期',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          passport?.adoptionDate != null
                              ? '${passport!.adoptionDate!.year}.${passport.adoptionDate!.month.toString().padLeft(2, '0')}.${passport.adoptionDate!.day.toString().padLeft(2, '0')}'
                              : '2024.01.01',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassportBack() {
    final pet = _pets[_selectedPetIndex];
    final passport = _passports[pet.id];

    return Container(
      width: 360,
      height: 540,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF764ba2), Color(0xFF667eea)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 背景装饰图案
          Positioned.fill(
            child: CustomPaint(painter: PassportPatternPainter()),
          ),

          // 内容
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 兴趣标签
                _buildSectionTitle('兴趣标签'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (passport?.interestTags ?? []).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // 成就徽章
                _buildSectionTitle('成就徽章'),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: (passport?.achievements.length ?? 0).clamp(0, 6),
                    itemBuilder: (context, index) {
                      final achievement = passport!.achievements[index];
                      return _buildAchievementBadge(achievement);
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // 社交信息
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        Icons.groups,
                        '好友',
                        '${passport?.friendCount ?? 0}',
                      ),
                      _buildStatItem(
                        Icons.emoji_events,
                        '成就',
                        '${passport?.achievements.length ?? 0}',
                      ),
                      _buildStatItem(
                        Icons.favorite,
                        '互动',
                        '${(passport?.friendCount ?? 0) * 3}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 构建宠物照片显示
  Widget _buildPetPhoto(PetPassport? passport) {
    // 如果有照片路径，显示照片
    if (passport?.photoPath != null && passport!.photoPath!.isNotEmpty) {
      final file = File(passport.photoPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultPetIcon();
          },
        );
      }
    }

    // 没有照片时显示默认图标
    return _buildDefaultPetIcon();
  }

  /// 构建默认宠物图标
  Widget _buildDefaultPetIcon() {
    final pet = _pets[_selectedPetIndex];
    return Center(
      child: Icon(
        pet.type == '猫' ? Icons.pets : Icons.pets,
        size: 60,
        color: const Color(0xFF667eea),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildAchievementBadge(Achievement achievement) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getAchievementIcon(achievement.iconName),
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            achievement.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
        ),
      ],
    );
  }

  IconData _getAchievementIcon(String iconName) {
    switch (iconName) {
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'vaccines':
        return Icons.vaccines;
      case 'groups':
        return Icons.groups;
      case 'book':
        return Icons.book;
      case 'military_tech':
        return Icons.military_tech;
      case 'celebration':
        return Icons.celebration;
      case 'restaurant':
        return Icons.restaurant;
      case 'sports_score':
        return Icons.sports_score;
      default:
        return Icons.emoji_events;
    }
  }

  void _navigateToEdit() async {
    final pet = _pets[_selectedPetIndex];
    final passport = _passports[pet.id];

    final result = await Navigator.push<PetPassport>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPetPassportPage(pet: pet, passport: passport),
      ),
    );

    // 如果编辑页面返回了更新的护照数据，更新本地状态
    if (result != null && mounted) {
      setState(() {
        _passports[pet.id!] = result;
      });
    }
  }
}

/// 护照背景装饰图案绘制器
class PassportPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 绘制网格图案
    const spacing = 30.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // 绘制对角线
    paint.strokeWidth = 0.5;
    for (double i = -size.height; i < size.width; i += spacing * 2) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
