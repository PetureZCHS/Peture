import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../../../core/auth_otp_email_context.dart';
import 'email_login_page.dart';

/// 密码强度等级
enum PasswordStrength {
  weak, // 弱：只有单一种类（大写/小写/数字）
  medium, // 中：有两种种类
  strong, // 强：有三种种类（大写+小写+数字）
}

/// 密码强度检测结果
class _PasswordStrengthResult {
  final PasswordStrength strength;
  final String message;
  final Color color;
  final bool isValid; // 是否满足注册要求（强度≥中 且 长度≥8）

  _PasswordStrengthResult({
    required this.strength,
    required this.message,
    required this.color,
    required this.isValid,
  });
}

/// 用户注册页面
///
/// 这是一个完整的用户注册组件，实现了以下功能：
/// 1. 邮箱和密码输入表单
/// 2. 邮箱验证码验证
/// 3. 客户端输入验证
/// 4. API请求处理
/// 5. 加载状态管理
/// 6. 成功/错误消息展示
class EmailRegisterPage extends StatefulWidget {
  const EmailRegisterPage({super.key});

  @override
  State<EmailRegisterPage> createState() => _EmailRegisterPageState();
}

class _EmailRegisterPageState extends State<EmailRegisterPage> {
  // ========== 状态管理 ==========

  /// 邮箱输入控制器
  final TextEditingController _emailController = TextEditingController();

  /// 验证码输入控制器
  final TextEditingController _codeController = TextEditingController();

  /// 表单验证Key
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Supabase 客户端
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 加载状态：true表示正在发送API请求
  bool _isLoading = false;

  /// 是否已发送验证码
  bool _isCodeSent = false;

  /// 验证码倒计时
  int _countdown = 0;
  Timer? _countdownTimer;

  /// 成功消息：注册成功后显示
  String? _successMessage;

  /// 错误消息：注册失败时显示
  String? _errorMessage;

  @override
  void dispose() {
    // 清理控制器，防止内存泄漏
    _emailController.dispose();
    _codeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// 开始倒计时
  void _startCountdown() {
    setState(() {
      _countdown = 60;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  // ========== 客户端验证方法 ==========

  /// 验证邮箱格式
  ///
  /// @param email 用户输入的邮箱地址
  /// @return 如果格式有效返回true，否则返回false
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // ========== API请求方法 ==========

  /// 发送邮箱验证码（仅校验邮箱是否已注册，不在本页设置密码）
  Future<void> _sendVerificationCode() async {
    // 清空之前的消息
    setState(() {
      _successMessage = null;
      _errorMessage = null;
    });

    // 验证邮箱格式
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = '请输入邮箱地址';
      });
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() {
        _errorMessage = '请输入有效的邮箱地址';
      });
      return;
    }

    // 开始加载状态
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🔍 检查用户是否已存在: $email');

      // 先尝试发送 OTP 但不创建用户，用于检查用户是否已存在
      // 如果用户不存在，会返回错误；如果用户存在，会成功发送验证码
      try {
        await _supabase.auth.signInWithOtp(
          email: email,
          shouldCreateUser: false, // 不创建新用户，只检查是否存在（已有用户会成功）
          emailRedirectTo: null,
          data: AuthOtpEmailKind.payload(AuthOtpEmailKind.login),
        );
        // 如果能执行到这里，说明用户已存在，验证码已发送
        // 直接跳转到邮箱验证码登录页，提示“已注册，可用验证码直接登录”
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => EmailLoginPage(
                initialEmail: email,
                initialMessage: '该邮箱已被注册，验证码已发送，可直接使用验证码登录',
                forceOtp: true,
                startCountdownOnInit: true,
              ),
            ),
          );
        }
        return;
      } on AuthException catch (checkError) {
        // 检查错误类型
        debugPrint('🔍 检查用户存在性结果: ${checkError.message}');

        // 如果错误是"用户不存在" / "邮箱未确认" / "Signups not allowed for otp"
        // 说明当前邮箱还没有可用账号，可以走注册流程
        if (checkError.message.contains('User not found') ||
            checkError.message.contains('Email not confirmed') ||
            checkError.message.contains('not found') ||
            checkError.message.contains('Signups not allowed for otp')) {
          debugPrint('✅ 用户不存在，可以注册');
        } else {
          // 其他错误，可能是用户已存在或其他问题
          if (checkError.message.contains('already registered') ||
              checkError.message.contains('already exists') ||
              checkError.message.contains('User already registered')) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => EmailLoginPage(
                    initialEmail: email,
                    initialMessage: '该邮箱已被注册，验证码已发送，可直接使用验证码登录',
                    forceOtp: true,
                    startCountdownOnInit: true,
                  ),
                ),
              );
            }
            return;
          }
          // 其他错误（如邮件服务问题），交给外层 catch 统一处理
          rethrow;
        }
      }

      // 用户不存在，发送验证码（这次允许创建用户，等验证码验证通过后才真正生效）
      debugPrint('🔍 发送验证码到: $email');
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true, // 允许通过 OTP 为新邮箱创建用户
        emailRedirectTo: null,
        data: AuthOtpEmailKind.payload(AuthOtpEmailKind.signup),
      );

      debugPrint('✅ 验证码已发送');

      setState(() {
        _isCodeSent = true;
        _successMessage = '验证码已发送到您的邮箱，请查收';
        _errorMessage = null;
        _isLoading = false;
      });

      _startCountdown();
    } on AuthException catch (e) {
      debugPrint('❌ 发送验证码失败: ${e.message}');
      debugPrint('Status Code: ${e.statusCode}');

      // 如果邮件服务未配置（500错误），提供备用方案
      if (e.statusCode?.toString() == '500' &&
          (e.message.contains('magic link') ||
              e.message.contains('email') ||
              e.message.contains('unexpected_failure'))) {
        setState(() {
          _errorMessage =
              '验证码邮件服务未正确配置，请联系管理员检查 Supabase 邮件设置。（错误码：${e.statusCode ?? '未知'}）';
          _successMessage = null;
          _isLoading = false;
        });
        return;
      }

      String errorMessage = '发送验证码失败，请稍后重试';

      // 检查用户是否已存在
      if (e.message.contains('already registered') ||
          e.message.contains('already exists') ||
          e.message.contains('User already registered') ||
          e.message.contains('email address is already registered')) {
        errorMessage = '该邮箱已被注册，请直接前往登录页登录';
      } else if (e.message.contains('Invalid email')) {
        errorMessage = '邮箱格式不正确，请检查是否有输入错误';
      } else if (e.message.contains('rate limit') || e.statusCode == '429') {
        errorMessage = '验证码请求过于频繁，请稍后再试';
      } else if (e.statusCode == '500') {
        errorMessage = '验证码服务暂时不可用（代码 500），请稍后重试或联系管理员';
      } else {
        errorMessage = '发送验证码失败，服务器返回错误代码 ${e.statusCode ?? '未知'}，请稍后重试或联系管理员';
      }

      setState(() {
        _errorMessage = errorMessage;
        _successMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 其他错误: $e');
      setState(() {
        _errorMessage = '发送验证码时本地出现未知错误，请检查网络后重试';
        _successMessage = null;
        _isLoading = false;
      });
    }
  }

  /// 验证验证码，通过后进入密码设置页
  Future<void> _verifyCodeAndRegister() async {
    // 清空之前的消息
    setState(() {
      _successMessage = null;
      _errorMessage = null;
    });

    // 验证验证码
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = '请输入验证码';
      });
      return;
    }

    if (code.length != 6) {
      setState(() {
        _errorMessage = '验证码应为6位数字';
      });
      return;
    }

    // 开始加载状态
    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();

      debugPrint('🔍 验证验证码: $email');

      // 验证 OTP 验证码
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: code,
      );

      debugPrint('✅ 验证码验证成功');
      debugPrint('User: ${response.user?.email}');
      debugPrint('Session: ${response.session != null}');

      // 验证码验证成功，进入密码设置页（此时通常已经有临时登录会话）
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => EmailPasswordSetupPage(email: email),
          ),
        );
      }
    } on AuthException catch (e) {
      debugPrint('❌ 验证失败: ${e.message}');
      debugPrint('Status Code: ${e.statusCode}');

      String errorMessage = '验证码验证失败，请稍后重试';

      if (e.message.contains('Invalid token') ||
          e.message.contains('expired')) {
        errorMessage = '验证码无效或已过期，请重新获取后再试';
      } else if (e.message.contains('rate limit') || e.statusCode == '429') {
        errorMessage = '验证码验证尝试过于频繁，请稍后再试';
      } else if (e.statusCode == '500') {
        errorMessage = '验证码验证服务暂时不可用（代码 500），请稍后重试或联系管理员';
      } else {
        errorMessage = '验证码验证失败，服务器返回错误代码 ${e.statusCode ?? '未知'}，请稍后重试或联系管理员';
      }

      setState(() {
        _errorMessage = errorMessage;
        _successMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 其他错误: $e');
      setState(() {
        _errorMessage = '验证码验证时本地出现未知错误，请检查网络后重试';
        _successMessage = null;
        _isLoading = false;
      });
    }
  }

  // ========== UI构建方法 ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true, // 键盘弹出时调整布局
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '注册账户',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // ===== 页面标题 =====
                const Text(
                  '创建新账户',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请先填写邮箱并完成验证码校验',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),

                // ===== 成功消息显示区域 =====
                if (_successMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    margin: const EdgeInsets.only(bottom: 24.0),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ===== 错误消息显示区域 =====
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    margin: const EdgeInsets.only(bottom: 24.0),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ===== 邮箱输入框 =====
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading, // 加载时禁用输入
                  decoration: InputDecoration(
                    labelText: '邮箱地址 *',
                    hintText: '请输入您的邮箱地址',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      borderSide: const BorderSide(
                        color: Color(0xFF5D5FEF),
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
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

                // 此处不再设置密码，仅在后续“密码设置页”完成
                const SizedBox(height: 8),
                const SizedBox(height: 24),

                // ===== 验证码输入区域 =====
                if (_isCodeSent) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: '验证码 *',
                            hintText: '请输入6位验证码',
                            prefixIcon: const Icon(Icons.verified_user),
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.0),
                              borderSide: const BorderSide(
                                color: Color(0xFF5D5FEF),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.0),
                              borderSide:
                                  const BorderSide(color: Colors.red, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入验证码';
                            }
                            if (value.length != 6) {
                              return '验证码应为6位数字';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: ElevatedButton(
                          onPressed: (_countdown > 0 || _isLoading)
                              ? null
                              : _sendVerificationCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5D5FEF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18.0),
                            elevation: 0,
                          ),
                          child: _countdown > 0
                              ? Text('${_countdown}s')
                              : const Text('重新发送'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // ===== 发送验证码/注册按钮 =====
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D5FEF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18.0),
                      elevation: 0,
                      // 加载时禁用按钮
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                    ),
                    onPressed: _isLoading
                        ? null
                        : (_isCodeSent
                            ? _verifyCodeAndRegister
                            : _sendVerificationCode),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                '处理中...',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _isCodeSent ? '下一步，设置密码' : '发送验证码',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // ===== 返回登录链接 =====
                Center(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        children: const [
                          TextSpan(text: '已有账户？ '),
                          TextSpan(
                            text: '立即登录',
                            style: TextStyle(
                              color: Color(0xFF5D5FEF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 邮箱注册 - 第二步：密码设置页
class EmailPasswordSetupPage extends StatefulWidget {
  final String email;

  const EmailPasswordSetupPage({super.key, required this.email});

  @override
  State<EmailPasswordSetupPage> createState() => _EmailPasswordSetupPageState();
}

class _EmailPasswordSetupPageState extends State<EmailPasswordSetupPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  _PasswordStrengthResult get _passwordStrength =>
      _evaluatePassword(_passwordController.text);

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// 评估密码强度（允许包含特殊符号）
  _PasswordStrengthResult _evaluatePassword(String password) {
    if (password.isEmpty) {
      return _PasswordStrengthResult(
        strength: PasswordStrength.weak,
        message: '',
        color: Colors.grey,
        isValid: false,
      );
    }

    // 检查包含的字符类型：大写、小写、数字、特殊字符
    bool hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowerCase = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[^A-Za-z0-9]'));

    int typeCount = 0;
    if (hasUpperCase) typeCount++;
    if (hasLowerCase) typeCount++;
    if (hasDigit) typeCount++;
    if (hasSpecial) typeCount++;

    PasswordStrength strength;
    String message;
    Color color;

    if (typeCount <= 1) {
      strength = PasswordStrength.weak;
      message = '弱：建议同时包含字母、数字或符号中的至少两种';
      color = Colors.red;
    } else if (typeCount == 2) {
      strength = PasswordStrength.medium;
      message = '中：密码强度良好';
      color = Colors.orange;
    } else {
      strength = PasswordStrength.strong;
      message = '强：密码强度优秀';
      color = Colors.green;
    }

    bool isValid = strength != PasswordStrength.weak && password.length >= 8;
    if (!isValid && password.length < 8) {
      message = '密码长度至少8位，建议混合使用字母、数字和符号';
    }

    return _PasswordStrengthResult(
      strength: strength,
      message: message,
      color: color,
      isValid: isValid,
    );
  }

  bool _isValidPassword(String password) {
    return _evaluatePassword(password).isValid;
  }

  Future<void> _submitPassword() async {
    setState(() {
      _errorMessage = null;
    });

    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    // 密码处于「可见」状态时，不允许直接提交
    if (_isPasswordVisible) {
      setState(() {
        _errorMessage = '请先关闭密码可见，然后再次确认密码后提交';
      });
      return;
    }

    if (!_isValidPassword(password)) {
      final result = _evaluatePassword(password);
      setState(() {
        _errorMessage = result.message.isNotEmpty
            ? result.message
            : '密码长度至少8位，建议混合使用字母、数字和符号';
      });
      return;
    }

    // 要求两次输入一致（需要先关闭小眼睛再填写确认密码）
    if (password != confirm) {
      setState(() {
        _errorMessage = '两次输入的密码不一致';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 此时用户通常已通过邮箱验证码登录（verifyOTP 成功后有 session）
      // 这里仅为当前用户设置密码，而不是再次创建账号
      await _supabase.auth.updateUser(
        UserAttributes(password: password),
      );

      // 设置完成后主动登出，让用户用新密码或验证码重新登录
      await _supabase.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('密码设置成功，请使用邮箱登录'),
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => EmailLoginPage(
              initialEmail: widget.email,
            ),
          ),
          (route) => route.isFirst,
        );
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = '密码设置失败，服务器返回错误代码 ${e.statusCode ?? '未知'}，请稍后重试或联系管理员';
      });
    } catch (e) {
      setState(() {
        _errorMessage = '密码设置时本地出现未知错误，请检查网络后重试';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '设置密码',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  '为 ${widget.email} 设置登录密码',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '密码允许包含字母、数字和符号，推荐长度不少于 8 位。',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 密码输入框
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  enabled: !_isLoading,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '密码 *',
                    hintText: '至少8位，建议混合字母、数字和符号',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      borderSide: BorderSide(
                        color: _passwordController.text.isNotEmpty
                            ? _passwordStrength.color
                            : const Color(0xFF5D5FEF),
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    if (!_isValidPassword(value)) {
                      final result = _evaluatePassword(value);
                      return result.message.isNotEmpty
                          ? result.message
                          : '密码长度至少8位，建议混合使用字母、数字和符号';
                    }
                    return null;
                  },
                ),

                // 密码强度显示
                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: Colors.grey[200],
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _passwordStrength.strength ==
                                    PasswordStrength.weak
                                ? 0.33
                                : _passwordStrength.strength ==
                                        PasswordStrength.medium
                                    ? 0.66
                                    : 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: _passwordStrength.color,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _passwordStrength.strength == PasswordStrength.weak
                            ? '弱'
                            : _passwordStrength.strength ==
                                    PasswordStrength.medium
                                ? '中'
                                : '强',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _passwordStrength.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _passwordStrength.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: _passwordStrength.color,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // 确认密码输入框：仅在密码不可见时显示
                if (!_isPasswordVisible) ...[
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: '确认密码 *',
                      hintText: '请再次输入密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请再次输入密码';
                      }
                      if (value != _passwordController.text) {
                        return '两次输入的密码不一致';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D5FEF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18.0),
                      elevation: 0,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_formKey.currentState?.validate() ?? false) {
                              _submitPassword();
                            }
                          },
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '完成注册',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
