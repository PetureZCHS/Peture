import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_service.dart';

/// 温馨画风：与 invitation_banner 一致，原图 + 中间空白处 8 位邀请码
class MyInvitationCodePage extends StatefulWidget {
  const MyInvitationCodePage({super.key});

  @override
  State<MyInvitationCodePage> createState() => _MyInvitationCodePageState();
}

class _MyInvitationCodePageState extends State<MyInvitationCodePage> {
  final SupabaseService _supabase = SupabaseService();
  String? _code;
  String? _error;
  bool _loading = true;

  static const Color _pinkDark = Color(0xFFE8919E);
  static const Color _yellow = Color(0xFFFFF8E7);
  static const Color _pinkBorder = Color(0xFFF8C4CC);

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    setState(() { _loading = true; _error = null; });
    final result = await _supabase.getOrCreateMyInvitationCode();
    if (!mounted) return;
    setState(() { _loading = false; _code = result.code; _error = result.error; });
  }

  Future<void> _copyCode() async {
    if (_code == null) return;
    await Clipboard.setData(ClipboardData(text: _code!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('邀请码已复制'), backgroundColor: _pinkDark, behavior: SnackBarBehavior.floating),
      );
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF666666)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('我的邀请码', style: TextStyle(color: Color(0xFF333333), fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/invitation_banner.png',
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        height: 280,
                        decoration: BoxDecoration(color: _pinkBorder, borderRadius: BorderRadius.circular(20)),
                        child: const Center(child: Text('图片加载失败', style: TextStyle(color: Colors.grey))),
                      ),
                    ),
                    Positioned.fill(
                      child: Align(
                        alignment: const Alignment(0, 1.35),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 48),
                          child: _loading
                              ? const SizedBox(
                                  height: 44,
                                  width: 44,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE8919E)),
                                )
                              : _error != null
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 14), textAlign: TextAlign.center),
                                    )
                                  : _code != null
                                      ? GestureDetector(
                                          onTap: _copyCode,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              _code!,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 2,
                                                color: _pinkDark,
                                              ),
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_code != null && !_loading) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _copyCode,
                    icon: const Icon(Icons.copy_rounded, size: 20, color: _pinkDark),
                    label: const Text('复制邀请码', style: TextStyle(color: _pinkDark, fontWeight: FontWeight.w500)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _pinkDark,
                      side: const BorderSide(color: _pinkBorder, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('一人一码，分享给好友兑换终身会员', style: TextStyle(fontSize: 13, color: Colors.grey[600]), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
