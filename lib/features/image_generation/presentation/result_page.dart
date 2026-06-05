import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/page_tracker_mixin.dart';
import '../../../services/analytics_service.dart';
import '../../../shared/utils/ui_helpers.dart';
import '../../../shared/utils/avatar_image_helper.dart';
import '../../../shared/utils/user_avatar_helper.dart';
import '../../../services/supabase_service.dart';
import '../../content_feedback/domain/content_feedback_kind.dart';
import '../../content_feedback/presentation/ai_generated_image_disclaimer.dart';
import '../../content_feedback/presentation/content_feedback_bar.dart';
import '../../../shared/utils/data_change_notifier.dart';

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

class AppColors {
  static const Color background = Color(0xFFFAF5FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF7C3AED);
  static const Color secondary = Color(0xFF6366F1);
  static const Color accent = Color(0xFFEC4899);
  static const Color textDark = Color(0xFF1D1D1F);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  static const Color favoriteActive = Color(0xFFFF5252);
  static const Color likeActive = Color(0xFF6366F1);
  static const Color dislikeActive = Color(0xFF9E9E9E);

  static const Color orb1 = Color(0xFFD8B4FE);
  static const Color orb2 = Color(0xFFA78BFA);
  static const Color orb3 = Color(0xFFF9A8D4);

  static const List<Color> primaryGradient = [
    Color(0xFF7C3AED),
    Color(0xFF6366F1),
    Color(0xFFEC4899),
  ];
}

class FadePageRoute extends PageRouteBuilder {
  final Widget page;

  FadePageRoute({required this.page})
      : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) =>
              FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
}

class ResultPage extends StatefulWidget {
  final File? originalImage;
  final String? originalImageUrl; // Web 平台使用 URL
  final String? resultImageUrl;
  final File? resultImageFile;

  const ResultPage(
      {super.key,
      this.originalImage,
      this.originalImageUrl,
      this.resultImageFile,
      this.resultImageUrl});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage>
    with TickerProviderStateMixin, PageTrackerMixin<ResultPage> {
  late AnimationController _orbController;
  late AnimationController _shimmerController;
  late AnimationController _saveButtonShimmerController;
  static const String _watermarkText = '智宠合生 Peture AI 生成';
  static int? _cachedAndroidSdkInt;

  bool _isFavorite = false;
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _shouldDeleteTempFile = false;
  bool _enableWatermark = true;
  bool _isSettingAvatar = false;

  @override
  String get analyticsPageName => 'ai_image_result';

  bool _isLocalFilePath(String? path) {
    if (path == null || path.isEmpty) return false;
    final uri = Uri.tryParse(path);
    if (uri == null) return false;
    if (uri.scheme == 'file') return true;
    // 本地路径通常以 / 开头（iOS 模拟器/真机）
    if (uri.scheme.isEmpty && (path.startsWith('/') || path.startsWith('~'))) {
      return true;
    }
    return false;
  }

  File _fileFromPath(String path) {
    if (path.startsWith('file://')) {
      return File(Uri.parse(path).toFilePath());
    }
    return File(path);
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      throw Exception('Failed to decode image: $e');
    }
  }

  Future<Uint8List> _addWatermarkToBytes(Uint8List originalBytes) async {
    final sourceImage = await _decodeImage(originalBytes);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final imageSize = Size(
      sourceImage.width.toDouble(),
      sourceImage.height.toDouble(),
    );
    final watermarkMetrics = _computeWatermarkMetrics(imageSize);
    final maxTextWidth =
        (imageSize.width * 0.75) - (watermarkMetrics.textPaddingH * 2);
    final textFitScale = _computeWatermarkTextFitScale(
      text: _watermarkText,
      maxTextWidth: maxTextWidth,
      fontSize: watermarkMetrics.fontSize,
      letterSpacing: watermarkMetrics.letterSpacing,
    );

    canvas.drawImageRect(
      sourceImage,
      Rect.fromLTWH(0, 0, imageSize.width, imageSize.height),
      Rect.fromLTWH(0, 0, imageSize.width, imageSize.height),
      Paint(),
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: _watermarkText,
        style: TextStyle(
          color: Colors.white.withOpacity(0.82),
          fontSize: watermarkMetrics.fontSize * textFitScale,
          fontWeight: FontWeight.w600,
          letterSpacing: watermarkMetrics.letterSpacing * textFitScale,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: watermarkMetrics.blurRadius * textFitScale,
              offset: watermarkMetrics.shadowOffset * textFitScale,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: math.max(1.0, maxTextWidth));

    final watermarkRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        imageSize.width -
            textPainter.width -
            (watermarkMetrics.textPaddingH * 2) -
            watermarkMetrics.horizontalPadding,
        imageSize.height -
            textPainter.height -
            (watermarkMetrics.textPaddingV * 2) -
            watermarkMetrics.verticalPadding,
        textPainter.width + (watermarkMetrics.textPaddingH * 2),
        textPainter.height + (watermarkMetrics.textPaddingV * 2),
      ),
      Radius.circular(watermarkMetrics.borderRadius),
    );

    canvas.drawRRect(
      watermarkRect,
      Paint()..color = Colors.black.withOpacity(0.22),
    );

    textPainter.paint(
      canvas,
      Offset(
        watermarkRect.left + watermarkMetrics.textPaddingH,
        watermarkRect.top + watermarkMetrics.textPaddingV,
      ),
    );

    final picture = recorder.endRecording();
    final watermarkedImage = await picture.toImage(
      sourceImage.width,
      sourceImage.height,
    );
    final byteData = await watermarkedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    sourceImage.dispose();
    watermarkedImage.dispose();

    if (byteData == null) {
      return originalBytes;
    }
    return byteData.buffer.asUint8List();
  }

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _saveButtonShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    if (widget.resultImageFile != null) {
      try {
        final filePath = widget.resultImageFile!.path;
        final filename = filePath.split(Platform.pathSeparator).last;
        if (filePath.contains(Directory.systemTemp.path) ||
            filename.startsWith('ai_gen_')) {
          _shouldDeleteTempFile = true;
        }
      } catch (e) {
        debugPrint('检查临时文件标记时出错: $e');
      }
    }
  }

  @override
  void dispose() {
    if (_shouldDeleteTempFile && widget.resultImageFile != null) {
      widget.resultImageFile!.exists().then((exists) {
        if (exists) {
          widget.resultImageFile!.delete().then((_) {
            debugPrint('已删除临时下载文件: ${widget.resultImageFile!.path}');
          }).catchError((e) {
            debugPrint('删除临时下载文件失败: $e');
          });
        }
      }).catchError((e) {
        debugPrint('检查临时下载文件存在性失败: $e');
      });
    }

    _orbController.dispose();
    _shimmerController.dispose();
    _saveButtonShimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isResultUrlLocalFile = _isLocalFilePath(widget.resultImageUrl);
    final resultFileFromUrl =
        widget.resultImageUrl != null && isResultUrlLocalFile
            ? _fileFromPath(widget.resultImageUrl!)
            : null;
    final ImageProvider<Object>? resultImageProvider = widget.resultImageFile !=
            null
        ? FileImage(widget.resultImageFile!) as ImageProvider<Object>
        : resultFileFromUrl != null
            ? FileImage(resultFileFromUrl) as ImageProvider<Object>
            : (widget.resultImageUrl != null &&
                    widget.resultImageUrl!.isNotEmpty)
                ? NetworkImage(widget.resultImageUrl!) as ImageProvider<Object>
                : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "生成完成",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: 0.8,
            shadows: [
              Shadow(
                color: Colors.black12,
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(color: AppColors.textDark),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withOpacity(0.85),
                    AppColors.background.withOpacity(0.4),
                  ],
                ),
              ),
            ),
          ),
        ),
        foregroundColor: AppColors.textDark,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _shareImage,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.6),
                      width: 1,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.4),
                        Colors.white.withOpacity(0.15),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Icon(
                        Icons.share_outlined,
                        color: AppColors.textDark.withOpacity(0.8),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Stack(
            children: [
              Container(color: AppColors.background),
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  final curvedValue = CurvedAnimation(
                          parent: _orbController, curve: Curves.easeInOut)
                      .value;
                  return Positioned(
                    top: -100 + (curvedValue * 40),
                    left: -50 + (curvedValue * 20),
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
                  final curvedValue = CurvedAnimation(
                          parent: _orbController, curve: Curves.easeInOut)
                      .value;
                  return Positioned(
                    top: 300 + (math.sin(curvedValue * math.pi) * 60),
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
                  final curvedValue = CurvedAnimation(
                          parent: _orbController, curve: Curves.easeInOut)
                      .value;
                  return Positioned(
                    bottom: -150,
                    left: -80 + (curvedValue * 150),
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
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 8),
                // 紧凑原图预览
                GestureDetector(
                  onTap: () {
                    _openFullscreenPreview(
                      heroTag: 'pet_photo_hero',
                      imageFile: widget.originalImage,
                      imageUrl: widget.originalImageUrl,
                      showWatermark: false,
                    );
                  },
                  child: Container(
                    height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withOpacity(0.45),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.65),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withOpacity(0.12),
                                      AppColors.secondary.withOpacity(0.08),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "原图",
                                  style: TextStyle(
                                    color: AppColors.primary.withOpacity(0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "点击查看原图",
                                  style: TextStyle(
                                    color: AppColors.textLight.withOpacity(0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              Hero(
                                tag: 'pet_photo_hero',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: widget.originalImageUrl != null
                                      ? Image.network(
                                          widget.originalImageUrl!,
                                          height: 40,
                                          width: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            height: 40,
                                            width: 40,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.pets,
                                                size: 20),
                                          ),
                                        )
                                      : Image.file(
                                          widget.originalImage!,
                                          height: 40,
                                          width: 40,
                                          fit: BoxFit.cover,
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
                const SizedBox(height: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _openFullscreenPreview(
                        heroTag: 'ai_result_hero',
                        imageFile: widget.resultImageFile,
                        imageUrl: widget.resultImageUrl,
                        showWatermark: _enableWatermark,
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                            spreadRadius: -4,
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.35),
                            blurRadius: 1,
                            offset: const Offset(0, -1),
                            blurStyle: BlurStyle.inner,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          children: [
                            if (resultImageProvider != null)
                              _ContainedImageWithWatermark(
                                heroTag: 'ai_result_hero',
                                imageProvider: resultImageProvider,
                                showWatermark: _enableWatermark,
                                watermarkText: _watermarkText,
                                progressColor: AppColors.primary,
                                errorIconColor: Colors.red,
                                errorTextColor: AppColors.textDark,
                                errorSubTextColor: AppColors.textGrey,
                              )
                            else
                              const Center(
                                child: Text(
                                  '未找到可预览的图片',
                                  style: TextStyle(color: AppColors.textGrey),
                                ),
                              ),
                            Positioned(
                              left: 16,
                              bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.65),
                                    width: 1,
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.35),
                                      Colors.white.withOpacity(0.2),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildIconAction(
                                            Icons.favorite_border,
                                            _isFavorite,
                                            AppColors.favoriteActive, () {
                                          setState(() {
                                            _isFavorite = !_isFavorite;
                                          });
                                        }),
                                        const SizedBox(width: 16),
                                        _buildIconAction(
                                            Icons.thumb_up_outlined,
                                            _isLiked,
                                            AppColors.likeActive, () {
                                          setState(() {
                                            if (_isDisliked) {
                                              _isDisliked = false;
                                            }
                                            _isLiked = !_isLiked;
                                          });
                                        }),
                                        const SizedBox(width: 16),
                                        _buildIconAction(
                                            Icons.thumb_down_outlined,
                                            _isDisliked,
                                            AppColors.dislikeActive, () {
                                          setState(() {
                                            if (_isLiked) {
                                              _isLiked = false;
                                            }
                                            _isDisliked = !_isDisliked;
                                          });
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.35),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            listTileTheme: const ListTileThemeData(
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16),
                              minVerticalPadding: 8,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          child: SwitchListTile.adaptive(
                            value: _enableWatermark,
                            title: const Text(
                              '水印',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                                fontSize: 15,
                                letterSpacing: 0.3,
                              ),
                            ),
                            subtitle: const Text(
                              _watermarkText,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                                height: 1.4,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _enableWatermark = value;
                              });
                            },
                            activeColor: AppColors.primary,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Save to Gallery Button with shimmer animation
                Container(
                  height: 68,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: AnimatedBuilder(
                    animation: _saveButtonShimmerController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glassmorphism base
                          ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
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
                          // Gradient button with shimmer
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: LinearGradient(
                                colors: AppColors.primaryGradient,
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                stops: const [0.0, 0.5, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.24),
                                  blurRadius: 20,
                                  spreadRadius: -2,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.4),
                                  blurRadius: 1,
                                  offset: const Offset(0, -1),
                                  blurStyle: BlurStyle.inner,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // 背景高光层：只作用在按钮背景，不覆盖文字内容
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(26),
                                    child: AnimatedBuilder(
                                      animation: _saveButtonShimmerController,
                                      builder: (context, child) {
                                        final shimmerPos = -1.0 +
                                            (_saveButtonShimmerController
                                                    .value *
                                                3.0);
                                        return Stack(
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors:
                                                      AppColors.primaryGradient,
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                ),
                                              ),
                                            ),
                                            Align(
                                              alignment:
                                                  Alignment(shimmerPos, 0),
                                              child: FractionallySizedBox(
                                                widthFactor: 0.35,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin:
                                                          Alignment.centerLeft,
                                                      end:
                                                          Alignment.centerRight,
                                                      colors: [
                                                        Colors.transparent,
                                                        Colors.white
                                                            .withOpacity(0.08),
                                                        Colors.transparent,
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                // Button content
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      // Web 平台不支持保存到相册
                                      if (kIsWeb) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    "当前平台不支持保存到相册，请在手机上使用")),
                                          );
                                        }
                                        return;
                                      }

                                      PermissionStatus? status;
                                      var canSaveToGallery = false;
                                      if (Platform.isIOS) {
                                        // iOS 最小权限：仅申请新增照片权限（不请求全相册读取）。
                                        status = await Permission.photosAddOnly
                                            .request();
                                        canSaveToGallery = status.isGranted ||
                                            status == PermissionStatus.limited;
                                      } else if (Platform.isAndroid) {
                                        // Android 最小权限：
                                        // - Android 10+ (API 29+) 可直接保存到媒体库，不主动请求读取权限
                                        // - Android 9 及以下才请求 storage 兜底
                                        _cachedAndroidSdkInt ??=
                                            (await DeviceInfoPlugin()
                                                    .androidInfo)
                                                .version
                                                .sdkInt;
                                        if (_cachedAndroidSdkInt! >= 29) {
                                          canSaveToGallery = true;
                                        } else {
                                          status = await Permission.storage
                                              .request();
                                          canSaveToGallery = status.isGranted;
                                        }
                                      } else {
                                        // 桌面或其他不支持保存到相册的平台
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content:
                                                      Text("当前平台不支持保存到相册")));
                                        }
                                        return;
                                      }

                                      if (!canSaveToGallery &&
                                          (status?.isPermanentlyDenied ==
                                                  true ||
                                              status ==
                                                  PermissionStatus
                                                      .restricted)) {
                                        // 权限被永久拒绝或受限，引导用户到设置
                                        if (context.mounted) {
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              return AlertDialog(
                                                title: const Text('权限被拒绝'),
                                                content: const Text(
                                                    '保存权限已被拒绝，请前往设置开启后再尝试写入相册。'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .pop();
                                                      openAppSettings();
                                                    },
                                                    child: const Text('去设置'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .pop();
                                                    },
                                                    child: const Text('取消'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        }
                                        return;
                                      } else if (!canSaveToGallery) {
                                        // 权限被拒绝，但可以再次请求
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content:
                                                      Text("需要保存权限才能写入相册")));
                                        }
                                        return;
                                      }

                                      try {
                                        late Uint8List bytes;

                                        if (widget.resultImageFile != null) {
                                          bytes = await widget.resultImageFile!
                                              .readAsBytes();
                                        } else if (widget.resultImageUrl !=
                                                null &&
                                            widget.resultImageUrl!.isNotEmpty) {
                                          final url = widget.resultImageUrl!;
                                          if (_isLocalFilePath(url)) {
                                            final file = _fileFromPath(url);
                                            if (await file.exists()) {
                                              bytes = await file.readAsBytes();
                                            } else {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                        const SnackBar(
                                                            content: Text(
                                                                "未找到本地图片")));
                                              }
                                              return;
                                            }
                                          } else {
                                            final response =
                                                await http.get(Uri.parse(url));
                                            if (response.statusCode == 200) {
                                              bytes = response.bodyBytes;
                                            } else {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                        const SnackBar(
                                                            content: Text(
                                                                "下载图片失败")));
                                              }
                                              return;
                                            }
                                          }
                                        } else {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text("未找到图片以保存")));
                                          }
                                          return;
                                        }

                                        if (_enableWatermark) {
                                          bytes =
                                              await _addWatermarkToBytes(bytes);
                                        }

                                        // 保存到临时文件
                                        final tempDir =
                                            await getTemporaryDirectory();
                                        final tempPath =
                                            '${tempDir.path}/ai_result_${DateTime.now().millisecondsSinceEpoch}.png';
                                        final tempFile = File(tempPath);
                                        await tempFile.writeAsBytes(bytes);

                                        try {
                                          // iOS 在“仅添加照片”权限下，写入自定义相册可能触发 ACCESS_DENIED；
                                          // 因此 iOS 优先写入系统相册，Android 保持写入 Peture 相册。
                                          if (Platform.isIOS) {
                                            await Gal.putImage(tempPath);
                                          } else {
                                            await Gal.putImage(tempPath,
                                                album: 'Peture');
                                          }
                                        } finally {
                                          // 无论保存成功或失败都删除临时文件
                                          if (await tempFile.exists()) {
                                            await tempFile.delete();
                                          }
                                        }

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text("已保存到相册！")));
                                          AnalyticsService.track(
                                            'pet_memory_saved',
                                            module: 'ai_image',
                                            properties: {
                                              'entry_page': 'ai_image_result',
                                              'memory_type': 'ai_image',
                                              'source_event':
                                                  'ai_image_save_gallery',
                                            },
                                          );
                                        }
                                      } catch (e) {
                                        debugPrint('保存图片到相册时出错: $e');
                                        if (context.mounted) {
                                          final errorText =
                                              e.toString().toLowerCase();
                                          final isPermissionDenied = errorText
                                                  .contains('access_denied') ||
                                              errorText.contains('denied') ||
                                              errorText.contains('permission');
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(isPermissionDenied
                                                      ? "保存失败：当前是“仅添加照片”权限，请在系统设置中允许“所有照片”后重试"
                                                      : "保存失败，请稍后重试")));
                                        }
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(26),
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.download_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "保存到相册",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              fontSize: 16,
                                              letterSpacing: 0,
                                              fontFamilyFallback: const [
                                                'PingFang SC',
                                                'Noto Sans CJK SC',
                                                'Noto Sans SC',
                                              ],
                                              shadows: const [
                                                Shadow(
                                                  color: Colors.black45,
                                                  offset: Offset(0, 1),
                                                  blurRadius: 2.5,
                                                ),
                                                Shadow(
                                                  color: Colors.black26,
                                                  offset: Offset(0, 0),
                                                  blurRadius: 1,
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

                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildAvatarActionButton(
                          label: '设为用户头像',
                          icon: Icons.person_rounded,
                          onTap: _setAsUserAvatar,
                          isLoading: _isSettingAvatar,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAvatarActionButton(
                          label: '设为宠物头像',
                          icon: Icons.pets_rounded,
                          onTap: _setAsPetAvatar,
                          isLoading: _isSettingAvatar,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                  child: Column(
                    children: [
                      const AiGeneratedImageDisclaimer(),
                      ContentFeedbackBar(
                        surface: ContentSurface.aiImage,
                        ref: {
                          if (widget.resultImageUrl != null &&
                              widget.resultImageUrl!.isNotEmpty)
                            'result_url_hint': widget.resultImageUrl,
                          if (widget.resultImageFile != null)
                            'local_path_hint': widget.resultImageFile!.path,
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconAction(
      IconData icon, bool isActive, Color activeColor, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        hoverColor: AppColors.primary.withOpacity(0.08),
        highlightColor: activeColor.withOpacity(0.12),
        splashColor: activeColor.withOpacity(0.16),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          scale: isActive ? 1.08 : 1.0,
          child: Icon(icon,
              color: isActive ? activeColor : AppColors.textDark, size: 22),
        ),
      ),
    );
  }

  void _openFullscreenPreview({
    required String heroTag,
    File? imageFile,
    String? imageUrl,
    bool showWatermark = false,
  }) {
    final hasLocalFile = imageFile != null;
    final hasUrl = imageUrl != null && imageUrl.isNotEmpty;
    if (!hasLocalFile && !hasUrl) return;
    final safeUrl = imageUrl ?? '';

    final isLocalUrl = hasUrl && _isLocalFilePath(safeUrl);
    final fileFromUrl = isLocalUrl ? _fileFromPath(safeUrl) : null;
    // 若本地文件已存在，优先使用本地文件，避免因网络波动导致全屏预览失败。
    final useNetwork = !hasLocalFile && hasUrl && !isLocalUrl;

    Navigator.of(context).push(
      TransparentImageRoute(
        builder: (_) => FullscreenImagePage(
          imageFile: imageFile ?? fileFromUrl ?? File(''),
          heroTag: heroTag,
          isNetworkImage: useNetwork,
          networkImage: useNetwork ? NetworkImage(safeUrl) : null,
          showWatermark: showWatermark,
        ),
      ),
    );
  }

  Widget _buildAvatarActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: 40,
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          final shimmer = _shimmerController.value;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment(-0.6 + shimmer * 1.2, -0.5),
                end: Alignment(0.6 - shimmer * 1.2, 0.5),
                colors: [
                  Colors.white.withOpacity(0.92),
                  AppColors.primary.withOpacity(0.05 + shimmer * 0.06),
                  AppColors.secondary.withOpacity(0.08 + shimmer * 0.06),
                  Colors.white.withOpacity(0.92),
                ],
              ),
              border: Border.all(
                color: isLoading
                    ? AppColors.textLight.withOpacity(0.18)
                    : AppColors.secondary.withOpacity(0.24),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  blurRadius: 1,
                  offset: const Offset(0, -1),
                  blurStyle: BlurStyle.inner,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isLoading ? null : onTap,
                borderRadius: BorderRadius.circular(20),
                hoverColor: AppColors.primary.withOpacity(0.05),
                highlightColor: AppColors.secondary.withOpacity(0.08),
                splashColor: AppColors.secondary.withOpacity(0.12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary.withOpacity(0.7),
                          ),
                        ),
                      )
                    else
                      Icon(icon,
                          size: 17, color: AppColors.primary.withOpacity(0.9)),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isLoading
                            ? AppColors.primary.withOpacity(0.6)
                            : AppColors.primary.withOpacity(0.95),
                        letterSpacing: 0.3,
                      ),
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

  /// 彻底清除头像缓存，确保所有页面立即显示新头像
  Future<void> _clearAvatarCache(String imageUrl) async {
    try {
      // 1. 清除 CachedNetworkImage 磁盘缓存
      await CachedNetworkImage.evictFromCache(imageUrl);

      // 2. 清除 Flutter 框架的 ImageCache（覆盖 Image.network / NetworkImage）
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      debugPrint('🗑️ 头像缓存已清除: $imageUrl');
    } catch (e) {
      debugPrint('⚠️ 清除头像缓存时出错: $e');
    }
  }

  /// 分享当前生成的图片（底部带品牌文字条）
  Future<void> _shareImage() async {
    try {
      late Uint8List bytes;

      if (widget.resultImageFile != null) {
        bytes = await widget.resultImageFile!.readAsBytes();
      } else if (widget.resultImageUrl != null &&
          widget.resultImageUrl!.isNotEmpty) {
        final url = widget.resultImageUrl!;
        if (_isLocalFilePath(url)) {
          final file = _fileFromPath(url);
          if (await file.exists()) {
            bytes = await file.readAsBytes();
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('未找到本地图片')),
              );
            }
            return;
          }
        } else {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            bytes = response.bodyBytes;
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('下载图片失败')),
              );
            }
            return;
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到图片以分享')),
          );
        }
        return;
      }

      // 先添加原有水印（如果用户开启了）
      if (_enableWatermark) {
        bytes = await _addWatermarkToBytes(bytes);
      }

      // 再添加底部分享文字条
      bytes = await _addShareFooterToBytes(bytes);

      // 保存到临时文件
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/peture_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes);

      // 调用系统分享
      await Share.shareXFiles(
        [XFile(tempPath)],
        text: '智宠合生 Peture AI 生成',
      );

      // 分享完成后删除临时文件（延迟确保分享面板已读取）
      Future.delayed(const Duration(seconds: 30), () async {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      });
    } catch (e) {
      debugPrint('分享图片时出错: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败：$e')),
        );
      }
    }
  }

  /// 在图片底部添加分享品牌文字条 - Premium Design
  Future<Uint8List> _addShareFooterToBytes(Uint8List originalBytes) async {
    final sourceImage = await _decodeImage(originalBytes);
    final footerHeight = (sourceImage.height * 0.15).clamp(80.0, 140.0).toInt();
    final newHeight = sourceImage.height + footerHeight;
    final width = sourceImage.width;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制原图
    canvas.drawImageRect(
      sourceImage,
      Rect.fromLTWH(0, 0, width.toDouble(), sourceImage.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), sourceImage.height.toDouble()),
      Paint(),
    );

    final footerTop = sourceImage.height.toDouble();
    final footerRect = Rect.fromLTWH(
      0,
      footerTop,
      width.toDouble(),
      footerHeight.toDouble(),
    );

    // 绘制渐变背景
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: AppColors.primaryGradient,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(footerRect);
    canvas.drawRect(footerRect, gradientPaint);

    // 绘制顶部细线（shine效果）
    final shinePaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(0, footerTop),
      Offset(width.toDouble(), footerTop),
      shinePaint,
    );

    // 绘制次级细线（增加层次感）
    final secondaryLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, footerTop + 2),
      Offset(width.toDouble(), footerTop + 2),
      secondaryLinePaint,
    );

    // 绘制Logo圆形背景（左对齐）
    final logoRadius = (footerHeight * 0.28).clamp(18.0, 28.0);
    final logoCenterX = logoRadius + (width * 0.06).clamp(20.0, 40.0);
    final logoCenterY = footerTop + footerHeight / 2;

    // Logo圆形渐变背景
    final logoGradientPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.35),
          Colors.white.withOpacity(0.15),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(logoCenterX, logoCenterY),
        radius: logoRadius,
      ))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(logoCenterX, logoCenterY),
      logoRadius,
      logoGradientPaint,
    );

    // Logo圆形边框
    final logoBorderPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(
      Offset(logoCenterX, logoCenterY),
      logoRadius,
      logoBorderPaint,
    );

    // 绘制"P"字母作为Logo
    final pTextPainter = TextPainter(
      text: TextSpan(
        text: 'P',
        style: TextStyle(
          color: Colors.white.withOpacity(0.95),
          fontSize: logoRadius * 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pTextPainter.paint(
      canvas,
      Offset(
        logoCenterX - pTextPainter.width / 2,
        logoCenterY - pTextPainter.height / 2 - 1,
      ),
    );

    // 计算字体大小
    final brandFontSize = (width * 0.038).clamp(16.0, 30.0);
    final subtitleFontSize = brandFontSize * 0.65;

    // 品牌主标题 "智宠合生 Peture"
    final brandTextPainter = TextPainter(
      text: TextSpan(
        text: '智宠合生 Peture',
        style: TextStyle(
          color: Colors.white.withOpacity(0.98),
          fontSize: brandFontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 副标题 "AI 生成"
    final subtitleTextPainter = TextPainter(
      text: TextSpan(
        text: 'AI 生成',
        style: TextStyle(
          color: Colors.white.withOpacity(0.72),
          fontSize: subtitleFontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 计算文字起始位置（在Logo右侧）
    final textStartX = logoCenterX + logoRadius + 16;
    final totalTextHeight =
        brandTextPainter.height + subtitleTextPainter.height + 2;
    final textStartY = footerTop + (footerHeight - totalTextHeight) / 2;

    // 绘制品牌文字
    brandTextPainter.paint(
      canvas,
      Offset(textStartX, textStartY),
    );

    // 绘制副标题
    subtitleTextPainter.paint(
      canvas,
      Offset(textStartX, textStartY + brandTextPainter.height + 2),
    );

    // 右侧装饰性几何图案（QR-code-like dots）
    final patternStartX = width - (width * 0.08).clamp(30.0, 60.0);
    final patternCenterY = footerTop + footerHeight / 2;
    final dotSize = (footerHeight * 0.06).clamp(3.0, 5.0);
    final dotSpacing = dotSize * 2.2;

    // 绘制3x3点阵
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.5);

    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        // 创建不规则的"QR-like"图案（跳过一些点）
        if ((row == 1 && col == 1) || (row == 2 && col == 0)) continue;

        final dotX = patternStartX + (col - 1) * dotSpacing;
        final dotY = patternCenterY + (row - 1) * dotSpacing;

        // 绘制圆角小方块
        final dotRect = Rect.fromCenter(
          center: Offset(dotX, dotY),
          width: dotSize,
          height: dotSize,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(dotRect, Radius.circular(dotSize * 0.3)),
          dotPaint,
        );
      }
    }

    // 添加额外的装饰性圆环
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(
      Offset(
          patternStartX + dotSpacing * 0.8, patternCenterY - dotSpacing * 0.3),
      dotSize * 1.2,
      ringPaint,
    );

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(width, newHeight);
    final byteData =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);

    sourceImage.dispose();
    finalImage.dispose();

    if (byteData == null) {
      return originalBytes;
    }
    return byteData.buffer.asUint8List();
  }

  Future<String?> _downloadToTempFileFromUrl(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return null;
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/ai_result_download_${DateTime.now().millisecondsSinceEpoch}.png';
      final f = File(path);
      await f.writeAsBytes(res.bodyBytes, flush: true);
      return f.path;
    } catch (e) {
      debugPrint('下载图片到临时文件失败: $e');
      return null;
    }
  }

  Future<String?> _getSourceFilePath() async {
    if (widget.resultImageFile != null) return widget.resultImageFile!.path;
    if (widget.resultImageUrl != null && widget.resultImageUrl!.isNotEmpty) {
      if (_isLocalFilePath(widget.resultImageUrl)) {
        return _fileFromPath(widget.resultImageUrl!).path;
      }
      // 下载到临时文件
      return await _downloadToTempFileFromUrl(widget.resultImageUrl!);
    }
    return null;
  }

  Future<void> _setAsUserAvatar() async {
    setState(() => _isSettingAvatar = true);

    final src = await _getSourceFilePath();
    if (!mounted) {
      setState(() => _isSettingAvatar = false);
      return;
    }
    if (src == null) {
      setState(() => _isSettingAvatar = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('未找到可用图片')));
      return;
    }

    if (!mounted) {
      setState(() => _isSettingAvatar = false);
      return;
    }
    final cropped = await AvatarImageHelper.cropAndCompressAvatar(context, src);
    if (!mounted) {
      setState(() => _isSettingAvatar = false);
      return;
    }
    if (cropped == null) {
      setState(() => _isSettingAvatar = false);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('正在设置用户头像...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );
    }

    String? persistedPath =
        await UserAvatarHelper.persistAvatarFile(cropped.path);
    if (!mounted) {
      setState(() => _isSettingAvatar = false);
      return;
    }
    if (persistedPath == null && cropped.existsSync()) {
      persistedPath = await UserAvatarHelper.persistAvatarBytes(
        await cropped.readAsBytes(),
      );
    }
    if (!mounted) {
      setState(() => _isSettingAvatar = false);
      return;
    }
    persistedPath ??= cropped.path;

    try {
      final upload = await SupabaseService()
          .uploadUserAvatarWithError(File(persistedPath));
      if (!mounted) {
        setState(() => _isSettingAvatar = false);
        return;
      }
      if (upload.url == null) {
        final err = upload.error ?? '上传失败';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传头像失败：$err')),
        );
        return;
      }

      final prof = await SupabaseService()
          .upsertUserProfileWithError(avatarUrl: upload.url);
      if (!mounted) {
        setState(() => _isSettingAvatar = false);
        return;
      }
      if (prof.success) {
        final baseUrl = upload.url!.split('?').first;
        await UserAvatarHelper.setAvatarSourceUrlBasename(baseUrl);
        if (!mounted) {
          setState(() => _isSettingAvatar = false);
          return;
        }
        await UserAvatarHelper.saveUserAvatarPath(persistedPath);
        if (!mounted) {
          setState(() => _isSettingAvatar = false);
          return;
        }
        await _clearAvatarCache(baseUrl);
        if (!mounted) {
          setState(() => _isSettingAvatar = false);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已设为用户头像')),
        );
      } else {
        final msg = prof.error ?? '保存失败';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存头像链接失败：$msg')),
        );
      }
    } catch (e) {
      debugPrint('设为用户头像失败: $e');
      setState(() => _isSettingAvatar = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设为用户头像失败：$e')),
      );
    } finally {
      setState(() => _isSettingAvatar = false);
    }
  }

  Future<void> _setAsPetAvatar() async {
    setState(() => _isSettingAvatar = true);

    final service = SupabaseService();
    final pets = await service.getAllPets();
    if (!mounted) {
      setState(() => _isSettingAvatar = false);
      return;
    }
    if (pets.isEmpty) {
      setState(() => _isSettingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有宠物档案，请先创建宠物')),
      );
      return;
    }

    final selected = await _pickPetForAvatar(pets);
    if (selected == null) {
      setState(() => _isSettingAvatar = false);
      return;
    }

    final src = await _getSourceFilePath();
    if (!mounted) {
      setState(() => _isSettingAvatar = false);
      return;
    }
    if (src == null) {
      setState(() => _isSettingAvatar = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('未找到可用图片')));
      return;
    }

    if (!mounted) {
      setState(() => _isSettingAvatar = false);
      return;
    }
    final cropped = await AvatarImageHelper.cropAndCompressAvatar(context, src);
    if (!mounted) {
      setState(() => _isSettingAvatar = false);
      return;
    }
    if (cropped == null) {
      setState(() => _isSettingAvatar = false);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('正在设置宠物头像...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );
    }

    final petId = selected['id']?.toString();
    if (petId == null || petId.isEmpty) {
      setState(() => _isSettingAvatar = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('宠物信息异常，无法设置头像')),
      );
      return;
    }

    try {
      final avatarUrl = await service.uploadPetAvatar(
        file: cropped,
        petId: petId,
      );
      if (!mounted) {
        setState(() => _isSettingAvatar = false);
        return;
      }
      if (avatarUrl == null || avatarUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上传宠物头像失败，请稍后重试')),
        );
        return;
      }

      // 清除所有层级的缓存，确保立即刷新
      final baseUrl = avatarUrl.split('?').first;
      await _clearAvatarCache(baseUrl);

      // 通知其他页面宠物数据已变更，需要刷新
      DataChangeNotifier.markPetDataChanged();

      if (!mounted) {
        setState(() => _isSettingAvatar = false);
        return;
      }
      final petName = (selected['name'] ?? '').toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已设为${petName.isEmpty ? '宠物' : petName}头像')),
      );
    } catch (e) {
      debugPrint('设为宠物头像失败: $e');
      setState(() => _isSettingAvatar = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设为宠物头像失败：$e')),
      );
    } finally {
      setState(() => _isSettingAvatar = false);
    }
  }

  Future<Map<String, dynamic>?> _pickPetForAvatar(
    List<Map<String, dynamic>> pets,
  ) async {
    if (!mounted) return null;
    final rawHeight = 180.0 + pets.length * 92.0;
    final sheetHeight = rawHeight.clamp(280.0, 440.0).toDouble();

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: false,
      backgroundColor: const Color(0xFFF8F7FF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (ctx) {
        return Container(
          color: const Color(0xFFF8F7FF),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: sheetHeight,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6D0F6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '选择宠物',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF241E44),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF4D447E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: pets.isEmpty
                        ? Center(
                            child: Text(
                              '暂无宠物可选',
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.52),
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            itemCount: pets.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final pet = pets[i];
                              final name = (pet['name'] ?? '').toString();
                              final type = (pet['type'] ?? '').toString();
                              final breed = (pet['breed'] ?? '').toString();
                              final avatar = (pet['avatar'] ?? '').toString();
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => Navigator.of(ctx).pop(pet),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: Colors.white,
                                      border: Border.all(
                                        color: const Color(0xFFE6E0FF),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF7A6BFF)
                                              .withOpacity(0.06),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        _buildPetAvatarThumb(avatar),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name.isEmpty ? '未命名宠物' : name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF241E44),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 6,
                                                children: [
                                                  _buildPetTag(
                                                    type.isEmpty
                                                        ? '未填写类型'
                                                        : type,
                                                  ),
                                                  if (breed.isNotEmpty)
                                                    _buildPetTag(breed),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 26,
                                          color: Colors.black.withOpacity(0.28),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPetTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6756F6),
        ),
      ),
    );
  }

  Widget _buildPetAvatarThumb(String avatar) {
    final fallback = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEAE6FF),
        border: Border.all(
          color: const Color(0xFF8D79FF).withOpacity(0.25),
        ),
      ),
      child: const Icon(
        Icons.pets_rounded,
        color: Color(0xFF6B5CE7),
        size: 24,
      ),
    );

    if (avatar.isEmpty) return fallback;

    if (_isLocalFilePath(avatar)) {
      final file = _fileFromPath(avatar);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(
            file,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          ),
        );
      }
      return fallback;
    }

    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return ClipOval(
        child: Image.network(
          avatar,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }

    return fallback;
  }
}

class TransparentImageRoute extends PageRouteBuilder {
  TransparentImageRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 200),
        );
}

class _ContainedImageWithWatermark extends StatefulWidget {
  final String heroTag;
  final ImageProvider imageProvider;
  final bool showWatermark;
  final String watermarkText;
  final Color progressColor;
  final Color errorIconColor;
  final Color errorTextColor;
  final Color errorSubTextColor;

  const _ContainedImageWithWatermark({
    required this.heroTag,
    required this.imageProvider,
    required this.showWatermark,
    required this.watermarkText,
    required this.progressColor,
    required this.errorIconColor,
    required this.errorTextColor,
    required this.errorSubTextColor,
  });

  @override
  State<_ContainedImageWithWatermark> createState() =>
      _ContainedImageWithWatermarkState();
}

class _ContainedImageWithWatermarkState
    extends State<_ContainedImageWithWatermark> {
  ImageStream? _imageStream;
  ImageStreamListener? _listener;
  double? _aspectRatio;
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  Widget _buildWatermarkOverlay(BoxConstraints constraints) {
    final imageSize = Size(constraints.maxWidth, constraints.maxHeight);
    final metrics = _computeWatermarkMetrics(imageSize);
    final maxTextWidth = (imageSize.width * 0.75) - (metrics.textPaddingH * 2);
    final textFitScale = _computeWatermarkTextFitScale(
      text: widget.watermarkText,
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
              widget.watermarkText,
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
  void didUpdateWidget(covariant _ContainedImageWithWatermark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
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
    final stream = widget.imageProvider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (ImageInfo info, bool syncCall) {
        if (!mounted) return;
        setState(() {
          _aspectRatio = info.image.width / info.image.height;
        });
      },
      onError: (Object exception, StackTrace? stackTrace) {
        if (!mounted) return;
        // 图片加载失败时设置兜底宽高比，使 build 退出 loading spinner
        // 并转入 _buildImage() 的 errorBuilder 展示错误 UI
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
    return Image(
      key: ValueKey(_refreshTick),
      image: widget.imageProvider,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            color: widget.progressColor,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 50, color: widget.errorIconColor),
              const SizedBox(height: 16),
              Text(
                '图片加载失败',
                style: TextStyle(fontSize: 16, color: widget.errorTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                '请检查网络连接后重试',
                style: TextStyle(fontSize: 14, color: widget.errorSubTextColor),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  widget.imageProvider.evict();
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

  @override
  Widget build(BuildContext context) {
    final ratio = _aspectRatio;
    final Widget content = ratio == null
        ? Center(
            child: CircularProgressIndicator(color: widget.progressColor),
          )
        : Center(
            child: AspectRatio(
              aspectRatio: ratio,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Positioned.fill(child: _buildImage()),
                    if (widget.showWatermark)
                      _buildWatermarkOverlay(constraints),
                  ],
                ),
              ),
            ),
          );

    return Hero(tag: widget.heroTag, child: content);
  }
}

class FullscreenImagePage extends StatefulWidget {
  final File imageFile;
  final String heroTag;
  final bool isAssetImage;
  final AssetImage? assetImage;
  final bool isNetworkImage;
  final NetworkImage? networkImage;
  final bool showWatermark;
  static const String watermarkText = '智宠合生 Peture AI 生成';

  const FullscreenImagePage({
    super.key,
    required this.imageFile,
    required this.heroTag,
    this.isAssetImage = false,
    this.assetImage,
    this.isNetworkImage = false,
    this.networkImage,
    this.showWatermark = false,
  });

  @override
  State<FullscreenImagePage> createState() => _FullscreenImagePageState();
}

class _FullscreenImagePageState extends State<FullscreenImagePage>
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
    final ImageProvider<Object> fullscreenImageProvider =
        widget.isNetworkImage && widget.networkImage != null
            ? widget.networkImage! as ImageProvider<Object>
            : widget.isAssetImage && widget.assetImage != null
                ? widget.assetImage! as ImageProvider<Object>
                : FileImage(widget.imageFile) as ImageProvider<Object>;

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
                  child: _ContainedImageWithWatermark(
                    heroTag: widget.heroTag,
                    imageProvider: fullscreenImageProvider,
                    showWatermark: widget.showWatermark,
                    watermarkText: FullscreenImagePage.watermarkText,
                    progressColor: Colors.white,
                    errorIconColor: Colors.white,
                    errorTextColor: Colors.white,
                    errorSubTextColor: Colors.white70,
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
