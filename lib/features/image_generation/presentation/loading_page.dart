import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/page_tracker_mixin.dart';
import '../../../shared/utils/ui_helpers.dart';
import '../../content_feedback/presentation/ai_generated_image_disclaimer.dart';
import 'result_page.dart';

class AppColors {
  // New design system colors
  static const Color background = Color(0xFFFAF5FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF7C3AED);
  static const Color secondary = Color(0xFF6366F1);
  static const Color accent = Color(0xFFEC4899);
  static const Color textDark = Color(0xFF1D1D1F);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  // Gradient orbs with new palette
  static const Color orb1 = Color(0xFFD8B4FE);
  static const Color orb2 = Color(0xFFA78BFA);
  static const Color orb3 = Color(0xFFF9A8D4);

  // Progress gradient colors
  static const List<Color> progressGradient = [
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

class LoadingPage extends StatefulWidget {
  final File? originalImage;
  final String? originalImageUrl; // Web 平台使用 URL
  final String uploadedFileName;
  final String style;
  final Future<FunctionResponse> generationFuture;
  final int expectedDurationSeconds;

  const LoadingPage({
    super.key,
    this.originalImage,
    this.originalImageUrl,
    required this.uploadedFileName,
    required this.style,
    required this.generationFuture,
    this.expectedDurationSeconds = 120,
  });

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage>
    with TickerProviderStateMixin, PageTrackerMixin<LoadingPage> {
  late AnimationController _progressController;
  late AnimationController _orbController;
  late AnimationController _pulseController;
  late AnimationController _sparkleController;
  late AnimationController _tipController;
  Timer? _timeoutTimer;
  bool _isTaskFinished = false;
  bool _isTimeout = false;
  String? _generatedImageUrl;
  File? _generatedImageFile;
  int _currentTipIndex = 0;

  final List<String> _techTips = [
    "正在分析宠物照片特征...",
    "AI 正在构建毛发纹理细节...",
    "优化光影与色彩平衡...",
    "增强面部特征识别...",
    "进行最终渲染处理...",
    "即将完成，请稍候...",
  ];

  @override
  String get analyticsPageName => 'ai_image_loading';

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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _tipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _startLoadingProcess();
    _startTimeoutTimer();
    _startTipRotation();
  }

  void _startTipRotation() {
    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_isTaskFinished || !mounted) {
        timer.cancel();
        return;
      }
      _tipController.forward().then((_) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _techTips.length;
        });
        _tipController.reverse();
      });
    });
  }

  String get _currentTip => _techTips[_currentTipIndex];

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

  void _handleLoadingError(String message) {
    if (!mounted) return;
    _isTaskFinished = true;
    _progressController.stop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );

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

      if (res.status == 429 || status == 'TOO_FREQUENT') {
        final retryAfterMs = data['retry_after_ms'] as int?;
        final seconds =
            retryAfterMs == null ? null : (retryAfterMs / 1000).ceil();
        _handleLoadingError(
            seconds == null ? '请求过于频繁，请稍后重试' : '请求过于频繁，请 $seconds 秒后重试');
        return;
      }

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

      final supabase = Supabase.instance.client;
      final bytes = await supabase.storage.from('ai-wallpapers').download(path);

      if (bytes.isNotEmpty) {
        final tmpFile = File(
            '${Directory.systemTemp.path}/ai_gen_${DateTime.now().millisecondsSinceEpoch}.png');
        await tmpFile.writeAsBytes(bytes);
        _generatedImageFile = tmpFile;
      }

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
            originalImageUrl: widget.originalImageUrl,
            resultImageFile: _generatedImageFile,
            resultImageUrl: _generatedImageUrl,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _isTaskFinished = true;
    _progressController.dispose();
    _orbController.dispose();
    _pulseController.dispose();
    _sparkleController.dispose();
    _tipController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "正在生成...",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.5,
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
      ),
      body: Stack(
        children: [
          // Background gradient orbs
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.background,
                      AppColors.background.withOpacity(0.8),
                      const Color(0xFFF3E8FF),
                    ],
                  ),
                ),
              ),
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
                        gradient: RadialGradient(
                          colors: [
                            AppColors.orb1.withOpacity(0.6),
                            AppColors.orb1.withOpacity(0.2),
                          ],
                        ),
                      ),
                    ).blurred(sigmaX: 100, sigmaY: 100),
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
                        gradient: RadialGradient(
                          colors: [
                            AppColors.orb3.withOpacity(0.5),
                            AppColors.orb3.withOpacity(0.1),
                          ],
                        ),
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
                    bottom: -150,
                    left: -80 + (curvedValue * 150),
                    child: Container(
                      width: 600,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.orb2.withOpacity(0.5),
                            AppColors.orb2.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ).blurred(sigmaX: 110, sigmaY: 110),
                  );
                },
              ),
            ],
          ),

          // Sparkle particles
          AnimatedBuilder(
            animation: _sparkleController,
            builder: (context, child) {
              return Stack(
                children: _buildSparkles(),
              );
            },
          ),

          // Main content
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _progressController,
                  _pulseController,
                  _tipController,
                ]),
                builder: (context, child) {
                  int percentage = (_progressController.value * 100).toInt();
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Enhanced glassmorphism container
                      _buildMainContainer(percentage),
                      const SizedBox(height: 48),

                      // Tech tips with fade animation
                      _buildTechTipDisplay(),

                      const SizedBox(height: 24),

                      // Status indicator
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPulsingDot(),
                          const SizedBox(width: 8),
                          Text(
                            "AI 创作中",
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildMainContainer(int percentage) {
    final pulseScale = 1.0 + (_pulseController.value * 0.03);

    return Transform.scale(
      scale: pulseScale,
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            // Outer glow
            BoxShadow(
              color: AppColors.primary
                  .withOpacity(0.15 + (_pulseController.value * 0.1)),
              blurRadius: 30 + (_pulseController.value * 10),
              spreadRadius: 2,
            ),
            // Inner depth shadow
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
                  // Gradient progress ring
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: GradientProgressPainter(
                        progress: _progressController.value,
                        gradientColors: AppColors.progressGradient,
                        strokeWidth: 10,
                        backgroundColor: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),

                  // Inner glow ring
                  SizedBox(
                    width: 164,
                    height: 164,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Center content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Paw print icon with animation
                      _buildPawIcon(),
                      const SizedBox(height: 12),

                      // Percentage display
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: AppColors.progressGradient,
                        ).createShader(bounds),
                        child: Text(
                          "$percentage%",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Decorative paw prints around the ring
                  ..._buildFloatingPaws(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPawIcon() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.1);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: AppColors.progressGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
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
    );
  }

  List<Widget> _buildFloatingPaws() {
    return [
      Positioned(
        top: 20,
        right: 40,
        child: _buildSmallPaw(0.8, 0),
      ),
      Positioned(
        bottom: 40,
        left: 30,
        child: _buildSmallPaw(0.6, math.pi),
      ),
      Positioned(
        top: 60,
        left: 25,
        child: _buildSmallPaw(0.5, math.pi / 2),
      ),
    ];
  }

  Widget _buildSmallPaw(double scale, double rotationOffset) {
    return AnimatedBuilder(
      animation: _orbController,
      builder: (context, child) {
        final float =
            math.sin((_orbController.value * 2 * math.pi) + rotationOffset) * 3;
        return Transform.translate(
          offset: Offset(0, float),
          child: Opacity(
            opacity: 0.4,
            child: Icon(
              Icons.pets,
              color: AppColors.primary.withOpacity(0.5),
              size: 16 * scale,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTechTipDisplay() {
    final opacity = 1.0 - _tipController.value;

    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 150),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.6),
            width: 1,
          ),
        ),
        child: Text(
          _currentTip,
          style: const TextStyle(
            color: AppColors.textGrey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingDot() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary
                    .withOpacity(0.4 + (_pulseController.value * 0.4)),
                blurRadius: 8 + (_pulseController.value * 8),
                spreadRadius: _pulseController.value * 2,
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildSparkles() {
    final sparkles = <Widget>[];
    final random = math.Random(42);

    for (int i = 0; i < 12; i++) {
      final x = random.nextDouble() * 400 - 50;
      final y = random.nextDouble() * 800;
      final delay = random.nextDouble();
      final size = 3.0 + random.nextDouble() * 4;

      sparkles.add(
        Positioned(
          left: x,
          top: y,
          child: AnimatedBuilder(
            animation: _sparkleController,
            builder: (context, child) {
              final progress = ((_sparkleController.value + delay) % 1.0);
              final opacity = math.sin(progress * math.pi) * 0.6;
              final scale = 0.5 + math.sin(progress * math.pi) * 0.5;

              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.6),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return sparkles;
  }
}

// Custom painter for gradient progress ring
class GradientProgressPainter extends CustomPainter {
  final double progress;
  final List<Color> gradientColors;
  final double strokeWidth;
  final Color backgroundColor;

  GradientProgressPainter({
    required this.progress,
    required this.gradientColors,
    required this.strokeWidth,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc with gradient
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        colors: gradientColors,
        stops: const [0.0, 0.5, 1.0],
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + (2 * math.pi * progress),
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
  }

  @override
  bool shouldRepaint(covariant GradientProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
