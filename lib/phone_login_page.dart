import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

// 导入主应用文件，登录成功后将跳转到这里
import 'main.dart';

/// 手机号验证码登录页面
class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  // 文本控制器
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  // 状态标识
  bool _isCodeSent = false; // 是否已发送验证码
  bool _isLoading = false; // 是否正在加载
  bool _agreedToTerms = false; // 是否同意协议

  // 倒计时
  int _countdown = 0;
  Timer? _timer;

  // Supabase 客户端
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /// 开始倒计时
  void _startCountdown() {
    setState(() {
      _countdown = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  /// 验证手机号格式
  bool _validatePhone(String phone) {
    // 简单的手机号验证（11位数字）
    final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    return phoneRegex.hasMatch(phone);
  }

  /// 请求验证码（当前短信登录暂不可用，仅展示提示）
  Future<void> _requestSmsCode() async {
    final phone = _phoneController.text.trim();

    if (!_validatePhone(phone)) {
      _showMessage('请输入正确的手机号');
      return;
    }

    _showMessage('短信登录功能暂不可用，请使用邮箱登录或稍后再试');
  }

  /// 验证验证码并登录（当前短信登录暂不可用，仅展示提示）
  Future<void> _verifySmsCodeAndLogin() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    if (!_validatePhone(phone)) {
      _showMessage('请输入正确的手机号');
      return;
    }

    if (code.isEmpty) {
      _showMessage('当前短信登录功能暂不可用，请使用邮箱登录');
      return;
    }

    _showMessage('短信登录功能暂不可用，请使用邮箱登录或稍后再试');
  }

  /// 显示提示消息
  void _showMessage(String message, {int duration = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: duration),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // 标题
              const Text(
                '手机号登录',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请输入手机号获取验证码',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),

              // 手机号输入框
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_isCodeSent,
                maxLength: 11,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '手机号',
                  hintText: '请输入手机号',
                  prefixIcon: const Icon(Icons.phone_android),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF5D5FEF),
                      width: 2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 验证码输入框和获取验证码按钮
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: '验证码',
                        hintText: '请输入验证码',
                        prefixIcon: const Icon(Icons.verified_user),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF5D5FEF),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          _countdown > 0 || _isLoading ? null : _requestSmsCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5D5FEF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _countdown > 0
                          ? Text('${_countdown}s')
                          : const Text('获取验证码'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 协议行
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    onChanged: (value) {
                      setState(() {
                        _agreedToTerms = value ?? false;
                      });
                    },
                    visualDensity: VisualDensity.compact,
                    activeColor: const Color(0xFF5D5FEF),
                  ),
                  const Text('我已阅读并同意'),
                  GestureDetector(
                    onTap: () {
                      _showMessage('服务协议详情');
                    },
                    child: const Text(
                      '《用户服务协议》',
                      style: TextStyle(
                        color: Color(0xFF5D5FEF),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 登录按钮
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifySmsCodeAndLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D5FEF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
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

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
