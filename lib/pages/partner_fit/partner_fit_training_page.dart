import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/fitness_course.dart';
import '../../database/fitness_helper.dart';
import 'partner_fit_completion_page.dart';

/// 训练进行中页面
class PartnerFitTrainingPage extends StatefulWidget {
  final FitnessCourse course;

  const PartnerFitTrainingPage({super.key, required this.course});

  @override
  State<PartnerFitTrainingPage> createState() => _PartnerFitTrainingPageState();
}

class _PartnerFitTrainingPageState extends State<PartnerFitTrainingPage> {
  int currentActionIndex = 0;
  int remainingSeconds = 0;
  Timer? countdownTimer;
  bool isPaused = false;

  @override
  void initState() {
    super.initState();
    _startAction();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
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
          } else {
            timer.cancel();
            _nextAction();
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

  void _completeWorkout() {
    countdownTimer?.cancel();

    // 保存训练记录
    final record = FitnessRecord(
      courseId: widget.course.id,
      courseName: widget.course.name,
      completedAt: DateTime.now(),
      durationMinutes: widget.course.durationMinutes,
      caloriesBurned: widget.course.caloriesEstimate,
      petCaloriesBurned: widget.course.petCaloriesEstimate,
    );

    FitnessHelper.instance.addRecord(record);

    // 导航到完成页面
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PartnerFitCompletionPage(course: widget.course, record: record),
      ),
    );
  }

  String _formatTime(int seconds) {
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
              child: Row(
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
