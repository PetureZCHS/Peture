import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth_otp_email_context.dart';
import '../../../shared/design_system/peture_design_system.dart';
import '../../../shared/utils/ui_helpers.dart';
import '../../auth/presentation/login_page.dart';

/// 账号注销：两次确认 → 绑定邮箱验证码 → 校验通过后调用 Edge 删除并全局退出。
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

  static const Color _warnRed = PetureColors.danger;

  TextStyle get _bodyBaseStyle =>
      TextStyle(fontSize: 15, height: 1.45, color: Colors.grey[800]);
  TextStyle get _bodyEmphasisStyle => _bodyBaseStyle.copyWith(
        color: _warnRed,
        fontWeight: FontWeight.w600,
      );

  /// 首屏说明（与弹窗要点一致，引导点击「开始注销流程」）。
  Widget _buildIntroCopy() {
    return Text.rich(
      TextSpan(
        style: _bodyBaseStyle,
        children: [
          const TextSpan(text: '您即将进入'),
          TextSpan(text: '账号注销', style: _bodyEmphasisStyle),
          const TextSpan(text: '流程，这与「'),
          TextSpan(text: '退出登录', style: _bodyEmphasisStyle),
          const TextSpan(text: '」不同：退出登录只是暂时登出；注销会导致您的账号及数据被'),
          TextSpan(text: '永久删除且无法恢复', style: _bodyEmphasisStyle),
          const TextSpan(
            text: '。须通过绑定邮箱验证码确认本人操作；请使用本人设备、在无人代操作的环境下继续。',
          ),
        ],
      ),
    );
  }

  /// 第一步风险提示弹窗正文。
  Widget _buildRiskDialogBody() {
    const base = TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF424242));
    final emph = base.copyWith(color: _warnRed, fontWeight: FontWeight.w600);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: '您即将进入账号注销流程。注销后，您的账号及所有数据将被'),
          TextSpan(text: '永久删除', style: emph),
          const TextSpan(text: '，且'),
          TextSpan(text: '无法恢复', style: emph),
          const TextSpan(text: '。\n\n这与「'),
          TextSpan(text: '退出登录', style: emph),
          const TextSpan(text: '」不同：退出登录只是暂时登出；而'),
          TextSpan(text: '注销', style: emph),
          const TextSpan(text: '会直接'),
          TextSpan(text: '清除账号及相关信息', style: emph),
          const TextSpan(text: '。\n\n为保障账号安全，注销须通过'),
          TextSpan(text: '绑定邮箱收到的验证码', style: emph),
          const TextSpan(text: '确认是您本人操作。\n\n请您务必使用'),
          TextSpan(text: '本人设备', style: emph),
          const TextSpan(text: '、在'),
          TextSpan(text: '无人代操作', style: emph),
          const TextSpan(text: '的环境下继续。\n\n请确认您已了解并接受注销的'),
          TextSpan(text: '全部后果', style: emph),
          const TextSpan(text: '后，再继续操作。'),
        ],
      ),
    );
  }

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
        data: AuthOtpEmailKind.payload(AuthOtpEmailKind.accountDeletion),
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

  /// 尽力全局退出，与注销成功路径一致。
  Future<void> _signOutGloballyBestEffort() async {
    try {
      await Supabase.instance.client.auth.signOut(
        scope: SignOutScope.global,
      );
    } catch (_) {
      await Supabase.instance.client.auth.signOut();
    }
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
    var otpEstablishedSession = false;
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      otpEstablishedSession = true;

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

      await _signOutGloballyBestEffort();

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
      if (otpEstablishedSession) {
        await _signOutGloballyBestEffort();
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('注销未完成'),
            content: SingleChildScrollView(
              child: Text(
                '未能完成注销，已为你退出登录，请重新登录后重试。\n\n详情：$e',
                style: const TextStyle(height: 1.4),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _onTapStartDeactivate() async {
    if (_isSubmitting) return;

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

    setState(() => _isSubmitting = true);
    try {
      final agreed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('注销账号'),
          content: SingleChildScrollView(child: _buildRiskDialogBody()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('我已了解并接受后果'),
            ),
          ],
        ),
      );
      if (agreed != true || !mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('最后确认'),
          content: const Text(
            '将向您的绑定邮箱发送验证码，用于确认注销操作。\n\n请点击下方「发送验证码」并查收邮件。',
          ),
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
    } finally {
      if (mounted && !_awaitingOtp) {
        setState(() => _isSubmitting = false);
      }
    }
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
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.85),
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: const Text(
          '账号注销',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1D1D1F),
              size: 18,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 120, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_awaitingOtp)
              _buildGlassCard(
                child: PetureCard(
                child: Text.rich(
                  TextSpan(
                    style: _bodyBaseStyle,
                    children: [
                      TextSpan(
                        text:
                            '请输入发送至 ${_maskEmail(_emailForOtp ?? '')} 的验证码。\n验证通过后，您的账号及数据将被',
                      ),
                      TextSpan(text: '永久删除', style: _bodyEmphasisStyle),
                      const TextSpan(text: '，且'),
                      TextSpan(text: '无法恢复', style: _bodyEmphasisStyle),
                      const TextSpan(text: '。'),
                    ],
                  ),
                )),
              )
            else ...[
              PetureAlertPanel(
                title: '高风险操作：账号注销',
                tone: PetureAlertTone.danger,
                message: '注销后账号与所有数据会被永久删除，无法恢复。',
              ),
              const SizedBox(height: PetureSpacing.md),
              _buildGlassCard(
                child: PetureCard(
                variant: PetureCardVariant.danger,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntroCopy(),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.grey[700],
                        ),
                        children: [
                          const TextSpan(text: '请确认您已理解上述说明，并'),
                          TextSpan(
                            text: '自愿承担注销的全部后果',
                            style: TextStyle(
                              color: _warnRed,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const TextSpan(text: '后再点击「开始注销流程」。'),
                        ],
                      ),
                    ),
                  ],
                )),
              ),
            ],
            if (_awaitingOtp) ...[
              const SizedBox(height: PetureSpacing.md),
              _buildGlassCard(
                child: PetureCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      decoration: petureInputDecoration(
                        labelText: '邮箱验证码',
                        hintText: '请输入邮件中的验证码',
                        prefixIcon: const Icon(Icons.pin_outlined),
                      ),
                      onSubmitted: (_) {
                        if (!_isSubmitting) {
                          unawaited(_verifyOtpAndDeleteAccount());
                        }
                      },
                    ),
                    const SizedBox(height: PetureSpacing.md),
                    PetureSecondaryButton(
                      label: _resendCooldown > 0
                          ? '重新发送（${_resendCooldown}s）'
                          : '重新发送验证码',
                      onPressed: (_isSubmitting || _resendCooldown > 0)
                          ? null
                          : _sendDeletionOtp,
                    ),
                    const SizedBox(height: PetureSpacing.sm),
                    PetureSecondaryButton(
                      label: '返回上一步',
                      onPressed: _isSubmitting ? null : _cancelOtpStep,
                    ),
                  ],
                )),
              ),
            ],
            const Spacer(),
            if (!_awaitingOtp)
              PetureDangerButton(
                label: '开始注销流程',
                onPressed: _isSubmitting ? null : _onTapStartDeactivate,
                isLoading: _isSubmitting,
              )
            else
              PetureDangerButton(
                label: '验证并完成注销',
                onPressed: _isSubmitting ? null : _verifyOtpAndDeleteAccount,
                isLoading: _isSubmitting,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.65),
            Colors.white.withOpacity(0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: Colors.white.withOpacity(0.1),
            child: child,
          ),
        ),
      ),
    );
  }
}
