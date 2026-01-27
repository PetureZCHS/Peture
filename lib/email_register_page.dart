import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'email_login_page.dart';

/// 密码强度等级
enum PasswordStrength {
  weak,   // 弱：只有单一种类（大写/小写/数字）
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

  /// 密码输入控制器
  final TextEditingController _passwordController = TextEditingController();

  /// 确认密码输入控制器
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  /// 验证码输入控制器
  final TextEditingController _codeController = TextEditingController();

  /// 表单验证Key
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Supabase 客户端
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 加载状态：true表示正在发送API请求
  bool _isLoading = false;

  /// 密码可见性状态
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  /// 密码强度结果
  _PasswordStrengthResult get _passwordStrength =>
      _evaluatePassword(_passwordController.text);

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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  /// 评估密码强度
  ///
  /// @param password 用户输入的密码
  /// @return 密码强度结果
  _PasswordStrengthResult _evaluatePassword(String password) {
    if (password.isEmpty) {
      return _PasswordStrengthResult(
        strength: PasswordStrength.weak,
        message: '',
        color: Colors.grey,
        isValid: false,
      );
    }

    // 检查是否包含不允许的字符（只允许大小写字母和数字）
    final allowedPattern = RegExp(r'^[a-zA-Z0-9]+$');
    if (!allowedPattern.hasMatch(password)) {
      return _PasswordStrengthResult(
        strength: PasswordStrength.weak,
        message: '密码只能包含字母和数字',
        color: Colors.red,
        isValid: false,
      );
    }

    // 检查包含的字符类型
    bool hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowerCase = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));

    int typeCount = 0;
    if (hasUpperCase) typeCount++;
    if (hasLowerCase) typeCount++;
    if (hasDigit) typeCount++;

    PasswordStrength strength;
    String message;
    Color color;

    if (typeCount == 1) {
      // 只有单一种类 → 弱
      strength = PasswordStrength.weak;
      message = '弱：密码应包含大小写字母和数字中的至少两种';
      color = Colors.red;
    } else if (typeCount == 2) {
      // 有两种种类 → 中
      strength = PasswordStrength.medium;
      message = '中：密码强度良好';
      color = Colors.orange;
    } else {
      // 有三种种类 → 强
      strength = PasswordStrength.strong;
      message = '强：密码强度优秀';
      color = Colors.green;
    }

    // 判断是否满足注册要求：强度≥中 且 长度≥8
    bool isValid = strength != PasswordStrength.weak && password.length >= 8;

    if (!isValid && password.length < 8) {
      message = '密码长度至少8位，且应包含大小写字母和数字中的至少两种';
    }

    return _PasswordStrengthResult(
      strength: strength,
      message: message,
      color: color,
      isValid: isValid,
    );
  }

  /// 验证密码强度
  ///
  /// @param password 用户输入的密码
  /// @return 如果密码符合要求（强度≥中 且 长度≥8）返回true
  bool _isValidPassword(String password) {
    final result = _evaluatePassword(password);
    return result.isValid;
  }

  // ========== API请求方法 ==========

  /// 发送邮箱验证码
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

    // 验证密码
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = '请输入密码';
      });
      return;
    }

    if (!_isValidPassword(_passwordController.text)) {
      final result = _evaluatePassword(_passwordController.text);
      setState(() {
        if (result.message.contains('只能包含')) {
          _errorMessage = result.message;
        } else {
          _errorMessage = '密码长度至少8位，且应包含大小写字母和数字中的至少两种';
        }
      });
      return;
    }

    // 检查两次密码是否一致
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = '两次输入的密码不一致';
      });
      return;
    }

    // 开始加载状态
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔍 检查用户是否已存在: $email');

      // 先尝试发送 OTP 但不创建用户，用于检查用户是否已存在
      // 如果用户不存在，会返回错误；如果用户存在，会成功发送验证码
      try {
        await _supabase.auth.signInWithOtp(
          email: email,
          shouldCreateUser: false, // 不创建新用户，只检查是否存在（已有用户会成功）
          emailRedirectTo: null,
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
              ),
            ),
          );
        }
        return;
      } on AuthException catch (checkError) {
        // 检查错误类型
        print('🔍 检查用户存在性结果: ${checkError.message}');

        // 如果错误是"用户不存在" / "邮箱未确认" / "Signups not allowed for otp"
        // 说明当前邮箱还没有可用账号，可以走注册流程
        if (checkError.message.contains('User not found') ||
            checkError.message.contains('Email not confirmed') ||
            checkError.message.contains('not found') ||
            checkError.message.contains('Signups not allowed for otp')) {
          print('✅ 用户不存在，可以注册');
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
      print('🔍 发送验证码到: $email');
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true, // 允许通过 OTP 为新邮箱创建用户
        emailRedirectTo: null,
      );

      print('✅ 验证码已发送');

      setState(() {
        _isCodeSent = true;
        _successMessage = '验证码已发送到您的邮箱，请查收';
        _errorMessage = null;
        _isLoading = false;
      });

      _startCountdown();
    } on AuthException catch (e) {
      print('❌ 发送验证码失败: ${e.message}');
      print('Status Code: ${e.statusCode}');

      // 如果邮件服务未配置（500错误），提供备用方案
      if (e.statusCode?.toString() == '500' && 
          (e.message.contains('magic link') || 
           e.message.contains('email') ||
           e.message.contains('unexpected_failure'))) {
        setState(() {
          _errorMessage = '邮件服务未配置。请在 Supabase Dashboard → Authentication → Settings 中配置邮件服务，或联系管理员。\n\n错误详情: ${e.message} (状态码: ${e.statusCode})';
          _successMessage = null;
          _isLoading = false;
        });
        return;
      }

      String errorMessage = '发送验证码失败';

      // 检查用户是否已存在
      if (e.message.contains('already registered') ||
          e.message.contains('already exists') ||
          e.message.contains('User already registered') ||
          e.message.contains('email address is already registered')) {
        errorMessage = '该邮箱已被注册，请直接登录';
      } else if (e.message.contains('Invalid email')) {
        errorMessage = '邮箱格式不正确';
      } else if (e.message.contains('rate limit')) {
        errorMessage = '请求过于频繁，请稍后再试';
      } else {
        errorMessage = '${e.message} (状态码: ${e.statusCode})';
      }

      setState(() {
        _errorMessage = errorMessage;
        _successMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 其他错误: $e');
      setState(() {
        _errorMessage = '网络连接失败，请检查您的网络设置后重试';
        _successMessage = null;
        _isLoading = false;
      });
    }
  }

  /// 验证验证码并完成注册
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
      final password = _passwordController.text;

      print('🔍 验证验证码并注册: $email');

      // 验证 OTP 验证码
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: code,
      );

      print('✅ 验证码验证成功');
      print('User: ${response.user?.email}');
      print('Session: ${response.session != null}');

      // 验证码验证成功
      // 如果用户不存在（response.user == null 或没有 session），创建新用户
      // 如果用户已存在（有 session），拒绝注册
      if (response.session != null) {
        // 用户已存在，拒绝注册
        await _supabase.auth.signOut(); // 登出，避免误登录
        setState(() {
          _errorMessage = '该邮箱已被注册，请直接登录';
          _successMessage = null;
          _isLoading = false;
        });
        return;
      }

      // 用户不存在，验证码验证成功，现在创建账户
      try {
        // 使用 signUp 创建新用户并设置密码
        final signUpResponse = await _supabase.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: null,
        );

        if (signUpResponse.user == null) {
          throw Exception('用户创建失败');
        }

        print('✅ 账户创建成功');

        // 注册/登录成功
        setState(() {
          _successMessage = '注册成功！正在跳转到登录页面...';
          _errorMessage = null;
          _isLoading = false;
        });

        // 清空输入框
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _codeController.clear();

        // 2秒后自动跳转到登录页面
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const EmailLoginPage()),
            );
          }
        });
      } catch (e) {
        print('❌ 创建账户失败: $e');
        // 如果创建失败，先登出
        await _supabase.auth.signOut();
        setState(() {
          _errorMessage = '创建账户失败，请重新注册';
          _isLoading = false;
        });
        return;
      }
    } on AuthException catch (e) {
      print('❌ 验证失败: ${e.message}');
      print('Status Code: ${e.statusCode}');

      String errorMessage = '验证失败';

      if (e.message.contains('Invalid token') ||
          e.message.contains('expired')) {
        errorMessage = '验证码无效或已过期，请重新获取';
      } else if (e.message.contains('rate limit')) {
        errorMessage = '请求过于频繁，请稍后再试';
      } else {
        errorMessage = '${e.message} (状态码: ${e.statusCode})';
      }

      setState(() {
        _errorMessage = errorMessage;
        _successMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 其他错误: $e');
      setState(() {
        _errorMessage = '网络连接失败，请检查您的网络设置后重试';
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
                  '请填写您的邮箱和密码以完成注册',
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

                // ===== 密码输入框 =====
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  enabled: !_isLoading, // 加载时禁用输入
                  onChanged: (value) {
                    // 实时更新密码强度显示
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: '密码 *',
                    hintText: '至少8位，包含大小写字母和数字中的至少两种',
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
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    final result = _evaluatePassword(value);
                    if (!result.isValid) {
                      if (result.message.contains('只能包含')) {
                        return result.message;
                      }
                      return '密码长度至少8位，且应包含大小写字母和数字中的至少两种';
                    }
                    return null;
                  },
                ),
                // 密码强度显示
                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 强度指示条
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: Colors.grey[200],
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _passwordStrength.strength == PasswordStrength.weak
                                ? 0.33
                                : _passwordStrength.strength == PasswordStrength.medium
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
                      // 强度文字
                      Text(
                        _passwordStrength.strength == PasswordStrength.weak
                            ? '弱'
                            : _passwordStrength.strength == PasswordStrength.medium
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
                  // 强度提示信息
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

                // ===== 确认密码输入框 =====
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  enabled: !_isLoading && !_isCodeSent, // 已发送验证码后禁用
                  decoration: InputDecoration(
                    labelText: '确认密码 *',
                    hintText: '请再次输入密码',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        });
                      },
                    ),
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
                      return '请再次输入密码';
                    }
                    return null;
                  },
                ),
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
                              borderSide: const BorderSide(color: Colors.red, width: 2),
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
                        : (_isCodeSent ? _verifyCodeAndRegister : _sendVerificationCode),
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
                            _isCodeSent ? '完成注册' : '发送验证码',
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
