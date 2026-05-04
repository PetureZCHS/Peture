import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/login_page.dart';

/// 立即注销：两次确认 → 向绑定邮箱发送验证码 → 校验通过后调用 Edge 删除并全局退出。
class AccountDeactivatePage extends StatefulWidget {
  const AccountDeactivatePage({super.key});

  @override
  State<AccountDeactivatePage> createState() => _AccountDeactivatePageState();
}

class _AccountDeactivatePageState extends State<AccountDeactivatePage> {
  bool _isSubmitting = false;
  bool _awaitingOtp = false;
  String? _emailForOtp;

  final TextEditingController _otpController = TextEditingController();
  int _resendCooldown = 0;
  Timer? _resendTimer;

  static const String _riskNotice =
      '注销后，你的账号及关联业务数据将被立即永久删除，无法恢复。\n\n'
      '完成后将在所有已登录设备上退出登录。\n\n'
      '下一步将向你的绑定邮箱发送验证码，请查收后填写。';

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return '***';
    if (at <= 2) return '***${email.substring(at)}';
    return '${email.substring(0, 2)}***${email.substring(at)}';
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendCooldown = 0);
      } else {
        if (mounted) setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _sendDeletionOtp() async {
    final email = _emailForOtp?.trim();
    if (email == null || email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前账号没有绑定邮箱，无法使用邮箱验证码注销')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
        emailRedirectTo: null,
      );
      if (!mounted) return;
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('验证码已发送至 ${_maskEmail(email)}'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final m = e.message.toLowerCase();
      String msg = '发送验证码失败：${e.message}';
      if (m.contains('rate limit') ||
          m.contains('too many requests') ||
          e.statusCode == '429') {
        msg = '发送过于频繁，请稍后再试';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送验证码失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _messageForVerifyFailure(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid otp') ||
        m.contains('invalid or expired otp') ||
        m.contains('invalid login credentials')) {
      return '验证码错误或已过期，请检查后重试';
    }
    if (m.contains('email not confirmed')) {
      return '邮箱尚未完成验证，请先在邮箱中完成验证';
    }
    if (m.contains('too many requests') || e.statusCode == '429') {
      return '尝试次数过多，请稍后再试';
    }
    return '验证失败：${e.message}';
  }

  Future<void> _verifyOtpAndDeleteAccount() async {
    final email = _emailForOtp?.trim();
    final code = _otpController.text.trim();
    if (email == null || email.isEmpty) return;
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入邮箱中的验证码')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );

      final res = await Supabase.instance.client.functions.invoke(
        'delete-my-account',
      );

      if (res.status != 200) {
        final data = res.data;
        final msg = data is Map
            ? (data['error']?.toString() ?? data['message']?.toString())
            : null;
        throw Exception(msg ?? '注销失败（${res.status}）');
      }

      try {
        await Supabase.instance.client.auth.signOut(
          scope: SignOutScope.global,
        );
      } catch (_) {
        await Supabase.instance.client.auth.signOut();
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageForVerifyFailure(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _onTapStartDeactivate() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未登录或会话已过期，请重新登录后再试')),
      );
      return;
    }

    final email = Supabase.instance.client.auth.currentUser?.email?.trim();
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前账号未绑定邮箱，无法使用邮箱验证码。请联系客服或先绑定邮箱后再注销。'),
        ),
      );
      return;
    }

    final agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('注销账号'),
        content: const SingleChildScrollView(
          child: Text(_riskNotice, style: TextStyle(height: 1.45, fontSize: 14)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('我已了解风险'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('最后确认'),
        content: const Text('确定要继续吗？将向你的绑定邮箱发送验证码。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('发送验证码'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() {
      _emailForOtp = email;
      _awaitingOtp = true;
      _otpController.clear();
    });
    await _sendDeletionOtp();
  }

  void _cancelOtpStep() {
    _resendTimer?.cancel();
    setState(() {
      _awaitingOtp = false;
      _emailForOtp = null;
      _resendCooldown = 0;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('用户注销')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _awaitingOtp
                  ? '请输入发送至 ${_maskEmail(_emailForOtp ?? '')} 的验证码，验证通过后账号将被立即删除。'
                  : '本页为「立即注销」：确认后账号与数据会马上删除，与设置里的「退出登录」不同。'
                      '需通过绑定邮箱验证码确认本人操作。',
              style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.4),
            ),
            if (!_awaitingOtp) ...[
              const SizedBox(height: 12),
              Text(
                '请使用本人设备、在确认无人代操作的情况下继续。',
                style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.35),
              ),
            ],
            if (_awaitingOtp) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: const InputDecoration(
                  labelText: '邮箱验证码',
                  hintText: '请输入邮件中的验证码',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                onSubmitted: (_) {
                  if (!_isSubmitting) unawaited(_verifyOtpAndDeleteAccount());
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: (_isSubmitting || _resendCooldown > 0)
                    ? null
                    : _sendDeletionOtp,
                child: Text(
                  _resendCooldown > 0
                      ? '重新发送（${_resendCooldown}s）'
                      : '重新发送验证码',
                ),
              ),
              TextButton(
                onPressed: _isSubmitting ? null : _cancelOtpStep,
                child: const Text('返回上一步'),
              ),
            ],
            const Spacer(),
            if (!_awaitingOtp)
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _onTapStartDeactivate,
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('开始注销流程'),
                ),
              )
            else
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _verifyOtpAndDeleteAccount,
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('验证并立即注销'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
