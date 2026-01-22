import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/ui_helpers.dart';
import 'result_page.dart';

// 添加颜色常量定义，与chat_page.dart保持一致
class AppColors {
  static const Color background = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF); // 卡片表面颜色
  static const Color primary = Color(0xFF5D5FEF);
  static const Color textDark = Color(0xFF1D1D1F);
  static const Color textGrey = Color(0xFF8E8E93);
  static const Color textLight = Color(0xFFAEAEB2); // 更淡的文字颜色

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

// 新增：从左侧滑入并带淡入效果的 PageRoute，用于返回时更自然的动画
class SlideFromLeftPageRoute extends PageRouteBuilder {
  final Widget page;

  SlideFromLeftPageRoute({required this.page})
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
          ) {
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

            final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeIn));

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(opacity: fadeAnimation, child: child),
            );
          },
        );
}

class LoadingPage extends StatefulWidget {
  final File originalImage;
  final String? uploadedFileName; // 添加上传的文件名参数
  final String taskId; // 必需的任务ID参数（不能为空）
  final String style; // 风格参数（必需）
  final int expectedDurationSeconds; // 预期完成时间（秒），决定进度动画速度

  const LoadingPage({required this.originalImage, this.uploadedFileName, required this.taskId, required this.style, this.expectedDurationSeconds = 180});

  @override
  _LoadingPageState createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _orbController;
  Timer? _pollingTimer;
  Timer? _timeoutTimer; // 添加超时计时器
  bool _isTaskFinished = false;
  bool _isTimeout = false; // 添加超时标志
  String? _generatedImageUrl; // 存储生成的图片URL（备用）
  File? _generatedImageFile; // 存储下载到本地的生成图片文件

  @override
  void initState() {
    super.initState();
    // 定义动画控制器，总时长基于预期完成时长（默认 50s，可通过 constructor 覆盖，用于更平滑长任务的进度表现）
    _progressController =
        AnimationController(vsync: this, duration: Duration(seconds: widget.expectedDurationSeconds));
        
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    // taskId 必需；Preparation 页面应先调用 img-gen-start 并传入 taskId。

    _startLoadingProcess();
    _startTimeoutTimer(); // 启动超时计时器
  }

  void _startLoadingProcess() async {
    // 不设置整体超时时间，等待后端完成（上游任务可能无固定时长）

    // taskId 在此处应当是必需的（由 PreparationPage 提供）——如果为空则直接报错提示并返回
    if (widget.taskId.isEmpty) {
      print('LoadingPage: taskId 为空，无法轮询任务状态');
      _handleLoadingError('内部错误：缺少任务 ID');
      return;
    }

    try {
        // 立即开始轮询后端（每5s一次）并把进度平滑推进到 95%（时长根据 expectedDurationSeconds）
      _startPollingBackend();

      if (!_isTaskFinished) {
        await _progressController.animateTo(0.95,
            duration: Duration(seconds: widget.expectedDurationSeconds), curve: Curves.decelerate);
      }
    } catch (e) {
      print('加载过程异常: $e');
      _progressController.stop();
      _handleLoadingError('加载过程发生异常，请重试');
    }
  }

  void _startTimeoutTimer() {
    // 设置最大轮询时间为8分钟（480秒）
    _timeoutTimer = Timer(Duration(seconds: 480), () {
      if (!_isTaskFinished && !_isTimeout) {  // 添加双重检查以避免重复处理
        _isTimeout = true;
        _pollingTimer?.cancel();
        _isTaskFinished = true;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('生成超时，请重试'),
              backgroundColor: Colors.orange,
            ),
          );
          
          // 直接返回到之前的PreparationPage实例
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
    _isTaskFinished = true;
    _pollingTimer?.cancel();
    _progressController.stop();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: '返回',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      );
    }
  }

  void _startPollingBackend() {
    // 每 5s 检查一次，持续轮询直到任务完成（或由错误处理提前终止）。

    Future<void> checkOnce() async {

      // 如果任务已经标记完成，则立即返回，避免额外的轮询或竞态
      if (_isTaskFinished) return;

      final taskIdToUse = widget.taskId;

      // 参数验证：确保文件名存在
      if (widget.uploadedFileName == null || widget.uploadedFileName!.isEmpty) {
        _pollingTimer?.cancel();
        _handleLoadingError('缺少必要的参数，请重新生成');
        return;
      }

      try {
        final supabase = Supabase.instance.client;
        final token = supabase.auth.currentSession?.accessToken;
        if (token == null) {
          _pollingTimer?.cancel();
          _handleLoadingError('未登录或会话已过期');
          return;
        }

        final res = await supabase.functions.invoke(
          'img-gen-check-v2',
          body: {
            'task_id': taskIdToUse,
            'file_name': widget.uploadedFileName,
          },
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        final data = res.data;
        if (data is Map<String, dynamic>) {
          final status = ((data['status'] as String?) ?? '').toUpperCase();
          final path = data['path'] as String?;


          print('Task status: $status');

          if (status == 'PENDING' || status == 'RUNNING') {
            // 还在运行，等待下一次轮询
            return;
          }

          // 成功类状态：立刻停止轮询并进入完成流程（兼容不同后端状态字符串）
          if (status == 'SUCCEED' || status == 'SUCCEEDED' || status == 'COMPLETED' || status == 'SUCCESS' || status == 'DONE') {
            _pollingTimer?.cancel();
            _isTaskFinished = true;

            // 优先尝试下载存储中的文件到本地临时目录
            if (path != null && path.isNotEmpty) {
              try {
                final bytes = await supabase.storage.from('ai-wallpapers').download(path) as Uint8List?;

                if (bytes != null && bytes.isNotEmpty) {
                  final tmpFile = File('${Directory.systemTemp.path}/ai_gen_${DateTime.now().millisecondsSinceEpoch}.png');
                  await tmpFile.writeAsBytes(bytes);
                  _generatedImageFile = tmpFile;
                  _onTaskComplete();
                  return;
                } else {
                  // 下载返回为空，则回退到 public url 方式
                  print('下载返回为空，尝试使用publicUrl回退');
                }
              } catch (e) {
                print('下载存储文件失败: $e，尝试回退到 publicUrl');
              }
            }

            // 回退方案：使用 public url
            String? publicUrl;
            final user = supabase.auth.currentUser;
            if (path != null && path.isNotEmpty) {
              publicUrl = supabase.storage.from('ai-wallpapers').getPublicUrl(path);
            } else if (user != null && widget.uploadedFileName != null) {
              final storagePath = '${user.id}/generated/${widget.uploadedFileName}';
              publicUrl = supabase.storage.from('ai-wallpapers').getPublicUrl(storagePath);
            }

            if (publicUrl != null && publicUrl.isNotEmpty) {
              _generatedImageUrl = publicUrl;
              _onTaskComplete();
            } else {
              _handleLoadingError('无法获取或下载生成图片，请重试');
            }
            return;
          }

          if (status == 'FAILED' || status == 'FAILURE' || status == 'ERROR') {
            _pollingTimer?.cancel();
            _isTaskFinished = true;
            // 后端失败时返回到 PreparationPage 并给出友好提示
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('后端繁忙，请稍后重试！'),
                  backgroundColor: Colors.orange,
                ),
              );
              // 直接返回到之前的PreparationPage实例
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted) {
                  Navigator.pop(context);
                }
              });
            }
            return;
          }
        } else {
          print('无效的响应数据格式: $data');
          // 忽略格式错误，等待下一次轮询
        }
      } catch (e) {
        print('调用img-gen-check失败: $e');
        // 忽略临时网络错误，等待下一次轮询
      }
    }

    // 先立即检查一次
    checkOnce();

    // 然后每5秒检查一次
    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_isTaskFinished) {
        timer.cancel();
        return;
      }
      checkOnce();
    });
  }

  void _onTaskComplete() async {
    // 如果 Widget 已被移除（disposed），就不继续执行，防止对已释放的 controller 调用方法
    if (!mounted) return;

    // 阶段3: 收到完成信号，快速冲刺到 100% (500毫秒)
    try {
      await _progressController.animateTo(1.0,
          duration: Duration(milliseconds: 500), curve: Curves.easeOut);
    } catch (e) {
      // 如果在动画期间 controller 被 dispose，会抛出断言；捕获并继续（避免崩溃）
      print('进度动画失败（可能已被释放）: $e');
    }

    // 再次检查 mounted，确保安全导航
    if (!mounted) return;

    // 跳转结果页
    if (_generatedImageFile != null || _generatedImageUrl != null) {
      Navigator.pushReplacement(
          context,
          FadePageRoute(
              page: ResultPage(
            originalImage: widget.originalImage,
            resultImageFile: _generatedImageFile,
            resultImageUrl: _generatedImageUrl,
          )));
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
    
    // 根据进度选择提示文本
    return techTips[(percentage ~/ 20) % techTips.length];
  }

  @override
  void dispose() {
    _progressController.dispose();
    _orbController.dispose();
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel(); // 取消超时计时器
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
          // 背景层 - 添加orb动画效果
          Stack(
            children: [
              Container(color: AppColors.background),
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  final curvedValue = CurvedAnimation(parent: _orbController, curve: Curves.easeInOut).value;
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
                  final curvedValue = CurvedAnimation(parent: _orbController, curve: Curves.easeInOut).value;
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
                  final curvedValue = CurvedAnimation(parent: _orbController, curve: Curves.easeInOut).value;
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
            child: Center(
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  int percentage = (_progressController.value * 100).toInt();
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 科技感环形进度条容器 - 使用毛玻璃效果
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
                                    AppColors.surface.withOpacity(0.15), // 降低透明度
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
                                          style: TextStyle(
                                              color: const Color(0xFF5D5FEF),
                                              fontSize: 36,
                                              fontFamily: "monospace",
                                              fontWeight: FontWeight.bold)),
                                      // 技术提示列表
                                      Text(
                                        _getTechTip(percentage),
                                        style: TextStyle(
                                          color: const Color(0xFF8E8E93),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 40),
                      // 这里可以放一些随机的"技术Tips"增加趣味性
                      Text("正在构建宠物毛发细节...",
                          style: TextStyle(color: const Color(0xFF8E8E93))),
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