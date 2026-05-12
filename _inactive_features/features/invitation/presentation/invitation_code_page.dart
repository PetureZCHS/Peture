import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';

/// 邀请码兑换页：温馨画风与 invitation_banner 一致，兑换成功即开通终身会员
class InvitationCodePage extends StatefulWidget {
  const InvitationCodePage({super.key});

  @override
  State<InvitationCodePage> createState() => _InvitationCodePageState();
}

class _InvitationCodePageState extends State<InvitationCodePage> {
  final TextEditingController _codeController = TextEditingController();
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  static const Color _pink = Color(0xFFFFB6C1);
  static const Color _pinkDark = Color(0xFFE8919E);
  static const Color _yellow = Color(0xFFFFF8E7);
  static const Color _pinkBorder = Color(0xFFF8C4CC);

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _message = '请输入邀请码';
        _isSuccess = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _message = null;
    });
    final result = await _supabase.redeemInvitationCode(code);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _message = result.error ?? '兑换成功';
      _isSuccess = result.success;
      if (result.success) _codeController.clear();
    });
    if (result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('已开通终身会员，享受全部权益'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating),
      );
      if (mounted) InvitationWelcomeDialog.showOnce(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _yellow,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF666666)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('输入邀请码',
            style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Icon(Icons.card_giftcard_rounded, size: 48, color: _pinkDark),
              const SizedBox(height: 12),
              const Text('Peture',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _pinkDark,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              const Text('邀请码',
                  style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _pinkBorder, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: _pink.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: TextField(
                  controller: _codeController,
                  enabled: !_isLoading,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    LengthLimitingTextInputFormatter(32)
                  ],
                  decoration: InputDecoration(
                    hintText: '请输入邀请码',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                    prefixIcon: Icon(Icons.confirmation_number_rounded,
                        color: _pinkDark, size: 22),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                  onSubmitted: (_) => _redeem(),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!,
                    style: TextStyle(
                        fontSize: 14,
                        color: _isSuccess
                            ? Colors.green.shade700
                            : Colors.red.shade700),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _redeem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pinkDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    shadowColor: _pinkDark.withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('兑换',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 32),
              Text('一起为宠物宝宝打造属于它们的未来',
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey[600], height: 1.4),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// 欢迎弹窗：欢迎您，内测官！画风与 invitation_banner 一致（温馨）
class InvitationWelcomeDialog extends StatelessWidget {
  static const String _shownKey = 'shown_invitation_welcome';

  const InvitationWelcomeDialog({super.key});

  static Future<void> showOnce(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shownKey) == true) return;
    if (!context.mounted) return;
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const InvitationWelcomeDialog());
    if (!context.mounted) return;
    await prefs.setBool(_shownKey, true);
  }

  /// 若当前用户为终身会员且未展示过欢迎弹窗，则展示一次
  static Future<void> showIfLifetime(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shownKey) == true) return;
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final profile = await supabase
          .from('users_profiles')
          .select('membership_type')
          .eq('id', userId)
          .maybeSingle();
      if (profile?['membership_type'] != 'lifetime') return;
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const InvitationWelcomeDialog());
    if (!context.mounted) return;
    await prefs.setBool(_shownKey, true);
  }

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFFFB6C1);
    const pinkDark = Color(0xFFE8919E);
    const yellow = Color(0xFFFFF8E7);
    const pinkBorder = Color(0xFFF8C4CC);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        decoration: BoxDecoration(
          color: yellow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: pinkBorder, width: 2),
          boxShadow: [
            BoxShadow(
                color: pink.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded, size: 56, color: pinkDark),
            const SizedBox(height: 20),
            const Text('欢迎您，内测官！',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B4545))),
            const SizedBox(height: 12),
            Text('感谢您加入 Peture，一起为宠物宝宝打造属于它们的未来',
                style: TextStyle(
                    fontSize: 14, color: Colors.grey[700], height: 1.4),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pinkDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('好的'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
