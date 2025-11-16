import 'package:flutter/material.dart';

// 导入主应用文件，登录成功后将跳转到这里
import 'main.dart';
// 导入邮箱登录页面
import 'email_login_page.dart';
// 导入手机号验证码登录页面
import 'phone_login_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Colors.white, body: _LoginBody());
  }
}

// 登录页面的主要内容
class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  // 模拟的手机号
  final String _phoneNumber = '186****9172';
  // 模拟用户是否同意协议
  bool _agreedToTerms = false;

  // 模拟登录逻辑
  void _login() {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先阅读并同意服务协议')));
      return;
    }
    // 登录成功后，使用 pushReplacement 清除堆栈，防止返回登录页
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => const MyApp()));
  }

  // 模拟其他登录方式
  void _otherLogin(String method) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('您选择了 $method 登录')));
  }

  // 邮箱登录
  void _emailLogin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const EmailLoginPage()));
  }

  // 手机号验证码登录
  void _phoneLogin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const PhoneLoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Spacer(flex: 3),
          // 添加应用Logo
          const Icon(Icons.pets, size: 80, color: Color(0xFF5D5FEF)),
          const SizedBox(height: 24),
          Text(
            _phoneNumber,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            '联通本机号码一键登录',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 48),
          _AgreementRow(
            value: _agreedToTerms,
            onChanged: (value) {
              setState(() {
                _agreedToTerms = value ?? false;
              });
            },
            onTap: () => _otherLogin('服务协议'),
          ),
          const SizedBox(height: 16),
          _LoginButton(onPressed: _login),
          const SizedBox(height: 16),
          // 添加邮箱登录按钮
          _EmailLoginButton(onPressed: _emailLogin),
          const SizedBox(height: 16),
          // 添加手机号验证码登录按钮
          _PhoneLoginButton(onPressed: _phoneLogin),
          const Spacer(flex: 2),
          const Divider(),
          const SizedBox(height: 24),
          const Text('其他登录选项', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          _SocialLoginButtons(onLogin: _otherLogin),
          const Spacer(),
        ],
      ),
    );
  }
}

// 一键登录按钮
class _LoginButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _LoginButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF5D5FEF), // 使用品牌主色
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0), // 增加圆角
          ),
          padding: const EdgeInsets.symmetric(vertical: 18.0),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: const Text('一键登录', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}

// 邮箱登录按钮
class _EmailLoginButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _EmailLoginButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF5D5FEF),
          side: const BorderSide(color: Color(0xFF5D5FEF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16.0),
        ),
        onPressed: onPressed,
        child: const Text('邮箱登录', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

// 手机号验证码登录按钮
class _PhoneLoginButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _PhoneLoginButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF5D5FEF),
          side: const BorderSide(color: Color(0xFF5D5FEF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16.0),
        ),
        onPressed: onPressed,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_android, size: 20),
            SizedBox(width: 8),
            Text('手机号验证码登录', style: TextStyle(fontSize: 16)),
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
        Checkbox(
          value: value,
          onChanged: onChanged,
          visualDensity: VisualDensity.compact,
          activeColor: const Color(0xFF5D5FEF), // 使用品牌主色
        ),
        const Text('我已阅读并同意'),
        GestureDetector(
          onTap: onTap,
          child: Text(
            '《中国联通认证服务协议》',
            style: TextStyle(
              color: const Color(0xFF5D5FEF), // 使用品牌主色
              decoration: TextDecoration.underline,
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
          color: Colors.green,
          method: '微信',
          onTap: () => onLogin('微信'),
        ),
        const SizedBox(width: 32),
        _SocialLoginButton(
          icon: Icons.apple,
          color: Colors.black,
          method: '苹果',
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
  final String method;
  final VoidCallback onTap;

  const _SocialLoginButton({
    required this.icon,
    required this.color,
    required this.method,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 32),
      ),
    );
  }
}
