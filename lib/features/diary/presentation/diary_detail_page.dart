import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../services/ai_image_cache_service.dart';
import '../../../shared/models/pet_diary.dart';
import 'diary_share_page.dart';

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
    textDirection: ui.TextDirection.ltr,
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

class DiaryDetailPage extends StatelessWidget {
  final PetDiary diary;

  const DiaryDetailPage({super.key, required this.diary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          DateFormat('yyyy年MM月dd日').format(diary.timestamp),
          style: GoogleFonts.notoSerif(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, color: Colors.black87),
            tooltip: '生成分享卡片',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DiarySharePage(diary: diary),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _getTagIcon(diary.style),
                  const SizedBox(width: 8),
                  Text(
                    diary.style,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('HH:mm').format(diary.timestamp),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHashtagRichText(
                    diary.content,
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      height: 1.8,
                      color: Colors.black87,
                    ),
                  ),
                  // AI 生成配图展示
                  if (diary.aiImg != null && diary.aiImg!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildAiImage(diary.aiImg!),
                  ],
                  if (diary.originalText.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      '原始记录',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      diary.originalText,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTagColor(String style) {
    switch (style) {
      case '哲学':
        return Colors.purple;
      case '搞笑':
        return Colors.orange;
      case '治愈':
        return Colors.green;
      case '中二':
        return Colors.red;
      case '小红书':
        return Colors.pink;
      default:
        return Colors.blue;
    }
  }

  Widget _getTagIcon(String style) {
    IconData icon;
    Color color = _getTagColor(style);

    switch (style) {
      case '哲学':
        icon = Icons.lightbulb_outline;
        break;
      case '搞笑':
        icon = Icons.sentiment_very_satisfied;
        break;
      case '治愈':
        icon = Icons.spa_outlined;
        break;
      case '中二':
        icon = Icons.flash_on;
        break;
      case '小红书':
        icon = Icons.favorite_border;
        break;
      default:
        icon = Icons.article_outlined;
    }

    return Icon(icon, size: 20, color: color);
  }

  /// 构建 AI 生成配图展示
  Widget _buildAiImage(String aiImgPath) {
    debugPrint('📷 AI Image Path: $aiImgPath');

    // 使用 AuthenticatedImage 组件来携带 JWT 访问受保护的图片
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 16, color: Colors.purple[400]),
            const SizedBox(width: 6),
            Text(
              'AI 生成配图',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _AuthenticatedImage(
          bucket: 'ai-wallpapers',
          path: aiImgPath,
          height: 200,
          borderRadius: BorderRadius.circular(12),
        ),
      ],
    );
  }

  /// 构建带蓝色标签的 RichText（小红书风格）
  Widget _buildHashtagRichText(String text, {required TextStyle style}) {
    return RichText(
      text: TextSpan(children: _buildHashtagSpans(text, baseStyle: style)),
    );
  }

  /// 解析文本中的 #标签，生成带样式的 InlineSpan 列表（小红书风格蓝色标签）
  List<InlineSpan> _buildHashtagSpans(String text, {required TextStyle baseStyle}) {
    const hashtagStyle = TextStyle(
      color: Color(0xFF2196F3), // 小红书风格的蓝色
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
        style: baseStyle.merge(hashtagStyle),
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
}

/// 携带认证信息加载 Storage 图片的组件
/// 使用 Supabase download 方法（自动携带 JWT），适合受保护的 bucket
class _AuthenticatedImage extends StatefulWidget {
  final String bucket;
  final String path;
  final double height;
  final BorderRadius borderRadius;

  const _AuthenticatedImage({
    required this.bucket,
    required this.path,
    required this.height,
    required this.borderRadius,
  });

  @override
  State<_AuthenticatedImage> createState() => _AuthenticatedImageState();
}

class _AuthenticatedImageState extends State<_AuthenticatedImage> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  String? _error;
  final AiImageCacheService _cacheService = AiImageCacheService();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      // 检查是否已经是完整 URL（http 开头）
      if (widget.path.startsWith('http')) {
        // 使用普通网络请求
        final response = await http.get(Uri.parse(widget.path));
        if (response.statusCode == 200) {
          setState(() {
            _imageBytes = response.bodyBytes;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'HTTP ${response.statusCode}';
            _isLoading = false;
          });
        }
        return;
      }

      // 使用缓存服务获取图片（自动处理本地缓存）
      final bytes = await _cacheService.getImageBytes(widget.path);

      if (bytes != null) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '加载失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ _AuthenticatedImage download error: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void didUpdateWidget(_AuthenticatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.bucket != widget.bucket) {
      setState(() {
        _isLoading = true;
        _error = null;
        _imageBytes = null;
      });
      _loadImage();
    }
  }

  void _showFullscreenImage() {
    if (_imageBytes == null) return;

    Navigator.of(context).push(
      _TransparentImageRoute(
        builder: (_) => _FullscreenImageViewer(
          imageBytes: _imageBytes!,
          heroTag: 'ai_image_${widget.path}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: widget.borderRadius,
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _imageBytes == null) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: widget.borderRadius,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                '图片加载失败',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _showFullscreenImage,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: _ContainedImageWithWatermark(
          heroTag: 'ai_image_${widget.path}',
          imageBytes: _imageBytes!,
          height: widget.height,
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}

/// 带水印的图片组件（用于 Hero 动画）
/// 确保图片和水印作为整体参与 Hero 动画
class _ContainedImageWithWatermark extends StatelessWidget {
  final String heroTag;
  final Uint8List imageBytes;
  final double height;
  final BorderRadius borderRadius;

  const _ContainedImageWithWatermark({
    required this.heroTag,
    required this.imageBytes,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Image.memory(
                imageBytes,
                width: double.infinity,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: borderRadius,
                    ),
                    child: Center(
                      child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                    ),
                  );
                },
              ),
              _buildWatermarkOverlay(constraints),
            ],
          );
        },
      ),
    );
  }
}

/// 全屏图片预览页面（模仿 result_page.dart 中的 FullscreenImagePage）
class _FullscreenImageViewer extends StatefulWidget {
  final Uint8List imageBytes;
  final String heroTag;

  const _FullscreenImageViewer({
    required this.imageBytes,
    required this.heroTag,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer>
    with SingleTickerProviderStateMixin {
  double dragOffsetY = 0;
  late AnimationController _controller;
  late Animation<double> _reboundAnimation;
  double? _aspectRatio;

  static const double dismissThreshold = 150;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _resolveAspectRatio();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    super.dispose();
  }

  void _resolveAspectRatio() {
    final image = Image.memory(widget.imageBytes);
    final stream = image.image.resolve(const ImageConfiguration());
    stream.addListener(
      ImageStreamListener(
        (ImageInfo info, bool _) {
          if (mounted) {
            setState(() {
              _aspectRatio = info.image.width / info.image.height;
            });
          }
        },
        onError: (_, __) {
          if (mounted) {
            setState(() {
              _aspectRatio = 1.0;
            });
          }
        },
      ),
    );
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
    final ratio = _aspectRatio;

    // 如果宽高比还没解析出来，显示 loading
    final Widget content = ratio == null
        ? const Center(
            child: CircularProgressIndicator(color: Colors.white),
          )
        : Center(
            child: _FullscreenImageWithWatermark(
              heroTag: widget.heroTag,
              imageBytes: widget.imageBytes,
              aspectRatio: ratio,
            ),
          );

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
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 全屏图片带水印组件（用于 Hero 动画）
class _FullscreenImageWithWatermark extends StatelessWidget {
  final String heroTag;
  final Uint8List imageBytes;
  final double aspectRatio;

  const _FullscreenImageWithWatermark({
    required this.heroTag,
    required this.imageBytes,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              _buildWatermarkOverlay(constraints),
            ],
          ),
        ),
      ),
    );
  }
}

/// 透明图片路由 - 用于全屏图片预览，无转场动画
/// 与 result_page.dart 中的 TransparentImageRoute 保持一致
class _TransparentImageRoute extends PageRouteBuilder {
  _TransparentImageRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 200),
        );
}
