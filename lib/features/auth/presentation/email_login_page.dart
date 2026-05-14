import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth_otp_email_context.dart';
import '../../../core/auth_terms_consent.dart';
import '../../home/presentation/home_screen.dart';
import '../../../services/analytics_service.dart';
import '../../../shared/design_system/peture_design_system.dart';
import 'email_register_page.dart';

class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({
    super.key,
    this.initialEmail,
    this.initialMessage,
    this.forceOtp = false,
    this.startCountdownOnInit = false,
  });

  /// 可选：预填的邮箱（从注册页跳转时带上）
  final String? initialEmail;

  /// 可选：进入页面后立即提示的消息（如“已注册，可直接使用验证码登录”）
  final String? initialMessage;

  /// 可选：强制进入时使用验证码登录模式
  final bool forceOtp;

  /// 可选：进入页面时是否直接进入验证码倒计时
  /// 场景：从注册页跳转过来时，验证码已经发送，这里应直接显示灰色倒计时按钮
  final bool startCountdownOnInit;

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _codeController =
      TextEditingController(); // 验证码输入
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isSendingCode = false;
  bool _obscurePassword = true; // 控制密码是否可见

  // 登录模式：true = 邮箱验证码登录（默认），false = 密码登录
  bool _useOtpLogin = true;

  /// 是否同意《用户协议与隐私政策》（含友盟等统计说明）
  bool _agreedToTerms = AuthTermsConsent.value;

  int _countdown = 0;
  Timer? _countdownTimer;
  static final Uri _termsUri = Uri.parse('https://PetureZCHS.github.io/terms');
  static final Uri _privacyUri =
      Uri.parse('https://PetureZCHS.github.io/privacy');

  void _enterHomeAfterLogin() {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    unawaited(AnalyticsService.acceptConsentAndInit());
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    AuthTermsConsent.accepted.addListener(_syncConsentState);

    // 预填邮箱
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }

    // 根据外部请求，强制使用验证码模式
    if (widget.forceOtp) {
      _useOtpLogin = true;
    }

    // 如果从注册页跳转且已经发送过验证码，则直接启动倒计时
    if (widget.startCountdownOnInit && widget.forceOtp) {
      _useOtpLogin = true;
      _startCountdown();
    }

    // 进入页面后弹提示（如：已注册，可直接用验证码登录）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialMessage != null) {
        _showMessage(widget.initialMessage!, isError: false);
      }
    });
  }

  @override
  void dispose() {
    AuthTermsConsent.accepted.removeListener(_syncConsentState);
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _countdownTimer?.cancel();
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
    });
    AuthTermsConsent.set(value);
  }

  // 启动验证码倒计时
  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 60;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        setState(() {
          _countdown = 0;
        });
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  bool _ensureTermsAccepted() {
    if (_agreedToTerms) return true;
    _showMessage('请先阅读并同意《用户协议》与《隐私政策》');
    return false;
  }

  Future<void> _openLegal(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok && mounted) {
      _showMessage('链接打开失败，请稍后重试');
    }
  }

  // 邮箱登录（只使用密码登录）
  Future<void> _emailLogin() async {
    if (!_ensureTermsAccepted()) return;
    // 仅在“密码登录”模式下使用
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔍 尝试密码登录: ${_emailController.text.trim()}');

      final response = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      debugPrint('✅ 密码登录成功');
      debugPrint('User: ${response.user?.email}');

      if (_supabase.auth.currentSession != null && mounted) {
        _enterHomeAfterLogin();
      } else {
        _showMessage('登录状态未建立，请稍后重试');
      }
    } on AuthException catch (e) {
      debugPrint('❌ 密码登录失败: ${e.message}');
      debugPrint('Status Code: ${e.statusCode}');

      String errorMsg = '登录失败，请稍后重试';
      if (e.message.contains('Invalid login credentials')) {
        errorMsg = '邮箱或密码错误，请检查后重新输入';
      } else if (e.message.contains('Email not confirmed')) {
        errorMsg = '该邮箱尚未完成验证，请先前往邮箱点击验证链接';
      } else if (e.message.contains('User not found')) {
        errorMsg = '该邮箱尚未注册，请先完成注册';
      } else if (e.statusCode == '500') {
        errorMsg = '服务器内部错误（代码 500），请稍后重试或联系管理员';
      } else if (e.statusCode == '429' ||
          e.message.contains('Too many requests') ||
          e.message.contains('rate limit')) {
        errorMsg = '尝试次数过多，请稍后再试';
      } else {
        errorMsg = '登录失败，服务器返回错误代码 ${e.statusCode ?? '未知'}，请稍后重试或联系管理员';
      }
      _showMessage(errorMsg);
    } catch (e) {
      debugPrint('❌ 其他错误: $e');
      _showMessage('登录失败，本地出现未知错误，请检查网络后重试');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _isOtpCodeReady => RegExp(r'^\d{6}$').hasMatch(_codeController.text);

  // 发送邮箱验证码（用于登录）
  Future<void> _sendLoginCode() async {
    if (!_ensureTermsAccepted()) return;

    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('请输入邮箱地址');
      return;
    }
    if (!_isValidEmail(email)) {
      _showMessage('请输入有效的邮箱地址');
      return;
    }

    setState(() {
      _isSendingCode = true;
    });

    try {
      debugPrint('🔍 尝试发送登录验证码到: $email');

      // 登录验证码：不创建新用户，只允许已有账号使用验证码登录
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
        emailRedirectTo: null,
        data: AuthOtpEmailKind.payload(AuthOtpEmailKind.login),
      );

      _startCountdown();
      _showMessage('验证码已发送，请查收邮箱', isError: false);
    } on AuthException catch (e) {
      debugPrint('❌ 发送登录验证码失败: ${e.message}');
      debugPrint('Status Code: ${e.statusCode}');

      String errorMsg = '发送验证码失败，请稍后重试';
      if (e.message.contains('User not found') ||
          e.message.contains('Signups not allowed for otp')) {
        errorMsg = '该邮箱尚未注册，请先前往注册页面完成注册';
      } else if (e.message.contains('Email not confirmed')) {
        errorMsg = '该邮箱尚未完成验证，请先在邮箱中完成验证操作';
      } else if (e.message.contains('rate limit exceeded') ||
          e.message.contains('Too many requests') ||
          e.statusCode == '429') {
        errorMsg = '验证码请求过于频繁，请稍后再试';
      } else if (e.statusCode == '500') {
        errorMsg = '验证码服务暂时不可用（代码 500），请稍后重试或联系管理员';
      } else {
        errorMsg = '发送验证码失败，服务器返回错误代码 ${e.statusCode ?? '未知'}，请稍后重试或联系管理员';
      }
      _showMessage(errorMsg);
    } catch (e) {
      debugPrint('❌ 发送验证码时出现其他错误: $e');
      _showMessage('发送验证码失败，本地出现未知错误，请检查网络后重试');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  // 验证验证码并登录
  Future<void> _verifyCodeAndLogin() async {
    if (!_ensureTermsAccepted()) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔍 使用验证码尝试登录: $email, code: $code');

      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );

      if ((response.session != null || response.user != null) && mounted) {
        debugPrint('✅ 验证码登录成功: ${response.user?.email}');
        if (_supabase.auth.currentSession != null) {
          _enterHomeAfterLogin();
        } else {
          _showMessage('登录状态未建立，请稍后重试');
        }
      } else {
        _showMessage('验证码验证失败，请重试');
      }
    } on AuthException catch (e) {
      debugPrint('❌ 验证码登录失败: ${e.message}');
      debugPrint('Status Code: ${e.statusCode}');

      String errorMsg = '登录失败，请稍后重试';
      if (e.message.contains('Invalid login credentials') ||
          e.message.contains('Invalid otp') ||
          e.message.contains('invalid or expired otp')) {
        errorMsg = '验证码错误或已过期';
      } else if (e.message.contains('Email not confirmed')) {
        errorMsg = '该邮箱尚未完成验证，请先在邮箱中完成验证操作';
      } else if (e.message.contains('User not found')) {
        errorMsg = '该邮箱尚未注册，请先前往注册页面完成注册';
      } else if (e.statusCode == '500') {
        errorMsg = '验证码登录服务暂时不可用（代码 500），请稍后重试或联系管理员';
      } else if (e.statusCode == '429' ||
          e.message.contains('Too many requests') ||
          e.message.contains('rate limit')) {
        errorMsg = '验证码尝试次数过多，请稍后再试';
      } else {
        errorMsg = '登录失败，服务器返回错误代码 ${e.statusCode ?? '未知'}，请稍后重试或联系管理员';
      }
      _showMessage(errorMsg);
    } catch (e) {
      debugPrint('❌ 其他错误: $e');
      _showMessage('登录失败，本地出现未知错误，请检查网络后重试');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 显示消息
  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: PetureTextStyles.body.copyWith(
            color: PetureColors.surfacePure,
          ),
        ),
        backgroundColor: isError ? PetureColors.danger : PetureColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 验证邮箱格式
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PetureColors.background,
      resizeToAvoidBottomInset: true, // 确保页面会随键盘调整
      appBar: AppBar(
        backgroundColor: PetureColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PetureColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // 添加滚动视图以避免键盘遮挡
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // 页面标题
                const Text(
                  '邮箱登录',
                  style: PetureTextStyles.largeTitle,
                ),
                const SizedBox(height: 8),
                Text(
                  _useOtpLogin ? '请输入邮箱并获取验证码登录' : '请输入您的邮箱地址和密码',
                  style: PetureTextStyles.body,
                ),
                const SizedBox(height: 40),

                // 登录方式切换：验证码登录 / 密码登录
                Container(
                  decoration: BoxDecoration(
                    color: PetureColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(PetureRadius.md),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _useOtpLogin = true;
                                  });
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _useOtpLogin
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(PetureRadius.sm),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '验证码登录',
                              style: PetureTextStyles.label.copyWith(
                                color: _useOtpLogin
                                    ? PetureColors.violet
                                    : PetureColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _useOtpLogin = false;
                                  });
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: !_useOtpLogin
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(PetureRadius.sm),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '密码登录',
                              style: PetureTextStyles.label.copyWith(
                                color: !_useOtpLogin
                                    ? PetureColors.violet
                                    : PetureColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 邮箱输入框
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                  decoration: petureInputDecoration(
                    labelText: '邮箱地址',
                    hintText: '请输入您的邮箱地址',
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入邮箱地址';
                    }
                    if (!_isValidEmail(value)) {
                      return '请输入有效的邮箱地址';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // 根据登录模式显示不同输入框
                if (_useOtpLogin) ...[
                  // 验证码输入 + 发送按钮
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: petureInputDecoration(
                            labelText: '验证码',
                            hintText: '请输入6位验证码',
                            prefixIcon: const Icon(Icons.verified_outlined),
                          ),
                          validator: (value) {
                            if (!_useOtpLogin) return null;
                            if (value == null || value.isEmpty) {
                              return '请输入验证码';
                            }
                            if (value.length != 6) {
                              return '验证码为6位数字';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        child: PetureSecondaryButton(
                          label: _countdown > 0 ? '重发(${_countdown}s)' : '发送验证码',
                          isLoading: _isSendingCode,
                          onPressed: _isSendingCode || _countdown > 0
                              ? null
                              : _sendLoginCode,
                          expand: false,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // 密码输入框
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: petureInputDecoration(
                      labelText: '密码',
                      hintText: '请输入您的密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (_useOtpLogin) return null;
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      if (value.length < 6) {
                        return '密码至少6位';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: _isLoading
                          ? null
                          : (v) => _onConsentChanged(v ?? false),
                      visualDensity: VisualDensity.compact,
                      activeColor: const Color(0xFF5D5FEF),
                    ),
                    const Text('我已阅读并同意',
                        style: PetureTextStyles.caption),
                    GestureDetector(
                      onTap: _isLoading ? null : () => _openLegal(_termsUri),
                      child: Text(
                        '《用户协议》',
                        style: PetureTextStyles.caption.copyWith(
                          color: PetureColors.violet,
                        ),
                      ),
                    ),
                    const Text(' 与 ', style: PetureTextStyles.caption),
                    GestureDetector(
                      onTap: _isLoading ? null : () => _openLegal(_privacyUri),
                      child: Text(
                        '《隐私政策》',
                        style: PetureTextStyles.caption.copyWith(
                          color: PetureColors.violet,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 登录按钮
                PeturePrimaryButton(
                  label: '登录',
                  isLoading: _isLoading,
                  onPressed: _isLoading
                      ? null
                      : (_useOtpLogin
                          ? (_isOtpCodeReady ? _verifyCodeAndLogin : null)
                          : _emailLogin),
                ),

                const SizedBox(height: 24),

                // 注册入口
                Center(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const EmailRegisterPage(),
                              ),
                            );
                          },
                    child: RichText(
                      text: TextSpan(
                        style: PetureTextStyles.body,
                        children: [
                          TextSpan(text: '还没有账户？ '),
                          TextSpan(
                            text: '立即注册',
                            style: PetureTextStyles.bodyStrong.copyWith(
                              color: PetureColors.violet,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.1,
                ), // 动态底部间距，替代 Spacer
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
