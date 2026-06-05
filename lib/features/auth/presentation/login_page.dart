import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth_pending_email_login.dart';
import '../../../core/auth_terms_consent.dart';
import '../../../services/analytics_service.dart';
import '../../home/presentation/home_screen.dart';
import '../../../shared/design_system/peture_design_system.dart';
// 导入邮箱登录页面
import 'email_login_page.dart';

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
                      color: PetureColors.surface.withOpacity(0.92),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: PetureColors.violet.withOpacity(0.2),
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
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _agreedToTerms = AuthTermsConsent.value;
  bool _showConsentHint = false;
  bool _isAppleLoading = false;
  StreamSubscription<AuthState>? _authStateSub;
  static final Uri _termsUri = Uri.parse('https://PetureZCHS.github.io/terms');
  static final Uri _privacyUri =
      Uri.parse('https://PetureZCHS.github.io/privacy');

  @override
  void initState() {
    super.initState();
    AuthTermsConsent.accepted.addListener(_syncConsentState);
    _authStateSub = _supabase.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.signedIn &&
          _supabase.auth.currentSession != null) {
        unawaited(_enterHomeAfterLogin());
      }
    });
  }

  Future<void> _enterHomeAfterLogin() async {
    if (!mounted) return;
    await AnalyticsService.acceptConsentAndInit();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    AuthTermsConsent.accepted.removeListener(_syncConsentState);
    _authStateSub?.cancel();
    super.dispose();
  }

  void _syncConsentState() {
    if (!mounted) return;
    final next = AuthTermsConsent.value;
    if (_agreedToTerms == next) return;
    setState(() {
      _agreedToTerms = next;
    });
  }

  void _onConsentChanged(bool value) {
    setState(() {
      _agreedToTerms = value;
      if (value) {
        _showConsentHint = false;
      }
    });
    AuthTermsConsent.set(value);
  }

  Future<void> _openEmailLogin() async {
    if (!_agreedToTerms) {
      setState(() {
        _showConsentHint = true;
      });
      return;
    }
    if (_showConsentHint) {
      setState(() {
        _showConsentHint = false;
      });
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const EmailLoginPage()),
    );
  }

  Future<void> _signInWithApple() async {
    if (!_agreedToTerms) {
      setState(() {
        _showConsentHint = true;
      });
      return;
    }
    if (_showConsentHint) {
      setState(() {
        _showConsentHint = false;
      });
    }

    setState(() {
      _isAppleLoading = true;
    });

    try {
      final rawNonce = _supabase.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('Apple 返回的身份令牌无效，请重试');
      }

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      await _syncAppleProfileAfterSignIn(credential);
    } on AuthException catch (e) {
      String message = 'Apple 登录失败，请稍后重试';
      if (e.statusCode == '429' ||
          e.message.contains('Too many requests') ||
          e.message.contains('rate limit')) {
        message = '尝试次数过多，请稍后再试';
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      if (e.code == AuthorizationErrorCode.canceled) {
        return;
      }
      debugPrint('Apple 授权失败 code=${e.code} message=${e.message}');
      String message = 'Apple 授权失败，请稍后重试';
      if (e.code == AuthorizationErrorCode.failed ||
          e.code == AuthorizationErrorCode.invalidResponse) {
        message = 'Apple 授权失败，请检查 iOS Apple 登录配置后重试';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apple 登录失败，请检查网络后重试')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAppleLoading = false;
        });
      }
    }
  }

  String? _pickAppleNickname(AuthorizationCredentialAppleID credential) {
    final family = (credential.familyName ?? '').trim();
    final given = (credential.givenName ?? '').trim();
    final full = '$family$given'.trim();
    if (full.isNotEmpty) return full;

    final email = (_supabase.auth.currentUser?.email ?? '').trim();
    if (email.contains('@')) {
      final local = email.split('@').first.trim();
      if (local.isNotEmpty) return local;
    }
    return null;
  }

  Future<void> _syncAppleProfileAfterSignIn(
    AuthorizationCredentialAppleID credential,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final userId = user.id;
    final nicknameCandidate = _pickAppleNickname(credential);

    try {
      final profile = await _supabase
          .from('users_profiles')
          .select('id, nickname, membership_type')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        await _supabase.from('users_profiles').insert({
          'id': userId,
          'nickname': nicknameCandidate,
          'avatar_url': null,
          'membership_type': 'free',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        return;
      }

      final currentNickname = (profile['nickname'] as String?)?.trim() ?? '';
      if (currentNickname.isNotEmpty || nicknameCandidate == null) return;

      await _supabase.from('users_profiles').update({
        'nickname': nicknameCandidate,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('Apple 登录后补全用户资料失败: $e');
    }
  }

  Widget _buildAppleButton() {
    final disabled = _isAppleLoading;
    return GestureDetector(
      onTap: disabled ? null : _signInWithApple,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: disabled ? 0.55 : 1,
        child: Container(
          height: 48,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(PetureRadius.pill),
            border: Border.all(
              color: PetureColors.border,
              width: 1,
            ),
          ),
          child: Center(
            child: _isAppleLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.apple, size: 19, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        '通过 Apple 继续',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLegal(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('链接打开失败，请稍后重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text(
          '登录以继续您的萌宠之旅',
          style: PetureTextStyles.body,
        ),
        const SizedBox(height: 32),
        if (Platform.isIOS) ...[
          _buildAppleButton(),
          const SizedBox(height: 12),
        ],
        PetureSecondaryButton(
          label: '邮箱登录',
          icon: Icons.email_outlined,
          onPressed: _openEmailLogin,
        ),
        const SizedBox(height: 24),
        _AgreementRow(
          value: _agreedToTerms,
          onChanged: (value) => _onConsentChanged(value ?? false),
          onTapTerms: () => _openLegal(_termsUri),
          onTapPrivacy: () => _openLegal(_privacyUri),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _showConsentHint
              ? Padding(
                  key: const ValueKey<String>('consent-hint'),
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '请先勾选并同意《用户协议》与《隐私政策》',
                    style: PetureTextStyles.caption.copyWith(
                      color: const Color(0xFFD9805D),
                    ),
                  ),
                )
              : const SizedBox(
                  key: ValueKey<String>('consent-hint-empty'),
                  height: 0,
                ),
        ),
      ],
    );
  }
}

// 协议行
class _AgreementRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onTapTerms;
  final VoidCallback onTapPrivacy;

  const _AgreementRow({
    required this.value,
    required this.onChanged,
    required this.onTapTerms,
    required this.onTapPrivacy,
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
            activeColor: PetureColors.violet,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const Text('我已阅读并同意', style: PetureTextStyles.caption),
        GestureDetector(
          onTap: onTapTerms,
          child: Text(
            '《用户协议》',
            style:
                PetureTextStyles.caption.copyWith(color: PetureColors.violet),
          ),
        ),
        const Text(' 与 ', style: PetureTextStyles.caption),
        GestureDetector(
          onTap: onTapPrivacy,
          child: Text(
            '《隐私政策》',
            style:
                PetureTextStyles.caption.copyWith(color: PetureColors.violet),
          ),
        ),
      ],
    );
  }
}
