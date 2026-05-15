import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/page_tracker_mixin.dart';
import '../../../services/supabase_edge_service.dart';
import '../../../shared/models/pet_diary.dart';
import '../../../services/supabase_service.dart';
import '../../content_feedback/domain/content_feedback_kind.dart';
import '../../content_feedback/presentation/content_feedback_bar.dart';
import '../../content_feedback/utils/content_ref_digest.dart';
import 'pet_diary_share_card.dart';

// ========== 水印配置 ==========
const String _watermarkText = '智宠合生 Peture AI 生成';

class _WatermarkMetrics {
  final double horizontalPadding;
  final double verticalPadding;
  final double textPaddingH;
  final double textPaddingV;
  final double fontSize;
  final double letterSpacing;
  final double blurRadius;
  final Offset shadowOffset;
  final double borderRadius;

  const _WatermarkMetrics({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.textPaddingH,
    required this.textPaddingV,
    required this.fontSize,
    required this.letterSpacing,
    required this.blurRadius,
    required this.shadowOffset,
    required this.borderRadius,
  });
}

_WatermarkMetrics _computeWatermarkMetrics(Size imageSize) {
  final ratio = imageSize.width / math.max(1.0, imageSize.height);
  final isSixteenByNine = (ratio - (16 / 9)).abs() <= 0.03;
  final scale = (imageSize.shortestSide / 1080.0).clamp(0.2, 1.5).toDouble();
  final fontBoost = isSixteenByNine ? 2.0 : 1.0;
  return _WatermarkMetrics(
    horizontalPadding: 24.0 * scale,
    verticalPadding: 16.0 * scale,
    textPaddingH: 14.0 * scale,
    textPaddingV: 8.0 * scale,
    fontSize: 30.0 * scale * fontBoost,
    letterSpacing: 0.4 * scale,
    blurRadius: 6.0 * scale,
    shadowOffset: Offset(0, 1.5 * scale),
    borderRadius: 14.0 * scale,
  );
}

double _computeWatermarkTextFitScale({
  required String text,
  required double maxTextWidth,
  required double fontSize,
  required double letterSpacing,
}) {
  final safeMaxWidth = math.max(1.0, maxTextWidth);
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: letterSpacing,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  if (painter.width <= safeMaxWidth) {
    return 1.0;
  }

  return (safeMaxWidth / painter.width).clamp(0.45, 1.0);
}

Widget _buildWatermarkOverlay(BoxConstraints constraints) {
  final imageSize = Size(constraints.maxWidth, constraints.maxHeight);
  final metrics = _computeWatermarkMetrics(imageSize);
  final maxTextWidth = (imageSize.width * 0.75) - (metrics.textPaddingH * 2);
  final textFitScale = _computeWatermarkTextFitScale(
    text: _watermarkText,
    maxTextWidth: maxTextWidth,
    fontSize: metrics.fontSize,
    letterSpacing: metrics.letterSpacing,
  );

  return Positioned(
    right: metrics.horizontalPadding,
    bottom: metrics.verticalPadding,
    child: IgnorePointer(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.textPaddingH,
          vertical: metrics.textPaddingV,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.22),
          borderRadius: BorderRadius.circular(metrics.borderRadius),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.max(1, maxTextWidth),
          ),
          child: Text(
            _watermarkText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: metrics.fontSize * textFitScale,
              fontWeight: FontWeight.w600,
              letterSpacing: metrics.letterSpacing * textFitScale,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: metrics.blurRadius * textFitScale,
                  offset: metrics.shadowOffset * textFitScale,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// 宠物日记结果展示页面
class PetDiaryResultPage extends StatefulWidget {
  final String originalText;
  final String? diaryContent; // 可选，用于查看已保存的日记
  final String style;
  final PetDiaryEdgeService? diaryService; // 可选，用于生成新日记
  final String? initialContent;
  final String? nickname; // diary-v4: 宠物昵称
  final String? ownerTitle; // diary-v4: 对主人的称呼
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
    this.ownerTitle,
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
    with TickerProviderStateMixin, PageTrackerMixin<PetDiaryResultPage> {
  late AnimationController _animationController;
  late AnimationController _cursorAnimationController; // 光标闪烁
  late AnimationController _loadingAnimationController; // 加载动画
  late AnimationController _shimmerAnimationController; // 微光动画
  late ScrollController _scrollController; // 滚动控制器
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isSaved = false; // 标记是否已保存
  bool _isSaving = false; // 标记是否正在保存中
  bool _isGenerating = false; // 是否正在生成
  bool _showLoading = true; // 是否显示加载动画
  String _generatedContent = ''; // 生成的内容
  String _loadingMessage = '正在连接 AI...'; // 加载提示信息
  Timer? _messageTimer; // 提示信息定时器
  String _fullTextBuffer = ''; // 完整文本缓冲区
  Timer? _typingTimer; // 打字效果定时器
  int _displayedLength = 0; // 已显示的字符数
  int _lastScrollLength = 0; // 上次滚动时的字符数

  // AI 生图相关
  bool _showGenerateImageButton = true;
  bool _isImageGenerating = false;
  bool _showRetryImageButton = false;
  String _imageLoadingMessage = '正在分析日记画面...';
  String? _generatedDiaryImagePath;
  bool _isImageSavedToGallery = false; // 标记图片是否已保存到相册
  File? _generatedDiaryImageFile;
  Timer? _imageMessageTimer;

  // AI 生图进度条相关（模仿 loading_page.dart）
  late AnimationController _imageProgressController;
  static const int _imageGenerationDurationSeconds = 45; // 预期生图时间

  // 分享相关
  final GlobalKey _globalKey = GlobalKey();
  final GlobalKey _imageWithWatermarkKey = GlobalKey();
  ShareCardStyle _currentShareStyle = ShareCardStyle.minimal;

  // 日记ID（用于保存后更新图片）
  String? _diaryId;

  @override
  String get analyticsPageName => 'diary_result';

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

    // AI 生图进度条控制器（模仿 loading_page.dart）
    _imageProgressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _imageGenerationDurationSeconds),
    );

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
    _imageProgressController.dispose();
    _scrollController.dispose();
    _messageTimer?.cancel();
    _imageMessageTimer?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _startImageLoadingMessages() {
    _imageMessageTimer?.cancel();
    final messages = [
      '正在分析日记画面...',
      'AI 正在构图与打光...',
      '正在渲染毛发与细节...',
      '即将生成完成...',
    ];
    var index = 0;
    _imageLoadingMessage = messages[index];

    _imageMessageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isImageGenerating || !mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        index = (index + 1) % messages.length;
        _imageLoadingMessage = messages[index];
      });
    });
  }

  Future<void> _generateDiaryImage() async {
    if (_isImageGenerating) return;
    if (_generatedContent.isEmpty ||
        widget.petId == null ||
        widget.petId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前缺少宠物或日记信息，暂时无法生图')),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录状态已失效，请重新登录后再试')),
      );
      return;
    }

    try {
      final petRecord = await supabase
          .from('pets')
          .select('id, life_photo')
          .eq('id', widget.petId!)
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (petRecord == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前宠物不存在，或不属于当前账号')),
          );
        }
        return;
      }

      // Debug: 打印前端查询到的宠物记录，帮助确认前端看到的数据
      try {
        debugPrint('⟡ precheck petRecord=$petRecord');
        debugPrint('⟡ precheck life_photo=${petRecord['life_photo'] ?? ''}');
      } catch (_) {}

      final lifePhoto = (petRecord['life_photo'] ?? '').toString();
      if (lifePhoto.isEmpty) {
        if (mounted) {
          // 显示上传生活照引导弹窗
          final uploadSuccess = await _showUploadLifePhotoSheet();
          if (!uploadSuccess) {
            // 用户取消上传或未成功，不继续生成
            return;
          }
          // 上传成功，重新获取宠物记录以拿到最新的 life_photo
          final refreshedPet = await supabase
              .from('pets')
              .select('id, life_photo')
              .eq('id', widget.petId!)
              .eq('user_id', currentUserId)
              .maybeSingle();
          if (refreshedPet == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('获取宠物信息失败，请稍后重试')),
              );
            }
            return;
          }
          // 继续执行生成逻辑（Edge Function 会从服务端重新读取 life_photo）
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('宠物信息校验失败，请稍后重试')),
        );
      }
      return;
    }

    setState(() {
      _showGenerateImageButton = false;
      _showRetryImageButton = false;
      _isImageGenerating = true;
      _generatedDiaryImagePath = null;
      _generatedDiaryImageFile = null;
      _imageLoadingMessage = '正在分析日记画面...';
    });
    _startImageLoadingMessages();

    // 启动进度条动画（从 0% 到 95%，完成后快速到 100%）
    _imageProgressController.reset();
    _imageProgressController.animateTo(0.95,
        duration: const Duration(seconds: _imageGenerationDurationSeconds),
        curve: Curves.decelerate);

    try {
      debugPrint(
          '⟡ diary-gen-image invoke -> petId=${widget.petId} userId=$currentUserId');

      final res = await supabase.functions.invoke(
        'diary-gen-image',
        body: {
          'pet_id': widget.petId,
          'diary_content': _generatedContent,
        },
      );

      debugPrint('⟡ diary-gen-image invoke returned: status=${res.status}');
      try {
        debugPrint('⟡ response.data=${res.data}');
      } catch (_) {}

      final data = res.data;
      if (data == null || data is! Map) {
        throw Exception('服务端返回格式错误');
      }

      final status = (data['status'] as String? ?? '').toUpperCase();
      final error = data['error']?.toString();
      if (res.status == 429 || status == 'TOO_FREQUENT') {
        final retryAfterMs = data['retry_after_ms'] as int?;
        final seconds =
            retryAfterMs == null ? null : (retryAfterMs / 1000).ceil();
        throw Exception(
            seconds == null ? '请求过于频繁，请稍后重试' : '请求过于频繁，请 $seconds 秒后重试');
      }
      if (error != null && status != 'SUCCEED') {
        throw Exception(error);
      }
      if (status != 'SUCCEED') {
        throw Exception('AI 生图失败，未返回成功状态');
      }

      final path = data['path'] as String?;
      if (path == null || path.isEmpty) {
        throw Exception('服务端未返回图片路径');
      }

      final bytes = await supabase.storage.from('ai-wallpapers').download(path);
      if (bytes.isEmpty) {
        throw Exception('图片下载失败');
      }

      final tmpFile = File(
        '${Directory.systemTemp.path}/diary_gen_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tmpFile.writeAsBytes(bytes, flush: true);

      // 完成时进度条快速到 100%
      await _imageProgressController.animateTo(1.0,
          duration: const Duration(milliseconds: 500), curve: Curves.easeOut);

      if (!mounted) return;
      setState(() {
        _isImageGenerating = false;
        _showRetryImageButton = false;
        _generatedDiaryImagePath = path;
        _generatedDiaryImageFile = tmpFile;
      });
      _imageMessageTimer?.cancel();
      _autoScrollToBottom();

      // If diary was already saved, update it with the new image path
      if (_isSaved && _diaryId != null) {
        await _updateDiaryImagePath(_diaryId!, path);
      }
    } on FunctionException catch (fe, st) {
      debugPrint(
          '⟡ FunctionException(status=${fe.status}) details=${fe.details} reason=${fe.reasonPhrase}');
      debugPrint(st.toString());
      _imageProgressController.stop();
      if (!mounted) return;
      setState(() {
        _isImageGenerating = false;
        _showRetryImageButton = true;
      });
      _imageMessageTimer?.cancel();
      final detailMsg =
          fe.details != null ? fe.details.toString() : fe.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 生图失败: $detailMsg')),
      );
    } catch (e, st) {
      debugPrint('⟡ diary-gen-image unknown error: $e');
      debugPrint(st.toString());
      _imageProgressController.stop();
      if (!mounted) return;
      setState(() {
        _isImageGenerating = false;
        _showRetryImageButton = true;
      });
      _imageMessageTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 生图失败: $e')),
      );
    }
  }

  /// 显示上传生活照引导弹窗
  /// 返回 true 表示上传成功，可以继续生成；false 表示取消或未成功
  Future<bool> _showUploadLifePhotoSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _UploadLifePhotoSheet(
          petId: widget.petId!,
          petName: widget.petName ?? '宠物',
        );
      },
    );
    return result ?? false;
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
        ownerTitle: widget.ownerTitle,
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
          // 使用 Characters 来正确处理 Unicode 字符（避免截断 emoji）
          final characters = _fullTextBuffer.characters;
          _generatedContent = characters.take(_displayedLength).toString();
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

    setState(() {
      _isSaving = true;
    });

    try {
      final diary = PetDiary(
        petId: widget.petId,
        originalText: widget.originalText,
        content: _generatedContent,
        style: widget.style,
        timestamp: DateTime.now(),
        aiImg: _generatedDiaryImagePath,
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
          _diaryId = diaryId;
        });
        // 保存成功后只更新按钮状态，不显示 SnackBar
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
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// 更新日记的AI配图路径
  Future<void> _updateDiaryImagePath(String diaryId, String aiImgPath) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('pet_diaries')
          .update({
            'ai_img': aiImgPath,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', diaryId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('更新日记图片路径失败: $e');
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

                  // AI 生成配图区域 - 在保存/编辑按钮上方
                  if (!_showLoading) _buildAiImageSection(),

                  if (!_showLoading && !_isGenerating && !_isImageGenerating)
                    const SizedBox(height: 16),

                  // 操作按钮 - 保存日记和重新编辑按钮
                  // 只在日记加载完成且不在AI生图过程中显示
                  if (!_showLoading && !_isGenerating && !_isImageGenerating)
                    _buildActionButtons(),

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
                                content: _generatedContent,
                                petName: widget.petName ?? '我的宠物',
                                avatarUrl: widget.petAvatarUrl,
                                breed: widget.breed,
                                gender: widget.gender,
                                date: DateTime.now(),
                                style: _currentShareStyle,
                                width: 300,
                                diaryImageFile: _generatedDiaryImageFile,
                                diaryImageUrl: _generatedDiaryImagePath,
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
                                  final isSelected =
                                      _currentShareStyle == style;
                                  return GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        _currentShareStyle = style;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
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
                                                  color: Colors.black
                                                      .withOpacity(0.2),
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
                                          await _captureAndSaveToGallery(
                                              inDialogContext: ctx);
                                        },
                                        icon: const Icon(Icons.download,
                                            color: Colors.blue),
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
                                            borderRadius:
                                                BorderRadius.circular(25),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Builder(builder: (btnContext) {
                                      return SizedBox(
                                        height: 50,
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content:
                                                      Text('正在生成图片并分享...')),
                                            );

                                            final box =
                                                btnContext.findRenderObject()
                                                    as RenderBox?;
                                            Rect? shareOrigin;
                                            if (box != null) {
                                              shareOrigin = box.localToGlobal(
                                                      Offset.zero) &
                                                  box.size;
                                            }

                                            await _captureAndSharePng(
                                              inDialogContext: ctx,
                                              shareOrigin: shareOrigin,
                                            );
                                          },
                                          icon: const Icon(Icons.share,
                                              color: Colors.white),
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
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
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

  Future<void> _captureAndSharePng(
      {BuildContext? inDialogContext, Rect? shareOrigin}) async {
    try {
      // 确保重绘
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _globalKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

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
      final file = File(
          '${tempDir.path}/pet_diary_share_${DateTime.now().millisecondsSinceEpoch}.png');
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

  Future<void> _saveImageWithWatermarkToGallery() async {
    try {
      if (_generatedDiaryImageFile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片尚未生成')),
          );
        }
        return;
      }

      final boundary = _imageWithWatermarkKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取图片边界')),
          );
        }
        return;
      }

      // Capture at pixelRatio 3.0 for high quality
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片编码失败')),
          );
        }
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();
      await Gal.putImageBytes(pngBytes);

      if (mounted) {
        setState(() {
          _isImageSavedToGallery = true;
        });
      }
    } catch (e) {
      debugPrint('保存带水印图片失败: $e');
      if (mounted) {
        String message = '保存失败，请检查保存权限设置';
        if (e is GalException) {
          message = '保存失败: ${e.type.message}';
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

  Future<void> _captureAndSaveToGallery({BuildContext? inDialogContext}) async {
    try {
      // 确保重绘
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _globalKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

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
        setState(() {
          _isImageSavedToGallery = true;
        });
      }
    } catch (e) {
      debugPrint('保存失败: $e');
      if (mounted) {
        // 如果是 gal 抛出的异常，可能是权限或不支持
        String message = '保存失败，请检查保存权限设置';
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
                if (!_showLoading && _generatedContent.isNotEmpty)
                  ContentFeedbackBar(
                    surface: ContentSurface.petDiary,
                    ref: _diaryFeedbackRef(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _diaryFeedbackRef() {
    if (_diaryId != null) {
      return {'diary_id': _diaryId};
    }
    return {
      'content_sha256': contentDigestSha256(_generatedContent),
      'style': widget.style,
    };
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
                      ..._buildHashtagSpans(_generatedContent),
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

  /// 解析文本中的 #标签，生成带样式的 InlineSpan 列表（小红书风格蓝色标签）
  List<InlineSpan> _buildHashtagSpans(String text) {
    const baseStyle = TextStyle(
      fontSize: 15.5,
      height: 2.0,
      color: Color(0xFF2D3142),
      letterSpacing: 0.5,
      fontWeight: FontWeight.w400,
    );
    const hashtagStyle = TextStyle(
      fontSize: 15.5,
      height: 2.0,
      color: Color(0xFF2196F3), // 小红书风格的蓝色
      letterSpacing: 0.5,
      fontWeight: FontWeight.w500,
    );

    final List<InlineSpan> spans = [];
    final RegExp hashtagRegExp = RegExp(r'#[\w\u4e00-\u9fa5]+');
    int currentIndex = 0;

    for (final match in hashtagRegExp.allMatches(text)) {
      // 添加标签前的普通文本
      if (match.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: baseStyle,
        ));
      }
      // 添加蓝色标签
      spans.add(TextSpan(
        text: match.group(0),
        style: hashtagStyle,
      ));
      currentIndex = match.end;
    }

    // 添加剩余的普通文本
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: baseStyle,
      ));
    }

    return spans;
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: _isSaving
                  ? const LinearGradient(
                      colors: [Color(0xFFB0B8C9), Color(0xFF9CA3B0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : _isSaved
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
                  color: (_isSaving
                          ? const Color(0xFF9CA3B0)
                          : _isSaved
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
                onTap: (_isSaved || _isGenerating || _isSaving)
                    ? null
                    : _saveDiary,
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            _isSaved
                                ? Icons.check_circle
                                : Icons.bookmark_outline,
                            color: Colors.white,
                            size: 22,
                          ),
                    const SizedBox(width: 8),
                    Text(
                      _isSaving ? '正在保存' : (_isSaved ? '已保存' : '保存日记'),
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

  Widget _buildAiImageSection() {
    final canGenerateAiImage = !_isGenerating && !_isImageGenerating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 流式输出过程中不显示 AI 生成配图按钮
        if (_showGenerateImageButton && !_isGenerating)
          Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: AnimatedBuilder(
              animation: _loadingAnimationController,
              builder: (context, child) {
                final shimmerPos =
                    -1.0 + (_loadingAnimationController.value * 3.0);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                              width: 1.2,
                            ),
                            gradient: RadialGradient(
                              radius: 1.8,
                              center: Alignment.topCenter,
                              colors: [
                                Colors.white.withOpacity(0.25),
                                Colors.white.withOpacity(0.5),
                                Colors.white.withOpacity(0.7),
                              ],
                              stops: const [0.0, 0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: LinearGradient(
                          colors: canGenerateAiImage
                              ? const [
                                  Color(0xFF7C3AED),
                                  Color(0xFF6366F1),
                                  Color(0xFFEC4899),
                                ]
                              : const [
                                  Color(0xFFBFC4D4),
                                  Color(0xFFAEB5C7),
                                ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (canGenerateAiImage
                                    ? const Color(0xFF7C3AED)
                                    : const Color(0xFF9CA3AF))
                                .withOpacity(0.24),
                            blurRadius: 20,
                            spreadRadius: -2,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Align(
                                alignment: Alignment(shimmerPos, 0),
                                child: FractionallySizedBox(
                                  widthFactor: 0.35,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.transparent,
                                          Colors.white.withOpacity(
                                              canGenerateAiImage ? 0.1 : 0.05),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: canGenerateAiImage
                                  ? _generateDiaryImage
                                  : null,
                              borderRadius: BorderRadius.circular(26),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.auto_awesome,
                                        color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'AI 生成配图',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        fontSize: 16,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black45,
                                            offset: Offset(0, 1),
                                            blurRadius: 2.5,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        if (_showRetryImageButton && !_isImageGenerating)
          Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _generateDiaryImage,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                '重试 AI 生成配图',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ),
          ),
        if (_isImageGenerating) _buildDiaryImageLoadingCard(),
        if (_generatedDiaryImageFile != null) ...[
          const SizedBox(height: 8),
          _buildGeneratedImageCard(),
          // 注意：AI 生图完成后，保存/编辑按钮由主布局在 _buildAiImageSection 之后统一显示
        ],
      ],
    );
  }

  Widget _buildDiaryImageLoadingCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Glassmorphism loading container - 模仿 loading_page.dart 样式
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.7),
                      width: 1.5,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.6),
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.15),
                      ],
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Gradient progress ring - 使用 _imageProgressController 实现 0-100% 进度
                      AnimatedBuilder(
                        animation: _imageProgressController,
                        builder: (context, child) {
                          return SizedBox(
                            width: 150,
                            height: 150,
                            child: CustomPaint(
                              painter: _GradientProgressPainter(
                                progress: _imageProgressController.value,
                                gradientColors: const [
                                  Color(0xFF7C3AED),
                                  Color(0xFF6366F1),
                                  Color(0xFFEC4899),
                                ],
                                strokeWidth: 10,
                                backgroundColor: Colors.white.withOpacity(0.3),
                              ),
                            ),
                          );
                        },
                      ),
                      // Inner glow ring
                      SizedBox(
                        width: 134,
                        height: 134,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF7C3AED).withOpacity(0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Center content - paw icon
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _shimmerAnimationController,
                            builder: (context, child) {
                              final scale = 1.0 +
                                  (_shimmerAnimationController.value * 0.1);
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF7C3AED),
                                        Color(0xFF6366F1),
                                        Color(0xFFEC4899),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF7C3AED)
                                            .withOpacity(0.3),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.pets,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          // Percentage display - 使用 _imageProgressController 显示真实进度百分比
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFF7C3AED),
                                Color(0xFF6366F1),
                                Color(0xFFEC4899),
                              ],
                            ).createShader(bounds),
                            child: AnimatedBuilder(
                              animation: _imageProgressController,
                              builder: (context, child) {
                                final percentage =
                                    (_imageProgressController.value * 100)
                                        .toInt();
                                return Text(
                                  "$percentage%",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -1,
                                    height: 1,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _imageLoadingMessage,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D3142),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPulsingDot(),
              const SizedBox(width: 8),
              const Text(
                "AI 创作中",
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingDot() {
    return AnimatedBuilder(
      animation: _shimmerAnimationController,
      builder: (context, child) {
        final scale = 1.0 + (_shimmerAnimationController.value * 0.3);
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF7C3AED),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(
                    0.5 - (_shimmerAnimationController.value * 0.3)),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Transform.scale(
            scale: scale,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF7C3AED),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGeneratedImageCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_fix_high,
                      color: Color(0xFF6366F1), size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'AI 日记配图',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ],
            ),
          ),
          // 图片区域 - 添加点击预览功能
          GestureDetector(
            onTap: () {
              if (_generatedDiaryImageFile != null) {
                Navigator.of(context).push(
                  _TransparentImageRoute(
                    builder: (_) => _FullscreenImagePage(
                      imageFile: _generatedDiaryImageFile!,
                      heroTag: 'diary_generated_image',
                    ),
                  ),
                );
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: LayoutBuilder(
                  builder: (context, constraints) => RepaintBoundary(
                    key: _imageWithWatermarkKey,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Hero(
                            tag: 'diary_generated_image',
                            child: Image.file(
                              _generatedDiaryImageFile!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFFF3F4F6),
                                  alignment: Alignment.center,
                                  child: const Text('图片加载失败'),
                                );
                              },
                            ),
                          ),
                        ),
                        _buildWatermarkOverlay(constraints),
                        // 添加点击提示图标
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 保存按钮区域 - 移除文件名，只保留保存按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _isImageSavedToGallery
                      ? null
                      : _saveImageWithWatermarkToGallery,
                  icon: Icon(
                    _isImageSavedToGallery
                        ? Icons.check
                        : Icons.download_rounded,
                    size: 16,
                  ),
                  label: Text(_isImageSavedToGallery ? '已保存到相册' : '保存到相册'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isImageSavedToGallery ? Colors.green : null,
                    foregroundColor:
                        _isImageSavedToGallery ? Colors.white : null,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
}

/// 渐变进度环绘制器 - 用于 AI 图像生成 loading 动画
class _GradientProgressPainter extends CustomPainter {
  final double progress;
  final List<Color> gradientColors;
  final double strokeWidth;
  final Color backgroundColor;

  _GradientProgressPainter({
    required this.progress,
    required this.gradientColors,
    required this.strokeWidth,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Draw progress arc with gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      colors: gradientColors,
      stops: const [0.0, 0.5, 1.0],
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + 2 * math.pi,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 透明图片路由 - 用于全屏预览
class _TransparentImageRoute extends PageRouteBuilder {
  final WidgetBuilder builder;

  _TransparentImageRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Enter: fade + scale up
            final enterAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            // Check if we're exiting (secondary animation is running)
            if (secondaryAnimation.value > 0) {
              final exitProgress = 1.0 - secondaryAnimation.value;
              return Opacity(
                opacity: exitProgress,
                child: Transform.scale(
                  scale: 0.95 + (0.05 * exitProgress),
                  child: child,
                ),
              );
            }

            // Entering animation
            final progress = enterAnimation.value;
            final opacity = progress;
            final scale = 0.9 + (0.1 * progress);

            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          },
        );
}

/// 全屏图片预览页面 - 复用 result_page.dart 的实现
class _FullscreenImagePage extends StatefulWidget {
  final File imageFile;
  final String heroTag;

  const _FullscreenImagePage({
    required this.imageFile,
    required this.heroTag,
  });

  @override
  State<_FullscreenImagePage> createState() => _FullscreenImagePageState();
}

class _FullscreenImagePageState extends State<_FullscreenImagePage>
    with SingleTickerProviderStateMixin {
  double dragOffsetY = 0;
  late AnimationController _controller;
  late Animation<double> _reboundAnimation;

  static const double dismissThreshold = 150;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    super.dispose();
  }

  void _runReboundAnimation() {
    _reboundAnimation =
        Tween<double>(begin: dragOffsetY, end: 0).animate(_controller)
          ..addListener(() {
            setState(() {
              dragOffsetY = _reboundAnimation.value;
            });
          });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dragPercent = (dragOffsetY / screenHeight).clamp(0.0, 1.0);
    final scale = 1.0 - dragPercent * 0.4;
    final bgOpacity = (1.0 - dragPercent).clamp(0.0, 1.0);

    return Stack(
      children: [
        Opacity(
          opacity: bgOpacity,
          child: Container(color: Colors.black),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            onVerticalDragUpdate: (details) {
              setState(() {
                dragOffsetY += details.delta.dy;
                if (dragOffsetY < 0) dragOffsetY = 0;
              });
            },
            onVerticalDragEnd: (_) {
              if (dragOffsetY > dismissThreshold) {
                Navigator.pop(context);
              } else {
                _runReboundAnimation();
              }
            },
            child: Transform.translate(
              offset: Offset(0, dragOffsetY),
              child: Transform.scale(
                scale: scale,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Hero(
                    tag: widget.heroTag,
                    child: _FullscreenImageWithWatermark(
                      imageFile: widget.imageFile,
                      heroTag: widget.heroTag,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 全屏预览图片组件 - 带水印（模仿 result_page.dart 的 _ContainedImageWithWatermark）
class _FullscreenImageWithWatermark extends StatefulWidget {
  final File imageFile;
  final String heroTag;

  const _FullscreenImageWithWatermark({
    required this.imageFile,
    required this.heroTag,
  });

  @override
  State<_FullscreenImageWithWatermark> createState() =>
      _FullscreenImageWithWatermarkState();
}

class _FullscreenImageWithWatermarkState
    extends State<_FullscreenImageWithWatermark> {
  ImageStream? _imageStream;
  ImageStreamListener? _listener;
  double? _aspectRatio;
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _FullscreenImageWithWatermark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageFile.path != widget.imageFile.path) {
      _resolveAspectRatio();
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  void _removeImageListener() {
    if (_imageStream != null && _listener != null) {
      _imageStream!.removeListener(_listener!);
    }
    _imageStream = null;
    _listener = null;
  }

  void _resolveAspectRatio() {
    _removeImageListener();
    final provider = FileImage(widget.imageFile);
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (ImageInfo info, bool syncCall) {
        if (!mounted) return;
        setState(() {
          _aspectRatio = info.image.width / info.image.height;
        });
      },
      onError: (Object exception, StackTrace? stackTrace) {
        if (!mounted) return;
        setState(() {
          _aspectRatio = 1.0;
        });
      },
    );
    stream.addListener(listener);
    _imageStream = stream;
    _listener = listener;
  }

  Widget _buildImage() {
    return Image.file(
      widget.imageFile,
      key: ValueKey(_refreshTick),
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                '图片加载失败',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                '请检查网络连接后重试',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  FileImage(widget.imageFile).evict();
                  setState(() {
                    _refreshTick++;
                  });
                  _resolveAspectRatio();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWatermarkOverlay(BoxConstraints constraints) {
    final imageSize = Size(constraints.maxWidth, constraints.maxHeight);
    final metrics = _computeWatermarkMetrics(imageSize);
    final maxTextWidth = (imageSize.width * 0.75) - (metrics.textPaddingH * 2);
    final textFitScale = _computeWatermarkTextFitScale(
      text: _watermarkText,
      maxTextWidth: maxTextWidth,
      fontSize: metrics.fontSize,
      letterSpacing: metrics.letterSpacing,
    );

    return Positioned(
      right: metrics.horizontalPadding,
      bottom: metrics.verticalPadding,
      child: IgnorePointer(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.textPaddingH,
            vertical: metrics.textPaddingV,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.22),
            borderRadius: BorderRadius.circular(metrics.borderRadius),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.max(1, maxTextWidth),
            ),
            child: Text(
              _watermarkText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: metrics.fontSize * textFitScale,
                fontWeight: FontWeight.w600,
                letterSpacing: metrics.letterSpacing * textFitScale,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: metrics.blurRadius * textFitScale,
                    offset: metrics.shadowOffset * textFitScale,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _aspectRatio;
    final Widget content = ratio == null
        ? const Center(
            child: CircularProgressIndicator(color: Colors.white),
          )
        : Center(
            child: AspectRatio(
              aspectRatio: ratio,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Positioned.fill(child: _buildImage()),
                    _buildWatermarkOverlay(constraints),
                  ],
                ),
              ),
            ),
          );

    return content;
  }
}

/// 上传生活照底部弹窗
/// 图片预检查结果
class _ImagePrecheckResult {
  final bool pass;
  final String reason;

  const _ImagePrecheckResult({
    required this.pass,
    required this.reason,
  });
}

class _UploadLifePhotoSheet extends StatefulWidget {
  final String petId;
  final String petName;

  const _UploadLifePhotoSheet({
    required this.petId,
    required this.petName,
  });

  @override
  State<_UploadLifePhotoSheet> createState() => _UploadLifePhotoSheetState();
}

class _UploadLifePhotoSheetState extends State<_UploadLifePhotoSheet> {
  bool _isUploading = false;
  File? _selectedImage;
  String? _precheckReason; // 预检查失败原因

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _precheckReason = null; // 清除之前的预检查结果
        });
      }
    } catch (e) {
      debugPrint('选择图片失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _precheckReason = null; // 清除之前的预检查结果
        });
      }
    } catch (e) {
      debugPrint('拍照失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    }
  }

  Future<void> _uploadAndSave() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploading = true;
    });

    String? uploadedFileName;
    String? storagePath;
    const bucket = 'user-avatars';

    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser?.id;

      if (currentUserId == null) {
        throw Exception('用户未登录');
      }

      // 读取图片文件
      final bytes = await _selectedImage!.readAsBytes();

      // 上传到 user-avatars bucket（与 uploadPetLifePhoto 一致）
      uploadedFileName =
          'lifephoto_${DateTime.now().millisecondsSinceEpoch}.jpg';
      storagePath = '$currentUserId/${widget.petId}/$uploadedFileName';

      await supabase.storage.from(bucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // 调用 img-gen-precheck 检查图片质量（指定 bucket 和 path）
      final precheckResult = await _precheckImage(
        fileName: uploadedFileName,
        bucket: bucket,
        path: storagePath,
      );

      if (!precheckResult.pass) {
        // 检查不通过，删除上传的文件
        try {
          await supabase.storage.from(bucket).remove([storagePath]);
        } catch (_) {}

        if (mounted) {
          setState(() {
            _precheckReason = precheckResult.reason;
            _isUploading = false;
          });
        }
        return;
      }

      // 检查通过，获取公共 URL 并更新宠物记录
      final publicUrl = supabase.storage.from(bucket).getPublicUrl(storagePath);
      await supabase.from('pets').update({
        'life_photo': publicUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.petId);

      if (mounted) {
        Navigator.of(context).pop(true); // 返回 true 表示上传成功
      }
    } catch (e) {
      debugPrint('上传生活照失败: $e');
      // 清理上传的文件
      if (storagePath != null) {
        try {
          await Supabase.instance.client.storage
              .from(bucket)
              .remove([storagePath]);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  /// 图片质量预检查 - 调用 img-gen-precheck Edge Function
  Future<_ImagePrecheckResult> _precheckImage({
    required String fileName,
    String bucket = 'ai-wallpapers',
    String? path,
  }) async {
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase.functions.invoke(
        'img-gen-precheck',
        body: {
          'file_name': fileName,
          'bucket': bucket,
          if (path != null && path.isNotEmpty) 'path': path,
        },
      );

      dynamic payload = response.data;
      if (payload is String && payload.isNotEmpty) {
        payload = jsonDecode(payload);
      }

      if (payload is! Map) {
        return const _ImagePrecheckResult(
          pass: false,
          reason: '图片检测服务返回了无效结果，请稍后重试',
        );
      }

      final bool pass = payload['pass'] == true;
      final String reason = (payload['reason'] as String? ?? '').trim();

      if (pass) {
        return const _ImagePrecheckResult(pass: true, reason: '');
      }

      return _ImagePrecheckResult(
        pass: false,
        reason: reason.isNotEmpty ? reason : '图片不符合生成要求，请更换后重试',
      );
    } on SocketException {
      return const _ImagePrecheckResult(
        pass: false,
        reason: '图片检测失败：网络连接异常，请检查网络后重试',
      );
    } on TimeoutException {
      return const _ImagePrecheckResult(
        pass: false,
        reason: '图片检测超时，请稍后再试',
      );
    } on FunctionException catch (e) {
      debugPrint('❌ 预检函数调用失败: $e');
      final message = e.toString().toLowerCase();
      if (message.contains('401') ||
          message.contains('403') ||
          message.contains('unauthorized') ||
          message.contains('forbidden')) {
        return const _ImagePrecheckResult(
          pass: false,
          reason: '登录状态已失效，请重新登录后重试',
        );
      }
      if (message.contains('timeout')) {
        return const _ImagePrecheckResult(
          pass: false,
          reason: '图片检测超时，请稍后再试',
        );
      }
      if (message.contains('network') || message.contains('fetch')) {
        return const _ImagePrecheckResult(
          pass: false,
          reason: '图片检测失败：网络连接异常，请检查网络后重试',
        );
      }

      return const _ImagePrecheckResult(
        pass: false,
        reason: '图片检测服务暂时不可用，请稍后重试',
      );
    } catch (e, st) {
      debugPrint('❌ 图片预检异常: $e\n$st');
      return const _ImagePrecheckResult(
        pass: false,
        reason: '图片检测失败，请检查网络后重试',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部把手
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 标题
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.photo_camera,
                      color: Color(0xFF7C3AED),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '需要生活照',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '上传${widget.petName}的生活照，AI 将基于这张照片生成配图',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 图片预览或选择区域
              if (_selectedImage != null)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: FileImage(_selectedImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _isUploading ? null : _pickImage,
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '点击选择图片',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '支持 JPG、PNG 格式',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // 预检查失败提示
              if (_precheckReason != null && _precheckReason!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFB74D),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFFF57C00),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _precheckReason!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFE65100),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_precheckReason != null && _precheckReason!.isNotEmpty)
                const SizedBox(height: 16),

              // 操作按钮行
              if (_selectedImage == null)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _pickImage,
                        icon: const Icon(Icons.photo_library, size: 20),
                        label: const Text('相册'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          foregroundColor: Colors.grey.shade800,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _takePhoto,
                        icon: const Icon(Icons.camera_alt, size: 20),
                        label: const Text('拍照'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          foregroundColor: Colors.grey.shade800,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUploading
                            ? null
                            : () {
                                setState(() {
                                  _selectedImage = null;
                                  _precheckReason = null; // 清除预检查结果
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('重新选择'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _uploadAndSave,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check, size: 20),
                        label: Text(_isUploading ? '上传中...' : '确认上传'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),

              // 取消按钮
              TextButton(
                onPressed: _isUploading
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text(
                  '暂不生成',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
