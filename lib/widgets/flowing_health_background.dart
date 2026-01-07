import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// 类似苹果健康应用的流动背景组件
/// 支持多层渐变色球体流动动画
class FlowingHealthBackground extends StatefulWidget {
  const FlowingHealthBackground({super.key});

  @override
  State<FlowingHealthBackground> createState() => _FlowingHealthBackgroundState();
}

class _FlowingHealthBackgroundState extends State<FlowingHealthBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;
  late AnimationController _controller4;

  @override
  void initState() {
    super.initState();
    
    // 创建多个不同速度的动画控制器，形成更自然的流动效果
    _controller1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _controller2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _controller3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    _controller4 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    _controller4.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 基础背景色
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF2F2F7),
                const Color(0xFFE8E8ED),
              ],
            ),
          ),
        ),
        
        // 流动光晕层 1 - 粉紫色
        AnimatedBuilder(
          animation: _controller1,
          builder: (context, child) {
            final angle1 = _controller1.value * 2 * math.pi;
            final angle2 = (_controller1.value * 2 * math.pi) + math.pi / 3;
            
            return Positioned(
              top: -200 + (math.sin(angle1) * 150),
              left: -100 + (math.cos(angle2) * 120),
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE2D1F9).withOpacity(0.8),
                      const Color(0xFFD4B5F7).withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // 流动光晕层 2 - 蓝色
        AnimatedBuilder(
          animation: _controller2,
          builder: (context, child) {
            final angle1 = _controller2.value * 2 * math.pi;
            final angle2 = (_controller2.value * 2 * math.pi) - math.pi / 4;
            
            return Positioned(
              top: 100 + (math.cos(angle1) * 180),
              right: -150 + (math.sin(angle2) * 140),
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFC4E0E5).withOpacity(0.7),
                      const Color(0xFFADD4D9).withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // 流动光晕层 3 - 橙色
        AnimatedBuilder(
          animation: _controller3,
          builder: (context, child) {
            final angle1 = _controller3.value * 2 * math.pi;
            final angle2 = (_controller3.value * 2 * math.pi) + math.pi / 2;
            
            return Positioned(
              bottom: -100 + (math.sin(angle1) * 130),
              left: 100 + (math.cos(angle2) * 160),
              child: Container(
                width: 550,
                height: 550,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFDFC4).withOpacity(0.7),
                      const Color(0xFFFFCFA0).withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // 流动光晕层 4 - 粉色
        AnimatedBuilder(
          animation: _controller4,
          builder: (context, child) {
            final angle1 = _controller4.value * 2 * math.pi;
            final angle2 = (_controller4.value * 2 * math.pi) - math.pi / 6;
            
            return Positioned(
              top: 400 + (math.cos(angle1) * 100),
              right: 50 + (math.sin(angle2) * 100),
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFB6D9).withOpacity(0.6),
                      const Color(0xFFFFA6C9).withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // 添加一个模糊层增强流动效果
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(
            color: Colors.white.withOpacity(0.05),
          ),
        ),
      ],
    );
  }
}
