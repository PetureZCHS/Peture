import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/supabase_edge_service.dart';
import '../../../shared/models/pet_diary.dart';
import '../../../services/supabase_service.dart';
import 'pet_diary_share_card.dart';

/// 宠物日记结果展示页面
class PetDiaryResultPage extends StatefulWidget {
  final String originalText;
  final String? diaryContent; // 可选，用于查看已保存的日记
  final String style;
  final PetDiaryEdgeService? diaryService; // 可选，用于生成新日记
  final String? initialContent;
  final String? nickname;
  final String? petId; // 关联的宠物ID
  final String? petName;
  final String? petAvatarUrl; // 新增：宠物头像
  final String? breed;
  final String? gender;
  final String? petType;

  const PetDiaryResultPage({
    super.key,
    required this.originalText,
    this.diaryContent,
    this.style = '小红书',
    this.diaryService,
    this.initialContent,
    this.nickname,
    this.petId,
    this.petName,
    this.petAvatarUrl,
    this.breed,
    this.gender,
    this.petType,
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
  Timer? _typingTimer; // 打字效果定时器
  int _displayedLength = 0; // 已显示的字符数
  int _lastScrollLength = 0; // 上次滚动时的字符数
  
  // 分享相关
  final GlobalKey _globalKey = GlobalKey();
  ShareCardStyle _currentShareStyle = ShareCardStyle.minimal;

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
    _scrollController.dispose();
    _messageTimer?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  /// 开始切换加载提示信息
  void _startLoadingMessages() {
    final petName = widget.petName ?? '十六';
    final messages = [
      '正在连接 AI...',
      '$petName正在构思...',
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

  /// 开始流式生成日记
  Future<void> _startGenerating() async {
    try {
      final stream = widget.diaryService!.generatePetDiary(
        query: widget.originalText,
        style: widget.style,
        nickname: widget.nickname,
        petName: widget.petName,
        breed: widget.breed,
        gender: widget.gender,
        petType: widget.petType,
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
              _startTypingEffect();
            } else {
              // 后续数据到达时，直接更新缓冲区
              // 打字定时器会自动追赶
              _fullTextBuffer = newText;
            }
          }
        } else if (event is DiaryDoneEvent) {
          if (mounted) {
            // 更新缓冲区为最终文本，让打字效果继续完成
            _fullTextBuffer = event.finalText;
            setState(() {
              _isGenerating = false;
              // 强制关闭 loading，防止卡在加载页(即使内容为空)
              if (_showLoading) {
                _showLoading = false;
                _messageTimer?.cancel();
                // 如果之前没触发打字效果（例如直接Done了），这里触发一下
                if (_fullTextBuffer.isNotEmpty) {
                   _startTypingEffect();
                }
              }
            });
            _messageTimer?.cancel();

            // 等待打字效果完成后再真正结束
            // 打字定时器会在显示完所有内容后自动停止
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

      // [防御性编程] 流结束后的最终状态检查
      // 防止因为 Stream 意外断开（如服务器关闭连接但未发DONE）而导致 UI 卡在 loading
      if (mounted && _isGenerating) {
        debugPrint('⚠️ 流传输异常结束（未收到完成或错误事件），执行强制终止');
        setState(() {
           _isGenerating = false;
           
           if (_showLoading) {
             _showLoading = false; 
             _messageTimer?.cancel();
             
             // 如果有累积的内容，即使断开也尝试显示出来
             if (_fullTextBuffer.isNotEmpty) {
               _startTypingEffect();
             } else {
               // 确实失败了
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('服务器连接不稳定，请稍后重试')),
                );
             }
           }
        });
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

  /// 开始打字效果
  void _startTypingEffect() {
    _typingTimer?.cancel();

    // 每次显示多个字符，实现更快的"流式"效果
    _typingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_displayedLength < _fullTextBuffer.length) {
        setState(() {
          // 计算还需要显示多少字符
          final remaining = _fullTextBuffer.length - _displayedLength;

          // 每次显示1-3个字符，让效果既流畅又不会太慢
          // 如果剩余字符很多，每次多显示几个字符加快追赶
          final charsToAdd = remaining > 50 ? 3 : (remaining > 20 ? 2 : 1);

          _displayedLength =
              (_displayedLength + charsToAdd).clamp(0, _fullTextBuffer.length);
          _generatedContent = _fullTextBuffer.substring(0, _displayedLength);
        });

        // 每显示约20个字符才滚动一次，进一步减少滚动频率
        if (_displayedLength - _lastScrollLength >= 20 ||
            _displayedLength >= _fullTextBuffer.length) {
          _autoScrollToBottom();
          _lastScrollLength = _displayedLength;
        }
      } else if (!_isGenerating) {
        // 如果已经显示完所有内容且生成已完成，停止定时器
        timer.cancel();
        _typingTimer = null;
      }
      // 如果还在生成中，即使显示完了当前内容，也继续运行
      // 因为可能还会有新数据到达
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
        petId: widget.petId,
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
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.share_outlined,
                color: Colors.black87,
                size: 20,
              ),
            ),
            onPressed: () {
              if (_showLoading || _generatedContent.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请等待生成完成')),
                );
                return;
              }
              _showShareDialog();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
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
                  // 原始记录卡片 - 简约设计
                  _buildOriginalCard(),

                  const SizedBox(height: 20),

                  // 十六的日记卡片 - 精致设计
                  _buildDiaryCard(),

                  const SizedBox(height: 32),

                  // 操作按钮 - 只在加载完成后显示
                  if (!_showLoading) _buildActionButtons(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示分享样式选择对话框
  void _showShareDialog() {
    // 确保有内容可分享
    if (_generatedContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在生成日记，请稍候...')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 顶部：标题 + 关闭
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '生成分享卡片',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      
                      const Divider(height: 1),

                      // 中间：卡片预览区 (可滚动)
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: RepaintBoundary(
                              key: _globalKey,
                              child: PetDiaryShareCard(
                                // 截断过长内容避免卡片太长
                                content: _generatedContent.length > 200 
                                    ? '${_generatedContent.substring(0, 200)}...' 
                                    : _generatedContent,
                                petName: widget.petName ?? '我的宠物',
                                avatarUrl: widget.petAvatarUrl,
                                breed: widget.breed,
                                gender: widget.gender,
                                date: DateTime.now(),
                                style: _currentShareStyle,
                                width: 300, 
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 底部：样式选择 + 按钮
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ShareCardStyle.values.map((style) {
                                  final isSelected = _currentShareStyle == style;
                                  return GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        _currentShareStyle = style;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.black87
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.transparent
                                              : Colors.grey.shade300,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Text(
                                        _getStyleName(style),
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 50,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('正在保存到相册...')),
                                          );
                                          await _captureAndSaveToGallery(inDialogContext: ctx);
                                        },
                                        icon: const Icon(Icons.download, color: Colors.blue),
                                        label: const Text(
                                          '保存相册', 
                                          style: TextStyle(
                                            fontSize: 16, 
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade50,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(25),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Builder(
                                      builder: (btnContext) {
                                        return SizedBox(
                                          height: 50,
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('正在生成图片并分享...')),
                                              );
                                              
                                              final box = btnContext.findRenderObject() as RenderBox?;
                                              Rect? shareOrigin;
                                              if (box != null) {
                                                shareOrigin = box.localToGlobal(Offset.zero) & box.size;
                                              }
                                              
                                              await _captureAndSharePng(
                                                inDialogContext: ctx, 
                                                shareOrigin: shareOrigin,
                                              );
                                            },
                                            icon: const Icon(Icons.share, color: Colors.white),
                                            label: const Text(
                                              '分享', 
                                              style: TextStyle(
                                                fontSize: 16, 
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.black87,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(25),
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getStyleName(ShareCardStyle style) {
    switch (style) {
      case ShareCardStyle.minimal:
        return '极简艺术';
      case ShareCardStyle.paper:
        return '手账笔记';
    }
  }

  Future<void> _captureAndSharePng({BuildContext? inDialogContext, Rect? shareOrigin}) async {
    try {
      // 确保重绘
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        debugPrint('无法获取截图边界');
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('生成的太快了，请稍后再试')),
           );
        }
        return;
      }

      // 提高清晰度
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      
      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/pet_diary_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      // 截图成功后，关闭弹窗
      if (inDialogContext != null && inDialogContext.mounted) {
        Navigator.pop(inDialogContext);
      }
      
      // 调起分享
      final xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile], 
        text: '来自 Peture 的宠物日记 🐾',
        sharePositionOrigin: shareOrigin,
      );

    } catch (e) {
      debugPrint('分享失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  Future<void> _captureAndSaveToGallery({BuildContext? inDialogContext}) async {
    try {
      // 确保重绘
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取截图边界')),
           );
        }
        return;
      }

      // 提高清晰度
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      
      final pngBytes = byteData.buffer.asUint8List();

      // 保存到相册
      await Gal.putImageBytes(pngBytes);
      
      // 截图成功后，关闭弹窗
      if (inDialogContext != null && inDialogContext.mounted) {
        Navigator.pop(inDialogContext);
      }

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('图片已保存到相册'),
              backgroundColor: Colors.green,
            ),
         );
      }
    } catch (e) {
      debugPrint('保存失败: $e');
      if (mounted) {
        // 如果是 gal 抛出的异常，可能是权限或不支持
        String message = '保存失败，请检查相册权限';
        if (e is GalException) {
           message = '保存失败: ${e.type.message}';
        } else {
           message = '保存失败: $e';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildOriginalCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7B95FF).withOpacity(0.15),
                      const Color(0xFF9B7FFF).withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_edu_outlined,
                  size: 20,
                  color: Color(0xFF7B95FF),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '原始记录',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3142),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.originalText,
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: Colors.grey[600],
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0F4FF), Color(0xFFE8EEFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B95FF).withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 装饰性图案
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
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
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF9B7FFF).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 内容
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题部分
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.petName ?? "十六"}正在写日记',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7B95FF),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.petName == null ? "Sixteen" : "Pet"}\'s Diary',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9B7FFF),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),

                  ],
                ),

                const SizedBox(height: 20),

                // 日记内容或加载动画
                _showLoading ? _buildLoadingState() : _buildDiaryContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 加载动画状态
  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),

        // "正在写日记"动画 - 呼吸 + 粒子闪烁 + 书写晃动
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 呼吸光晕 - 外层脉冲
              AnimatedBuilder(
                animation: _shimmerAnimationController,
                builder: (context, child) {
                  final breathe = 1.0 +
                      0.15 *
                          math.sin(
                              2 * math.pi * _shimmerAnimationController.value);
                  return Transform.scale(
                    scale: breathe,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF7B95FF).withOpacity(0.3),
                            const Color(0xFF9B7FFF).withOpacity(0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // 中层呼吸光晕
              AnimatedBuilder(
                animation: _shimmerAnimationController,
                builder: (context, child) {
                  final breathe = 1.0 +
                      0.1 *
                          math.sin(
                              2 * math.pi * _shimmerAnimationController.value +
                                  0.5);
                  return Transform.scale(
                    scale: breathe,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF9B7FFF).withOpacity(0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // 主体 - 书写晃动 + 呼吸
              AnimatedBuilder(
                animation: Listenable.merge(
                    [_loadingAnimationController, _shimmerAnimationController]),
                builder: (context, child) {
                  // 书写晃动效果 - 模拟手写时的轻微摆动
                  final tilt = 0.08 *
                      math.sin(4 * math.pi * _loadingAnimationController.value);
                  // 轻微呼吸
                  final breathe = 1.0 +
                      0.05 *
                          math.sin(
                              2 * math.pi * _shimmerAnimationController.value);

                  return Transform.rotate(
                    angle: tilt,
                    child: Transform.scale(
                      scale: breathe,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF7B95FF),
                              Color(0xFF9B7FFF),
                              Color(0xFFB896FF),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(38),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B95FF).withOpacity(0.5),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                              spreadRadius: 3,
                            ),
                            BoxShadow(
                              color: const Color(0xFF9B7FFF).withOpacity(0.4),
                              blurRadius: 50,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 主图标（稍微缩小，为粒子留空间）
                            const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 48,
                            ),
                            // 粒子闪烁效果 - 三个小星星
                            ..._buildSparkleParticles(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // 主标题 - 动态变化的提示
        Text(
          _loadingMessage,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D3142),
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 40),

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

  /// 构建闪烁粒子效果 - 三个小星星轮流闪烁
  List<Widget> _buildSparkleParticles() {
    return List.generate(3, (index) {
      // 每个星星有不同的延迟和位置
      final positions = [
        const Offset(25, -25), // 右上
        const Offset(-30, -20), // 左上
        const Offset(28, 20), // 右下
      ];

      return AnimatedBuilder(
        animation: _loadingAnimationController,
        builder: (context, child) {
          // 计算闪烁：每个星星在不同时间闪烁
          final phase =
              (_loadingAnimationController.value + index * 0.33) % 1.0;
          // 使用正弦波创建平滑的闪烁效果
          final opacity = 0.3 + 0.7 * math.sin(phase * 2 * math.pi).abs();
          final scale = 0.8 + 0.4 * math.sin(phase * 2 * math.pi).abs();

          return Positioned(
            left: 70 + positions[index].dx,
            top: 70 + positions[index].dy,
            child: Transform.scale(
              scale: scale,
              child: Icon(
                Icons.star,
                color: Colors.white.withOpacity(opacity),
                size: 12,
              ),
            ),
          );
        },
      );
    });
  }

  // 日记内容显示
  Widget _buildDiaryContent() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _generatedContent.isEmpty
              ? const Text(
                  '等待生成中...',
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 2.0,
                    color: Color(0xFF2D3142),
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w400,
                  ),
                )
              : RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _generatedContent,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 2.0,
                          color: Color(0xFF2D3142),
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w400,
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
                  color: (_isSaved
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
