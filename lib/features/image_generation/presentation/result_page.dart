import 'package:gal/gal.dart';

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../shared/utils/ui_helpers.dart';

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
  static const Color background = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF5D5FEF);
  static const Color textDark = Color(0xFF1D1D1F);
  static const Color textGrey = Color(0xFF8E8E93);
  static const Color textLight = Color(0xFFAEAEB2);

  static const Color favoriteActive = Color(0xFFFF5252);
  static const Color likeActive = Color(0xFF2196F3);
  static const Color dislikeActive = Color(0xFF9E9E9E);

  static const Color orb1 = Color(0xFFC4E0E5);
  static const Color orb2 = Color(0xFFE2D1F9);
  static const Color orb3 = Color(0xFFFFDFC4);
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
  final File originalImage;
  final String? resultImageUrl;
  final File? resultImageFile;

  const ResultPage(
      {super.key,
      required this.originalImage,
      this.resultImageFile,
      this.resultImageUrl});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> with TickerProviderStateMixin {
  late AnimationController _orbController;
  static const String _watermarkText = '智宠合生 Peture AI 生成';
  static int? _cachedAndroidSdkInt;

  bool _isFavorite = false;
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _shouldDeleteTempFile = false;
  bool _enableWatermark = true;

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

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (image) {
      completer.complete(image);
    });
    return completer.future;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isResultUrlLocalFile = _isLocalFilePath(widget.resultImageUrl);
    final resultFileFromUrl =
        widget.resultImageUrl != null && isResultUrlLocalFile
            ? _fileFromPath(widget.resultImageUrl!)
            : null;
    final useNetworkImage =
        widget.resultImageFile == null && !isResultUrlLocalFile;
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
        title: const Text("生成完成"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.share), onPressed: () {})],
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
            child: Column(
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      TransparentImageRoute(
                        builder: (_) => FullscreenImagePage(
                          imageFile: widget.originalImage,
                          heroTag: 'pet_photo_hero',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                              width: 1.2,
                            ),
                            gradient: RadialGradient(
                              radius: 1.8,
                              center: Alignment.topCenter,
                              colors: [
                                AppColors.surface.withOpacity(0.15),
                                AppColors.surface.withOpacity(0.3),
                                AppColors.surface.withOpacity(0.45),
                              ],
                              stops: const [0.0, 0.6, 1.0],
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("原图",
                                  style: TextStyle(color: AppColors.textGrey)),
                              const SizedBox(width: 10),
                              Hero(
                                tag: 'pet_photo_hero',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(widget.originalImage,
                                      height: 100,
                                      width: 100,
                                      fit: BoxFit.cover),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        TransparentImageRoute(
                          builder: (_) => FullscreenImagePage(
                            imageFile: widget.resultImageFile ??
                                resultFileFromUrl ??
                                File(''),
                            heroTag: 'ai_result_hero',
                            isNetworkImage: useNetworkImage,
                            showWatermark: _enableWatermark,
                            networkImage:
                                useNetworkImage && widget.resultImageUrl != null
                                    ? NetworkImage(widget.resultImageUrl!)
                                    : null,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20)
                        ],
                      ),
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
                            left: 20,
                            bottom: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.6),
                                  width: 1.2,
                                ),
                                gradient: RadialGradient(
                                  radius: 1.8,
                                  center: Alignment.topCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0.45),
                                  ],
                                  stops: const [0.0, 0.6, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                                      const SizedBox(width: 20),
                                      _buildIconAction(Icons.thumb_up_outlined,
                                          _isLiked, AppColors.likeActive, () {
                                        setState(() {
                                          if (_isDisliked) {
                                            _isDisliked = false;
                                          }
                                          _isLiked = !_isLiked;
                                        });
                                      }),
                                      const SizedBox(width: 20),
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
                        child: SwitchListTile.adaptive(
                          value: _enableWatermark,
                          title: const Text(
                            '水印',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          subtitle: const Text(
                            _watermarkText,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textGrey,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _enableWatermark = value;
                            });
                          },
                          activeColor: AppColors.primary,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 80,
                  padding: const EdgeInsets.all(20.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
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
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5D5FEF), Color(0xFF8B77FF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5D5FEF).withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: -1,
                              offset: const Offset(0, 3),
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.4),
                              blurRadius: 1,
                              offset: const Offset(0, -1),
                              blurStyle: BlurStyle.inner,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              PermissionStatus status;
                              if (Platform.isIOS) {
                                // iOS 双兜底：优先请求 add-only，失败后回退到 photos。
                                final addOnlyStatus =
                                    await Permission.photosAddOnly.request();
                                if (addOnlyStatus.isGranted ||
                                    addOnlyStatus == PermissionStatus.limited) {
                                  status = addOnlyStatus;
                                } else if (addOnlyStatus.isPermanentlyDenied ||
                                    addOnlyStatus ==
                                        PermissionStatus.restricted) {
                                  status = addOnlyStatus;
                                } else {
                                  status = await Permission.photos.request();
                                }
                              } else {
                                // Android: 根据 API 级别请求合适的存储权限
                                // Android 13+ (API 33+) 使用 READ_MEDIA_IMAGES (Permission.photos)
                                // Android 12 及以下 (API 32-) 使用 READ_EXTERNAL_STORAGE (Permission.storage)
                                _cachedAndroidSdkInt ??=
                                    (await DeviceInfoPlugin().androidInfo)
                                        .version
                                        .sdkInt;
                                if (_cachedAndroidSdkInt! >= 33) {
                                  status = await Permission.photos.request();
                                } else {
                                  status = await Permission.storage.request();
                                }
                              }

                              if (status.isGranted ||
                                  status == PermissionStatus.limited) {
                                // 权限已授予，继续保存
                              } else if (status.isPermanentlyDenied ||
                                  status == PermissionStatus.restricted) {
                                // 权限被永久拒绝或受限，引导用户到设置
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('权限被拒绝'),
                                        content:
                                            const Text('相册权限已被拒绝，请前往设置开启。'),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              openAppSettings();
                                            },
                                            child: const Text('去设置'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('取消'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }
                                return;
                              } else {
                                // 权限被拒绝，但可以再次请求
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text("需要相册权限才能保存图片")));
                                }
                                return;
                              }

                              try {
                                late Uint8List bytes;

                                if (widget.resultImageFile != null) {
                                  bytes = await widget.resultImageFile!
                                      .readAsBytes();
                                } else if (widget.resultImageUrl != null &&
                                    widget.resultImageUrl!.isNotEmpty) {
                                  final url = widget.resultImageUrl!;
                                  if (_isLocalFilePath(url)) {
                                    final file = _fileFromPath(url);
                                    if (await file.exists()) {
                                      bytes = await file.readAsBytes();
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text("未找到本地图片")));
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
                                            .showSnackBar(const SnackBar(
                                                content: Text("下载图片失败")));
                                      }
                                      return;
                                    }
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text("未找到图片以保存")));
                                  }
                                  return;
                                }

                                if (_enableWatermark) {
                                  bytes = await _addWatermarkToBytes(bytes);
                                }

                                // 保存到临时文件
                                final tempDir = await getTemporaryDirectory();
                                final tempPath =
                                    '${tempDir.path}/ai_result_${DateTime.now().millisecondsSinceEpoch}.png';
                                final tempFile = File(tempPath);
                                await tempFile.writeAsBytes(bytes);

                                // 使用 Gal 插件保存图片到相册
                                await Gal.putImage(tempPath, album: 'Peture');

                                // 删除临时文件
                                if (await tempFile.exists()) {
                                  await tempFile.delete();
                                }

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("已保存到相册！")));
                                }
                              } catch (e) {
                                debugPrint('保存图片到相册时出错: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text("保存失败，请检查权限设置")));
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(25),
                            child: const Center(
                              child: Text(
                                "保存到相册",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 16,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
    );
  }

  Widget _buildIconAction(
      IconData icon, bool isActive, Color activeColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon,
          color: isActive ? activeColor : AppColors.textDark, size: 24),
    );
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
