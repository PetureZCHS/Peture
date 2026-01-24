import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/ui_helpers.dart';
import '../../services/supabase_edge_service.dart';
import 'pet_diary_result_page.dart';
import '../../library_screen.dart';

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
  late AnimationController _orbController;

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
  }

  @override
  void dispose() {
    _orbController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  /// 生成宠物日记（跳转到生成页面）
  Future<void> _generatePetDiary() async {
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

    // 直接跳转到结果页面,在那里显示加载动画和流式生成
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetDiaryResultPage(
          originalText: userInput,
          style: _selectedStyle,
          diaryService: _diaryService,
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
    setState(() {
      _inputController.text = _exampleText;
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
                              backgroundColor: const Color(0xFF1A1A1A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_note),
                                SizedBox(width: 8),
                                Text(
                                  "生成日记",
                                  style: TextStyle(
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
