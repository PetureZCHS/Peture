import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/ui_helpers.dart';
import '../../services/supabase_edge_service.dart';
import '../../models/pet_diary.dart';
import '../../services/supabase_service.dart';

/// 宠物日记结果展示页面
class PetDiaryResultPage extends StatefulWidget {
  final String originalText;
  final String? diaryContent; // 可选，用于查看已保存的日记
  final String style;
  final PetDiaryEdgeService? diaryService; // 可选，用于生成新日记
  final String? initialContent; // 可选，初始内容（从生成页面传递）

  const PetDiaryResultPage({
    super.key,
    required this.originalText,
    this.diaryContent,
    this.style = '小红书',
    this.diaryService,
    this.initialContent,
  });

  @override
  State<PetDiaryResultPage> createState() => _PetDiaryResultPageState();
}

class _PetDiaryResultPageState extends State<PetDiaryResultPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _cursorAnimationController; // 光标闪烁
  late AnimationController _loadingAnimationController; // 加载动画
  late AnimationController _shimmerAnimationController; // 微光动画
  late AnimationController _orbController; // 背景光球动画
  late ScrollController _scrollController; // 滚动控制器
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isSaved = false; // 标记是否已保存
  bool _isGenerating = false; // 是否正在生成
  bool _showLoading = true; // 是否显示加载动画
  String _generatedContent = ''; // 生成的内容
  String _loadingMessage = '正在连接 AI...'; // 加载提示信息
  Timer? _messageTimer; // 提示信息定时器
  String _fullTextBuffer = ''; // 完整文本缓冲区
  String _gibberishBuffer = ''; // 乱码缓冲区
  Timer? _typingTimer; // 打字效果定时器
  int _displayedLength = 0; // 已显示的字符数 (打字机光标位置)
  int _decodedLength = 0; // 已解码的字符数 (真实文本位置)
  int _lastScrollLength = 0; // 上次滚动时的字符数

  // 宠物乱码字符集
  final List<String> _petSounds = ['喵', '汪', '嗷', '呜', '吱', '~', '！', '？', '...'];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cursorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000), // 延长旋转时间，让它更流畅
      vsync: this,
    )..repeat(); // 无缝循环旋转

    _shimmerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    // 如果提供了 diaryContent，直接使用（查看已保存的日记）
    if (widget.diaryContent != null) {
      _generatedContent = widget.diaryContent!;
      _showLoading = false; // 已有内容，不显示加载动画
    } else if (widget.diaryService != null) {
      // 开始流式生成
      _isGenerating = true;
      _showLoading = true; // 显示加载动画
      _startLoadingMessages(); // 开始切换加载提示
      _startGenerating();
    } else {
      _showLoading = false;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cursorAnimationController.dispose();
    _loadingAnimationController.dispose();
    _shimmerAnimationController.dispose();
    _orbController.dispose();
    _scrollController.dispose();
    _messageTimer?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  /// 开始切换加载提示信息
  void _startLoadingMessages() {
    final messages = [
      '正在连接 AI...',
      '十六正在构思...',
      '正在生成日记...',
      '马上就好...',
    ];
    int index = 0;

    _messageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isGenerating || !mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        index = (index + 1) % messages.length;
        _loadingMessage = messages[index];
      });
    });
  }

  /// 更新乱码缓冲区以匹配文本长度
  void _updateGibberish() {
    while (_gibberishBuffer.length < _fullTextBuffer.length) {
      _gibberishBuffer += _petSounds[_random.nextInt(_petSounds.length)];
    }
  }

  /// 开始流式生成日记
  Future<void> _startGenerating() async {
    try {
      final stream = widget.diaryService!.generatePetDiary(
        query: widget.originalText,
        style: widget.style,
        userId: 'pet_diary_user_${DateTime.now().millisecondsSinceEpoch}',
      );

      await for (final event in stream) {
        if (event is DiaryContentEvent) {
          if (mounted) {
            // 更新完整文本缓冲区
            final newText = event.fullText;
            
            // 第一次收到数据时，隐藏加载动画并开始打字效果
            if (_showLoading && newText.isNotEmpty) {
              _showLoading = false;
              _messageTimer?.cancel();
              _fullTextBuffer = newText;
              _updateGibberish(); // 生成对应的乱码
              _startTypingEffect();
            } else {
              // 后续数据到达时，直接更新缓冲区
              _fullTextBuffer = newText;
              _updateGibberish(); // 补充乱码
            }
          }
        } else if (event is DiaryDoneEvent) {
          if (mounted) {
            // 更新缓冲区为最终文本
            _fullTextBuffer = event.finalText;
            _updateGibberish();
            
            setState(() {
              _isGenerating = false;
              _generatedContent = event.finalText;
            });
            _messageTimer?.cancel();
            
            // 等待打字效果完成后再真正结束
          }
          break;
        } else if (event is DiaryErrorEvent) {
          if (mounted) {
            setState(() {
              _isGenerating = false;
              _showLoading = false;
            });
            _messageTimer?.cancel();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text('生成失败: ${event.error}')),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          break;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _showLoading = false;
        });
        _messageTimer?.cancel();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('生成失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  /// 开始打字和解码效果
  void _startTypingEffect() {
    _typingTimer?.cancel();
    
    // 50ms 刷新一次
    _typingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      bool needsUpdate = false;

      // 1. 打字机效果：增加显示的字符总数 (包含乱码)
      if (_displayedLength < _fullTextBuffer.length) {
        // 每次增加 1-3 个字符
        final remaining = _fullTextBuffer.length - _displayedLength;
        final charsToAdd = remaining > 50 ? 3 : (remaining > 20 ? 2 : 1);
        _displayedLength = (_displayedLength + charsToAdd).clamp(0, _fullTextBuffer.length);
        needsUpdate = true;
      }

      // 2. 解码效果：只有当乱码全部打完，且生成已完成时，才开始解码
      // 这样就实现了"先写完乱码，再翻译成人类语言"的效果
      bool typingFinished = _displayedLength >= _fullTextBuffer.length;
      bool generationFinished = !_isGenerating;

      if (typingFinished && generationFinished && _decodedLength < _fullTextBuffer.length) {
        // 解码速度
        final remaining = _fullTextBuffer.length - _decodedLength;
        // 加速解码，避免等待太久
        final decodeSpeed = remaining > 50 ? 3 : (remaining > 20 ? 2 : 1);
        
        _decodedLength = (_decodedLength + decodeSpeed).clamp(0, _fullTextBuffer.length);
        needsUpdate = true;
      }

      if (needsUpdate) {
        setState(() {
          // 拼接：已解码部分 + 未解码部分(乱码)
          // _buildDiaryContent 会根据 _decodedLength 和 _displayedLength 自动处理
        });

        // 自动滚动
        if (_displayedLength - _lastScrollLength >= 20 || 
            _displayedLength >= _fullTextBuffer.length) {
          _autoScrollToBottom();
          _lastScrollLength = _displayedLength;
        }
      } else if (!_isGenerating && _decodedLength == _fullTextBuffer.length) {
        // 全部生成完毕，且全部解码完毕
        timer.cancel();
        _typingTimer = null;
      }
    });
  }

  /// 自动滚动到底部
  void _autoScrollToBottom() {
    // 如果加载消息已经到了"马上就好..."，不再自动滚动
    if (_loadingMessage == '马上就好...') {
      return;
    }
    
    // 延迟滚动，避免与UI更新冲突
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      if (_scrollController.hasClients && _typingTimer != null) {
        // 使用 animateTo 但时长很短，既平滑又不抖动
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 保存日记到本地数据库
  Future<void> _saveDiary() async {
    // 如果还在生成中或没有内容，不允许保存
    if (_isGenerating || _generatedContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请等待日记生成完成'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    try {
      final diary = PetDiary(
        originalText: widget.originalText,
        content: _generatedContent,
        style: widget.style,
        timestamp: DateTime.now(),
      );

      final supabaseService = SupabaseService();
      final diaryId = await supabaseService.insertDiary(diary);
      if (diaryId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('保存失败，请检查网络连接'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isSaved = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('日记已保存到本地'),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              CupertinoIcons.back,
              color: Colors.black87,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '日记详情',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.share_outlined,
                color: Colors.black87,
                size: 20,
              ),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('分享功能开发中'),
                  backgroundColor: Colors.black87,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
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
                      width: 500, height: 500,
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
                      width: 350, height: 350,
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
                      width: 600, height: 400,
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
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 顶部 Kimi Ball
                      const Center(child: _KimiBall()),
                      const SizedBox(height: 20),

                      // 原始记录卡片
                      _buildOriginalCard(),

                      const SizedBox(height: 20),

                      // 十六的日记卡片
                      _buildDiaryCard(),

                      const SizedBox(height: 32),

                      // 操作按钮 - 只在加载完成后显示
                      if (!_showLoading)
                        _buildActionButtons(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginalCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B95FF).withOpacity(0.08),
                blurRadius: 20,
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B95FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_edu_outlined,
                          size: 14,
                          color: Color(0xFF7B95FF),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Original',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7B95FF),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.originalText,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.grey[700],
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiaryCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B95FF).withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 装饰性背景
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF7B95FF).withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题部分
                    Row(
                      children: [
                        // 宠物头像占位
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8EC5FC).withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.pets, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '十六的日记',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2D3142),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  '${DateTime.now().year}.${DateTime.now().month}.${DateTime.now().day} | AI 宠物视角',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 日记内容或加载动画
                    _showLoading ? _buildLoadingState() : _buildDiaryContent(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 加载动画状态
  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        
        // 简单的加载提示，因为顶部已经有 Kimi Ball 了
        Text(
          _loadingMessage,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 30),

        // 微光骨架屏 - 3行
        ...List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildShimmerBar(
              delay: index * 0.1, // 每条延迟0.1秒，产生波浪效果
            ),
          ),
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }

  /// 构建微光横条
  Widget _buildShimmerBar({double delay = 0}) {
    return AnimatedBuilder(
      animation: _shimmerAnimationController,
      builder: (context, child) {
        // 计算带延迟的动画进度
        final progress = (_shimmerAnimationController.value + delay) % 1.0;
        
        return Container(
          height: 10,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                0.0,
                progress - 0.3,
                progress,
                progress + 0.3,
                1.0,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
              colors: const [
                Color(0xFFE8EAF0), // 基础灰色
                Color(0xFFE8EAF0),
                Color(0xFFF5F7FA), // 微光高亮
                Color(0xFFE8EAF0),
                Color(0xFFE8EAF0),
              ],
            ),
          ),
        );
      },
    );
  }

  // 日记内容显示
  Widget _buildDiaryContent() {
    // 计算两部分的文本
    String decodedPart = '';
    String gibberishPart = '';
    
    if (_fullTextBuffer.isNotEmpty) {
      // 确保索引不越界
      final safeDecodedLen = _decodedLength.clamp(0, _fullTextBuffer.length);
      final safeDisplayedLen = _displayedLength.clamp(0, _fullTextBuffer.length);
      
      if (safeDecodedLen > 0) {
        decodedPart = _fullTextBuffer.substring(0, safeDecodedLen);
      }
      
      if (safeDisplayedLen > safeDecodedLen) {
        // 确保乱码缓冲区足够长
        if (_gibberishBuffer.length < safeDisplayedLen) {
          // 紧急补充乱码 (理论上 _updateGibberish 应该处理好了，但为了安全)
          while (_gibberishBuffer.length < safeDisplayedLen) {
            _gibberishBuffer += _petSounds[_random.nextInt(_petSounds.length)];
          }
        }
        gibberishPart = _gibberishBuffer.substring(safeDecodedLen, safeDisplayedLen);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _fullTextBuffer.isEmpty && _isGenerating
              ? const Text(
                  '等待生成中...',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.8,
                    color: Color(0xFF2D3142),
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w400,
                  ),
                )
              : RichText(
                  text: TextSpan(
                    children: [
                      // 已解码部分 (正常显示)
                      TextSpan(
                        text: decodedPart,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.8,
                          color: Color(0xFF2D3142),
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w400,
                          fontFamily: '.SF UI Text',
                        ),
                      ),
                      // 乱码部分 (特殊样式: 稍微淡一点，或者用特殊字体)
                      TextSpan(
                        text: gibberishPart,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.8,
                          color: const Color(0xFF7B95FF).withOpacity(0.8), // 使用主题色
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600, // 稍微加粗
                          fontFamily: 'Courier', // 等宽字体更有代码感/乱码感
                        ),
                      ),
                      // 打字光标
                      if (_isGenerating)
                        WidgetSpan(
                          child: FadeTransition(
                            opacity: _cursorAnimationController,
                            child: Container(
                              margin: const EdgeInsets.only(left: 2),
                              width: 2,
                              height: 20,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF7B95FF),
                                    Color(0xFF9B7FFF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 20),
        // 底部装饰：爪印签名
        Align(
          alignment: Alignment.centerRight,
          child: Opacity(
            opacity: 0.5,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Created by Peture AI',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[500],
                    fontFamily: 'Georgia', // 衬线体更有签名感
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.pets, size: 14, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: _isSaved
                  ? const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF7B95FF), Color(0xFF9B7FFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              boxShadow: [
                BoxShadow(
                  color:
                      (_isSaved
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF7B95FF))
                          .withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (_isSaved || _isGenerating) ? null : _saveDiary,
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isSaved ? Icons.check_circle : Icons.bookmark_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isSaved ? '已保存' : '保存日记',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF7B95FF), Color(0xFF9B7FFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B95FF).withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_outlined, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      '重新编辑',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
