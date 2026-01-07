import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:io';
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

class LoadingPage extends StatefulWidget {
  final File originalImage;
  final String? uploadedFileName; // 添加上传的文件名参数
  final String taskId; // 添加任务ID参数
  
  const LoadingPage({required this.originalImage, this.uploadedFileName, required this.taskId});

  @override
  _LoadingPageState createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _orbController;
  Timer? _pollingTimer;
  Timer? _timeoutTimer;
  bool _isTaskFinished = false;
  String? _generatedImageUrl; // 存储生成的图片URL

  @override
  void initState() {
    super.initState();
    // 定义动画控制器，总时长设为40秒（基准参考）
    _progressController =
        AnimationController(vsync: this, duration: Duration(seconds: 40));
        
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _startLoadingProcess();
  }

  void _startLoadingProcess() async {
    // 设置整体超时时间（60秒）
    _timeoutTimer = Timer(Duration(seconds: 60), () {
      if (!_isTaskFinished) {
        _handleLoadingTimeout();
      }
    });

    try {
      // 阶段1: 快速启动，25秒内走到 65%
      // 我们使用 animateTo 模拟这个过程
      await _progressController.animateTo(0.65,
          duration: Duration(seconds: 1), curve: Curves.linear);

      // 阶段2: 25秒时刻，开始轮询后端
      _startPollingBackend();

      // 同时让进度条继续极慢地挪动，营造“正在努力计算”的感觉 (65% -> 85% 用时 30秒)
      if (!_isTaskFinished) {
        _progressController.animateTo(0.85,
            duration: Duration(seconds: 3), curve: Curves.decelerate);
      }
    } catch (e) {
      print('加载过程异常: $e');
      _timeoutTimer?.cancel();
      _progressController.stop();
      _handleLoadingError('加载过程发生异常，请重试');
    }
  }

  void _handleLoadingTimeout() {
    _isTaskFinished = true;
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel();
    _progressController.stop();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('生成时间过长，请稍后重试'),
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

  void _handleLoadingError(String message) {
    _isTaskFinished = true;
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel();
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
    // 每2秒查一次状态
    _pollingTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      try {
        // 参数验证：确保task_id和file_name都存在
        if (widget.taskId.isEmpty || widget.uploadedFileName == null || widget.uploadedFileName!.isEmpty) {
          timer.cancel();
          _handleLoadingError('缺少必要的参数，请重新生成');
          return;
        }
        
        // 调用真实的API查询状态
        final supabase = Supabase.instance.client;
        final res = await supabase.functions.invoke(
          'img-gen-check',
          body: {
            'task_id': widget.taskId,
            'file_name': widget.uploadedFileName,
          },
        );
        
        final data = res.data;
        if (data is Map<String, dynamic>) {
          final status = data['status'] as String?;
          final resultUrl = data['result_url'] as String?;
          final error = data['error'] as String?;
          
          print('Task status: $status');
          print('Result URL: $resultUrl');
          
          // 根据任务状态处理
          // 支持多种成功状态：'completed'（当前后端返回）和 'SUCCEED'（可能的后端直接返回值）
          if (status == 'completed' || status == 'SUCCEED') {
            timer.cancel();
            _isTaskFinished = true;
            // 直接在前端构建存储路径，不需要依赖后端返回的result_url
            final supabase = Supabase.instance.client;
            final user = supabase.auth.currentUser;
            if (user != null && widget.uploadedFileName != null) {
              final storagePath = '${user.id}/generated/${widget.uploadedFileName}';
              final publicUrl = supabase.storage
                  .from('ai-wallpapers')
                  .getPublicUrl(storagePath);
              _generatedImageUrl = publicUrl;
              // 立即执行任务完成逻辑，确保进度条更新和页面跳转
              _onTaskComplete();
            } else {
              // 处理用户或文件名缺失的情况
              timer.cancel();
              _handleLoadingError('无法构建图片路径，请重试');
            }
          } else if (status == 'failed') {
            timer.cancel();
            _isTaskFinished = true;
            // 任务失败，显示错误提示
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error != null ? 'AI图像生成失败: $error' : 'AI图像生成失败，请重试'),
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
          } else if (status == 'error') {
            timer.cancel();
            _isTaskFinished = true;
            // 任务发生错误
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error != null ? '生成过程发生错误: $error' : '生成过程发生错误，请重试'),
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
        } else {
          // 数据格式错误
          print('无效的响应数据格式: $data');
          if (timer.tick > 10) {
            timer.cancel();
            _handleLoadingError('服务器响应格式错误，请重试');
          }
        }
      } catch (e) {
        print('调用img-gen-check失败: $e');
        // 如果出现错误，可以选择继续轮询或者停止
        // 这里选择继续轮询，最多轮询10次
        if (timer.tick > 10) {
          timer.cancel();
          _handleLoadingError('查询生成状态失败，请检查网络连接');
        }
      }
    });
  }

  void _onTaskComplete() async {
    _timeoutTimer?.cancel();
    // 阶段3: 收到完成信号，快速冲刺到 100% (500毫秒)
    await _progressController.animateTo(1.0,
        duration: Duration(milliseconds: 500), curve: Curves.easeOut);

    // 跳转结果页
    if (mounted && _generatedImageUrl != null) {
      Navigator.pushReplacement(
          context,
          FadePageRoute(
              page: ResultPage(
                originalImage: widget.originalImage,
                resultImageUrl: _generatedImageUrl!, // 传递生成的图片URL
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