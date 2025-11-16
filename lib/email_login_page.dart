import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // 导入主应用文件，登录成功后将跳转到这里
import 'email_register_page.dart'; // 导入注册页面

class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _obscurePassword = true; // 控制密码是否可见

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 邮箱登录（只使用密码登录）
  Future<void> _emailLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔍 尝试密码登录: ${_emailController.text.trim()}');
      
      final response = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('✅ 密码登录成功');
      print('User: ${response.user?.email}');

      if (response.user != null) {
        // 隐藏键盘
        FocusScope.of(context).unfocus();
        
        // 直接跳转，不显示提示消息
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const MyApp(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      print('❌ 密码登录失败: ${e.message}');
      print('Status Code: ${e.statusCode}');
      
      String errorMsg = '登录失败';
      if (e.message.contains('Invalid login credentials')) {
        errorMsg = '邮箱或密码错误';
      } else if (e.message.contains('Email not confirmed')) {
        errorMsg = '请先验证您的邮箱';
      } else if (e.message.contains('User not found')) {
        errorMsg = '用户不存在，请先注册';
      } else {
        errorMsg = '${e.message} (状态码: ${e.statusCode})';
      }
      _showMessage(errorMsg);
    } catch (e) {
      print('❌ 其他错误: $e');
      _showMessage('登录失败: $e');
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
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
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
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true, // 确保页面会随键盘调整
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '邮箱登录',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请输入您的邮箱地址和密码',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),

                // 邮箱输入框
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: '邮箱地址',
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

                // 密码输入框
                TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
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
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      if (value.length < 6) {
                        return '密码至少6位';
                      }
                      return null;
                    },
                  ),
                
                const SizedBox(height: 32),

                // 登录按钮
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
                    onPressed: _isLoading ? null : _emailLogin,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '登录',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
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
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        children: const [
                          TextSpan(text: '还没有账户？ '),
                          TextSpan(
                            text: '立即注册',
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
