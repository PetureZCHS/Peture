import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/login_page.dart';
import '../../../services/supabase_service.dart';

class AccountDeactivatePage extends StatefulWidget {
  const AccountDeactivatePage({super.key});

  @override
  State<AccountDeactivatePage> createState() => _AccountDeactivatePageState();
}

class _AccountDeactivatePageState extends State<AccountDeactivatePage> {
  bool _isSubmitting = false;
  final _supabaseService = SupabaseService();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deactivate() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入当前账号密码')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认注销'),
        content: const Text('该操作会永久删除你的账号业务数据，且不可恢复。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认注销'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final email = user?.email;
      if (email == null || email.isEmpty) {
        throw Exception('当前账号缺少邮箱，无法校验密码');
      }

      // 先验证密码，确保“永久注销”需要用户再次确认身份
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final deleteResult = await _supabaseService.deleteCurrentUserAllData();
      if (!deleteResult.success) {
        throw Exception(deleteResult.error ?? '删除失败');
      }

      final authDeleteResult = await _supabaseService.deleteCurrentAuthUser();
      if (!authDeleteResult.success) {
        throw Exception(authDeleteResult.error ?? '删除认证账户失败');
      }

      // 账户删除后令牌通常会失效，这里尽量清理本地会话。
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('账号已永久注销'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('注销失败：$e')),
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
      appBar: AppBar(title: const Text('用户注销')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '此操作会永久删除你的账号业务数据。',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              '删除后不可恢复。退出登录是另一项独立功能，请在设置页底部使用。',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: '请输入当前密码',
                hintText: '用于确认你本人正在操作',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '若你使用纯验证码登录且未设置密码，请先在“修改密码”中设置后再注销。',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const Spacer(),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _deactivate,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('确认永久注销'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
