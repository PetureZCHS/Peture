import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui';
import '../../../shared/models/pet.dart';
import '../../../shared/models/pet_passport.dart';
import '../../../services/supabase_service.dart';
import '../../profile/presentation/account_settings_page.dart';
import '../../profile/presentation/pet_profile_form_page.dart';
import '../../../shared/utils/user_avatar_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_pet_passport_page.dart';
import '../../../shared/utils/data_change_notifier.dart';

/// 宠物身份证（护照风格）页面
class PetPassportPage extends StatefulWidget {
  const PetPassportPage({super.key});

  @override
  State<PetPassportPage> createState() => _PetPassportPageState();
}

class _PetPassportPageState extends State<PetPassportPage>
    with TickerProviderStateMixin {
  List<Pet> _pets = [];
  final Map<String, PetPassport?> _passports = {};
  bool _isLoading = true;
  int _selectedPetIndex = 0;
  late AnimationController _flipController;
  late AnimationController _shimmerController;
  bool _isFlipped = false;
  bool _isPressed = false;

  // 用户头像路径
  String? _userAvatarPath;
  String? _userName;
  /// 账号里「宠物对你的称呼」默认（users_profiles.owner_nickname）
  String? _profileOwnerNickname;

  static const _placeholderPassportOwnerNames = {'铲屎官', '主人'};
  late final VoidCallback _petDataRefreshListener;

  @override
  void initState() {
    super.initState();
    _petDataRefreshListener = () {
      if (!mounted) return;
      _loadPets();
    };
    DataChangeNotifier.petDataRefreshNotifier.addListener(
      _petDataRefreshListener,
    );
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadPets();
  }

  /// 加载用户信息（头像、昵称、默认主人称呼）
  Future<void> _loadUserInfo() async {
    try {
      final avatarPath = await UserAvatarHelper.getCurrentUserAvatarPath();
      final supabaseService = SupabaseService();
      final profile = await supabaseService.getUserProfile();
      final nickname = profile?['nickname'] as String?;
      final ownerNick = profile?['owner_nickname'] as String?;
      final user = Supabase.instance.client.auth.currentUser;
      final metaName = user?.userMetadata?['name'] as String?;
      final emailLocal = user?.email != null && user!.email!.contains('@')
          ? user.email!.split('@').first
          : null;

      if (mounted) {
        setState(() {
          _userAvatarPath = avatarPath;
          _userName = nickname ??
              (metaName != null && metaName.isNotEmpty ? metaName : null) ??
              (emailLocal != null && emailLocal.isNotEmpty ? emailLocal : null) ??
              '宠物家长';
          _profileOwnerNickname =
              (ownerNick != null && ownerNick.isNotEmpty) ? ownerNick : '主人';
        });
      }
    } catch (e) {
      debugPrint('加载用户信息失败: $e');
    }
  }

  /// 身份证「主人」展示：占位文案（铲屎官/主人）或空则与账号昵称同步；用户曾在编辑里自定义则保留。
  String _displayOwnerName(PetPassport? passport) {
    final raw = passport?.ownerName?.trim();
    if (raw != null &&
        raw.isNotEmpty &&
        !_placeholderPassportOwnerNames.contains(raw)) {
      return raw;
    }
    final u = _userName?.trim();
    if (u != null && u.isNotEmpty) return u;
    return '宠物家长';
  }

  /// 宠物怎么叫你：优先宠物档案自定义，否则用户默认称呼。
  String _petCallsOwner(Pet pet) {
    if (pet.useCustomNickname &&
        pet.ownerNickname != null &&
        pet.ownerNickname!.trim().isNotEmpty) {
      return pet.ownerNickname!.trim();
    }
    return _profileOwnerNickname?.trim().isNotEmpty == true
        ? _profileOwnerNickname!.trim()
        : '主人';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 检查宠物数据是否在其他页面被修改，如果是则刷新
    if (DataChangeNotifier.checkAndReset()) {
      _loadPets();
    }
  }

  @override
  void dispose() {
    DataChangeNotifier.petDataRefreshNotifier.removeListener(
      _petDataRefreshListener,
    );
    _flipController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadPets() async {
    setState(() => _isLoading = true);
    try {
      await _loadUserInfo();

      final supabaseService = SupabaseService();
      final pets = await supabaseService.getAllPets();
      setState(() {
        _pets = pets.map((p) => Pet.fromMap(p)).toList();
      });

      // 从数据库加载每个宠物的护照信息
      for (var pet in _pets) {
        if (pet.id != null) {
          // 先尝试从数据库加载
          var passportData = await supabaseService.getPassportByPetId(pet.id!);
          PetPassport? passport;

          if (passportData != null) {
            passport = PetPassport.fromMap(passportData);
          } else {
            // 如果数据库中没有，生成默认数据并保存
            passport = _generateDefaultPassport(pet);
            await supabaseService.upsertPetPassport(passport.toMap());
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
    final selectedAchievements =
        achievements.take(2 + random.nextInt(3)).toList();

    return PetPassport(
      petId: pet.id!,
      ownerName: _userName?.trim().isNotEmpty == true ? _userName!.trim() : '宠物家长',
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
    // Trigger shimmer animation
    _shimmerController.forward(from: 0).then((_) => _shimmerController.reset());
    
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      extendBodyBehindAppBar: true,
      appBar: _buildEnhancedAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pets.isEmpty
              ? _buildEnhancedEmptyState()
              : _buildPassportView(),
      bottomNavigationBar: const SizedBox(height: 20),
    );
  }

  PreferredSizeWidget _buildEnhancedAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1E1E)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      title: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            '宠物身份证',
            style: TextStyle(
              color: const Color(0xFF1E1E1E),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 80,
            height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: IconButton(
                icon: const Icon(Icons.person_outline, color: Color(0xFF5A8EFA)),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AccountSettingsPage(),
                    ),
                  );
                  if (mounted) await _loadPets();
                },
              ),
            ),
          ),
        ),
        if (_pets.isNotEmpty && _pets[_selectedPetIndex].id != null)
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF5A8EFA)),
                  onPressed: () => _navigateToEdit(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEnhancedEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.pets,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '还没有宠物信息',
            style: TextStyle(
              fontSize: 22,
              color: Colors.grey[800],
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '快去添加一只可爱的宠物吧',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PetProfileFormPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                '添加宠物',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassportView() {
    return Column(
      children: [
        const SizedBox(height: kToolbarHeight + 20),
        if (_pets.length > 1) _buildEnhancedPetSelector(),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: GestureDetector(
                onTap: _flipCard,
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                child: AnimatedBuilder(
                  animation: _flipController,
                  builder: (context, child) {
                    final angle = _flipController.value * math.pi;
                    final scale = _isPressed ? 0.97 : 1.0;
                    
                    final shadowOpacity = 0.2 + (_flipController.value - 0.5).abs() * 0.1;
                    
                    return Transform.scale(
                        scale: scale,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(shadowOpacity),
                                blurRadius: 20 + (_isPressed ? 10 : 0),
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(angle),
                            alignment: Alignment.center,
                            child: angle < math.pi / 2
                                ? _buildEnhancedPassportFront()
                                : Transform(
                                    transform: Matrix4.identity()..rotateY(math.pi),
                                    alignment: Alignment.center,
                                    child: _buildEnhancedPassportBack(),
                                  ),
                           ),
                         ),
                       );
                  },
                ),
              ),
            ),
          ),
        ),
        _buildEnhancedHint(),
      ],
    );
  }

  Widget _buildEnhancedPetSelector() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _pets.length,
        itemBuilder: (context, index) {
          final pet = _pets[index];
          final passport = _passports[pet.id];
          final isSelected = index == _selectedPetIndex;

          return AnimatedScale(
            scale: isSelected ? 1.0 : 0.9,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPetIndex = index;
                  if (_isFlipped) _flipCard();
                });
              },
              child: Container(
                width: 70,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              )
                            : null,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF667eea).withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      padding: isSelected ? const EdgeInsets.all(3) : null,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          border: !isSelected
                              ? Border.all(
                                  color: Colors.white.withOpacity(0.7),
                                  width: 2,
                                )
                              : null,
                        ),
                        child: ClipOval(
                          child: _buildPetSelectorPhoto(passport, pet, isSelected),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pet.name,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF667eea) : Colors.grey[500],
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPetSelectorPhoto(
    PetPassport? passport,
    Pet pet,
    bool isSelected,
  ) {
    if (passport?.photoPath != null && passport!.photoPath!.isNotEmpty) {
      final file = File(passport.photoPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: 60,
          height: 60,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultPetSelectorIcon(isSelected);
          },
        );
      }
    }

    if (pet.avatar != null && pet.avatar!.isNotEmpty) {
      final a = pet.avatar!;
      if (a.startsWith('http://') || a.startsWith('https://')) {
        return CachedNetworkImage(
          imageUrl: a,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildDefaultPetSelectorIcon(isSelected),
          errorWidget: (context, url, err) =>
              _buildDefaultPetSelectorIcon(isSelected),
        );
      }
      final file = File(a);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: 60,
          height: 60,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultPetSelectorIcon(isSelected);
          },
        );
      }
    }

    return _buildDefaultPetSelectorIcon(isSelected);
  }

  Widget _buildDefaultPetSelectorIcon(bool isSelected) {
    return Icon(
      Icons.pets,
      color: isSelected ? const Color(0xFF667eea) : Colors.grey[400],
      size: 28,
    );
  }

  Widget _buildEnhancedHint() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 18,
                      color: const Color(0xFF667eea).withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '点击卡片查看背面',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600]?.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }

  Widget _buildEnhancedPassportFront() {
    final pet = _pets[_selectedPetIndex];
    final passport = _passports[pet.id];

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 48).clamp(300.0, 360.0);
    final cardHeight = cardWidth * 1.55;

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 背景装饰图案
            Positioned.fill(
              child: CustomPaint(painter: PassportPatternPainter()),
            ),
            
            // Glassmorphism overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                ),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),

            // Shimmer effect
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, child) {
                return Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment(-1.0 + _shimmerController.value * 3, 0),
                        end: Alignment(0.0 + _shimmerController.value * 3, 0),
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.srcATop,
                    child: Container(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                );
              },
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Elegant header with gradient text
                  _buildPassportHeader(),
                  const SizedBox(height: 24),

                  // Photo and basic info row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Decorative photo frame
                      _buildDecorativePhotoFrame(passport),
                      const SizedBox(width: 16),

                      // Info column with icons
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRowWithIcon(
                              Icons.pets,
                              '姓名',
                              pet.name,
                            ),
                            const SizedBox(height: 10),
                            _buildInfoRowWithIcon(
                              Icons.category,
                              '品种',
                              pet.breed,
                            ),
                            const SizedBox(height: 10),
                            _buildInfoRowWithIcon(
                              pet.gender == '公' ? Icons.male : Icons.female,
                              '性别',
                              pet.gender,
                            ),
                            const SizedBox(height: 10),
                            _buildInfoRowWithIcon(
                              Icons.cake,
                              '年龄',
                              pet.age,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.4),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // MBTI section with enhanced styling
                  if (passport?.mbtiType != null) ...[
                    _buildEnhancedMBTISection(passport!),
                  ],

                  const Spacer(),

                  // Bottom info row with owner and adoption date
                  _buildBottomInfoRow(pet, passport),
                ],
              ),
            ),

            // Decorative stamp — must be direct child of Stack
            Positioned(
              bottom: 20,
              right: 20,
              child: _buildDecorativeStamp(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassportHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.verified,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [Colors.white, Color(0xFFE0E0E0)],
            ).createShader(bounds);
          },
          child: const Text(
            'PET PASSPORT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDecorativePhotoFrame(PetPassport? passport) {
    return Container(
      width: 100,
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF0F0F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF667eea).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildPetPhoto(passport),
        ),
      ),
    );
  }

  Widget _buildInfoRowWithIcon(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: Colors.white.withOpacity(0.9),
            size: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedMBTISection(PetPassport passport) {
    final mbtiInfo = MBTITypes.getTypeInfo(passport.mbtiType!);
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.white, Color(0xFFF5F5F5)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.psychology,
                      color: const Color(0xFF667eea),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      passport.mbtiType!,
                      style: const TextStyle(
                        color: Color(0xFF667eea),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (mbtiInfo != null)
                Text(
                  mbtiInfo['name']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            passport.mbtiDescription ?? '',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfoRow(Pet pet, PetPassport? passport) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Owner info
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                backgroundImage: _userAvatarPath != null &&
                        File(_userAvatarPath!).existsSync()
                    ? FileImage(File(_userAvatarPath!))
                    : null,
                child: _userAvatarPath == null ||
                        !File(_userAvatarPath!).existsSync()
                    ? Text(
                        _userName?.isNotEmpty == true
                            ? _userName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFF667eea),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        color: Colors.white.withOpacity(0.7),
                        size: 10,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '主人',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _displayOwnerName(passport),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '称呼 · ${_petCallsOwner(pet)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Adoption date
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Colors.white.withOpacity(0.7),
                    size: 10,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '领养日期',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                passport?.adoptionDate != null
                    ? '${passport!.adoptionDate!.year}.${passport.adoptionDate!.month.toString().padLeft(2, '0')}.${passport.adoptionDate!.day.toString().padLeft(2, '0')}'
                    : '2024.01.01',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDecorativeStamp() {
    return Opacity(
      opacity: 0.15,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.verified,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildEnhancedPassportBack() {
    final pet = _pets[_selectedPetIndex];
    final passport = _passports[pet.id];

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 48).clamp(300.0, 360.0);
    final cardHeight = cardWidth * 1.55;

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF764ba2), Color(0xFF667eea)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF764ba2).withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 背景装饰图案
            Positioned.fill(
              child: CustomPaint(painter: PassportPatternPainter()),
            ),

            // Glassmorphism overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.03),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Decorative header with stamp
                    _buildBackHeader(),
                    const SizedBox(height: 14),

                    // Interest tags with gradient styling
                    _buildSectionTitleWithIcon(Icons.local_offer, '兴趣标签'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (passport?.interestTags ?? []).map((tag) {
                        return _buildGradientTag(tag);
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    // Achievements grid with enhanced badges
                    _buildSectionTitleWithIcon(Icons.emoji_events, '成就徽章'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (passport?.achievements ?? [])
                          .take(6)
                          .map((a) => _buildEnhancedAchievementBadge(a))
                          .toList(),
                    ),

                    const SizedBox(height: 10),

                    // Social stats with glassmorphism
                    _buildEnhancedSocialStats(passport),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [Colors.white, Color(0xFFE0E0E0)],
            ).createShader(bounds);
          },
          child: const Text(
            'PET DETAILS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.fingerprint,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitleWithIcon(IconData icon, String title) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildGradientTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.25),
            Colors.white.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEnhancedAchievementBadge(Achievement achievement) {
    final gradientColors = _getAchievementGradient(achievement.iconName);
    
    return SizedBox(
      width: 80,
      child: Container(
        decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _getAchievementIcon(achievement.iconName),
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      ),
    );
  }

  List<Color> _getAchievementGradient(String iconName) {
    switch (iconName) {
      case 'health_and_safety':
        return [const Color(0xFF4CAF50), const Color(0xFF2E7D32)];
      case 'vaccines':
        return [const Color(0xFF2196F3), const Color(0xFF1565C0)];
      case 'groups':
        return [const Color(0xFF9C27B0), const Color(0xFF6A1B9A)];
      case 'book':
        return [const Color(0xFFFF9800), const Color(0xFFE65100)];
      case 'military_tech':
        return [const Color(0xFFFFD700), const Color(0xFFFFA000)];
      case 'celebration':
        return [const Color(0xFFE91E63), const Color(0xFFC2185B)];
      case 'restaurant':
        return [const Color(0xFF00BCD4), const Color(0xFF0097A7)];
      case 'sports_score':
        return [const Color(0xFFFF5722), const Color(0xFFD84315)];
      default:
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
    }
  }

  Widget _buildEnhancedSocialStats(PetPassport? passport) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEnhancedStatItem(
                Icons.groups,
                '好友',
                '${passport?.friendCount ?? 0}',
                const Color(0xFF4CAF50),
              ),
              Container(
                width: 1,
                height: 35,
                color: Colors.white.withOpacity(0.2),
              ),
              _buildEnhancedStatItem(
                Icons.emoji_events,
                '成就',
                '${passport?.achievements.length ?? 0}',
                const Color(0xFFFFA000),
              ),
              Container(
                width: 1,
                height: 35,
                color: Colors.white.withOpacity(0.2),
              ),
              _buildEnhancedStatItem(
                Icons.favorite,
                '互动',
                '${(passport?.friendCount ?? 0) * 3}',
                const Color(0xFFE91E63),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedStatItem(IconData icon, String label, String value, Color accentColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [Colors.white, Color(0xFFE0E0E0)],
            ).createShader(bounds);
          },
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPetPhoto(PetPassport? passport) {
    final pet = _pets[_selectedPetIndex];

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

    if (pet.avatar != null && pet.avatar!.isNotEmpty) {
      final a = pet.avatar!;
      if (a.startsWith('http://') || a.startsWith('https://')) {
        return CachedNetworkImage(
          imageUrl: a,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildDefaultPetIcon(),
          errorWidget: (context, url, err) => _buildDefaultPetIcon(),
        );
      }
      final file = File(a);
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

    return _buildDefaultPetIcon();
  }

  Widget _buildDefaultPetIcon() {
    final pet = _pets[_selectedPetIndex];
    return Center(
      child: Icon(
        pet.type == '猫' ? Icons.pets : Icons.pets,
        size: 50,
        color: const Color(0xFF667eea),
      ),
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
        builder: (_) => EditPetPassportPage(
          pet: pet,
          passport: passport,
          suggestedOwnerDisplay: _displayOwnerName(passport),
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _passports[pet.id!] = result;
      });
      DataChangeNotifier.markPetDataChanged();
    }
  }
}

/// 护照背景装饰图案绘制器
class PassportPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
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