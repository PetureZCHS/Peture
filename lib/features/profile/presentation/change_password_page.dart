import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth_otp_email_context.dart';
import '../../../core/auth_pending_email_login.dart';
import '../../../core/root_navigator_key.dart';
import '../../auth/presentation/login_page.dart';
import '../../../shared/design_system/peture_design_system.dart';
import '../../../shared/utils/password_policy.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  /// 开启：邮箱 OTP 验证身份（未设密码 / 长期验证码登录）；关闭：输入当前密码验证。
  bool _verifyIdentityWithEmailOtp = false;
  bool _otpMailSent = false;
  int _otpCooldownSec = 0;
  Timer? _otpCooldownTimer;

  PasswordValidationResult get _newStrength =>
      evaluateAppPassword(_newPasswordController.text.trim());

  @override
  void dispose() {
    _otpCooldownTimer?.cancel();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startOtpCooldown() {
    _otpCooldownTimer?.cancel();
    setState(() => _otpCooldownSec = 60);
    _otpCooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_otpCooldownSec <= 1) {
        t.cancel();
        if (mounted) setState(() => _otpCooldownSec = 0);
      } else if (mounted) {
        setState(() => _otpCooldownSec--);
      }
    });
  }

  Future<void> _sendPasswordChangeOtp(String email) async {
    if (_otpCooldownSec > 0) return;
    setState(() => _isSubmitting = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
        emailRedirectTo: null,
        data: AuthOtpEmailKind.payload(AuthOtpEmailKind.passwordChange),
      );
      if (!mounted) return;
      setState(() {
        _otpMailSent = true;
      });
      _startOtpCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码已发送至邮箱，请查收')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送验证码失败：${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送验证码失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _applyNewPasswordAndSignOut(String email, String newPwd) async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(password: newPwd),
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.check_circle_rounded,
            color: Colors.green.shade600,
            size: 52,
          ),
          title: const Text('密码已更新'),
          content: const Text(
            '请使用新密码重新登录。\n\n'
            '你在其他设备上的登录状态已失效，这是为了保障账号安全。',
            style: TextStyle(height: 1.45, fontSize: 15),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('去登录'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    try {
      await Supabase.instance.client.auth.signOut(
        scope: SignOutScope.global,
      );
    } catch (_) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e2) {
        AuthPendingEmailLogin.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('密码已更新，但退出登录失败，请手动退出后再登录：$e2'),
          ),
        );
        return;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AuthPendingEmailLogin.armAfterPasswordChanged(email);
      rootNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    });
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    required IconData icon,
    required Widget suffix,
  }) {
    return petureInputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: PetureColors.textSecondary),
      suffixIcon: suffix,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = Supabase.instance.client.auth.currentUser?.email?.trim();
    if (email == null || email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前账号缺少邮箱，无法校验密码')),
      );
      return;
    }

    final oldPwd = _oldPasswordController.text.trim();
    final newPwd = _newPasswordController.text.trim();
    final otpCode = _otpController.text.trim();

    if (!_verifyIdentityWithEmailOtp && oldPwd == newPwd) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新密码不能与当前密码相同')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_verifyIdentityWithEmailOtp) {
        if (!_otpMailSent) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先点击「发送验证码」')),
          );
          return;
        }
        if (otpCode.length != 6) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请输入 6 位邮箱验证码')),
          );
          return;
        }
        await Supabase.instance.client.auth.verifyOTP(
          email: email,
          token: otpCode,
          type: OtpType.email,
        );
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: oldPwd,
        );
      }
      await _applyNewPasswordAndSignOut(email, newPwd);
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      if (_verifyIdentityWithEmailOtp) {
        final badOtp = msg.contains('invalid') ||
            msg.contains('otp') ||
            msg.contains('expired');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              badOtp
                  ? '验证码错误或已过期，请重新获取后输入'
                  : '密码设置失败：${e.message}',
            ),
          ),
        );
      } else {
        final isBadCredentials = msg.contains('invalid') ||
            msg.contains('credential') ||
            msg.contains('password');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBadCredentials
                  ? '当前密码校验失败。若从未设置密码或长期使用验证码登录，请打开「使用邮箱验证码验证身份」后重试。'
                  : '密码修改失败：${e.message}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('密码修改失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PeturePageScaffold(
      title: '修改密码',
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Text(
              '$appPasswordRulesUserDescription\n\n'
              '修改成功后须使用新密码重新登录，其他设备上的登录将一并退出。',
              style: PetureTextStyles.body.copyWith(
                height: 1.45,
                color: PetureColors.textSecondary,
              ),
            ),
            const SizedBox(height: PetureSpacing.md),
            PetureCard(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                title: Text(
                  '使用邮箱验证码验证身份',
                  style: PetureTextStyles.bodyStrong.copyWith(
                    color: PetureColors.textPrimary,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Text(
                    '适合长期用验证码登录或记不清当前密码的情况',
                    style: PetureTextStyles.caption.copyWith(
                      height: 1.35,
                      color: PetureColors.textSecondary,
                    ),
                  ),
                ),
                value: _verifyIdentityWithEmailOtp,
                activeTrackColor: PetureColors.primary.withOpacity(0.45),
                activeThumbColor: PetureColors.primary,
                onChanged: _isSubmitting
                    ? null
                    : (v) {
                        setState(() {
                          _verifyIdentityWithEmailOtp = v;
                          _otpMailSent = false;
                          _otpController.clear();
                          _otpCooldownTimer?.cancel();
                          _otpCooldownSec = 0;
                        });
                      },
              ),
            ),
            const SizedBox(height: PetureSpacing.lg),
            PetureCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    if (!_verifyIdentityWithEmailOtp) ...[
                      TextFormField(
                        controller: _oldPasswordController,
                        obscureText: _obscureOld,
                        enabled: !_isSubmitting,
                        decoration: _fieldDecoration(
                          label: '当前密码',
                          hint: '请输入现用密码',
                          icon: Icons.verified_user_outlined,
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _obscureOld = !_obscureOld),
                            icon: Icon(
                              _obscureOld
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: PetureColors.textSecondary,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (_verifyIdentityWithEmailOtp) return null;
                          if ((value ?? '').trim().isEmpty) {
                            return '请输入当前密码';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Text(
                        '将向当前账号邮箱发送验证码（与登录相同）。请先点击发送，再填写收到的 6 位数字。',
                        style: PetureTextStyles.caption.copyWith(
                          height: 1.45,
                          color: PetureColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 46,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isSubmitting || _otpCooldownSec > 0
                              ? null
                              : () {
                                  final em = Supabase
                                      .instance.client.auth.currentUser
                                      ?.email
                                      ?.trim();
                                  if (em == null || em.isEmpty) return;
                                  _sendPasswordChangeOtp(em);
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PetureColors.primary,
                            side: const BorderSide(color: PetureColors.primary),
                          ),
                          child: Text(
                            _otpCooldownSec > 0
                                ? '重新发送（${_otpCooldownSec}s）'
                                : (_otpMailSent ? '重新发送验证码' : '发送验证码'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        enabled: !_isSubmitting,
                        decoration: _fieldDecoration(
                          label: '邮箱验证码',
                          hint: '6 位数字',
                          icon: Icons.mark_email_read_outlined,
                          suffix: const SizedBox(width: 8),
                        ),
                        validator: (value) {
                          if (!_verifyIdentityWithEmailOtp) return null;
                          final c = (value ?? '').trim();
                          if (c.isEmpty) return '请输入验证码';
                          if (c.length != 6) return '验证码应为 6 位';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      enabled: !_isSubmitting,
                      onChanged: (_) => setState(() {}),
                      decoration: _fieldDecoration(
                        label: '新密码',
                        hint: '至少 8 位，两种及以上字符类型',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                            icon: Icon(
                              _obscureNew
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: PetureColors.textSecondary,
                            ),
                          ),
                      ),
                      validator: (value) {
                        final pwd = (value ?? '').trim();
                        if (pwd.isEmpty) return '请输入新密码';
                        final result = evaluateAppPassword(pwd);
                        if (!result.isValid) {
                          return result.message.isNotEmpty
                              ? result.message
                              : '密码不符合安全要求';
                        }
                        return null;
                      },
                    ),
                    if (_newPasswordController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _newStrength.strength == PasswordStrength.weak
                              ? 0.33
                              : _newStrength.strength ==
                                      PasswordStrength.medium
                                  ? 0.66
                                  : 1,
                          backgroundColor: Colors.grey.shade200,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_newStrength.color),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _newStrength.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: _newStrength.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      enabled: !_isSubmitting,
                      decoration: _fieldDecoration(
                        label: '确认新密码',
                        hint: '再次输入新密码',
                        icon: Icons.lock_rounded,
                        suffix: IconButton(
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: PetureColors.textSecondary,
                            ),
                          ),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim() !=
                            _newPasswordController.text.trim()) {
                          return '两次输入的新密码不一致';
                        }
                        return null;
                      },
                    ),
                  ],
              ),
            ),
            const SizedBox(height: PetureSpacing.xl),
            PeturePrimaryButton(
              label: '确认修改',
              onPressed: _isSubmitting ? null : _submit,
              isLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }
}
