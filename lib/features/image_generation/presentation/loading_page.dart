import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../app_navigator.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/utils/ui_helpers.dart';
import 'result_page.dart';
import '../../moderation/data/moderation_client.dart';
import '../../moderation/domain/moderation_scene.dart';
import '../../content_feedback/presentation/ai_generated_image_disclaimer.dart';
import '../../moderation/presentation/moderation_dialog.dart';

class AppColors {
  static const Color background = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF5D5FEF);
  static const Color textDark = Color(0xFF1D1D1F);
  static const Color textGrey = Color(0xFF8E8E93);
  static const Color textLight = Color(0xFFAEAEB2);

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

class LoadingPage extends StatefulWidget {
  final File originalImage;
  final String uploadedFileName;
  final String style;
  final Future<FunctionResponse> generationFuture;
  final int expectedDurationSeconds;

  const LoadingPage({
    super.key,
    required this.originalImage,
    required this.uploadedFileName,
    required this.style,
    required this.generationFuture,
    this.expectedDurationSeconds = 120,
  });

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _orbController;
  Timer? _timeoutTimer;
  bool _isTaskFinished = false;
  bool _isTimeout = false; // 添加超时标志
  String? _generatedImageUrl; // 存储生成的图片URL（备用）
  File? _generatedImageFile; // 存储下载到本地的生成图片文件
  String? _generatedStoragePath;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
        vsync: this,
        duration: Duration(seconds: widget.expectedDurationSeconds));

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _startLoadingProcess();
    _startTimeoutTimer();
  }

  void _startLoadingProcess() {
    if (!_isTaskFinished) {
      _progressController.animateTo(0.95,
          duration: Duration(seconds: widget.expectedDurationSeconds),
          curve: Curves.decelerate);
    }
    _waitForGenerationResult();
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(const Duration(seconds: 480), () {
      if (!_isTaskFinished && !_isTimeout) {
        _isTimeout = true;
        _isTaskFinished = true;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('生成超时，请重试'),
              backgroundColor: Colors.orange,
            ),
          );
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
      }
    });
  }

  void _abortTaskPipeline() {
    _isTaskFinished = true;
    _progressController.stop();
    _timeoutTimer?.cancel();
  }

  void _handleLoadingError(String message) {
    if (!mounted) return;
    _abortTaskPipeline();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );

    // 先展示 SnackBar，再尽快返回上一页。
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _waitForGenerationResult() async {
    if (_isTaskFinished) return;

    try {
      final res = await widget.generationFuture;
      if (_isTaskFinished) return;

      final data = res.data;
      if (data == null || data is! Map) {
        _handleLoadingError('服务端返回格式错误');
        return;
      }

      final status = (data['status'] as String? ?? '').toUpperCase();
      final error = data['error']?.toString();

      // 处理限频
      if (res.status == 429 || status == 'TOO_FREQUENT') {
        final retryAfterMs = data['retry_after_ms'] as int?;
        final seconds =
            retryAfterMs == null ? null : (retryAfterMs / 1000).ceil();
        _handleLoadingError(seconds == null
            ? '请求过于频繁，请稍后重试'
            : '请求过于频繁，请 $seconds 秒后重试');
        return;
      }

      // 处理其他后端抛出的错误
      if (error != null && status != 'SUCCEED') {
        _handleLoadingError('生成失败: $error');
        return;
      }

      if (status != 'SUCCEED') {
        _handleLoadingError('AI 生图失败，未返回成功状态');
        return;
      }

      final path = data['path'] as String?;
      if (path == null || path.isEmpty) {
        _handleLoadingError('服务端未返回图片路径');
        return;
      }
      _generatedStoragePath = path;

      // 下载文件到临时目录供 ResultPage 极速加载
      final supabase = Supabase.instance.client;
      final bytes = await supabase.storage.from('ai-wallpapers').download(path);

      if (bytes.isNotEmpty) {
        final tmpFile = File(
            '${Directory.systemTemp.path}/ai_gen_${DateTime.now().millisecondsSinceEpoch}.png');
        await tmpFile.writeAsBytes(bytes);
        _generatedImageFile = tmpFile;
      }

      // 设置备用 URL
      _generatedImageUrl =
          supabase.storage.from('ai-wallpapers').getPublicUrl(path);

      _isTaskFinished = true;
      _onTaskComplete();
    } catch (e) {
      if (!_isTaskFinished) {
        debugPrint('生图请求异常: $e');
        _handleLoadingError('生图过程发生网络或服务异常，请重试');
      }
    }
  }

  void _onTaskComplete() async {
    if (!mounted) return;

    final moderationClient = ModerationClient();
    if (_generatedImageFile != null) {
      final bytes = await _generatedImageFile!.readAsBytes();
      final outputCheck = await moderationClient.moderateImageByBytes(
        scene: ModerationScene.imageOutput,
        bytes: bytes,
      );
      if (!outputCheck.passed) {
        _abortTaskPipeline();
        final rootCtx = AppNavigator.rootKey.currentContext;
        if (rootCtx != null) {
          await showModerationBlockedDialog(rootCtx, result: outputCheck);
        } else if (mounted) {
          _handleLoadingError(
            outputCheck.traceId.isEmpty
                ? '生成结果未通过内容审核，请重试'
                : '生成结果未通过内容审核（traceId: ${outputCheck.traceId}）',
          );
        }
        return;
      }
    } else if (_generatedStoragePath != null && _generatedStoragePath!.isNotEmpty) {
      final outputCheck = await moderationClient.moderateImageByStoragePath(
        scene: ModerationScene.imageOutput,
        storagePath: _generatedStoragePath!,
      );
      if (!outputCheck.passed) {
        _abortTaskPipeline();
        final rootCtx = AppNavigator.rootKey.currentContext;
        if (rootCtx != null) {
          await showModerationBlockedDialog(rootCtx, result: outputCheck);
        } else if (mounted) {
          _handleLoadingError(
            outputCheck.traceId.isEmpty
                ? '生成结果未通过内容审核，请重试'
                : '生成结果未通过内容审核（traceId: ${outputCheck.traceId}）',
          );
        }
        return;
      }
    }
    try {
      await _progressController.animateTo(1.0,
          duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    } catch (e) {
      debugPrint('进度动画失败（可能已被释放）: $e');
    }

    if (!mounted) return;

    if (_generatedImageFile != null || _generatedImageUrl != null) {
      Navigator.pushReplacement(
        context,
        FadePageRoute(
          page: ResultPage(
            originalImage: widget.originalImage,
            resultImageFile: _generatedImageFile,
            resultImageUrl: _generatedImageUrl,
          ),
        ),
      );
    }
  }

  String _getTechTip(int percentage) {
    final List<String> techTips = [
      "正在构建宠物毛发细节...",
      "优化光影效果...",
      "调整色彩饱和度...",
      "增强面部特征识别...",
      "最终渲染处理..."
    ];
    return techTips[(percentage ~/ 20) % techTips.length];
  }

  @override
  void dispose() {
    _isTaskFinished = true;
    _progressController.dispose();
    _orbController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Peture AI 图像实验室"),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            child: Center(
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  int percentage = (_progressController.value * 100).toInt();
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
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
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 200,
                                    height: 200,
                                    child: CircularProgressIndicator(
                                      value: _progressController.value,
                                      strokeWidth: 8,
                                      backgroundColor: const Color(0xFFE0E0E0),
                                      color: const Color(0xFF5D5FEF),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text("$percentage%",
                                          style: const TextStyle(
                                              color: Color(0xFF5D5FEF),
                                              fontSize: 36,
                                              fontFamily: "monospace",
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                        _getTechTip(percentage),
                                        style: const TextStyle(
                                          color: Color(0xFF8E8E93),
                                          fontSize: 12,
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
                      const SizedBox(height: 40),
                      const Text("正在构建宠物毛发细节...",
                          style: TextStyle(color: Color(0xFF8E8E93))),
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: AiGeneratedImageDisclaimer(compact: true),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
