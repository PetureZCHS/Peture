import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

/// 高级专业训宠响片设备
/// 采用现代专业训犬设备风格：哑光深灰机身、RGB氛围灯、高端触控旋钮
///
/// 交互流程：
/// 1. 待命状态：显示提示语
/// 2. 点击响片 (onClick)：播放声音 + 触觉反馈 + 进入待确认状态
/// 3. 待确认状态 (pendingConfirmation=true)：显示「✓ 成功」「✗ 失败」按钮
/// 4. 用户确认：onConfirmSuccess 或 onConfirmFail
class SkeuomorphicClickerDevice extends StatefulWidget {
  final int successCount;
  final int failCount;
  final int unconfirmedCount; // 未确认的点击次数
  final int totalSuccessCount;
  final int totalFailCount;
  final String currentProject;
  final List<String> projects;
  final int selectedIndex;
  final VoidCallback onSuccess; // 保留兼容旧逻辑（直接成功）
  final VoidCallback onFail; // 保留兼容旧逻辑
  final VoidCallback? onClick; // 新：响片点击（只播放声音，不计数）
  final VoidCallback? onConfirmSuccess; // 新：确认成功
  final VoidCallback? onConfirmFail; // 新：确认失败
  final VoidCallback? onSkipConfirm; // 新：跳过确认（记为未确认）
  final Function(int) onProjectChanged;
  final VoidCallback onAddProject;
  final Function(String) onDeleteProject; // 删除训练项目
  final VoidCallback onReset; // 重置当前项目统计
  final VoidCallback onShowStats; // 显示详细统计
  final bool isCoolingDown;
  final bool pendingConfirmation; // 是否处于待确认状态

  const SkeuomorphicClickerDevice({
    super.key,
    required this.successCount,
    required this.failCount,
    this.unconfirmedCount = 0,
    required this.totalSuccessCount,
    required this.totalFailCount,
    required this.currentProject,
    required this.projects,
    required this.selectedIndex,
    required this.onSuccess,
    required this.onFail,
    this.onClick,
    this.onConfirmSuccess,
    this.onConfirmFail,
    this.onSkipConfirm,
    required this.onProjectChanged,
    required this.onAddProject,
    required this.onDeleteProject,
    required this.onReset,
    required this.onShowStats,
    required this.isCoolingDown,
    this.pendingConfirmation = false,
  });

  @override
  State<SkeuomorphicClickerDevice> createState() =>
      _SkeuomorphicClickerDeviceState();
}

class _SkeuomorphicClickerDeviceState extends State<SkeuomorphicClickerDevice>
    with TickerProviderStateMixin {
  // 旋钮回弹动画
  late AnimationController _knobRotationController;
  late Animation<double> _knobRotationAnimation;

  // 按压缩放动画
  late AnimationController _pressController;
  late Animation<double> _pressAnimation;

  // 玻璃反光动画
  late AnimationController _glareController;
  late Animation<double> _glareAnimation;

  // RGB 氛围灯呼吸动画
  late AnimationController _rgbController;
  late Animation<double> _rgbAnimation;

  // 脉冲波纹动画
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // 成功闪烁动画
  late AnimationController _successFlashController;

  // 摔碎闪白动画
  late AnimationController _breakFlashController;

  // 冷却进度动画
  late AnimationController _cooldownController;
  late Animation<double> _cooldownAnimation;

  // 数字滚动动画
  late AnimationController _numberRollController;
  late Animation<double> _numberRollAnimation;
  int _previousSuccessCount = 0;

  // 砸设备 - 连续长按蓄力系统
  late AnimationController _smashChargeController; // 蓄力进度
  late AnimationController _smashDropController; // 掉落动画
  double _smashProgress = 0.0; // 0.0~1.0 破坏程度
  bool _isLongPressing = false; // 是否正在长按
  bool _isDropping = false; // 是否正在掉落
  bool _isDestroyed = false; // 是否已完全破坏
  List<_ComponentPart> _fallenParts = []; // 掉落的零部件
  List<_CrackLine> _crackLines = [];
  int _lastCrackUpdate = -1; // 防止重复更新裂纹
  bool _isRepairing = false; // 是否正在修复中
  late AnimationController _repairController; // 修复动画控制器

  // 摇晃检测相关
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _lastShakeTime = 0; // 上次检测到摇晃的时间
  double _shakeAccumulator = 0; // 摇晃累积量
  bool _isShaking = false; // 是否正在摇晃
  static const double _shakeThreshold = 15.0; // 摇晃检测阈值
  static const double _shakeDecayRate = 0.02; // 摇晃累积衰减速率

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    // 旋钮回弹动画 - 更高级的阻尼效果
    _knobRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _knobRotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -0.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.12, end: 0.06)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.06, end: -0.03)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.03, end: 0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
    ]).animate(_knobRotationController);

    // 按压缩放动画
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
    );
    _pressAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    // 玻璃反光动画
    _glareController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _glareAnimation = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(parent: _glareController, curve: Curves.easeInOut),
    );

    // RGB 氛围灯呼吸动画
    _rgbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _rgbAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _rgbController, curve: Curves.easeInOut),
    );

    // 脉冲波纹动画
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // 成功闪烁
    _successFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 摔碎闪白动画
    _breakFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    // 冷却进度动画 - 与冷却时间同步（250ms）
    _cooldownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _cooldownAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cooldownController, curve: Curves.linear),
    );

    // 数字滚动动画
    _numberRollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _numberRollAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _numberRollController, curve: Curves.easeOutBack),
    );
    _previousSuccessCount = widget.successCount;

    // 砸设备 - 蓄力控制器（长按时持续增加）
    _smashChargeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // 2秒充满
    );
    // 监听蓄力进度，实时更新UI
    _smashChargeController.addListener(() {
      if (_isLongPressing && !_isDestroyed) {
        final newProgress = _smashChargeController.value;
        // 进度变化时更新状态
        if (newProgress != _smashProgress) {
          setState(() {
            _smashProgress = newProgress;
          });
        }
        // 只在特定进度点更新裂纹和触发震动
        final progressPercent = (_smashProgress * 100).toInt();
        if (progressPercent % 10 == 0 && _lastCrackUpdate != progressPercent) {
          _lastCrackUpdate = progressPercent;
          _updateCracks();
          if (progressPercent >= 30) HapticFeedback.mediumImpact();
          if (progressPercent >= 60) HapticFeedback.heavyImpact();
        }
        // 蓄力满100%时自动触发破碎
        if (_smashProgress >= 1.0) {
          _triggerDrop();
        }
      }
    });

    // 掉落动画控制器
    _smashDropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _smashDropController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 掉落完成，等待用户手动拼装
        setState(() {
          _isDropping = false; // 标记掉落动画完成
        });
      }
    });

    // 修复动画控制器
    _repairController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _repairController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 修复动画完成，恢复设备
        _finishRepair();
      }
    });

    // 启动摇晃检测
    _startShakeDetection();
  }

  /// 启动摇晃检测
  void _startShakeDetection() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      if (_isDestroyed || _isRepairing) return;

      // 计算加速度的变化幅度（排除重力）
      final double acceleration =
          math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      final now = DateTime.now().millisecondsSinceEpoch.toDouble();

      // 检测是否有剧烈晃动
      if (acceleration > _shakeThreshold) {
        // 距离上次摇晃的时间间隔
        final timeDelta = now - _lastShakeTime;
        _lastShakeTime = now;

        // 只有在短时间内连续摇晃才累积
        if (timeDelta < 500) {
          _shakeAccumulator += (acceleration - _shakeThreshold) * 0.01;
          _shakeAccumulator = _shakeAccumulator.clamp(0.0, 1.0);

          if (!_isShaking && _shakeAccumulator > 0.05) {
            _isShaking = true;
            HapticFeedback.lightImpact();
          }

          // 更新蓄力进度
          if (_shakeAccumulator > 0) {
            setState(() {
              _smashProgress = _shakeAccumulator;
            });
            _updateCracks();

            // 震动反馈
            if (_smashProgress >= 0.3 && _smashProgress < 0.6) {
              HapticFeedback.mediumImpact();
            } else if (_smashProgress >= 0.6) {
              HapticFeedback.heavyImpact();
            }

            // 蓄力满触发破碎
            if (_smashProgress >= 1.0) {
              _triggerDrop();
            }
          }
        }
      } else {
        // 没有摇晃时，蓄力逐渐衰减
        if (_isShaking && _shakeAccumulator > 0) {
          _shakeAccumulator -= _shakeDecayRate;
          if (_shakeAccumulator <= 0) {
            _shakeAccumulator = 0;
            _isShaking = false;
            setState(() {
              _smashProgress = 0;
              _crackLines.clear();
              _lastCrackUpdate = -1;
            });
          } else {
            setState(() {
              _smashProgress = _shakeAccumulator;
            });
          }
        }
      }
    });
  }

  /// 根据破坏进度更新裂纹
  void _updateCracks() {
    final random = math.Random();
    final crackCount = (_smashProgress * 15).toInt();

    if (_crackLines.length < crackCount) {
      for (int i = _crackLines.length; i < crackCount; i++) {
        _crackLines.add(_CrackLine(
          startX: 180 + (random.nextDouble() - 0.5) * 200,
          startY: 250 + (random.nextDouble() - 0.5) * 300,
          angle: random.nextDouble() * math.pi * 2,
          length: random.nextDouble() * 60 + 20 + _smashProgress * 40,
          branches: random.nextInt(3) + 1,
        ));
      }
    }
  }

  @override
  void didUpdateWidget(SkeuomorphicClickerDevice oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检测成功次数变化，触发滚动动画
    if (widget.successCount != oldWidget.successCount) {
      _previousSuccessCount = oldWidget.successCount;
      _numberRollController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _knobRotationController.dispose();
    _pressController.dispose();
    _glareController.dispose();
    _rgbController.dispose();
    _pulseController.dispose();
    _successFlashController.dispose();
    _breakFlashController.dispose();
    _cooldownController.dispose();
    _numberRollController.dispose();
    _smashChargeController.dispose();
    _smashDropController.dispose();
    _repairController.dispose();
    super.dispose();
  }

  /// 长按开始 - 开始蓄力砸设备
  void _onSmashStart(LongPressStartDetails details) {
    if (_isDestroyed || _isDropping) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isLongPressing = true;
    });
    _smashChargeController.forward(from: _smashProgress);
  }

  /// 长按更新 - 持续蓄力
  void _onSmashUpdate(LongPressMoveUpdateDetails details) {
    // 蓄力过程中持续震动反馈
    if (_isLongPressing && _smashProgress > 0.5) {
      // 进度越高震动越频繁
      if ((_smashProgress * 100).toInt() % 5 == 0) {
        HapticFeedback.selectionClick();
      }
    }
  }

  /// 长按结束 - 如果没有破碎则逐渐恢复
  void _onSmashEnd(LongPressEndDetails details) {
    if (!_isLongPressing) return;

    _smashChargeController.stop();
    setState(() {
      _isLongPressing = false;
    });

    // 如果已经破碎了，不做处理
    if (_isDestroyed) return;

    // 未破碎时，松手后逐渐恢复
    _startRecovery();
  }

  /// 松手后逐渐恢复设备状态
  void _startRecovery() {
    // 使用动画平滑恢复
    final startProgress = _smashProgress;
    _smashChargeController.reverse(from: startProgress).then((_) {
      if (!_isLongPressing && !_isDestroyed) {
        setState(() {
          _smashProgress = 0.0;
          _crackLines.clear();
          _lastCrackUpdate = -1;
        });
      }
    });
  }

  /// 用户点击零部件进行拼装
  void _onPartTapped(_ComponentPart part) {
    if (_isRepairing) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _fallenParts.remove(part);
    });

    // 所有零件都被拼装回去后，修复设备
    if (_fallenParts.isEmpty) {
      _startRepairAnimation();
    }
  }

  /// 一键修复 - 零件飞回去组装
  void _onRepairAll() {
    if (_isRepairing || _fallenParts.isEmpty) return;
    HapticFeedback.heavyImpact();
    _startRepairAnimation();
  }

  /// 开始修复动画
  void _startRepairAnimation() {
    setState(() {
      _isRepairing = true;
    });
    _repairController.forward(from: 0);
  }

  /// 完成修复
  void _finishRepair() {
    _repairDevice();
  }

  /// 触发设备掉落 - 优化版
  void _triggerDrop() {
    // 先停止蓄力并锁定状态，防止重复触发
    _smashChargeController.stop();
    _isLongPressing = false;

    HapticFeedback.heavyImpact();

    // 闪白动画
    _breakFlashController
        .forward(from: 0)
        .then((_) => _breakFlashController.reverse());

    // 先生成零部件（在setState外部计算）
    final parts = _generateFallenParts();

    setState(() {
      _isDropping = true;
      _isDestroyed = true;
      _fallenParts = parts;
    });

    // 延迟震动，模拟零件落地的声音
    Future.delayed(
        const Duration(milliseconds: 50), () => HapticFeedback.heavyImpact());
    Future.delayed(
        const Duration(milliseconds: 150), () => HapticFeedback.mediumImpact());
    Future.delayed(
        const Duration(milliseconds: 300), () => HapticFeedback.lightImpact());

    _smashDropController.forward(from: 0);
  }

  /// 预生成掉落零部件 - 强化版
  List<_ComponentPart> _generateFallenParts() {
    final random = math.Random();
    // 精简零件数量，确保都在屏幕可见区域内
    // 限制速度范围，避免飞出屏幕

    return [
      // 电池（绿色大块）
      _ComponentPart(
        type: ComponentType.battery,
        x: 180 + (random.nextDouble() - 0.5) * 30,
        y: 280,
        rotation: random.nextDouble() * 0.3 - 0.15,
        velocityX:
            (random.nextBool() ? 1 : -1) * (20 + random.nextDouble() * 40),
        velocityY: -180 - random.nextDouble() * 60,
        rotationSpeed: (random.nextDouble() - 0.5) * 8,
        width: 55,
        height: 28,
        color: const Color(0xFF4CAF50),
      ),
      // LCD屏幕（深蓝色矩形）
      _ComponentPart(
        type: ComponentType.screen,
        x: 180,
        y: 200,
        rotation: random.nextDouble() * 0.2 - 0.1,
        velocityX: (random.nextDouble() - 0.5) * 60,
        velocityY: -200 - random.nextDouble() * 50,
        rotationSpeed: (random.nextDouble() - 0.5) * 6,
        width: 90,
        height: 45,
        color: const Color(0xFF1A237E),
      ),
      // 电路板（绿色带金色线路）
      _ComponentPart(
        type: ComponentType.circuitBoard,
        x: 180 + (random.nextDouble() - 0.5) * 20,
        y: 320,
        rotation: random.nextDouble() * 0.4 - 0.2,
        velocityX: (random.nextDouble() - 0.5) * 50,
        velocityY: -150 - random.nextDouble() * 50,
        rotationSpeed: (random.nextDouble() - 0.5) * 7,
        width: 70,
        height: 35,
        color: const Color(0xFF2E7D32),
      ),
      // 按钮（红色圆形）
      _ComponentPart(
        type: ComponentType.button,
        x: 180,
        y: 350,
        rotation: 0,
        velocityX:
            (random.nextBool() ? 1 : -1) * (30 + random.nextDouble() * 30),
        velocityY: -200 - random.nextDouble() * 50,
        rotationSpeed: (random.nextDouble() - 0.5) * 12,
        width: 32,
        height: 32,
        color: const Color(0xFFE53935),
      ),
      // 外壳碎片 - 3块
      ...List.generate(3, (i) {
        final offsetX = (i - 1) * 50.0; // -50, 0, 50
        return _ComponentPart(
          type: ComponentType.casing,
          x: 180 + offsetX,
          y: 280 + (random.nextDouble() - 0.5) * 40,
          rotation: random.nextDouble() * math.pi,
          velocityX: offsetX * 1.5 + (random.nextDouble() - 0.5) * 30,
          velocityY: -120 - random.nextDouble() * 80,
          rotationSpeed: (random.nextDouble() - 0.5) * 10,
          width: 35 + random.nextDouble() * 10,
          height: 25 + random.nextDouble() * 10,
          color: Color.lerp(const Color(0xFF3A3A3A), const Color(0xFF5A5A5A),
              random.nextDouble())!,
        );
      }),
    ];
  }

  /// 修复设备
  void _repairDevice() {
    _lastCrackUpdate = -1;
    _shakeAccumulator = 0.0;
    _isShaking = false;
    _lastShakeTime = 0;
    setState(() {
      _isDestroyed = false;
      _isDropping = false;
      _isRepairing = false;
      _isLongPressing = false;
      _smashProgress = 0.0;
      _fallenParts.clear();
      _crackLines.clear();
    });
    _smashDropController.reset();
    _smashChargeController.reset();
    _repairController.reset();
  }

  // 移除了 _handleTapDown/Up/Cancel，改用 Listener + GestureDetector 组合模式
  // 这种模式能完美解决点击和长按的手势冲突，以及按压状态的视觉同步问题

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final baseWidth = 360.0;
    final availableWidth = screenSize.width - 32;
    final availableHeight = screenSize.height * 0.68;
    final scaleByWidth = (availableWidth / baseWidth).clamp(0.55, 1.15);
    final scaleByHeight = (availableHeight / 560).clamp(0.55, 1.15);
    final scale = math.min(scaleByWidth, scaleByHeight);

    // 预构建设备主体，以便在动画中复用，避免每帧重绘整个UI
    final deviceBody = _buildDeviceBody();

    // 判断是否显示蓄力状态：正在长按 或 有蓄力进度
    final showDamageState = _isLongPressing || _smashProgress > 0;

    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: baseWidth,
        child: _isDestroyed
            ? _buildDroppedParts()
            : (showDamageState
                ? _buildDamagedDevice(childDeviceBody: deviceBody)
                : deviceBody),
      ),
    );
  }

  /// 受损状态的设备（长按蓄力中）
  Widget _buildDamagedDevice({required Widget childDeviceBody}) {
    return AnimatedBuilder(
      animation: _smashChargeController,
      builder: (context, child) {
        // 震动强度随进度增加（低于10%不震动）
        final effectiveProgress = (_smashProgress - 0.1).clamp(0.0, 1.0);
        final shakeIntensity = effectiveProgress * 15;
        final time = DateTime.now().millisecondsSinceEpoch;
        final shakeOffset = (_isLongPressing && effectiveProgress > 0)
            ? Offset(
                math.sin(time * 0.05) * shakeIntensity,
                math.cos(time * 0.03) * shakeIntensity * 0.5,
              )
            : Offset.zero;

        // 倾斜角度（只有超过30%才开始倾斜）
        final tiltProgress = (_smashProgress - 0.3).clamp(0.0, 1.0);
        final tiltAngle = tiltProgress * 0.06;

        // 变形程度（只有超过50%才开始变形）
        final deformProgress = (_smashProgress - 0.5).clamp(0.0, 1.0);
        final deformAmount = deformProgress * 0.12;

        return Transform.translate(
          offset: shakeOffset,
          child: Transform.rotate(
            angle: tiltAngle * math.sin(time * 0.002), // 持续微微晃动
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(deformAmount * 0.3)
                ..rotateY(deformAmount * math.sin(time * 0.001) * 0.5),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 变形的设备主体
                  Opacity(
                    opacity: 1.0 - _smashProgress * 0.3,
                    child: child!,
                  ),
                  // 裂纹层
                  if (_crackLines.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: CrackPainter(
                            cracks: _crackLines,
                            progress: _smashProgress,
                            intensity: _smashProgress * 3,
                          ),
                        ),
                      ),
                    ),
                  // 屏幕故障效果
                  if (_smashProgress > 0.15)
                    Positioned(
                      left: 90,
                      top: 70,
                      child: _buildScreenGlitch(),
                    ),
                  // 电流火花效果
                  if (_smashProgress > 0.3)
                    Positioned(
                      left: 100,
                      top: 120,
                      child: _buildElectricSparks(),
                    ),
                  // 冒黑烟效果
                  if (_smashProgress > 0.4)
                    Positioned(
                      left: 120,
                      top: 30,
                      child: _buildBlackSmoke(),
                    ),
                  // 更多烟雾
                  if (_smashProgress > 0.6)
                    Positioned(
                      left: 160,
                      top: 60,
                      child: _buildBlackSmoke(),
                    ),
                  // 蓄力进度指示（破坏程度条）
                  Positioned(
                    left: 80,
                    right: 80,
                    bottom: -30,
                    child: _buildDamageIndicator(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: childDeviceBody,
    );
  }

  /// 屏幕故障效果
  Widget _buildScreenGlitch() {
    final glitchIntensity = (_smashProgress - 0.15).clamp(0.0, 1.0);
    return SizedBox(
      width: 180,
      height: 100,
      child: CustomPaint(
        painter: _ScreenGlitchPainter(
          intensity: glitchIntensity,
          time: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
  }

  /// 电流火花效果
  Widget _buildElectricSparks() {
    return SizedBox(
      width: 160,
      height: 80,
      child: CustomPaint(
        painter: _ElectricSparkPainter(
          intensity: (_smashProgress - 0.3).clamp(0.0, 1.0),
          time: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
  }

  /// 冒黑烟效果
  Widget _buildBlackSmoke() {
    return SizedBox(
      width: 100,
      height: 120,
      child: CustomPaint(
        painter: _BlackSmokePainter(
          intensity: (_smashProgress - 0.4).clamp(0.0, 1.0),
          time: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
  }

  /// 冒烟效果（原来的，保留兼容）
  Widget _buildSmokeEffect() {
    return SizedBox(
      width: 80,
      height: 60,
      child: CustomPaint(
        painter: _SmokePainter(
          intensity: (_smashProgress - 0.5) / 0.5,
          time: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
  }

  /// 破坏程度指示条
  Widget _buildDamageIndicator() {
    return Column(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: Colors.black26,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _smashProgress,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: [
                    Colors.yellow,
                    Colors.orange,
                    Colors.red,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _smashProgress > 0.7
                        ? Colors.red.withValues(alpha: 0.6)
                        : Colors.orange.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _smashProgress < 0.8 ? '继续按住...' : '松手释放!',
          style: TextStyle(
            fontSize: 10,
            color: _smashProgress < 0.8 ? Colors.grey : Colors.red,
            fontWeight:
                _smashProgress >= 0.8 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// 掉落的零部件
  Widget _buildDroppedParts() {
    return AnimatedBuilder(
      animation: Listenable.merge([_smashDropController, _repairController]),
      builder: (context, child) {
        final dropProgress =
            Curves.easeIn.transform(_smashDropController.value);
        final bounceProgress = Curves.bounceOut.transform(
          (_smashDropController.value * 1.5).clamp(0.0, 1.0),
        );
        final repairProgress = _repairController.value;

        return SizedBox(
          height: 560,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 地面阴影
              Positioned(
                left: 60,
                right: 60,
                bottom: 20,
                child: Opacity(
                  opacity: dropProgress * 0.5 * (1 - repairProgress),
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      gradient: RadialGradient(
                        colors: [
                          Colors.black54,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // 修复中：显示设备轮廓
              if (_isRepairing)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 50,
                  child: Opacity(
                    opacity: repairProgress,
                    child: Transform.scale(
                      scale: 0.5 + repairProgress * 0.5,
                      child: _buildDeviceBody(),
                    ),
                  ),
                ),
              // 零部件（可点击拼装）
              ..._fallenParts.map((part) => _buildFallingPart(
                  part, dropProgress, bounceProgress, repairProgress)),
              // 拼装提示和一键修复按钮
              if (!_isDropping && !_isRepairing)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 一键修复按钮
                      GestureDetector(
                        onTap: _onRepairAll,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.build_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                '修复设备',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '或点击零件逐个拼装',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              // 修复中提示
              if (_isRepairing)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 30,
                  child: Text(
                    '修复中...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF4CAF50),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 构建单个掉落零部件
  Widget _buildFallingPart(_ComponentPart part, double dropProgress,
      double bounceProgress, double repairProgress) {
    // 物理模拟
    final gravity = 600.0;
    final time = dropProgress * 1.0;

    // 计算掉落位置
    final rawX = part.x + part.velocityX * time;
    final rawY = part.y + part.velocityY * time + 0.5 * gravity * time * time;

    // 限制 X 在屏幕内 (20 ~ 340)
    final droppedX = rawX.clamp(20.0, 340.0);

    // 限制在地面
    final groundY = 450.0;
    final droppedY = rawY.clamp(-50.0, groundY);

    // 修复动画：零件飞回中心
    final targetX = 180.0;
    final targetY = 280.0;
    final x = droppedX +
        (targetX - droppedX) * Curves.easeInOut.transform(repairProgress);
    final finalY = droppedY +
        (targetY - droppedY) * Curves.easeInOut.transform(repairProgress);

    // 旋转（修复时逐渐回正）
    final droppedRotation =
        part.rotation + part.rotationSpeed * dropProgress * 2;
    final rotation = droppedRotation * (1 - repairProgress);

    // 落地后的弹跳效果
    final hasLanded = rawY >= groundY;
    final landedScale =
        hasLanded ? 1.0 - (bounceProgress - dropProgress).abs() * 0.1 : 1.0;

    // 修复时缩小并淡出
    final scale = landedScale * (1 - repairProgress * 0.5);
    final opacity = 1.0 - repairProgress;

    // 掉落动画完成后可以点击
    final canTap = !_isDropping && !_isRepairing;

    return Positioned(
      left: x - part.width / 2,
      top: finalY - part.height / 2,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: GestureDetector(
          onTap: canTap ? () => _onPartTapped(part) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildPartWidget(part, dropProgress),
                    // 点击提示光晕
                    if (canTap)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
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
    );
  }

  /// 根据类型构建零部件外观
  Widget _buildPartWidget(_ComponentPart part, double progress) {
    switch (part.type) {
      case ComponentType.battery:
        // 电池 - 带膨胀和冒白烟效果（锂电池热失控）
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: part.width * (1 + progress * 0.15), // 膨胀
              height: part.height * (1 + progress * 0.1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(part.color, Colors.orange, progress * 0.4)!,
                    part.color,
                    Color.lerp(part.color, Colors.brown, progress * 0.3)!,
                  ],
                ),
                border: Border.all(
                  color: Color.lerp(
                      Colors.black26, Colors.orange, progress * 0.5)!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                  // 发热发光
                  if (progress > 0.3)
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: progress * 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 6,
                    height: 12,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
            // 冒白烟（锂电池热失控特征）
            if (progress > 0.2)
              Positioned(
                top: -20,
                left: part.width * 0.3,
                child: _BatterySmoke(intensity: progress),
              ),
          ],
        );

      case ComponentType.screen:
        // LCD屏幕 - 带漏液效果
        return Container(
          width: part.width,
          height: part.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: part.color,
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _LCDLeakPainter(progress: progress),
          ),
        );

      case ComponentType.circuitBoard:
        return Container(
          width: part.width,
          height: part.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: part.color,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: const Offset(1, 1),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _CircuitBoardPainter(),
          ),
        );

      case ComponentType.speaker:
        return Container(
          width: part.width,
          height: part.height,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: part.color,
            border: Border.all(color: Colors.grey.shade700, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: part.width * 0.4,
              height: part.height * 0.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        );

      case ComponentType.button:
        return Container(
          width: part.width,
          height: part.height,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                part.color.withValues(alpha: 0.8),
                part.color,
                part.color.withValues(alpha: 0.6),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(color: Colors.black38, width: 2),
            boxShadow: [
              BoxShadow(
                color: part.color.withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );

      case ComponentType.screw:
        return Container(
          width: part.width,
          height: part.height,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: part.color,
            border: Border.all(color: Colors.grey.shade600, width: 0.5),
          ),
          child: Center(
            child: Container(
              width: 2,
              height: 2,
              color: Colors.grey.shade700,
            ),
          ),
        );

      case ComponentType.casing:
        return Container(
          width: part.width,
          height: part.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                part.color.withValues(alpha: 0.9),
                part.color,
                part.color.withValues(alpha: 0.7),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 2,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        );

      case ComponentType.glassShard:
        // 玻璃碎片 - 锐利的三角形
        return SizedBox(
          width: part.width,
          height: part.height,
          child: CustomPaint(
            painter: TriangleDebrisPainter(color: part.color),
          ),
        );
    }
  }

  /// 设备左上角小天线
  Widget _buildAntenna() {
    return Positioned(
      top: -18,
      left: 28,
      child: Column(
        children: [
          // 天线顶部圆球
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.3),
                colors: [
                  Color(0xFF808080),
                  Color(0xFF505050),
                  Color(0xFF3A3A3A),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 2,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
          ),
          // 天线杆
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF3A3A3A),
                  Color(0xFF5A5A5A),
                  Color(0xFF3A3A3A),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  /// 设备主机身
  Widget _buildDeviceBody() {
    // 1. 构建静态内容（不包含 Scale 和 RGB 光晕）
    // 这部分内容非常重，包含了整个 UI 树
    final deviceContent = _buildDeviceContent();

    // 2. 包装 RGB 动画（仅重绘阴影容器）
    // 使用 child 参数避免重绘 deviceContent
    final rgbWrapper = AnimatedBuilder(
      animation: _rgbAnimation,
      builder: (context, child) {
        return Container(
          width: 360,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            // 多层立体阴影
            boxShadow: [
              // 最底层大阴影 - 地面投影
              BoxShadow(
                color: Colors.black.withOpacity(0.7),
                blurRadius: 40,
                offset: const Offset(0, 25),
                spreadRadius: -5,
              ),
              // 中层阴影 - 增加层次
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
              // RGB 氛围灯光晕
              BoxShadow(
                color: Color.lerp(
                  const Color(0xFF4CAF50),
                  const Color(0xFF8BC34A),
                  _rgbAnimation.value,
                )!
                    .withOpacity(0.25 * _rgbAnimation.value),
                blurRadius: 30,
                spreadRadius: 4,
              ),
              // 边缘微光
              BoxShadow(
                color: const Color(0xFF5A5A5A).withOpacity(0.1),
                blurRadius: 2,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        );
      },
      child: deviceContent,
    );

    // 3. 包装点击缩放动画
    // 同样使用 child 参数
    return AnimatedBuilder(
      animation: _pressAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pressAnimation.value,
          child: child,
        );
      },
      child: rgbWrapper,
    );
  }

  /// 设备主体的内部结构
  Widget _buildDeviceContent() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 天线 - 放在左上角
        _buildAntenna(),
        // 外壳底层 - 立体边框
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF555555),
                Color(0xFF3A3A3A),
                Color(0xFF1A1A1A),
                Color(0xFF0A0A0A),
              ],
              stops: [0.0, 0.15, 0.85, 1.0],
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(33),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF404040),
                  Color(0xFF2A2A2A),
                ],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(31),
                // 主机身渐变 - 增强立体感
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF424242),
                    Color(0xFF353535),
                    Color(0xFF2A2A2A),
                    Color(0xFF222222),
                    Color(0xFF1C1C1C),
                  ],
                  stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                ),
              ),
              child: Column(
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 8),
                  _buildProjectSelector(),
                  const SizedBox(height: 10),
                  _buildAdvancedLCDScreen(),
                  const SizedBox(height: 14),
                  _buildPremiumKnob(),
                  const SizedBox(height: 12),
                  _buildControlButtons(),
                  const SizedBox(height: 12),
                  _buildBottomBar(),
                ],
              ),
            ),
          ),
        ),
        // 顶部高光边缘 - 金属反光
        Positioned(
          top: 3,
          left: 30,
          right: 30,
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.35),
                  Colors.white.withOpacity(0.25),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
              ),
            ),
          ),
        ),
        // 左侧高光 - 增强立体
        Positioned(
          top: 50,
          left: 3,
          bottom: 50,
          child: Container(
            width: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // 底部阴影线 - 增强厚度感
        Positioned(
          bottom: 3,
          left: 40,
          right: 40,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 训练项目选择器（嵌入设备屏幕上方）
  Widget _buildProjectSelector() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E1E1E),
            Color(0xFF151515),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A3A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.03),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 项目滚动列表
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              itemCount: widget.projects.length,
              itemBuilder: (context, index) {
                final isSelected = widget.selectedIndex == index;
                final projectName = widget.projects[index];
                final isDefaultProject =
                    ['喂食', '握手', '坐下'].contains(projectName);

                return GestureDetector(
                  onTap: () => widget.onProjectChanged(index),
                  onLongPress: isDefaultProject
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          _showDeleteProjectDialog(projectName);
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF5ACC6D), Color(0xFF3DAA52)],
                            )
                          : LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF2E2E2E),
                                const Color(0xFF222222),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6FE085)
                            : const Color(0xFF404040),
                        width: 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                              const BoxShadow(
                                color: Color(0xFF2D7D38),
                                blurRadius: 1,
                                offset: Offset(0, 1),
                                spreadRadius: -1,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Center(
                      child: Text(
                        projectName,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF999999),
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: 0.5,
                          shadows: isSelected
                              ? [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 添加按钮
          GestureDetector(
            onTap: widget.onAddProject,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: const Border(
                  left: BorderSide(color: Color(0xFF3A3A3A), width: 1.5),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF252525), Color(0xFF1A1A1A)],
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFF5ACC6D),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示删除项目确认对话框
  void _showDeleteProjectDialog(String projectName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2D2D2D), Color(0xFF1A1A1A)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF404040)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.3),
                      Colors.red.withOpacity(0.1),
                    ],
                  ),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFFF6B6B), size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                '删除训练项目',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                '确定要删除「$projectName」吗？\n该项目的所有训练记录也将被删除。',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side:
                              BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                      ),
                      child: Text('取消',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onDeleteProject(projectName);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('删除',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 总训练统计条
  Widget _buildTotalStatsBar() {
    final totalClicks = widget.totalSuccessCount + widget.totalFailCount;
    final overallRate =
        totalClicks > 0 ? (widget.totalSuccessCount / totalClicks * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2A2A2A).withOpacity(0.8),
            const Color(0xFF1F1F1F).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A3A).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          // 总成功
          _buildMiniStat(
            icon: Icons.emoji_events_rounded,
            label: '总成功',
            value: widget.totalSuccessCount.toString(),
            color: const Color(0xFF4CAF50),
          ),
          _buildDivider(),
          // 总失败
          _buildMiniStat(
            icon: Icons.replay_rounded,
            label: '总重试',
            value: widget.totalFailCount.toString(),
            color: const Color(0xFFFF9800),
          ),
          _buildDivider(),
          // 综合成功率
          _buildMiniStat(
            icon: Icons.insights_rounded,
            label: '综合率',
            value: '${overallRate.toStringAsFixed(0)}%',
            color: overallRate >= 70
                ? const Color(0xFF4CAF50)
                : overallRate >= 40
                    ? const Color(0xFFFFC107)
                    : const Color(0xFFFF5722),
          ),
          _buildDivider(),
          // 总训练次数
          _buildMiniStat(
            icon: Icons.touch_app_rounded,
            label: '总次数',
            value: totalClicks.toString(),
            color: const Color(0xFF2196F3),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFF3A3A3A).withOpacity(0.5),
    );
  }

  /// 顶部工具栏
  Widget _buildTopBar() {
    return Row(
      children: [
        _buildStatusLED(const Color(0xFF4CAF50), true),
        const SizedBox(width: 8),
        _buildStatusLED(const Color(0xFF2196F3), false),
        const Spacer(),
        // 品牌 Logo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4A4A4A).withOpacity(0.8),
                const Color(0xFF3A3A3A).withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF5A5A5A).withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 狗爪图标
              CustomPaint(
                size: const Size(14, 14),
                painter: PawPrintPainter(color: const Color(0xFF8BC34A)),
              ),
              const SizedBox(width: 6),
              const Text(
                'PetClicker',
                style: TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    color: Color(0xFF8BC34A),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // 通风孔装饰
        Row(
          children: List.generate(
            4,
            (i) => Container(
              margin: const EdgeInsets.only(left: 3),
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 状态 LED 指示灯
  Widget _buildStatusLED(Color color, bool isActive) {
    return AnimatedBuilder(
      animation: _rgbAnimation,
      builder: (context, child) {
        final intensity = isActive ? _rgbAnimation.value : 0.3;
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.3),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.6 * intensity),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(isActive ? intensity : 0.4),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 高级 LCD 屏幕
  Widget _buildAdvancedLCDScreen() {
    final total = widget.successCount + widget.failCount;
    final successRate = total > 0 ? (widget.successCount / total * 100) : 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            // LCD 内容
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A1A1A),
                    Color(0xFF151515),
                    Color(0xFF101010),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // 顶部状态栏
                  _buildScreenStatusBar(),
                  const SizedBox(height: 8),
                  // 主显示区
                  _buildMainDisplay(successRate),
                  const SizedBox(height: 10),
                  // 底部进度条
                  _buildProgressBar(successRate),
                ],
              ),
            ),
            // 扫描线效果
            CustomPaint(
              size: const Size(double.infinity, 180),
              painter: ScanLinePainter(),
            ),
            // 玻璃反光
            AnimatedBuilder(
              animation: _glareAnimation,
              builder: (context, child) {
                return Positioned.fill(
                  child: CustomPaint(
                    painter: ScreenGlarePainter(
                      glarePosition: _glareAnimation.value,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 屏幕状态栏
  Widget _buildScreenStatusBar() {
    return Row(
      children: [
        // 训练模式图标
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF4CAF50).withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4CAF50),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Text(
                widget.currentProject,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4CAF50),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // 时间显示
        Text(
          _getCurrentTime(),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Color(0xFF666666),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 10),
        // 电池图标
        _buildBatteryIcon(),
      ],
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildBatteryIcon() {
    return Row(
      children: [
        Container(
          width: 20,
          height: 10,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF4CAF50), width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.5),
            child: Row(
              children: [
                Expanded(
                  flex: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                const Expanded(flex: 2, child: SizedBox()),
              ],
            ),
          ),
        ),
        Container(
          width: 2,
          height: 5,
          decoration: const BoxDecoration(
            color: Color(0xFF4CAF50),
            borderRadius: BorderRadius.horizontal(
              right: Radius.circular(1),
            ),
          ),
        ),
      ],
    );
  }

  /// 主显示区域
  Widget _buildMainDisplay(double successRate) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 成功计数 - 超大数字
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SUCCESS',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4CAF50).withOpacity(0.6),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 2),
              // 数字滚动动画
              AnimatedBuilder(
                animation: Listenable.merge(
                    [_successFlashController, _numberRollAnimation]),
                builder: (context, child) {
                  final flash = _successFlashController.value;
                  final roll = _numberRollAnimation.value;

                  return ClipRect(
                    child: SizedBox(
                      height: 64,
                      child: Stack(
                        children: [
                          // 旧数字（向上滚出）
                          if (roll < 1.0)
                            Transform.translate(
                              offset: Offset(0, -64 * roll),
                              child: Opacity(
                                opacity: (1.0 - roll).clamp(0.0, 1.0),
                                child: _buildNumberText(
                                  _previousSuccessCount
                                      .toString()
                                      .padLeft(3, '0'),
                                  flash,
                                ),
                              ),
                            ),
                          // 新数字（从下方滚入）
                          Transform.translate(
                            offset: Offset(0, 64 * (1.0 - roll)),
                            child: Transform.scale(
                              scale: 0.8 + 0.2 * roll,
                              child: Opacity(
                                opacity: roll.clamp(0.0, 1.0),
                                child: _buildNumberText(
                                  widget.successCount
                                      .toString()
                                      .padLeft(3, '0'),
                                  flash,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // 右侧统计
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildStatBox(
              icon: Icons.trending_up_rounded,
              label: 'RATE',
              value: '${successRate.toStringAsFixed(0)}%',
              color: successRate >= 70
                  ? const Color(0xFF4CAF50)
                  : successRate >= 40
                      ? const Color(0xFFFFC107)
                      : const Color(0xFFFF5722),
            ),
            const SizedBox(height: 6),
            _buildStatBox(
              icon: Icons.replay_rounded,
              label: 'RETRY',
              value: widget.failCount.toString(),
              color: const Color(0xFFFF9800),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建带闪烁效果的数字文本
  Widget _buildNumberText(String number, double flash) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(
            const Color(0xFF4CAF50),
            const Color(0xFFFFFFFF),
            flash * 0.5,
          )!,
          Color.lerp(
            const Color(0xFF8BC34A),
            const Color(0xFF4CAF50),
            flash,
          )!,
        ],
      ).createShader(bounds),
      child: Text(
        number,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 64,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 7,
                    color: color.withOpacity(0.7),
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 进度条
  Widget _buildProgressBar(double successRate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SESSION PROGRESS',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: Colors.white.withOpacity(0.4),
                letterSpacing: 1,
              ),
            ),
            Text(
              '${widget.successCount + widget.failCount} CLICKS',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: Colors.white.withOpacity(0.4),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              children: [
                // 成功部分
                Flexible(
                  flex: widget.successCount > 0 ? widget.successCount : 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                // 失败部分
                Flexible(
                  flex: widget.failCount > 0 ? widget.failCount : 0,
                  child: Container(
                    color: const Color(0xFFFF9800).withOpacity(0.8),
                  ),
                ),
                // 空白部分
                if (widget.successCount + widget.failCount == 0)
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 高级触控旋钮
  Widget _buildPremiumKnob() {
    final isCooling = widget.isCoolingDown;

    return GestureDetector(
      // 按下时的视觉反馈
      onTapDown: (_) {
        if (isCooling || _isDestroyed) return;
        setState(() => _isPressed = true);
        _pressController.forward();
      },
      onTapUp: (_) {
        if (_isPressed) {
          setState(() => _isPressed = false);
          _pressController.reverse();
        }
      },
      onTapCancel: () {
        if (_isPressed) {
          setState(() => _isPressed = false);
          _pressController.reverse();
        }
      },
      // 点击逻辑：触发响片
      onTap: () {
        if (isCooling || _isDestroyed) return;
        // 触发动画效果
        _knobRotationController.forward(from: 0);
        _successFlashController.forward(from: 0);
        _cooldownController.forward(from: 0);
        // 新流程：如果有 onClick 回调，调用它（只播放声音，进入待确认）
        // 否则使用旧的 onSuccess 直接记录成功
        if (widget.onClick != null) {
          widget.onClick!();
        } else {
          widget.onSuccess();
        }
      },
      // 长按逻辑：触发砸设备蓄力
      onLongPressStart: (details) {
        if (_isDestroyed) return;
        setState(() => _isPressed = true);
        _pressController.forward();
        _onSmashStart(details);
      },
      onLongPressMoveUpdate: _onSmashUpdate,
      onLongPressEnd: (details) {
        setState(() => _isPressed = false);
        _pressController.reverse();
        _onSmashEnd(details);
      },
      onLongPressCancel: () {
        setState(() => _isPressed = false);
        _pressController.reverse();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _knobRotationAnimation,
          _rgbAnimation,
          _pulseAnimation,
          _cooldownAnimation,
        ]),
        builder: (context, child) {
          return Transform.rotate(
            angle: _knobRotationAnimation.value,
            child: SizedBox(
              width: 210,
              height: 210,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 脉冲波纹
                  if (_isPressed && !isCooling) ...[
                    _buildPulseRing(1.0, 0.0),
                    _buildPulseRing(0.7, 0.3),
                  ],
                  // 外圈底座
                  Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF3A3A3A),
                          Color(0xFF2A2A2A),
                          Color(0xFF1A1A1A),
                        ],
                        stops: [0.8, 0.9, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: AdvancedScalePainter(
                        activeColor: Color.lerp(
                          const Color(0xFF4CAF50),
                          const Color(0xFF8BC34A),
                          _rgbAnimation.value,
                        )!,
                      ),
                    ),
                  ),
                  // RGB 光环
                  Container(
                    width: 175,
                    height: 175,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color.lerp(
                            const Color(0xFF4CAF50),
                            const Color(0xFF8BC34A),
                            _rgbAnimation.value,
                          )!
                              .withOpacity(_isPressed ? 0.6 : 0.25),
                          blurRadius: _isPressed ? 20 : 12,
                          spreadRadius: _isPressed ? 3 : 1,
                        ),
                      ],
                    ),
                  ),
                  // 金属旋钮主体
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          Color(0xFF6A6A6A),
                          Color(0xFF9A9A9A),
                          Color(0xFF7A7A7A),
                          Color(0xFFAAAAAA),
                          Color(0xFF6A6A6A),
                          Color(0xFF8A8A8A),
                          Color(0xFF7A7A7A),
                          Color(0xFF9A9A9A),
                          Color(0xFF6A6A6A),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(170, 170),
                          painter: BrushedMetalPainter(),
                        ),
                        // 中心按压区
                        _buildCenterButton(),
                      ],
                    ),
                  ),
                  // 冷却状态遮罩和进度环
                  if (isCooling || _cooldownAnimation.value < 1.0)
                    _buildCooldownOverlay(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 冷却状态遮罩和进度环
  Widget _buildCooldownOverlay() {
    final progress = _cooldownAnimation.value;
    final showOverlay = progress < 1.0;

    if (!showOverlay) return const SizedBox.shrink();

    return SizedBox(
      width: 175,
      height: 175,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 半透明灰色遮罩
          AnimatedOpacity(
            opacity: (1.0 - progress).clamp(0.0, 0.6),
            duration: const Duration(milliseconds: 50),
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A1A1A).withOpacity(0.7),
              ),
            ),
          ),
          // 进度环
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: CooldownRingPainter(
                progress: progress,
                color: const Color(0xFF4CAF50),
                backgroundColor: const Color(0xFF2A2A2A),
              ),
            ),
          ),
          // 冷却图标
          AnimatedOpacity(
            opacity: (1.0 - progress).clamp(0.0, 1.0),
            duration: const Duration(milliseconds: 50),
            child: Icon(
              Icons.hourglass_empty_rounded,
              color: const Color(0xFF4CAF50).withOpacity(0.8),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseRing(double scale, double delay) {
    final value = (_pulseAnimation.value - delay).clamp(0.0, 1.0);
    return Transform.scale(
      scale: 1.0 + value * 0.3 * scale,
      child: Container(
        width: 170,
        height: 170,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF4CAF50).withOpacity((1 - value) * 0.5),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _isPressed ? const Color(0xFF66BB6A) : const Color(0xFF4CAF50),
            _isPressed ? const Color(0xFF43A047) : const Color(0xFF388E3C),
            _isPressed ? const Color(0xFF2E7D32) : const Color(0xFF1B5E20),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
          if (_isPressed)
            BoxShadow(
              color: const Color(0xFF4CAF50).withOpacity(0.6),
              blurRadius: 20,
              spreadRadius: 5,
            ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 内部高光
          Positioned(
            top: 8,
            child: Container(
              width: 50,
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          // 狗爪图标
          CustomPaint(
            size: const Size(36, 36),
            painter: PawPrintPainter(
              color: Colors.white.withOpacity(_isPressed ? 1.0 : 0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// 控制按钮区
  Widget _buildControlButtons() {
    // 如果处于待确认状态，显示成功/失败确认按钮
    if (widget.pendingConfirmation) {
      return _buildConfirmationButtons();
    }

    // 默认状态：只显示重置和统计按钮（无标记失败）
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 重置按钮
        _buildSmallButton(
          icon: Icons.refresh_rounded,
          color: const Color(0xFF607D8B),
          onTap: () {
            HapticFeedback.mediumImpact();
            widget.onReset();
          },
        ),
        const SizedBox(width: 24),
        // 统计按钮
        _buildSmallButton(
          icon: Icons.bar_chart_rounded,
          color: const Color(0xFF607D8B),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onShowStats();
          },
        ),
      ],
    );
  }

  /// 待确认状态下的确认按钮组
  Widget _buildConfirmationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 跳过/不确定按钮
        _buildSmallButton(
          icon: Icons.skip_next_rounded,
          color: const Color(0xFF607D8B),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onSkipConfirm?.call();
          },
        ),
        const SizedBox(width: 12),
        // 成功确认按钮
        _buildConfirmSuccessButton(),
        const SizedBox(width: 12),
        // 失败确认按钮
        _buildConfirmFailButton(),
      ],
    );
  }

  /// 确认成功按钮
  Widget _buildConfirmSuccessButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (widget.onConfirmSuccess != null) {
          widget.onConfirmSuccess!();
        } else {
          // 兼容旧逻辑
          widget.onSuccess();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF66BB6A),
              Color(0xFF43A047),
            ],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_rounded,
              color: Colors.white.withOpacity(0.95),
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              '成功',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 确认失败按钮
  Widget _buildConfirmFailButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (widget.onConfirmFail != null) {
          widget.onConfirmFail!();
        } else {
          // 兼容旧逻辑
          widget.onFail();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFF7043),
              Color(0xFFE64A19),
            ],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.close_rounded,
              color: Colors.white.withOpacity(0.95),
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              '失败',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4A4A4A),
              Color(0xFF3A3A3A),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: color.withOpacity(0.6), size: 20),
      ),
    );
  }

  Widget _buildFailureButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onFail();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFF7043),
              Color(0xFFE64A19),
            ],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.close_rounded,
              color: Colors.white.withOpacity(0.95),
              size: 18,
            ),
            const SizedBox(width: 6),
            const Text(
              '标记失败',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部信息栏
  Widget _buildBottomBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 序列号
        Text(
          'SN: PC2024-${widget.successCount.toString().padLeft(4, '0')}',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 8,
            color: const Color(0xFF5A5A5A).withOpacity(0.6),
            letterSpacing: 1,
          ),
        ),
        // 认证标志
        Row(
          children: [
            _buildCertBadge('CE'),
            const SizedBox(width: 6),
            _buildCertBadge('FCC'),
          ],
        ),
      ],
    );
  }

  Widget _buildCertBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF4A4A4A),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.w700,
          color: Color(0xFF5A5A5A),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ============== Custom Painters ==============

/// 编织纹理绘制器
class WeavePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A4A4A).withOpacity(0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // 对角线编织纹理
    for (double i = -size.height; i < size.width + size.height; i += 4) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(i + size.height, 0),
        Offset(i, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 狗爪印绘制器
class PawPrintPainter extends CustomPainter {
  final Color color;

  PawPrintPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width / 36;

    // 主掌垫 - 椭圆形
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + 4 * scale),
        width: 16 * scale,
        height: 14 * scale,
      ),
      paint,
    );

    // 四个趾垫
    final toePads = [
      Offset(cx - 8 * scale, cy - 6 * scale), // 左外
      Offset(cx - 3 * scale, cy - 10 * scale), // 左内
      Offset(cx + 3 * scale, cy - 10 * scale), // 右内
      Offset(cx + 8 * scale, cy - 6 * scale), // 右外
    ];

    for (final pos in toePads) {
      canvas.drawOval(
        Rect.fromCenter(center: pos, width: 7 * scale, height: 8 * scale),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PawPrintPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 扫描线效果绘制器
class ScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.03)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 屏幕反光绘制器
class ScreenGlarePainter extends CustomPainter {
  final double glarePosition;

  ScreenGlarePainter({required this.glarePosition});

  @override
  void paint(Canvas canvas, Size size) {
    // 动态反光条
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0),
          Colors.white.withOpacity(0.03),
          Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(0.03),
          Colors.white.withOpacity(0),
        ],
        stops: [
          (glarePosition - 0.4).clamp(0, 1),
          (glarePosition - 0.15).clamp(0, 1),
          glarePosition.clamp(0, 1),
          (glarePosition + 0.15).clamp(0, 1),
          (glarePosition + 0.4).clamp(0, 1),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // 左上角固定高光
    final cornerPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.8, -0.8),
        radius: 0.6,
        colors: [
          Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant ScreenGlarePainter oldDelegate) =>
      oldDelegate.glarePosition != glarePosition;
}

/// 高级刻度绘制器
class AdvancedScalePainter extends CustomPainter {
  final Color activeColor;

  AdvancedScalePainter({required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final majorPaint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final minorPaint = Paint()
      ..color = const Color(0xFF4A4A4A)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 48; i++) {
      final angle = (i * 7.5 - 90) * math.pi / 180;
      final isMajor = i % 4 == 0;
      final innerRadius = radius - (isMajor ? 18 : 12);
      final outerRadius = radius - 5;

      if (isMajor) {
        // 主刻度带绿色高光
        majorPaint.color = i < 12 ? activeColor : const Color(0xFF5A5A5A);
      }

      final start = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );
      final end = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );

      canvas.drawLine(start, end, isMajor ? majorPaint : minorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AdvancedScalePainter oldDelegate) =>
      oldDelegate.activeColor != activeColor;
}

/// 拉丝金属纹理绘制器
class BrushedMetalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // 同心圆拉丝纹理
    for (double r = 50; r < maxRadius - 8; r += 1.5) {
      final opacity = ((r - 50) / (maxRadius - 58)).clamp(0.0, 1.0);
      paint.color = (r.toInt() % 3 == 0)
          ? Colors.white.withOpacity(0.12 * opacity)
          : Colors.black.withOpacity(0.06 * opacity);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 冷却进度环绘制器
class CooldownRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  CooldownRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 4.0;

    // 背景圆环
    final bgPaint = Paint()
      ..color = backgroundColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // 进度圆弧
    final progressPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 添加发光效果
    final glowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = 2 * math.pi * progress;
    const startAngle = -math.pi / 2; // 从顶部开始

    // 绘制发光
    canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
    // 绘制进度
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CooldownRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.backgroundColor != backgroundColor;
}

/// 裂纹线数据类
class _CrackLine {
  final double startX;
  final double startY;
  final double angle;
  final double length;
  final int branches;

  _CrackLine({
    required this.startX,
    required this.startY,
    required this.angle,
    required this.length,
    required this.branches,
  });
}

/// 裂纹绘制器
class CrackPainter extends CustomPainter {
  final List<_CrackLine> cracks;
  final double progress;
  final double intensity;

  CrackPainter({
    required this.cracks,
    required this.progress,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42); // 固定种子保证一致性

    for (final crack in cracks) {
      _drawCrackLine(
        canvas,
        crack.startX,
        crack.startY,
        crack.angle,
        crack.length * progress,
        crack.branches,
        random,
        intensity,
      );
    }
  }

  void _drawCrackLine(
    Canvas canvas,
    double x,
    double y,
    double angle,
    double length,
    int branches,
    math.Random random,
    double intensity,
  ) {
    if (length < 5) return;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 2.5 - intensity * 0.3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final path = Path();
    path.moveTo(x, y);

    double currentX = x;
    double currentY = y;
    double currentAngle = angle;
    double remainingLength = length;
    int segmentCount = 0;

    while (remainingLength > 0 && segmentCount < 20) {
      final segmentLength =
          math.min(remainingLength, random.nextDouble() * 15 + 8);
      final angleVariation = (random.nextDouble() - 0.5) * 0.6;
      currentAngle += angleVariation;

      currentX += math.cos(currentAngle) * segmentLength;
      currentY += math.sin(currentAngle) * segmentLength;
      path.lineTo(currentX, currentY);

      // 随机分支
      if (branches > 0 && random.nextDouble() < 0.3 && remainingLength > 20) {
        final branchAngle = currentAngle +
            (random.nextBool() ? 1 : -1) * (random.nextDouble() * 0.8 + 0.4);
        _drawCrackLine(
          canvas,
          currentX,
          currentY,
          branchAngle,
          remainingLength * 0.5,
          branches - 1,
          random,
          intensity,
        );
      }

      remainingLength -= segmentLength;
      segmentCount++;
    }

    // 绘制阴影
    canvas.drawPath(path, shadowPaint);
    // 绘制裂纹
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CrackPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.intensity != intensity;
}

/// 三角形碎片绘制器
class TriangleDebrisPainter extends CustomPainter {
  final Color color;

  TriangleDebrisPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // 阴影
    canvas.save();
    canvas.translate(3, 3);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // 主体
    canvas.drawPath(path, paint);

    // 高光边
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(0, size.height), highlightPaint);
  }

  @override
  bool shouldRepaint(covariant TriangleDebrisPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 零部件类型
enum ComponentType {
  battery, // 电池
  screen, // LCD屏幕
  circuitBoard, // 电路板
  speaker, // 扬声器
  button, // 按钮
  screw, // 螺丝
  casing, // 外壳碎片
  glassShard, // 玻璃碎片
}

/// 掉落零部件数据类
class _ComponentPart {
  final ComponentType type;
  double x;
  double y;
  double rotation;
  final double velocityX;
  final double velocityY;
  final double rotationSpeed;
  final double width;
  final double height;
  final Color color;

  _ComponentPart({
    required this.type,
    required this.x,
    required this.y,
    required this.rotation,
    required this.velocityX,
    required this.velocityY,
    required this.rotationSpeed,
    required this.width,
    required this.height,
    required this.color,
  });
}

/// 屏幕故障绘制器
class _ScreenGlitchPainter extends CustomPainter {
  final double intensity;
  final int time;

  _ScreenGlitchPainter({required this.intensity, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(time ~/ 50);

    // 故障条纹
    for (int i = 0; i < (intensity * 10).toInt(); i++) {
      final y = random.nextDouble() * size.height;
      final height = random.nextDouble() * 8 + 2;
      final offset = (random.nextDouble() - 0.5) * 20 * intensity;

      final paint = Paint()
        ..color = [
          Colors.cyan.withValues(alpha: 0.4),
          Colors.pink.withValues(alpha: 0.4),
          Colors.yellow.withValues(alpha: 0.3),
          Colors.white.withValues(alpha: 0.5),
        ][random.nextInt(4)];

      canvas.drawRect(
        Rect.fromLTWH(offset, y, size.width, height),
        paint,
      );
    }

    // 雪花噪点
    if (intensity > 0.5) {
      for (int i = 0; i < (intensity * 50).toInt(); i++) {
        final x = random.nextDouble() * size.width;
        final y = random.nextDouble() * size.height;
        final dotSize = random.nextDouble() * 3 + 1;

        final paint = Paint()
          ..color = random.nextBool()
              ? Colors.white.withValues(alpha: 0.8)
              : Colors.black.withValues(alpha: 0.8);

        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }

    // RGB偏移效果
    if (intensity > 0.3) {
      final rgbOffset = intensity * 5;
      final redPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.2)
        ..blendMode = BlendMode.screen;
      final bluePaint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.2)
        ..blendMode = BlendMode.screen;

      canvas.drawRect(
        Rect.fromLTWH(-rgbOffset, 0, size.width, size.height),
        redPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(rgbOffset, 0, size.width, size.height),
        bluePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScreenGlitchPainter oldDelegate) => true;
}

/// 冒烟效果绘制器
class _SmokePainter extends CustomPainter {
  final double intensity;
  final int time;

  _SmokePainter({required this.intensity, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(time ~/ 100);
    final t = (time % 1000) / 1000.0;

    for (int i = 0; i < (intensity * 8).toInt(); i++) {
      final baseX = size.width / 2 + (random.nextDouble() - 0.5) * 30;
      final drift = (random.nextDouble() - 0.5) * 40 * t;
      final rise = t * 50 * (0.5 + random.nextDouble() * 0.5);
      final scale = 0.5 + t * 0.8;
      final opacity = (1 - t) * 0.4 * intensity;

      final paint = Paint()
        ..color = Colors.grey.shade600.withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(
        Offset(baseX + drift, size.height - rise),
        10 * scale,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SmokePainter oldDelegate) => true;
}

/// 碎裂屏幕绘制器
class _CrackedScreenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // 绘制裂纹
    for (int i = 0; i < 5; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final endX = random.nextDouble() * size.width;
      final endY = random.nextDouble() * size.height;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrackedScreenPainter oldDelegate) => false;
}

/// 电路板绘制器
class _CircuitBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);

    // 金色线路
    final tracePaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // 绘制电路线路
    for (int i = 0; i < 8; i++) {
      final path = Path();
      path.moveTo(
          random.nextDouble() * size.width, random.nextDouble() * size.height);

      for (int j = 0; j < 3; j++) {
        if (random.nextBool()) {
          path.lineTo(path.getBounds().right + random.nextDouble() * 15,
              path.getBounds().bottom);
        } else {
          path.lineTo(path.getBounds().right,
              path.getBounds().bottom + random.nextDouble() * 10);
        }
      }

      canvas.drawPath(path, tracePaint);
    }

    // 小焊点
    final dotPaint = Paint()
      ..color = const Color(0xFFC0C0C0)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 6; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width,
            random.nextDouble() * size.height),
        2,
        dotPaint,
      );
    }

    // 芯片
    final chipPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.6, size.height * 0.5),
        width: 15,
        height: 10,
      ),
      chipPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircuitBoardPainter oldDelegate) => false;
}

/// 电流火花绘制器
class _ElectricSparkPainter extends CustomPainter {
  final double intensity;
  final int time;

  _ElectricSparkPainter({required this.intensity, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    final random = math.Random(time ~/ 30);
    final sparkCount = (intensity * 12).toInt();

    // 电弧主线
    final arcPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (int i = 0; i < sparkCount; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height * 0.5;

      final path = Path();
      path.moveTo(startX, startY);

      double x = startX;
      double y = startY;

      // 锯齿状电弧
      for (int j = 0; j < 5; j++) {
        x += (random.nextDouble() - 0.5) * 30;
        y += random.nextDouble() * 15 + 5;
        path.lineTo(x, y);
      }

      // 发光效果
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, arcPaint);
    }

    // 火花点
    final sparkPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    for (int i = 0; i < (intensity * 20).toInt(); i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final sparkSize = random.nextDouble() * 3 + 1;

      canvas.drawCircle(Offset(x, y), sparkSize, sparkPaint);

      // 发光
      final glowSparkPaint = Paint()
        ..color = Colors.orange.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(x, y), sparkSize * 2, glowSparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ElectricSparkPainter oldDelegate) => true;
}

/// 黑烟绘制器
class _BlackSmokePainter extends CustomPainter {
  final double intensity;
  final int time;

  _BlackSmokePainter({required this.intensity, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    final random = math.Random(42);
    final smokeCount = (intensity * 15).toInt();
    final t = (time % 2000) / 2000.0;

    for (int i = 0; i < smokeCount; i++) {
      final seed = random.nextDouble();
      final phase = (t + seed) % 1.0;

      // 烟雾起始位置随机
      final baseX = size.width * 0.3 + random.nextDouble() * size.width * 0.4;
      final drift = (random.nextDouble() - 0.5) * 60 * phase;
      final rise = phase * size.height * 0.8;

      // 烟雾大小随上升增大
      final smokeSize = (10 + phase * 40) * intensity;

      // 烟雾透明度随上升减小
      final opacity = (0.7 - phase * 0.6) * intensity;

      // 深色烟雾 - 模拟燃烧产生的黑烟
      final smokePaint = Paint()
        ..color = Color.lerp(
          const Color(0xFF2D2D2D),
          const Color(0xFF1A1A1A),
          random.nextDouble(),
        )!
            .withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + phase * 12);

      canvas.drawCircle(
        Offset(baseX + drift, size.height - rise),
        smokeSize,
        smokePaint,
      );

      // 内层更黑的核心
      if (phase < 0.5) {
        final corePaint = Paint()
          ..color = Colors.black.withValues(alpha: opacity * 0.8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + phase * 6);
        canvas.drawCircle(
          Offset(baseX + drift * 0.5, size.height - rise * 0.8),
          smokeSize * 0.5,
          corePaint,
        );
      }
    }

    // 偶尔的火星
    if (random.nextDouble() < intensity * 0.3) {
      final emberPaint = Paint()
        ..color = Colors.orange.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      for (int i = 0; i < 3; i++) {
        final x = size.width * 0.3 + random.nextDouble() * size.width * 0.4;
        final y = size.height * 0.7 + random.nextDouble() * size.height * 0.2;
        canvas.drawCircle(Offset(x, y), 2, emberPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BlackSmokePainter oldDelegate) => true;
}

/// 电池冒白烟组件（锂电池热失控）
class _BatterySmoke extends StatelessWidget {
  final double intensity;

  const _BatterySmoke({required this.intensity});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 50,
      child: CustomPaint(
        painter: _BatterySmokePainter(intensity: intensity),
      ),
    );
  }
}

/// 电池白烟绘制器
class _BatterySmokePainter extends CustomPainter {
  final double intensity;

  _BatterySmokePainter({required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final time = DateTime.now().millisecondsSinceEpoch;
    final t = (time % 1500) / 1500.0;

    // 白色/灰白色烟雾 - 锂电池热失控特征
    for (int i = 0; i < (intensity * 8).toInt(); i++) {
      final seed = random.nextDouble();
      final phase = (t + seed * 0.5) % 1.0;

      final baseX = size.width * 0.5 + (random.nextDouble() - 0.5) * 15;
      final drift = (random.nextDouble() - 0.5) * 30 * phase;
      final rise = phase * 45;
      final smokeSize = (5 + phase * 15) * intensity;
      final opacity = (0.8 - phase * 0.7) * intensity;

      // 白烟
      final smokePaint = Paint()
        ..color = Color.lerp(
          Colors.white,
          Colors.grey.shade300,
          random.nextDouble() * 0.3,
        )!
            .withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + phase * 8);

      canvas.drawCircle(
        Offset(baseX + drift, size.height - rise),
        smokeSize,
        smokePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BatterySmokePainter oldDelegate) => true;
}

/// LCD漏液绘制器 - 真实的液晶屏损坏效果
class _LCDLeakPainter extends CustomPainter {
  final double progress;

  _LCDLeakPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);

    // 裂纹
    final crackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 4; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final endX = random.nextDouble() * size.width;
      final endY = random.nextDouble() * size.height;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), crackPaint);
    }

    // 漏液黑斑 - 液晶泄漏的特征
    final leakCount = (progress * 6).toInt();
    for (int i = 0; i < leakCount; i++) {
      final cx = random.nextDouble() * size.width;
      final cy = random.nextDouble() * size.height;
      final radius = (5 + random.nextDouble() * 15) * progress;

      // 深色墨水状扩散
      final leakPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(cx, cy), radius, leakPaint);

      // 边缘的蓝紫色（液晶的颜色）
      final edgePaint = Paint()
        ..color = const Color(0xFF1A237E).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(cx, cy), radius * 1.2, edgePaint);
    }

    // 显示乱码/缺墨效果 - 部分区域显示异常
    if (progress > 0.3) {
      for (int i = 0; i < 3; i++) {
        final y = random.nextDouble() * size.height;
        final glitchPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.7);
        // 水平条纹（排线故障）
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, 3 + random.nextDouble() * 5),
          glitchPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LCDLeakPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
