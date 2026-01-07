import 'dart:ui';

import 'package:flutter/material.dart';

class AnimatedMeshGradient extends StatefulWidget {
  const AnimatedMeshGradient({super.key});

  @override
  State<AnimatedMeshGradient> createState() => _AnimatedMeshGradientState();
}

class _AnimatedMeshGradientState extends State<AnimatedMeshGradient>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;
  late AnimationController _controller4;

  late Animation<Offset> _posAnimation1;
  late Animation<Offset> _posAnimation2;
  late Animation<Offset> _posAnimation3;
  late Animation<Offset> _posAnimation4;

  late Animation<double> _scaleAnimation1;
  late Animation<double> _scaleAnimation2;
  late Animation<double> _scaleAnimation3;
  late Animation<double> _scaleAnimation4;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with faster durations for more visible movement
    _controller1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _controller2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _controller3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _controller4 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    // Define position animations with larger ranges
    _posAnimation1 = Tween<Offset>(
      begin: const Offset(-0.2, -0.2),
      end: const Offset(0.6, 0.5),
    ).animate(CurvedAnimation(parent: _controller1, curve: Curves.easeInOut));

    _posAnimation2 = Tween<Offset>(
      begin: const Offset(1.0, -0.2),
      end: const Offset(0.1, 0.6),
    ).animate(CurvedAnimation(parent: _controller2, curve: Curves.easeInOut));

    _posAnimation3 = Tween<Offset>(
      begin: const Offset(-0.1, 1.0),
      end: const Offset(0.8, 0.1),
    ).animate(CurvedAnimation(parent: _controller3, curve: Curves.easeInOut));

    _posAnimation4 = Tween<Offset>(
      begin: const Offset(1.1, 1.1),
      end: const Offset(0.2, 0.4),
    ).animate(CurvedAnimation(parent: _controller4, curve: Curves.easeInOut));

    // Define scale animations with more dramatic breathing effect
    _scaleAnimation1 = Tween<double>(begin: 0.8, end: 1.8).animate(
      CurvedAnimation(parent: _controller1, curve: Curves.easeInOut),
    );
    _scaleAnimation2 = Tween<double>(begin: 0.8, end: 1.6).animate(
      CurvedAnimation(parent: _controller2, curve: Curves.easeInOut),
    );
    _scaleAnimation3 = Tween<double>(begin: 0.8, end: 2.0).animate(
      CurvedAnimation(parent: _controller3, curve: Curves.easeInOut),
    );
    _scaleAnimation4 = Tween<double>(begin: 0.8, end: 1.5).animate(
      CurvedAnimation(parent: _controller4, curve: Curves.easeInOut),
    );
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
    // Soft, vibrant pastel colors
    final color1 = const Color(0xFF8EC5FC); // Pastel Blue
    final color2 = const Color(0xFFE0C3FC); // Pastel Purple
    final color3 = const Color(0xFF80D0C7); // Pastel Teal
    final color4 = const Color(0xFFFF9A9E); // Soft Pink/Peach

    return Stack(
      children: [
        // Background base color
        Container(color: Colors.white),

          // Apply strong blur to the whole stack of blobs
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Stack(
              children: [
                _buildAnimatedBlob(
                  color: color1,
                  posAnimation: _posAnimation1,
                  scaleAnimation: _scaleAnimation1,
                  baseSize: 400,
                ),
                _buildAnimatedBlob(
                  color: color2,
                  posAnimation: _posAnimation2,
                  scaleAnimation: _scaleAnimation2,
                  baseSize: 350,
                ),
                _buildAnimatedBlob(
                  color: color3,
                  posAnimation: _posAnimation3,
                  scaleAnimation: _scaleAnimation3,
                  baseSize: 450,
                ),
                _buildAnimatedBlob(
                  color: color4,
                  posAnimation: _posAnimation4,
                  scaleAnimation: _scaleAnimation4,
                  baseSize: 380,
                ),
              ],
            ),
          ),


        ],
      );
  }

  Widget _buildAnimatedBlob({
    required Color color,
    required Animation<Offset> posAnimation,
    required Animation<double> scaleAnimation,
    required double baseSize,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([posAnimation, scaleAnimation]),
      builder: (context, child) {
        // Convert relative offset (0.0-1.0) to absolute pixels based on screen size
        final screenSize = MediaQuery.of(context).size;
        final offset = posAnimation.value;
        final scale = scaleAnimation.value;
        final size = baseSize * scale;

        return Positioned(
          left: offset.dx * screenSize.width - (size / 2),
          top: offset.dy * screenSize.height - (size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
