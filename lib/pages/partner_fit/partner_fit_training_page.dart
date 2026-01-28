import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/fitness_course.dart';
import '../../services/supabase_service.dart';
import 'partner_fit_completion_page.dart';

/// 训练进行中页面
class PartnerFitTrainingPage extends StatefulWidget {
  final FitnessCourse course;

  const PartnerFitTrainingPage({super.key, required this.course});

  @override
  State<PartnerFitTrainingPage> createState() => _PartnerFitTrainingPageState();
}

class _PartnerFitTrainingPageState extends State<PartnerFitTrainingPage>
    with TickerProviderStateMixin {
  int currentActionIndex = 0;
  int remainingSeconds = 0;
  bool isPaused = false;

  // 动画控制 (来自 Develop 分支)
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  DateTime? _startTime;
  Duration? _remainingDuration;
  double? _pausedAnimationValue;

  // 实际运动时长（正计时 - 来自当前分支）
  int actualDurationSeconds = 0;
  Timer? actualDurationTimer;
  
  // 音效相关 (来自当前分支)
  final AudioPlayer _tickSoundPlayer = AudioPlayer();
  bool _tickSoundEnabled = true;
  static const String _tickSoundEnabledKey = 'partner_fit_tick_sound_enabled';
  
  // 鼓励文字动画（致敬 Keep - 来自当前分支）
  late AnimationController _encouragementController;
  late Animation<double> _encouragementFadeAnimation;
  String? _encouragementText;
  
  // Keep 风格的鼓励文案
  static const List<String> _encouragementTexts = [
    '加油！',
    '坚持！',
    '很棒！',
    '继续！',
    '很好！',
  ];

  @override
  void initState() {
    super.initState();
    
    // 初始化鼓励文字动画控制器
    _encouragementController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _encouragementFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _encouragementController,
      curve: Curves.easeOut,
    ));

    // 初始化倒计时动画控制器 (Develop 特性)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // 初始值，会在_startAction中更新
    );

    _progressAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_animationController)
      ..addListener(() {
        if (mounted) {
          setState(() {
            // 动画更新时重新计算剩余时间
            if (_remainingDuration != null && _startTime != null) {
              final elapsed = DateTime.now().difference(_startTime!);
              final totalDuration = _remainingDuration!;
              if (elapsed < totalDuration) {
                final newRemainingSeconds = (totalDuration - elapsed).inSeconds;
                
                // 只有当秒数发生变化时才执行特定逻辑
                if (newRemainingSeconds != remainingSeconds) {
                  remainingSeconds = newRemainingSeconds;
                  // 播放嘀嗒音效 (当前分支特性)
                  if (remainingSeconds > 0 && _tickSoundEnabled) {
                    _playTickSound();
                  }
                }
              } else {
                remainingSeconds = 0;
              }
            }
          });
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // 动作完成
          _handleActionComplete();
        }
      });

    _loadTickSoundSetting();
    _startWorkout(); // 开始实际时长计时
    _startAction();
  }

  @override
  void dispose() {
    actualDurationTimer?.cancel();
    _animationController.dispose();
    _encouragementController.dispose();
    _tickSoundPlayer.dispose();
    super.dispose();
  }

  /// 加载嘀嗒音效设置
  Future<void> _loadTickSoundSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _tickSoundEnabled = prefs.getBool(_tickSoundEnabledKey) ?? true;
        });
      }
    } catch (e) {
      debugPrint('加载音效设置失败: $e');
    }
  }

  /// 播放嘀嗒音效
  Future<void> _playTickSound() async {
    try {
      // 使用系统提示音
      await SystemSound.play(SystemSoundType.click);
      // 配合触觉反馈
      await HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('播放嘀嗒音效失败: $e');
    }
  }

  /// 开始训练（启动实际运动时长计时）
  void _startWorkout() {
    actualDurationTimer?.cancel();
    actualDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused && mounted) {
        setState(() {
          actualDurationSeconds++;
        });
      }
    });
  }

  void _startAction() {
    final action = widget.course.actions[currentActionIndex];
    setState(() {
      remainingSeconds = action.durationSeconds;
      isPaused = false;
    });

    // 这里不再使用 Timer (Develop 分支改用了 AnimationController)
    
    // 设置动画控制器持续时间 (Develop 逻辑)
    _animationController.duration = Duration(seconds: action.durationSeconds);
    _remainingDuration = Duration(seconds: action.durationSeconds);
    _startTime = DateTime.now();
    _pausedAnimationValue = null; // 重置暂停值

    // 重新创建从1.0到0.0的动画
    _progressAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_animationController);

    // 重置动画并开始
    _animationController.reset();
    _animationController.forward();
  }

  void _handleActionComplete() {
    // 动作完成时显示鼓励文字 (当前分支特性)
    _showEncouragement();
    
    // 延迟一下再切换到下一个动作，让用户看到鼓励文字
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _nextAction();
      }
    });
  }

  void _nextAction() {
    _animationController.stop();
    if (currentActionIndex < widget.course.actions.length - 1) {
      setState(() {
        currentActionIndex++;
      });
      _startAction();
    } else {
      // 完成所有动作
      _completeWorkout();
    }
  }

  void _previousAction() {
    _animationController.stop();
    if (currentActionIndex > 0) {
      setState(() {
        currentActionIndex--;
      });
      _startAction();
    }
  }

  /// 显示鼓励文字（致敬 Keep 风格）
  void _showEncouragement() {
    setState(() {
      _encouragementText = _encouragementTexts[
        (currentActionIndex % _encouragementTexts.length)
      ];
    });
    _encouragementController.reset();
    _encouragementController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _encouragementController.reverse();
        }
      });
    });
  }

  void _togglePause() {
    setState(() {
      isPaused = !isPaused;
    });

    if (isPaused) {
      // 暂停时停止动画并保存剩余时间和当前动画值 (Develop 逻辑)
      _animationController.stop();
      _pausedAnimationValue = _progressAnimation.value;
      if (_startTime != null && _remainingDuration != null) {
        final elapsed = DateTime.now().difference(_startTime!);
        _remainingDuration = _remainingDuration! - elapsed;
      }
    } else {
      // 继续时从暂停位置重新开始动画 (Develop 逻辑)
      if (_remainingDuration != null && _remainingDuration!.inSeconds > 0 && _pausedAnimationValue != null) {
        _animationController.duration = _remainingDuration;
        _startTime = DateTime.now();

        // 从暂停时的位置开始动画
        _progressAnimation = Tween<double>(
          begin: _pausedAnimationValue,
          end: 0.0,
        ).animate(_animationController);

        _animationController.reset();
        _animationController.forward();
      }
    }
  }

  Future<void> _completeWorkout() async {
    _animationController.stop();
    actualDurationTimer?.cancel();

    // 计算实际运动时长（分钟）(当前分支特性)
    final actualDurationMinutes = (actualDurationSeconds / 60).ceil();

    // 构建训练记录
    final record = FitnessRecord(
      courseId: widget.course.id,
      courseName: widget.course.name,
      completedAt: DateTime.now(),
      durationMinutes: actualDurationMinutes, // 使用实际运动时长
      caloriesBurned: widget.course.caloriesEstimate,
      petCaloriesBurned: widget.course.petCaloriesEstimate,
    );

    final supabaseService = SupabaseService();
    // 先检查是否登录
    final loggedIn = await supabaseService.isLoggedIn;

    if (!loggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前未登录，无法将训练记录同步到云端，请先通过邮箱登录。'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // 仍然允许进入完成页面，只是本次记录不会存到 Supabase
    } else {
      // 尝试保存训练记录
      final result = await supabaseService.insertFitnessRecord(record.toMap());

      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('训练记录保存失败，可能是网络或 Supabase 权限问题，请稍后重试。'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // 即使保存失败，也允许用户看到完成页面的反馈
      }
    }

    // 导航到完成页面
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PartnerFitCompletionPage(course: widget.course, record: record),
        ),
      );
    }
  }

  /// 格式化时间显示 (当前分支特性：等宽字体适配)
  String _formatTime(int seconds) {
    if (seconds < 100) {
      return seconds.toString();
    }
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 格式化实际运动时长为 mm:ss
  String _formatActualDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double get progress {
    if (widget.course.actions.isEmpty) return 0;
    return (currentActionIndex + 1) / widget.course.actions.length;
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.course.actions[currentActionIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部进度条和关闭按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF1E1E1E)),
                    onPressed: () {
                      _showExitDialog();
                    },
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${currentActionIndex + 1} / ${widget.course.actions.length}',
                          style: const TextStyle(
                            color: Color(0xFF424242),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: const Color(0xFFF0F2F5),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF5A8EFA),
                          ),
                          minHeight: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // 主要内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // 倒计时大圆圈
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 进度圆环 (使用 Develop 的 _progressAnimation)
                          SizedBox(
                            width: 220,
                            height: 220,
                            child: CircularProgressIndicator(
                              value: _progressAnimation.value,
                              strokeWidth: 12,
                              backgroundColor: const Color(0xFFF0F2F5),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF5A8EFA),
                              ),
                            ),
                          ),
                          // 时间文字
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _formatTime(remainingSeconds),
                                style: const TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E1E1E),
                                  letterSpacing: 2,
                                  fontFamily: 'monospace', // 当前分支特性：等宽字体
                                ),
                              ),
                              Text(
                                isPaused ? '已暂停' : '剩余时间',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF424242),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // 实际运动时长（显示为 mm:ss）
                              Text(
                                '实际运动时长：${_formatActualDuration(actualDurationSeconds)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8E8E93),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 动作名称
                    Text(
                      action.name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1E1E),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 鼓励文字（致敬 Keep - 来自当前分支）
                    AnimatedBuilder(
                      animation: _encouragementFadeAnimation,
                      builder: (context, child) {
                        // 确保动画在不可见时不占位
                        if (_encouragementText == null || _encouragementFadeAnimation.value == 0) {
                          return const SizedBox.shrink(); 
                        }
                        return Opacity(
                          opacity: _encouragementFadeAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35).withOpacity(0.1), // Keep 风格的橙色
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFFF6B35).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _encouragementText!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF6B35), // Keep 风格的橙色
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // 音频指导
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.mic, color: Color(0xFF5A8EFA)),
                              SizedBox(width: 8),
                              Text(
                                '音频指导',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E1E1E),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            action.audioGuide,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF424242),
                              height: 1.6,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 动作演示
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.accessibility_new,
                                color: Colors.greenAccent,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '动作演示',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E1E1E),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            action.demonstration,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF424242),
                              height: 1.6,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 底部控制按钮
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   // 音效开关 (当前分支特性)
                  IconButton(
                    onPressed: () async {
                      setState(() {
                        _tickSoundEnabled = !_tickSoundEnabled;
                      });
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(_tickSoundEnabledKey, _tickSoundEnabled);
                      } catch (e) {
                        debugPrint('保存音效设置失败: $e');
                      }
                    },
                    icon: Icon(
                      _tickSoundEnabled ? Icons.volume_up : Icons.volume_off,
                      size: 20,
                      color: const Color(0xFF8E8E93),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 上一个
                      IconButton(
                        onPressed: currentActionIndex > 0 ? _previousAction : null,
                        icon: const Icon(Icons.skip_previous, size: 36),
                        color: const Color(0xFF424242),
                        disabledColor: const Color(0xFFE0E0E0),
                      ),

                      // 暂停/继续
                      GestureDetector(
                        onTap: _togglePause,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
                            ),
                          ),
                          child: Icon(
                            isPaused ? Icons.play_arrow : Icons.pause,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // 下一个
                      IconButton(
                        onPressed:
                            currentActionIndex < widget.course.actions.length - 1
                            ? _nextAction
                            : null,
                        icon: const Icon(Icons.skip_next, size: 36),
                        color: const Color(0xFF424242),
                        disabledColor: const Color(0xFFE0E0E0),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确定退出训练？'),
        content: const Text('当前训练进度将不会被保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('继续训练'),
          ),
          TextButton(
            onPressed: () {
              // 先关闭对话框
              Navigator.pop(dialogContext);
              // 延迟执行导航，避免冲突
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  // 退出训练页面
                  Navigator.of(context).pop();
                  // 退出详情页
                  Navigator.of(context).pop();
                }
              });
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
