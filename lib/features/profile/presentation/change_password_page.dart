import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth_pending_email_login.dart';
import '../../../core/root_navigator_key.dart';
import '../../auth/presentation/login_page.dart';
import '../../../shared/utils/password_policy.dart';
import '../../../shared/utils/ui_helpers.dart';

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
  bool _isSubmitting = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  PasswordValidationResult get _newStrength =>
      evaluateAppPassword(_newPasswordController.text.trim());

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    required IconData icon,
    required Widget suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textGrey),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0A84FF), width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textGrey),
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

    if (oldPwd == newPwd) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新密码不能与当前密码相同')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: oldPwd,
      );

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPwd),
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // 必须在 signOut 之前提示：登出后 RootRouter 会立刻切走，子页面 context 上的 SnackBar/Navigator 会失效。
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
      AuthPendingEmailLogin.armAfterPasswordChanged(email);

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

      // 强制回到根登录栈，避免嵌套 Navigator 仍停留在「已登录」界面；并再次 arm 邮箱供新 [LoginPage] 接力。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AuthPendingEmailLogin.armAfterPasswordChanged(email);
        rootNavigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      final code = e.message.toLowerCase();
      final isBadCredentials = code.contains('invalid') ||
          code.contains('credential') ||
          code.contains('password');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBadCredentials
                ? '当前密码错误，请重新输入'
                : '密码修改失败：${e.message}',
          ),
        ),
      );
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.92),
        elevation: 0,
        centerTitle: true,
        title: Text(
          '修改密码',
          style: GoogleFonts.notoSerif(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textDark,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              '$appPasswordRulesUserDescription\n\n'
              '修改成功后须使用新密码重新登录，其他设备上的登录将一并退出。',
              style: GoogleFonts.lato(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 20),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 0,
              shadowColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return '请输入当前密码';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
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
                            color: AppColors.textGrey,
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
                            color: AppColors.textGrey,
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
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '确认修改',
                        style: GoogleFonts.notoSerif(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
