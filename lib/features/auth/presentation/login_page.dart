import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

// 导入主应用文件
import '../../../core/auth_pending_email_login.dart';
import '../../../../main.dart';
import '../../../services/analytics_service.dart';
// 导入邮箱登录页面
import 'email_login_page.dart';
// 导入手机号验证码登录页面
import 'phone_login_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  // 状态控制
  bool _showLoginOptions = false;

  // 动画控制器
  late AnimationController _rotationController; // 黑洞旋转
  late AnimationController _breathingController; // 呼吸光晕
  late AnimationController _starController; // 星星闪烁
  late AnimationController _activateController; // 激活/点击动画

  @override
  void initState() {
    super.initState();

    // 0. 星星闪烁
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // 1. 黑洞旋转 (缓慢恒定)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // 2. 呼吸光晕 (缓慢深沉)
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // 3. 激活动画 (点击后的爆发)
    _activateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _activateController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showLoginOptions = true;
        });
      }
    });

    // 修改密码等：先弹窗再 signOut 后进入根 [LoginPage]，此处接力打开邮箱登录并预填邮箱。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final email = AuthPendingEmailLogin.takeInitialEmail();
      if (email == null || email.isEmpty) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailLoginPage(initialEmail: email),
        ),
      );
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _breathingController.dispose();
    _starController.dispose();
    _activateController.dispose();
    super.dispose();
  }

  void _onBlackHoleTap() {
    if (!_showLoginOptions) {
      _activateController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      // 背景使用深邃的宇宙渐变，呼应 "萌星球" 主题
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF050510), // Deepest Black/Blue
              Color(0xFF0F0F1E),
              Color(0xFF1A1A2E),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // 0. 动态星云背景 (Nebula Background) - 增加呼吸感
            AnimatedBuilder(
              animation: _breathingController,
              builder: (context, child) {
                return Stack(
                  children: [
                    // 左上角紫色星云
                    Positioned(
                      top: -150,
                      left: -150,
                      child: Opacity(
                        opacity: 0.2 +
                            0.1 *
                                math.sin(
                                    _breathingController.value * math.pi * 2),
                        child: Container(
                          width: 600,
                          height: 600,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF8B77FF).withOpacity(0.3),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.7],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 右下角蓝色星云
                    Positioned(
                      bottom: -100,
                      right: -100,
                      child: Opacity(
                        opacity: 0.2 +
                            0.1 *
                                math.cos(
                                    _breathingController.value * math.pi * 2),
                        child: Container(
                          width: 500,
                          height: 500,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF5A8EFA).withOpacity(0.3),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.7],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // 背景星光点缀 (增加数量和随机性)
            ...List.generate(60, (index) {
              final random = math.Random(index);
              final left = random.nextDouble() * screenWidth;
              final top = random.nextDouble() * screenHeight;
              final size = random.nextDouble() * 2 + 0.5;
              final opacity = random.nextDouble() * 0.8 + 0.2;
              return Positioned(
                left: left,
                top: top,
                child: FadeTransition(
                  opacity: _starController.drive(
                    Tween(begin: opacity * 0.2, end: opacity).chain(
                      CurveTween(
                          curve: Interval(random.nextDouble() * 0.8, 1.0,
                              curve: Curves.easeInOut)),
                    ),
                  ),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: size * 2,
                        )
                      ],
                    ),
                  ),
                ),
              );
            }),

            // 1. 顶部品牌文字 (位置优化)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              top:
                  _showLoginOptions ? screenHeight * 0.05 : screenHeight * 0.12,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF8B77FF), Color(0xFF5A8EFA)],
                    ).createShader(bounds),
                    child: const Text(
                      'PETURE',
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 4.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // 2. 中间的黑洞
            Positioned(
              top: screenHeight * 0.32 - 50, // 稍微上移
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: _onBlackHoleTap,
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                      [_activateController, _breathingController]),
                  builder: (context, child) {
                    // 激活时的缩放 (先收缩再爆发)
                    double scale = 1.0;
                    if (_activateController.isAnimating) {
                      final t = _activateController.value;
                      if (t < 0.3) {
                        scale = 1.0 - t * 0.5; // 收缩
                      } else {
                        scale = 0.85 + (t - 0.3) * 10.0; // 爆发放大
                      }
                    } else {
                      // 待机呼吸
                      scale = 1.0 +
                          math.sin(_breathingController.value * math.pi * 2) *
                              0.02;
                    }

                    return Transform.scale(
                      scale: scale,
                      child: _BlackHoleWidget(
                          rotationController: _rotationController),
                    );
                  },
                ),
              ),
            ),

            // 提示手势 (未开始时显示)
            if (!_showLoginOptions)
              Positioned(
                top: screenHeight * 0.32 + 340, // 放在黑洞下方，更靠近黑洞
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _breathingController.drive(
                    Tween(begin: 0.4, end: 1.0)
                        .chain(CurveTween(curve: Curves.easeInOut)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.touch_app,
                        color: Colors.white54,
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '点击进入',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 3. 登录选项面板 (磨砂玻璃质感)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              bottom: _showLoginOptions ? 0 : -screenHeight,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // 增加模糊度
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92), // 稍微不那么透，保证可读性
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5A8EFA).withOpacity(0.15),
                          blurRadius: 40,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: const _LoginBodyContent(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 黑洞组件
class _BlackHoleWidget extends StatelessWidget {
  final AnimationController rotationController;

  const _BlackHoleWidget({required this.rotationController});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      height: 400,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 外部光晕 (Nebula Glow)
          Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF5A8EFA).withOpacity(0.0),
                  const Color(0xFF8B77FF).withOpacity(0.1),
                  const Color(0xFF5A8EFA).withOpacity(0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 0.7, 1.0],
              ),
            ),
          ),

          // 2. 吸积盘 (Accretion Disk) - 旋转
          AnimatedBuilder(
            animation: rotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: rotationController.value * 2 * math.pi,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      colors: [
                        Color(0x001A1A2E),
                        Color(0xFF5A8EFA), // 蓝
                        Color(0xFF8B77FF), // 紫
                        Color(0xFFE056FD), // 亮紫
                        Color(0x001A1A2E),
                      ],
                      stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                      transform: GradientRotation(math.pi / 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B77FF).withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 3. 事件视界 (Event Horizon) - 核心黑洞
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              boxShadow: [
                // 内部发光，模拟光线被吞噬
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
                // 外部暗影
                BoxShadow(
                  color: const Color(0xFF8B77FF).withOpacity(0.5),
                  blurRadius: 50,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),

          // 4. 核心深渊
          Container(
            width: 200,
            height: 200,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// 登录表单内容
class _LoginBodyContent extends StatefulWidget {
  const _LoginBodyContent();

  @override
  State<_LoginBodyContent> createState() => _LoginBodyContentState();
}

class _LoginBodyContentState extends State<_LoginBodyContent> {
  bool _agreedToTerms = false;

  Future<void> _login() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先阅读并同意服务协议'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MyApp()),
    );
    unawaited(AnalyticsService.acceptConsentAndInit());
  }

  void _otherLogin(String method) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('您选择了 $method 登录')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          '登录以继续您的萌宠之旅',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        _GradientLoginButton(
          onPressed: () {
            _login();
          },
        ),
        const SizedBox(height: 16),
        _SecondaryLoginButton(
          text: '邮箱登录',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const EmailLoginPage()),
          ),
        ),
        const SizedBox(height: 16),
        _SecondaryLoginButton(
          text: '手机号验证码登录',
          icon: Icons.phone_android,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const PhoneLoginPage()),
          ),
        ),
        const SizedBox(height: 24),
        _AgreementRow(
          value: _agreedToTerms,
          onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
          onTap: () => _otherLogin('服务协议'),
        ),
        const SizedBox(height: 24),
        Row(
          children: const [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('或使用其他方式登录',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),
        _SocialLoginButtons(onLogin: _otherLogin),
      ],
    );
  }
}

// 渐变色一键登录按钮
class _GradientLoginButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GradientLoginButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)], // 蓝紫渐变
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A8EFA).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: const Center(
            child: Text(
              '一键登录',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 次要登录按钮
class _SecondaryLoginButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onPressed;

  const _SecondaryLoginButton({
    required this.text,
    this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF5A8EFA),
          side: const BorderSide(color: Color(0xFFE0E0E0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.0),
          ),
          backgroundColor: Colors.white,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: const Color(0xFF5A8EFA)),
              const SizedBox(width: 8),
            ],
            Text(text,
                style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF424242),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// 协议行
class _AgreementRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onTap;

  const _AgreementRow({
    required this.value,
    required this.onChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.scale(
          scale: 0.9,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            visualDensity: VisualDensity.compact,
            activeColor: const Color(0xFF5A8EFA),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const Text('我已阅读并同意',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        GestureDetector(
          onTap: onTap,
          child: const Text(
            '《用户协议与隐私政策》',
            style: TextStyle(
              color: Color(0xFF5A8EFA),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// 社交登录按钮行
class _SocialLoginButtons extends StatelessWidget {
  final void Function(String method) onLogin;

  const _SocialLoginButtons({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialLoginButton(
          icon: Icons.wechat,
          color: const Color(0xFF07C160),
          onTap: () => onLogin('微信'),
        ),
        const SizedBox(width: 32),
        _SocialLoginButton(
          icon: Icons.apple,
          color: Colors.black,
          onTap: () => onLogin('苹果'),
        ),
      ],
    );
  }
}

// 单个社交登录按钮
class _SocialLoginButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialLoginButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}
