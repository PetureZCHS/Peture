import 'package:gal/gal.dart';

import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../shared/utils/ui_helpers.dart';
import '../../content_feedback/domain/content_feedback_kind.dart';
import '../../content_feedback/presentation/ai_generated_image_disclaimer.dart';
import '../../content_feedback/presentation/content_feedback_bar.dart';

// 添加颜色常量定义，与preparation_page.dart保持一致
class AppColors {
  static const Color background = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF); // 卡片表面颜色
  static const Color primary = Color(0xFF5D5FEF);
  static const Color textDark = Color(0xFF1D1D1F);
  static const Color textGrey = Color(0xFF8E8E93);
  static const Color textLight = Color(0xFFAEAEB2); // 更淡的文字颜色

  // 添加按钮状态颜色 - 使用更美观的颜色
  static const Color favoriteActive = Color(0xFFFF5252); // 红色，用于收藏
  static const Color likeActive = Color(0xFF2196F3); // 蓝色，用于点赞
  static const Color dislikeActive = Color(0xFF9E9E9E); // 灰色，用于点踩

  static const Color orb1 = Color(0xFFC4E0E5);
  static const Color orb2 = Color(0xFFE2D1F9);
  static const Color orb3 = Color(0xFFFFDFC4);
}

// 添加自定义PageRoute以实现更好的过渡效果
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
  final String? resultImageUrl; // 生成结果 URL（可选回退）
  final File? resultImageFile; // 本地下载的生成文件（优先）

  const ResultPage(
      {super.key,
      required this.originalImage,
      this.resultImageFile,
      this.resultImageUrl});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> with TickerProviderStateMixin {
  // Orb动画控制器
  late AnimationController _orbController;

  // 添加按钮状态变量
  bool _isFavorite = false;
  bool _isLiked = false;
  bool _isDisliked = false;
  // 标记传入的 resultImageFile 是否为临时下载文件，需要在 dispose 时清理
  bool _shouldDeleteTempFile = false;

  /// Android 上 `Directory.systemTemp` 常在 `code_cache` 下，系统可能随时清理；
  /// 进入本页后尽快读入内存，保存到相册时优先用缓存，避免 PathNotFoundException。
  Uint8List? _cachedResultImageBytes;

  Future<void> _warmResultImageBytes() async {
    final f = widget.resultImageFile;
    if (f == null) return;
    try {
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        if (!mounted) return;
        setState(() => _cachedResultImageBytes = bytes);
      }
    } catch (e) {
      debugPrint('生成图内存缓存失败: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    // 如果 resultImageFile 存在且看起来来自系统临时目录或命名为 LoadingPage 生成的文件，标记为需要清理
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
      // 尽快把临时文件读入内存，避免用户在页面上停留后系统删掉 code_cache 导致无法保存
      unawaited(_warmResultImageBytes());
    }
  }

  @override
  void dispose() {
    // 如果需要删除临时生成的文件，异步尝试删除（dispose 不能 await，因此使用 then/catchError）
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
          // 背景层 - 添加orb动画效果
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

          // 内容层
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // 上半部分：原图缩略 (高斯模糊背景 + 小图)
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
                                AppColors.surface.withOpacity(0.15), // 降低透明度
                                AppColors.surface.withOpacity(0.3),
                                AppColors.surface.withOpacity(0.45),
                              ],
                              stops: const [0.0, 0.6, 1.0],
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("原图",
                                  style: TextStyle(color: AppColors.textGrey)),
                              const SizedBox(width: 10),
                              Hero(
                                tag:
                                    'pet_photo_hero', // 与preparation_page.dart保持一致
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

                // 下半部分：AI 大图
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        TransparentImageRoute(
                          builder: (_) => FullscreenImagePage(
                            imageFile: widget.resultImageFile ?? File(''),
                            heroTag: 'ai_result_hero',
                            isNetworkImage: widget.resultImageFile == null,
                            networkImage: widget.resultImageFile == null &&
                                    widget.resultImageUrl != null
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
                        alignment: Alignment.bottomCenter,
                        children: [
                          // 显示生成的结果图（优先使用本地下载文件）
                          widget.resultImageFile != null
                              ? Hero(
                                  tag: 'ai_result_hero',
                                  child: Image.file(
                                    widget.resultImageFile!,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                )
                              : Hero(
                                  tag: 'ai_result_hero',
                                  child: Image.network(
                                    widget.resultImageUrl ?? '',
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                          color: AppColors.primary,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.error_outline,
                                                size: 50, color: Colors.red),
                                            const SizedBox(height: 16),
                                            Text(
                                              '图片加载失败',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: AppColors.textDark),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '请检查网络连接后重试',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: AppColors.textGrey),
                                            ),
                                            const SizedBox(height: 16),
                                            ElevatedButton(
                                              onPressed: () {
                                                setState(() {
                                                  // Trigger rebuild to retry image loading
                                                });
                                              },
                                              child: const Text('重试'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                          // 浮动操作栏 (点赞/收藏) 使用毛玻璃效果
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
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
                                )
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
                          )
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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

                // 底部：保存按钮 - 使用毛玻璃效果
                Container(
                  height: 80,
                  padding: const EdgeInsets.all(20.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 毛玻璃背景效果
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

                      // 渐变色前景按钮
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
                              try {
                                late Uint8List bytes;

                                if (_cachedResultImageBytes != null &&
                                    _cachedResultImageBytes!.isNotEmpty) {
                                  bytes = _cachedResultImageBytes!;
                                } else if (widget.resultImageFile != null) {
                                  try {
                                    bytes = await widget.resultImageFile!
                                        .readAsBytes();
                                  } catch (_) {
                                    // 临时路径已被系统清理或文件已删，回退网络地址
                                    if (widget.resultImageUrl != null &&
                                        widget.resultImageUrl!.isNotEmpty) {
                                      final response = await http.get(
                                        Uri.parse(widget.resultImageUrl!),
                                      );
                                      if (response.statusCode != 200) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                            content: Text('本地文件已失效且下载失败'),
                                          ));
                                        }
                                        return;
                                      }
                                      bytes = response.bodyBytes;
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content: Text(
                                            '本地临时文件已失效，请返回重新生成后保存',
                                          ),
                                        ));
                                      }
                                      return;
                                    }
                                  }
                                } else if (widget.resultImageUrl != null &&
                                    widget.resultImageUrl!.isNotEmpty) {
                                  final response = await http
                                      .get(Uri.parse(widget.resultImageUrl!));
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
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text("未找到图片以保存")));
                                  }
                                  return;
                                }

                                await Gal.putImageBytes(
                                  bytes,
                                  album: 'Peture',
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("已保存到相册！")));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("保存出错: $e")));
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

  // 获取 AssetImage 的字节数据
  // ignore: unused_element
  Future<Uint8List?> _getAssetImageData(AssetImage image) async {
    final completer = Completer<ImageInfo>();
    image
        .resolve(const ImageConfiguration())
        .addListener(ImageStreamListener((info, _) {
      completer.complete(info);
    }));

    final imageInfo = await completer.future;
    final byteData =
        await imageInfo.image.toByteData(format: ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}

/// 透明背景路由：让下层页面在预览时直接可见
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

/// 全屏图片页
/// 特性：
/// 1. 独立全屏黑色背景，只负责暗化，不参与缩放。
/// 2. 图片层铺满全屏，InteractiveViewer 负责双指缩放，放大时覆盖全屏无死角。
/// 3. 支持下滑整体缩小 + 背景渐显。
/// 4. 隐藏状态栏。
class FullscreenImagePage extends StatefulWidget {
  final File imageFile;
  final String heroTag;
  final bool isAssetImage;
  final AssetImage? assetImage;
  final bool isNetworkImage;
  final NetworkImage? networkImage;

  const FullscreenImagePage({
    super.key,
    required this.imageFile,
    required this.heroTag,
    this.isAssetImage = false,
    this.assetImage,
    this.isNetworkImage = false,
    this.networkImage,
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
    // 缩放比例
    final scale = 1.0 - dragPercent * 0.4;
    // 背景透明度
    final bgOpacity = (1.0 - dragPercent).clamp(0.0, 1.0);

    return Stack(
      children: [
        // 1. 全屏黑色背景：固定不动，只变透明度
        Opacity(
          opacity: bgOpacity,
          child: Container(color: Colors.black),
        ),

        // 2. 交互层：铺满全屏，确保放大时不会被裁剪
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
                  // 让 child 居中，但 InteractiveViewer 本身是占满全屏的
                  child: Center(
                    child: Hero(
                      tag: widget.heroTag,
                      child: widget.isNetworkImage &&
                              widget.networkImage != null
                          ? Image.network(
                              widget.networkImage!.url,
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: Colors.white,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline,
                                        size: 50, color: Colors.white),
                                    const SizedBox(height: 16),
                                    Text(
                                      '图片加载失败',
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.white),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '请检查网络连接后重试',
                                      style: TextStyle(
                                          fontSize: 14, color: Colors.white70),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          // 触发重建以重试图片加载
                                        });
                                      },
                                      child: const Text('重试'),
                                    ),
                                  ],
                                );
                              },
                            )
                          : widget.isAssetImage && widget.assetImage != null
                              ? Image(image: widget.assetImage!)
                              : Image.file(
                                  widget.imageFile,
                                  fit: BoxFit.contain, // 初始完整显示
                                ),
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
