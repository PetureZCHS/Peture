import 'dart:math' as math;
import 'dart:async'; // Added for Timer
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

// =========================================================
// 1. 核心页面 (The Stage)
// =========================================================

class TurfWarsScreen extends StatefulWidget {
  const TurfWarsScreen({super.key});

  @override
  State<TurfWarsScreen> createState() => _TurfWarsScreenState();
}

class _TurfWarsScreenState extends State<TurfWarsScreen> with TickerProviderStateMixin {
  // --- 模拟引擎状态 ---
  double _cameraY = 0.0; // 摄像机在Y轴的位置 (模拟行走)
  double _cameraX = 0.0; // 摄像机在X轴的位置 (模拟左右偏移)
  double _noiseOffset = 0.0; // 用于生成随机路径
  final double _walkSpeed = 1.5; // 行走速度
  
  // --- 缩放状态 ---
  double _scale = 1.0;
  double _baseScale = 1.0;

  // --- 游戏数据 ---
  // 使用 "q,r" 作为 Key 存储六边形状态
  final Map<String, HexState> _gridData = {};
  final ValueNotifier<int> _myScoreNotifier = ValueNotifier(0);
  final ValueNotifier<int> _enemyScoreNotifier = ValueNotifier(0);
  final ValueNotifier<String> _territoryInfoNotifier = ValueNotifier("");
  final ValueNotifier<int> _gameTickNotifier = ValueNotifier(0);
  
  // 弹窗状态
  HexState? _activeEnemyTerritory;
  String? _lastPopupKey;
  Timer? _popupDismissTimer;

  // --- 动画控制器 ---
  late Ticker _gameLoop;
  late AnimationController _claimAnimController;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    
    // 0. 预先生成一些周围的敌人 (Initial Population)
    _populateInitialEnemies();

    // 1. 游戏主循环 (Game Loop)
    _gameLoop = createTicker((elapsed) {
      // 移除 setState，改用 Notifier 驱动局部刷新
      _cameraY -= _walkSpeed; // 持续向前走
      
      // 模拟真实遛狗：不走直线，随机左右 meandering
      _noiseOffset += 0.015;
      double turn = math.sin(_noiseOffset) * 1.5 + math.cos(_noiseOffset * 0.4) * 0.5;
      _cameraX += turn;

      _generateEnemies(); // 随机生成敌人
      _checkCurrentTerritory(); // 检查当前位置
      
      _gameTickNotifier.value++; // 驱动地图重绘
    });
    _gameLoop.start();

    // 2. 占领动画 (Claim Animation)
    _claimAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _rippleAnimation = CurvedAnimation(
      parent: _claimAnimController,
      curve: Curves.easeOutExpo,
    );
  }

  @override
  void dispose() {
    _popupDismissTimer?.cancel();
    _gameLoop.dispose();
    _claimAnimController.dispose();
    super.dispose();
  }

  // --- 逻辑核心 ---

  // 预生成初始敌人
  void _populateInitialEnemies() {
    for (int i = 0; i < 25; i++) {
      _generateEnemies(force: true, rangeY: 600); // 在周围 600 范围内生成
    }
  }

  // 检查当前脚下的领地
  void _checkCurrentTerritory() {
     final hex = _pixelToHex(Offset(_cameraX, _cameraY));
     final key = "${hex.q},${hex.r}";
     
     if (_gridData.containsKey(key)) {
       final state = _gridData[key]!;
       if (state.faction == Faction.enemy) {
         final info = "进入了 ${state.breed}·${state.ownerName} 的领地";
         if (_territoryInfoNotifier.value != info) {
            _territoryInfoNotifier.value = info;
            
            // 触发照片弹窗 (如果是新的领地)
            if (_lastPopupKey != key) {
               _lastPopupKey = key;
               _activeEnemyTerritory = state;
               // 弹窗状态仍需 setState 更新 UI
               if (mounted) setState(() {});
               
               // 4秒后自动消失
               _popupDismissTimer?.cancel();
               _popupDismissTimer = Timer(const Duration(seconds: 4), () {
                 if (mounted) {
                   setState(() {
                     _activeEnemyTerritory = null;
                   });
                 }
               });
            }
         }
       } else if (state.faction == Faction.me) {
          if (_territoryInfoNotifier.value != "这是你的领地") {
            _territoryInfoNotifier.value = "这是你的领地";
            if (_activeEnemyTerritory != null) {
               _activeEnemyTerritory = null; // 离开敌人领地，立即关闭弹窗
               if (mounted) setState(() {});
            }
            _popupDismissTimer?.cancel();
          }
       }
     } else {
       if (_territoryInfoNotifier.value.isNotEmpty) {
          _territoryInfoNotifier.value = "";
          if (_activeEnemyTerritory != null) {
             _activeEnemyTerritory = null; // 进入无主之地，关闭弹窗
             if (mounted) setState(() {});
          }
          _popupDismissTimer?.cancel();
       }
     }
  }

  // 随机生成敌人领地
  void _generateEnemies({bool force = false, double rangeY = 0}) {
    // 提高生成概率：从 3% 提升到 12%，增加标记密度
    if (force || math.Random().nextDouble() < 0.12) { 
      // 随机坐标
      // 考虑到 CameraX 的偏移，我们需要在 CameraX 附近生成
      final currentQ = (_cameraX / (HexMapPainter.hexWidth * 0.75)).floor();
      // 调整左右范围：从 30 缩小到 20，让标记稍微集中一些，更容易遇到
      final q = currentQ + (math.Random().nextInt(20) - 10); 
      
      // 估算当前的 r 坐标 (Hex Grid 的行)
      final currentR = (_cameraY / 45).floor(); 
      
      // 如果是 force 模式，则在前后都生成；否则只在前方生成
      int rOffset;
      if (force) {
        rOffset = (math.Random().nextInt(30) - 15); // 前后 15 格
      } else {
        rOffset = -10 - math.Random().nextInt(15); // 前方 10-25 格 (生成得更近一点)
      }
      
      final r = currentR + rOffset;

      final key = "$q,$r";
      if (!_gridData.containsKey(key)) {
        // 随机生成狗狗信息
        final dogs = [
          ('Cooper', '金毛'), ('豆豆', '泰迪'), ('旺财', '中华田园犬'), 
          ('Luna', '哈士奇'), ('Max', '德牧'), ('Oreo', '边牧'),
          ('皮皮', '柯基'), ('辛巴', '柴犬'), ('Bella', '拉布拉多'),
          ('Charlie', '法斗'), ('Rocky', '罗威纳'), ('Coco', '比熊')
        ];
        final dog = dogs[math.Random().nextInt(dogs.length)];
        
        // 随机生成头像颜色 (模拟照片)
        final randomColor = Color((math.Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0);

        _gridData[key] = HexState(
          faction: Faction.enemy, 
          timestamp: DateTime.now(),
          ownerName: dog.$1,
          breed: dog.$2,
          avatarColor: randomColor,
        );
        _enemyScoreNotifier.value++;
      }
    }
    
    // 清理太远的网格以优化性能
    // _gridData.removeWhere(...) // 实际项目中需要
  }

  // 玩家执行"占领"
  void _onClaimPressed() {
    HapticFeedback.mediumImpact();
    
    // 弹出文明占领确认框
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCivilizedClaimSheet(),
    );
  }

  Widget _buildCivilizedClaimSheet() {
    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "文明占领认证",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "要想成为小区老大，必须以身作则。\n请拍摄清理后的地面，证明你是一名负责任的主人。",
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 20),
          
          // 模拟相机取景框
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.camera_alt, color: Colors.white.withOpacity(0.2), size: 48),
                  // 网格线
                  Column(
                    children: [
                      Expanded(child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))))),
                      Expanded(child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))))),
                      Expanded(child: Container()),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white10))))),
                      Expanded(child: Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white10))))),
                      Expanded(child: Container()),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 拍照按钮
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _executeClaim();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              icon: const Icon(Icons.camera),
              label: const Text("拍照并插旗占领", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _executeClaim() {
    HapticFeedback.heavyImpact();
    _claimAnimController.forward(from: 0.0);

    // 1. 计算玩家当前脚下的 Hex 坐标
    final hex = _pixelToHex(Offset(_cameraX, _cameraY));
    final key = "${hex.q},${hex.r}";

    // 2. 判定逻辑
    if (_gridData.containsKey(key)) {
      if (_gridData[key]!.faction == Faction.enemy) {
        _enemyScoreNotifier.value--; // 夺取敌人领地
        _myScoreNotifier.value++;
      }
    } else {
      _myScoreNotifier.value++; // 占领无主之地
    }

    // 3. 更新状态
    _gridData[key] = HexState(
      faction: Faction.me, 
      timestamp: DateTime.now(),
      opacity: 1.0,
      ownerName: "我",
      breed: "我的爱犬",
      avatarColor: Colors.cyanAccent, // 我的头像颜色
    );
    _territoryInfoNotifier.value = "这是你的领地";
  }

  @override
  Widget build(BuildContext context) {
    // 使用 PopScope 拦截返回事件 (包括手势返回)
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // 无论通过何种方式退出，都立即停止高频循环
        _gameLoop.stop();
        _claimAnimController.stop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212), // Cyberpunk Dark
        body: Stack(
          children: [
            // 1. 地图层 (Hex Grid Map)
            Positioned.fill(
              child: GestureDetector(
                onScaleStart: (details) {
                  _baseScale = _scale;
                },
                onScaleUpdate: (details) {
                  setState(() {
                    _scale = (_baseScale * details.scale).clamp(0.5, 2.0);
                  });
                },
                child: ListenableBuilder(
                  listenable: _gameTickNotifier,
                  builder: (context, child) {
                    return AnimatedBuilder(
                      animation: _claimAnimController,
                      builder: (context, child) {
                        // 使用 RepaintBoundary 隔离高频重绘的地图层
                        return RepaintBoundary(
                          child: CustomPaint(
                            painter: HexMapPainter(
                              cameraY: _cameraY,
                              cameraX: _cameraX,
                              gridData: _gridData,
                              rippleValue: _rippleAnimation.value,
                              scale: _scale,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

          // 2. UI 层 (HUD)
          SafeArea(
            child: Column(
              children: [
                  ListenableBuilder(
                    listenable: _gameTickNotifier,
                    builder: (context, child) => _buildScoreBar(),
                  ),
                  const Spacer(),
                  
                  // 领地信息提示 (Scanner UI)
                  ValueListenableBuilder<String>(
                    valueListenable: _territoryInfoNotifier,
                    builder: (context, info, child) {
                      if (info.isEmpty) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: info.contains("你的") ? Colors.cyanAccent : Colors.redAccent,
                            width: 1.5
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (info.contains("你的") ? Colors.cyanAccent : Colors.redAccent).withOpacity(0.3),
                              blurRadius: 10,
                            )
                          ]
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              info.contains("你的") ? Icons.flag : Icons.pets,
                              color: info.contains("你的") ? Colors.cyanAccent : Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              info,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  _buildClaimButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),

          // 3. 玩家头像 (始终在中心)
          Center(child: _buildPlayerAvatar()),

          // 4. 敌人领地弹窗 (Photo Popup)
          _buildEnemyPopup(),
          
          // 5. 返回按钮
          Positioned(
            top: 50, left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white54),
              onPressed: () {
                // 主动触发返回，PopScope 会处理停止逻辑
                Navigator.maybePop(context);
              },
            ),
          )
        ],
      ),
      ),
    );
  }

  // --- UI 组件 ---

  Widget _buildScoreBar() {
    // 简单估算距离：将像素坐标转换为米
    // 假设每 20 像素约等于 1 米
    final int distance = (_cameraY.abs() / 20).floor();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_run, color: Colors.cyanAccent, size: 20),
          const SizedBox(width: 12),
          Text(
            "本次遛狗 $distance m", 
            style: const TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.bold, 
              fontSize: 18,
              letterSpacing: 1
            )
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerAvatar() {
    return Container(
      width: 12, height: 12,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.cyanAccent.withOpacity(0.8), blurRadius: 10, spreadRadius: 2)
        ],
      ),
    );
  }

  Widget _buildClaimButton() {
    return GestureDetector(
      onTap: _onClaimPressed,
      child: Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF00E5FF), Color(0xFF008CBA)],
          ),
          boxShadow: [
            BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
            BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 5, offset: const Offset(-2, -2), blurStyle: BlurStyle.inner),
          ],
        ),
        child: const Center(
          child: Text(
            "CLAIM",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildEnemyPopup() {
    if (_activeEnemyTerritory == null) return const SizedBox.shrink();
    
    final state = _activeEnemyTerritory!;
    
    return Positioned(
      top: 160, // 位于顶部下方
      left: 40, right: 40,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)
                    ]
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 标题
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                          const SizedBox(width: 8),
                          Text("入侵警报", style: TextStyle(color: Colors.redAccent.shade100, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // 照片 (带波纹)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 110, height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.redAccent.withOpacity(0.2),
                            ),
                          ),
                          Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              color: state.avatarColor, // 模拟照片
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)]
                            ),
                            child: Center(child: Icon(Icons.pets, color: Colors.white.withOpacity(0.5), size: 40)),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 名字
                      Text(
                        state.ownerName ?? "未知领主",
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        state.breed ?? "神秘犬种",
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 挑衅语
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "\"这是我的地盘，快走开！\"",
                          style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 13),
                        ),
                      )
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
}

// =========================================================
// 2. 核心绘制逻辑 (The Painter)
// =========================================================

class HexMapPainter extends CustomPainter {
  final double cameraY;
  final double cameraX; 
  final Map<String, HexState> gridData;
  final double rippleValue;
  final double scale; // New

  // Hex 配置
  static const double hexSize = 40.0;
  static const double hexWidth = 1.732 * hexSize; // sqrt(3) * size
  static const double hexHeight = 2.0 * hexSize;
  
  // Cache the path to avoid allocation per frame per hex
  static final Path _cachedHexPath = _createHexPath(hexSize - 2);
  
  static Path _createHexPath(double size) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * (math.pi / 180);
      final x = size * math.cos(angle);
      final y = size * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
  
  HexMapPainter({
    required this.cameraY,
    this.cameraX = 0.0, 
    required this.gridData,
    required this.rippleValue,
    this.scale = 1.0, // New
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // 应用缩放
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);

    // 1. 绘制背景网格线 (模拟街道)
    _drawBackgroundStreets(canvas, size, center);

    // 2. 计算可见区域的 Hex 坐标范围
    final playerHex = _pixelToHex(Offset(cameraX, cameraY)); 
    final int range = (8 / scale).ceil() + 2; 

    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 
      ..color = Colors.white.withOpacity(0.05); 

    for (int q = playerHex.q - range; q <= playerHex.q + range; q++) {
      for (int r = playerHex.r - range; r <= playerHex.r + range; r++) {
        // 转换回屏幕坐标
        final hexCenterWorld = _hexToPixel(Hex(q, r));
        final screenOffset = Offset(
          (hexCenterWorld.dx - cameraX) + center.dx, 
          (hexCenterWorld.dy - cameraY) + center.dy
        );

        // Optimization: Use translate and cached path
        canvas.save();
        canvas.translate(screenOffset.dx, screenOffset.dy);
        
        // 绘制 Hex 轮廓 (Grid)
        canvas.drawPath(_cachedHexPath, borderPaint);

        // 绘制领地颜色
        final key = "$q,$r";
        if (gridData.containsKey(key)) {
          final state = gridData[key]!;
          
          // 1. 领地背景
          final factionColor = state.faction == Faction.me ? Colors.cyanAccent : Colors.redAccent;
          paint.color = factionColor.withOpacity(0.15);
          paint.maskFilter = null;
          canvas.drawPath(_cachedHexPath, paint);

          // 2. 领地边界
          canvas.drawPath(_cachedHexPath, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = factionColor.withOpacity(0.4)
          );

          // 3. 绘制"照片" (模拟圆形头像)
          // 坐标系已经 translate 到 hex 中心，所以圆心是 (0,0)
          final double avatarRadius = hexSize * 0.45;
          final avatarCenter = Offset.zero;
          
          // 3.1 选中/玩家光晕特效
          if (state.faction == Faction.me) {
             final double breath = (math.sin(DateTime.now().millisecondsSinceEpoch / 500) + 1) / 2;
             canvas.drawCircle(avatarCenter, avatarRadius + 6, Paint()
               ..color = Colors.cyanAccent.withOpacity(0.3 * breath)
               ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
             );
          }

          // 3.2 头像本体
          canvas.drawCircle(avatarCenter, avatarRadius, Paint()..color = state.avatarColor);
          
          // 3.3 头像内阴影
          canvas.drawCircle(avatarCenter, avatarRadius, Paint()
            ..shader = RadialGradient(
              colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
              stops: const [0.7, 1.0],
            ).createShader(Rect.fromCircle(center: avatarCenter, radius: avatarRadius))
          );

          // 3.4 头像边框
          canvas.drawCircle(avatarCenter, avatarRadius, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withOpacity(0.9)
          );
        }
        canvas.restore(); // Restore translation
      }
    }

    // 3. 绘制点击波纹 (Ripple)
    if (rippleValue > 0) {
      final ripplePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.cyanAccent.withOpacity(1.0 - rippleValue)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      
      canvas.drawCircle(center, rippleValue * 300, ripplePaint);
    }
    
    canvas.restore(); // 恢复缩放
  }

  void _drawBackgroundStreets(Canvas canvas, Size size, Offset center) {
    // 0. 背景色 (Dark Slate Blue Theme)
    // 注意：背景色不需要缩放，所以我们在 save/restore 之外画，或者在这里画满整个可能的区域
    // 但因为我们已经 scale 了 canvas，drawColor 会填充整个 layer，不受 transform 影响
    canvas.drawColor(const Color(0xFF263246), BlendMode.src);

    // 1. 配置画笔
    final buildingTopPaint = Paint()..color = const Color(0xFF344155);
    final buildingSidePaint = Paint()..color = const Color(0xFF1E2736); // 阴影侧面
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    const double blockSize = 140.0; // 街区大小
    
    // 计算可见区域 (考虑缩放)
    // 屏幕坐标 (0,0) 对应的世界坐标
    // S = (W - C) * Scale + Center
    // W = (S - Center) / Scale + C
    
    final double worldLeft = (0 - center.dx) / scale + center.dx - center.dx + cameraX;
    final double worldTop = (0 - center.dy) / scale + center.dy - center.dy + cameraY;
    final double worldRight = (size.width - center.dx) / scale + center.dx - center.dx + cameraX;
    final double worldBottom = (size.height - center.dy) / scale + center.dy - center.dy + cameraY;
    
    final int startRow = (worldTop / blockSize).floor() - 1;
    final int endRow = (worldBottom / blockSize).ceil() + 1;
    final int startCol = (worldLeft / blockSize).floor() - 1;
    final int endCol = (worldRight / blockSize).ceil() + 1;

    for (int row = startRow; row <= endRow; row++) {
      for (int col = startCol; col <= endCol; col++) {
        // 使用伪随机数生成器，基于坐标固定生成
        final random = math.Random(row * 10000 + col);
        
        final double x = col * blockSize;
        final double y = row * blockSize;
        
        // 屏幕坐标 (未缩放前，因为 Canvas 已经缩放了)
        final double sx = (x - cameraX) + center.dx; 
        final double sy = (y - cameraY) + center.dy;

        // 随机生成内容类型
        final double type = random.nextDouble();

        // 留出道路间隙 (Road Padding)
        final double padding = 12.0 + random.nextDouble() * 8.0;
        final rect = Rect.fromLTWH(sx + padding, sy + padding, blockSize - padding * 2, blockSize - padding * 2);

        if (type > 0.35) { 
          // === 绘制 2.5D 建筑 (Residential/Office Blocks) ===
          
          // 1. 阴影/侧面 (模拟厚度) - 向下偏移
          final double depth = 8.0 + random.nextDouble() * 12.0;
          final sideRect = rect.shift(Offset(0, depth));
          canvas.drawRRect(
            RRect.fromRectAndRadius(sideRect, const Radius.circular(6)), 
            buildingSidePaint
          );

          // 2. 顶面
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(6)), 
            buildingTopPaint
          );

          // 3. 楼号文字 (e.g., "3幢") - 仅在部分建筑显示
          // if (random.nextDouble() > 0.6) {
          //   final String label = "${random.nextInt(30) + 1}幢";
          //   _drawText(canvas, label, rect.center, Colors.white54, 11, textPainter);
          // }

        } else if (type > 0.15) {
          // === 绘制 POI (商铺/设施) ===
          // 绘制一个较矮的底座
          final poiRect = rect.deflate(5);
          canvas.drawRRect(
            RRect.fromRectAndRadius(poiRect, const Radius.circular(8)), 
            Paint()..color = const Color(0xFF2E3B50) // 略深于建筑
          );

          // POI 数据模拟
          final poiData = _getRandomPOI(random);
          final iconColor = poiData['color'] as Color;
          final iconIcon = poiData['icon'] as IconData;

          // 布局：左边图标，右边文字
          final iconCenter = poiRect.center.translate(-25, 0);
          
          // 图标背景圈
          canvas.drawCircle(iconCenter, 14, Paint()..color = iconColor);
          // 图标内圈 (模拟立体感)
          canvas.drawCircle(iconCenter, 12, Paint()..color = Colors.black.withOpacity(0.1));
          
          // 绘制 Icon (使用 TextPainter 绘制 Icon 字符)
          _drawIcon(canvas, iconIcon, iconCenter, Colors.black87, 16, textPainter);

          // 店名
          // _drawText(canvas, name, poiRect.center.translate(15, 0), const Color(0xFFE0E0E0), 13, textPainter, isBold: true);
          
          // 装饰点 (周围的小圆点)
          for(int i=0; i<3; i++) {
             canvas.drawCircle(
               poiRect.center.translate(
                 (random.nextDouble() - 0.5) * 60, 
                 (random.nextDouble() - 0.5) * 60
               ), 
               3, 
               Paint()..color = iconColor.withOpacity(0.5)
             );
          }
        }
        
        // 绘制路名 (Road Names) - 竖向路名
        if (col % 3 == 0 && row % 4 == 0) {
           final roadName = _getRandomRoadName(random);
           _drawVerticalText(canvas, roadName, Offset(sx - 10, sy + blockSize/2), const Color(0xFF546E7A), 12, textPainter);
        }
      }
    }
  }



  void _drawVerticalText(Canvas canvas, String text, Offset center, Color color, double fontSize, TextPainter painter) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    // 竖排文字简单模拟：每个字换行
    String verticalString = text.split('').join('\n');
    painter.text = TextSpan(
      text: verticalString,
      style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold, height: 1.2),
    );
    painter.layout();
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  void _drawIcon(Canvas canvas, IconData icon, Offset center, Color color, double size, TextPainter painter) {
    painter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        color: color,
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
      ),
    );
    painter.layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  Map<String, dynamic> _getRandomPOI(math.Random random) {
    final types = [
      {'color': const Color(0xFFFF9F43), 'icon': Icons.restaurant, 'names': ['九道菜馆', '王俊碗北地锅鸡', '鲜旺老妈饺子', '炉桥手擀面', '不可思艺']},
      {'color': const Color(0xFFFF6B6B), 'icon': Icons.mic, 'names': ['国·云汀商务KTV', 'ak桌游俱乐部', '星空里桌球', '极武武术馆']},
      {'color': const Color(0xFFFDCB6E), 'icon': Icons.shopping_bag, 'names': ['星光天地', '合肥星光天地', '青年五金', '便民超市']},
      {'color': const Color(0xFF55EFC4), 'icon': Icons.spa, 'names': ['像泰合古法泰式', '足疗养生', '美容美发']},
    ];
    final type = types[random.nextInt(types.length)];
    final names = type['names'] as List<String>;
    return {
      'color': type['color'],
      'icon': type['icon'],
      'name': names[random.nextInt(names.length)],
    };
  }
  
  String _getRandomRoadName(math.Random random) {
    final roads = ['宁国南路', '太湖路', '马鞍山路', '青年路', '九华山路'];
    return roads[random.nextInt(roads.length)];
  }



  @override
  bool shouldRepaint(covariant HexMapPainter oldDelegate) => true;
}

// =========================================================
// 3. 数学工具 (Hex Math)
// =========================================================

enum Faction { me, enemy }

class HexState {
  final Faction faction;
  final DateTime timestamp;
  final double opacity;
  final String? ownerName;
  final String? breed;
  final Color avatarColor; // 模拟狗狗照片的主色调

  HexState({
    required this.faction, 
    required this.timestamp, 
    this.opacity = 1.0,
    this.ownerName,
    this.breed,
    this.avatarColor = Colors.grey,
  });
}

class Hex {
  final int q;
  final int r;
  Hex(this.q, this.r);
}

// Pointy-topped Hex 转换
// Size = radius
Offset _hexToPixel(Hex hex) {
  const size = HexMapPainter.hexSize;
  final x = size * (math.sqrt(3) * hex.q + math.sqrt(3) / 2 * hex.r);
  final y = size * (3.0 / 2 * hex.r);
  return Offset(x, y);
}

Hex _pixelToHex(Offset point) {
  const size = HexMapPainter.hexSize;
  final q = (math.sqrt(3) / 3 * point.dx - 1.0 / 3 * point.dy) / size;
  final r = (2.0 / 3 * point.dy) / size;
  return _axialRound(q, r);
}

Hex _axialRound(double x, double y) {
  double z = -x - y;
  int rx = x.round();
  int ry = y.round();
  int rz = z.round();

  double xDiff = (rx - x).abs();
  double yDiff = (ry - y).abs();
  double zDiff = (rz - z).abs();

  if (xDiff > yDiff && xDiff > zDiff) {
    rx = -ry - rz;
  } else if (yDiff > zDiff) {
    ry = -rx - rz;
  } else {
    rz = -rx - ry;
  }
  return Hex(rx, ry);
}
