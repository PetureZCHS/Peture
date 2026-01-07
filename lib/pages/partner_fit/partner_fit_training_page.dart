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
    with SingleTickerProviderStateMixin {
  int currentActionIndex = 0;
  int remainingSeconds = 0;
  Timer? countdownTimer;
  bool isPaused = false;
  
  // 实际运动时长（正计时）
  int actualDurationSeconds = 0;
  Timer? actualDurationTimer;
  DateTime? workoutStartTime;
  
  // 音效相关
  final AudioPlayer _tickSoundPlayer = AudioPlayer();
  bool _tickSoundEnabled = true;
  static const String _tickSoundEnabledKey = 'partner_fit_tick_sound_enabled';
  
  // 鼓励文字动画（致敬 Keep）
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
    // 初始化鼓励文字动画
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
    
    _loadTickSoundSetting();
    _startWorkout();
    _startAction();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    actualDurationTimer?.cancel();
    _tickSoundPlayer.dispose();
    _encouragementController.dispose();
    super.dispose();
  }

  /// 加载嘀嗒音效设置
  Future<void> _loadTickSoundSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _tickSoundEnabled = prefs.getBool(_tickSoundEnabledKey) ?? true;
      });
    } catch (e) {
      debugPrint('加载音效设置失败: $e');
    }
  }

  /// 开始训练（启动实际运动时长计时）
  void _startWorkout() {
    workoutStartTime = DateTime.now();
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

    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused) {
        setState(() {
          if (remainingSeconds > 0) {
            remainingSeconds--;
            // 播放嘀嗒音效
            if (_tickSoundEnabled) {
              _playTickSound();
            }
          } else {
            timer.cancel();
            // 动作完成时显示鼓励文字
            _showEncouragement();
            // 延迟一下再切换到下一个动作，让用户看到鼓励文字
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _nextAction();
              }
            });
          }
        });
      }
    });
  }

  void _nextAction() {
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
  
  /// 显示鼓励文字（致敬 Keep 风格）
  void _showEncouragement() {
    _encouragementText = _encouragementTexts[
      (currentActionIndex % _encouragementTexts.length)
    ];
    _encouragementController.reset();
    _encouragementController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _encouragementController.reverse();
        }
      });
    });
  }

  void _previousAction() {
    if (currentActionIndex > 0) {
      setState(() {
        currentActionIndex--;
      });
      _startAction();
    }
  }

  void _togglePause() {
    setState(() {
      isPaused = !isPaused;
    });
  }

  /// 播放嘀嗒音效
  Future<void> _playTickSound() async {
    if (!_tickSoundEnabled) return;
    try {
      // 使用系统提示音（轻量级，无需额外音频文件）
      SystemSound.play(SystemSoundType.click);
      // 配合触觉反馈增强体验
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('播放嘀嗒音效失败: $e');
    }
  }

  Future<void> _completeWorkout() async {
    countdownTimer?.cancel();
    actualDurationTimer?.cancel();

    // 计算实际运动时长（分钟）
    final actualDurationMinutes = (actualDurationSeconds / 60).ceil();

    // 保存训练记录（使用实际运动时长）
    final record = FitnessRecord(
      courseId: widget.course.id,
      courseName: widget.course.name,
      completedAt: DateTime.now(),
      durationMinutes: actualDurationMinutes, // 使用实际运动时长
      caloriesBurned: widget.course.caloriesEstimate,
      petCaloriesBurned: widget.course.petCaloriesEstimate,
    );

    final supabaseService = SupabaseService();
    final result = await supabaseService.insertFitnessRecord(record.toMap());
    
    if (result == null) {
      // 保存失败，显示错误提示
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

  /// 格式化时间显示（使用等宽字体，小于100秒时仅显示秒数）
  String _formatTime(int seconds) {
    // 如果小于100秒，仅显示秒数
    if (seconds < 100) {
      return seconds.toString();
    }
    
    // 大于等于100秒，显示 MM:SS 格式
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 格式化实际运动时长
  String _formatActualDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0) {
      return '${mins}分${secs}秒';
    } else {
      return '${secs}秒';
    }
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
                          // 进度圆环
                          SizedBox(
                            width: 220,
                            height: 220,
                            child: CircularProgressIndicator(
                              value: remainingSeconds / action.durationSeconds,
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
                                  fontFamily: 'monospace', // 等宽字体，避免冒号抖动
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
                              // 实际运动时长
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
                    
                    // 鼓励文字（致敬 Keep）
                    AnimatedBuilder(
                      animation: _encouragementFadeAnimation,
                      builder: (context, child) {
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
                  // 音效开关
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
                  // 控制按钮
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
                  // 致敬 Keep 的小标签
                  Text(
                    'Inspired by Keep',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                    ),
                  ),
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
