import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/utils/ui_helpers.dart';
import '../../../services/supabase_edge_service.dart';
import '../../../shared/models/pet.dart';
import '../../../services/supabase_service.dart';
import 'pet_diary_result_page.dart';
import 'dart:io';
import '../../library/presentation/library_screen.dart';

/// 撰写日记页面 - AI将用户输入改写成宠物第一人称
class PetDiaryComposePage extends StatefulWidget {
  const PetDiaryComposePage({super.key});

  @override
  State<PetDiaryComposePage> createState() => _PetDiaryComposePageState();
}

class _PetDiaryComposePageState extends State<PetDiaryComposePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final PetDiaryEdgeService _diaryService = PetDiaryEdgeService();
  final SupabaseService _supabaseService = SupabaseService();
  late AnimationController _orbController;
  
  // 宠物选择
  List<Pet> _pets = [];
  Pet? _selectedPet;
  bool _isLoadingPets = false;
  // 控制宠物列表的展开状态
  bool _isPetSelectorExpanded = false;

  // 当前选中的风格
  String _selectedStyle = '小红书';

  // 可用的风格列表
  final List<String> _availableStyles = ['哲学', '搞笑', '治愈', '中二', '小红书'];

  // 示例文本
  final String _exampleText =
      '今天，我带我的宠物狗狗十六去逍遥津的大草坪玩飞盘。小妮带着她的宠物狗狗朱朱一起。十六跑得比朱朱快。十六和朱朱都玩得很开心，我奖励它们吃苹果狗粮。';
  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    
    _loadPets();
  }

  Future<void> _loadPets() async {
    if (!mounted) return;
    setState(() => _isLoadingPets = true);
    try {
      final petsData = await _supabaseService.getAllPets();
      if (mounted) {
        setState(() {
          _pets = petsData.map((data) => Pet.fromMap(data)).toList();
          _isLoadingPets = false;
        });
      }
    } catch (e) {
      debugPrint('加载宠物列表失败: $e');
      if (mounted) {
        setState(() => _isLoadingPets = false);
      }
    }
  }

  void _onPetSelected(Pet? pet) {
    setState(() {
      _selectedPet = pet;
    });
  }

  @override
  void dispose() {
    _orbController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  /// 生成宠物日记（跳转到生成页面）
  Future<void> _generatePetDiary() async {
    // 检查是否选择了宠物
    if (_selectedPet == null) {
      _showCustomDialog(
        title: '还没有选择主角呢 🐾',
        content: '请先从上方列表选择一只宠物，\nAI 才能以它的视角写日记哦！',
        confirmText: '这就去选',
      );
      return;
    }

    final userInput = _inputController.text.trim();

    if (userInput.isEmpty) {
      _showToast('请先输入内容');
      return;
    }

    // 字数限制检查 (10-500字)
    if (userInput.length < 10) {
      _showToast('输入内容太短，至少需要10个字');
      return;
    }

    if (userInput.length > 500) {
      _showToast('输入内容超出限制，最多500个字');
      return;
    }

    // 获取昵称：优先使用宠物的自定义昵称，否则使用用户默认昵称
    String? nickname;
    if (_selectedPet != null &&
        _selectedPet!.ownerNickname != null &&
        _selectedPet!.ownerNickname!.isNotEmpty) {
      nickname = _selectedPet!.ownerNickname;
    } else {
      nickname = await _supabaseService.getOwnerNickname();
    }

    if (!mounted) return;

    // 直接跳转到结果页面,在那里显示加载动画和流式生成
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetDiaryResultPage(
          originalText: userInput,
          style: _selectedStyle,
          diaryService: _diaryService,
          nickname: nickname,
          petId: _selectedPet?.id,
          petName: _selectedPet?.name,
          petAvatarUrl: _selectedPet?.avatar, // 传递宠物头像
          breed: _selectedPet?.breed,
          gender: _selectedPet?.gender,
          petType: _selectedPet?.type,
        ),
      ),
    );
  }

  /// 选择风格
  void _onStyleSelected(String style) {
    setState(() {
      _selectedStyle = style;
    });
  }

  /// 点击示例文本
  void _onExampleTap() {
    String example;
    // 根据已选宠物的类型提供不同的示例
    if (_selectedPet != null) {
      if (_selectedPet!.type == '猫咪') {
        example =
            '今天，我回到家一开门，${_selectedPet!.name} 就迈着优雅的猫步走过来，“喵”了一声蹭我的腿求摸摸。我给它倒了些猫粮，它吃得呼噜呼噜的。吃饱后，它跳上窗台晒太阳，眯着眼睛的样子太治愈了，感觉一天的疲惫都消失了。';
      } else if (_selectedPet!.type == '狗狗') {
        example =
            '今天天气真好，我带 ${_selectedPet!.name} 去公园玩飞盘。它精力特别旺盛，跑得飞快，每次都能精准接住飞盘，周围的人都夸它聪明。玩累了我们就坐在草地上休息，它吐着舌头傻笑，我把准备好的零食喂给它，它开心得尾巴摇个不停。';
      } else {
        // 其他类型或未知类型，使用通用模版
        example =
            '今天 ${_selectedPet!.name} 特别乖，一直陪在我身边。看着它是圆滚滚的小眼睛，感觉心都要化了。给它喂了最爱吃的零食，它开心得不得了，希望它能一直这样快乐健康地成长。';
      }
    } else {
      // 未选择宠物时，交替显示猫狗示例（或随机一个）
      final random = math.Random();
      if (random.nextBool()) {
        example =
            '今天下班回家，家里的猫咪立刻跑过来迎接我，蹭来蹭去要小鱼干吃。吃饱喝足后，它就在沙发上踩奶，然后缩成一团睡着了，呼噜声听着真让人安心。';
      } else {
        example =
            '今天带狗狗去公园散步，它看到别的狗狗特别兴奋，一直想冲过去玩。我们玩了会捡球游戏，它跑得气喘吁吁的，回来后喝了一大碗水，现在正趴在脚边打呼噜呢。';
      }
    }

    setState(() {
      _inputController.text = example;
    });
  }

  /// 显示提示信息
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// 显示自定义美观弹窗
  void _showCustomDialog({
    required String title,
    required String content,
    String confirmText = '好的',
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 可爱的装饰图标容器
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pets_rounded,
                  size: 40,
                  color: Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(height: 24),
              
              // 标题
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              
              // 内容
              Text(
                content,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              
              // 按钮
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    confirmText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
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

          SafeArea(
            child: Column(
              children: [
                _buildTopHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        // Kimi 风格精灵小球
                        const _KimiBall(),
                        const SizedBox(height: 12),
                        // 标题区域
                        const Text(
                          "Hello, 记录美好",
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -1.0,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "今天发生了什么有趣的事？",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // 1. 引导选择宠物
                        const Text(
                          "第一步：选择主角",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPetSelector(),

                        const SizedBox(height: 24),

                        // 2. 引导记录
                        const Text(
                          "第二步：记录日常",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 输入框区域
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _inputController,
                                maxLines: null,
                                minLines: 5,
                                maxLength: 500,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.6,
                                  color: Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: '例如：今天带十六去公园玩了，它追着蝴蝶跑了好久...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                  counterStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // 风格选择
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _availableStyles.map((style) {
                                    final isSelected = _selectedStyle == style;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: ChoiceChip(
                                        label: Text(style),
                                        selected: isSelected,
                                        onSelected: (selected) {
                                          if (selected) _onStyleSelected(style);
                                        },
                                        backgroundColor: Colors.grey.shade100,
                                        selectedColor: const Color(0xFF4facfe)
                                            .withOpacity(0.2),
                                        labelStyle: TextStyle(
                                          color: isSelected
                                              ? const Color(0xFF4facfe)
                                              : Colors.grey.shade600,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          side: BorderSide(
                                            color: isSelected
                                                ? const Color(0xFF4facfe)
                                                : Colors.transparent,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        // 示例文本按钮
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _onExampleTap,
                            icon: Icon(Icons.auto_awesome,
                                size: 16, color: Colors.grey.shade500),
                            label: Text(
                              "试一试示例",
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // 生成按钮
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _generatePetDiary,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedPet == null
                                  ? Colors.grey.shade400
                                  : const Color(0xFF1A1A1A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_selectedPet != null)
                                  const Icon(Icons.edit_note),
                                SizedBox(width: _selectedPet != null ? 8 : 0),
                                Text(
                                  _selectedPet != null ? "生成日记" : "请先选择宠物",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.chevron_back, size: 28),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '返回',
          ),
          Text(
            "Peture Diary",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.style, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PetJournalDemoPage()),
              );
            },
            tooltip: '手记模式 (Apple Journal)',
          ),
          IconButton(
            icon: const Icon(Icons.local_library_rounded,
                size: 28), // Changed icon to library
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LibraryScreen()),
              );
            },
            tooltip: '日记书库',
          ),
        ],
      ),
    );
  }

  Widget _buildPetSelector() {
    if (_isLoadingPets) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_pets.isEmpty) {
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.pets_outlined, size: 20, color: Colors.grey.shade400),
            const SizedBox(width: 10),
            Text(
              '还没有添加宠物哦',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isPetSelectorExpanded = !_isPetSelectorExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isPetSelectorExpanded
                  ? Colors.white
                  : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(_isPetSelectorExpanded ? 4 : 16),
                bottomRight: Radius.circular(_isPetSelectorExpanded ? 4 : 16),
              ),
              border: Border.all(
                color: _isPetSelectorExpanded
                    ? Colors.blue.withOpacity(0.3)
                    : Colors.white,
                width: _isPetSelectorExpanded ? 1 : 2,
              ),
              boxShadow: _isPetSelectorExpanded
                  ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: Row(
              children: [
                if (_selectedPet == null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.pets,
                        color: Colors.grey.shade400, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '点击选择主角 🐾',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  _buildPetAvatar(_selectedPet!.avatar, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPet!.name,
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_selectedPet!.breed} · ${_selectedPet!.gender}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                AnimatedRotation(
                  turns: _isPetSelectorExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _isPetSelectorExpanded
                        ? Colors.blue
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Container(
            height: _isPetSelectorExpanded ? null : 0,
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                children: _pets.map((pet) {
                  final isSelected = _selectedPet?.id == pet.id;
                  return InkWell(
                    onTap: () {
                      _onPetSelected(pet);
                      setState(() {
                        _isPetSelectorExpanded = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue.withOpacity(0.05)
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade50,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildPetAvatar(pet.avatar, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pet.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.blue
                                        : const Color(0xFF1A1A1A),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  pet.breed,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.blue.withOpacity(0.7)
                                        : Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.blue, size: 20),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPetAvatar(String? avatar, {double size = 32}) {
    final radius = size / 2;
    if (avatar != null && avatar.trim().isNotEmpty) {
      final a = avatar.trim();
      final uri = Uri.tryParse(a);
      final isHttp =
          uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      if (isHttp) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.network(
            a,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _petAvatarFallback(size),
          ),
        );
      }
      if (File(a).existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.file(
            File(a),
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      }
    }
    return _petAvatarFallback(size);
  }

  Widget _petAvatarFallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.pets, size: size * 0.6, color: Colors.grey[600]),
    );
  }
}

// =======================================================================
// Kimi 风格精灵小球组件 (复用自 ChatPage)
// =======================================================================
class _KimiBall extends StatefulWidget {
  const _KimiBall();

  @override
  State<_KimiBall> createState() => _KimiBallState();
}

class _KimiBallState extends State<_KimiBall> with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _bounceController;
  late AnimationController _lookController;
  late AnimationController _breathController;
  Timer? _blinkTimer;
  Timer? _lookTimer;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _lookController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _startBlinking();
    _startLooking();
  }

  void _startBlinking() {
    _blinkTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        if (math.Random().nextBool()) {
          _blinkController.forward().then((_) {
            _blinkController.reverse().then((_) {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  _blinkController
                      .forward()
                      .then((_) => _blinkController.reverse());
                }
              });
            });
          });
        } else {
          _blinkController.forward().then((_) => _blinkController.reverse());
        }
      }
    });
  }

  void _startLooking() {
    _lookTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_lookController.isAnimating && math.Random().nextBool()) {
        _lookController.forward().then((_) {
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) _lookController.reverse();
          });
        });
      }
    });
  }

  void _onTap() {
    if (!_bounceController.isAnimating) {
      HapticFeedback.mediumImpact();
      _bounceController.forward().then((_) => _bounceController.reverse());
      _blinkController.forward().then((_) => _blinkController.reverse());
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _bounceController.dispose();
    _lookController.dispose();
    _breathController.dispose();
    _blinkTimer?.cancel();
    _lookTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bounceController, _breathController]),
        builder: (context, child) {
          double bounceScale = 1.0;
          double translateY = 0.0;

          if (_bounceController.value <= 0.5) {
            bounceScale = 1.0 - (_bounceController.value * 0.2);
            translateY = _bounceController.value * 10;
          } else {
            bounceScale = 0.9 + ((_bounceController.value - 0.5) * 0.2);
            translateY = (1.0 - _bounceController.value) * 10;
          }

          double breathScale = 1.0 + (_breathController.value * 0.03);

          return Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(
              scale: bounceScale * breathScale,
              child: child,
            ),
          );
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4facfe),
                Color(0xFF00f2fe),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4facfe).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: const Alignment(-0.35, -0.2),
                child: _buildEye(),
              ),
              Align(
                alignment: const Alignment(0.35, -0.2),
                child: _buildEye(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEye() {
    return AnimatedBuilder(
      animation: Listenable.merge([_blinkController, _lookController]),
      builder: (context, child) {
        final height = 10.0 * (1.0 - _blinkController.value);
        final lookProgress = Curves.easeInOut.transform(_lookController.value);
        final lookOffset = Offset(4.0 * lookProgress, -3.0 * lookProgress);

        return Transform.translate(
          offset: lookOffset,
          child: Container(
            width: 6,
            height: height > 1.5 ? height : 1.5,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      },
    );
  }
}
