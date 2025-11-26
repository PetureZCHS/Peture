import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_login_page.dart';

/// 用户注册页面
///
/// 这是一个完整的用户注册组件，实现了以下功能：
/// 1. 邮箱和密码输入表单
/// 2. 客户端输入验证
/// 3. API请求处理（POST /api/auth/register）
/// 4. 加载状态管理
/// 5. 成功/错误消息展示
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

  /// 表单验证Key
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Supabase 客户端
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 加载状态：true表示正在发送API请求
  bool _isLoading = false;

  /// 密码可见性状态
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

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
    super.dispose();
  }

  // ========== 客户端验证方法 ==========

  /// 验证邮箱格式
  ///
  /// @param email 用户输入的邮箱地址
  /// @return 如果格式有效返回true，否则返回false
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// 验证密码强度
  ///
  /// @param password 用户输入的密码
  /// @return 如果密码符合要求（至少8位）返回true
  bool _isValidPassword(String password) {
    return password.length >= 8;
  }

  // ========== API请求方法 ==========

  /// 使用 Supabase 注册新用户
  Future<void> _register() async {
    // 清空之前的消息
    setState(() {
      _successMessage = null;
      _errorMessage = null;
    });

    // 表单验证
    if (!_formKey.currentState!.validate()) {
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
      print('🔍 开始注册用户: ${_emailController.text.trim()}');

      // 使用 Supabase 注册，禁用邮箱确认
      final response = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        emailRedirectTo: null,
      );

      print('✅ 注册请求完成');
      print('User: ${response.user?.email}');
      print('Session: ${response.session != null}');

      if (response.user != null) {
        // 注册成功
        setState(() {
          _successMessage = '注册成功！正在跳转到登录页面...';
          _errorMessage = null;
          _isLoading = false;
        });

        // 清空输入框
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();

        // 2秒后自动跳转到登录页面
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const EmailLoginPage()),
            );
          }
        });
      } else {
        // 注册失败
        setState(() {
          _errorMessage = '注册失败，请稍后重试';
          _successMessage = null;
          _isLoading = false;
        });
      }
    } on AuthException catch (e) {
      print('❌ 注册失败: ${e.message}');
      print('Status Code: ${e.statusCode}');

      String errorMessage = '注册失败';

      if (e.message.contains('already registered') ||
          e.message.contains('already exists')) {
        errorMessage = '该邮箱已被注册，请直接登录';
      } else if (e.message.contains('Invalid email')) {
        errorMessage = '邮箱格式不正确';
      } else if (e.message.contains('Password')) {
        errorMessage = '密码不符合要求（至少6位）';
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
      // 处理网络错误或其他异常
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
                  decoration: InputDecoration(
                    labelText: '密码 *',
                    hintText: '至少8位字符',
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
                      return '请输入密码';
                    }
                    if (!_isValidPassword(value)) {
                      return '密码必须至少8位字符';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ===== 确认密码输入框 =====
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  enabled: !_isLoading, // 加载时禁用输入
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
                const SizedBox(height: 32),

                // ===== 注册按钮 =====
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
                    onPressed: _isLoading ? null : _register,
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
                                '注册中...',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            '注册',
                            style: TextStyle(
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
