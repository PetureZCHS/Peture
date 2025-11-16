// lib/account_settings_page.dart
// 账户设置页面 - 支持修改密码、编辑个人资料等

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  
  // 用户信息
  String? _userEmail;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // 加载用户信息
  Future<void> _loadUserInfo() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        setState(() {
          _userEmail = user.email;
          _userName = user.userMetadata?['name'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('❌ 加载用户信息失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 修改密码
  Future<void> _changePassword() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改密码'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '当前密码',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '新密码',
                  prefixIcon: Icon(Icons.lock),
                  helperText: '至少6个字符',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '确认新密码',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              // 验证输入
              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('新密码至少需要6个字符')),
                );
                return;
              }

              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('两次输入的新密码不一致')),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            child: const Text('确认修改'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() => _isLoading = true);

      try {
        // Supabase 修改密码（需要先验证当前密码）
        // 注意：Supabase 的 updateUser 不需要验证旧密码
        await _supabase.auth.updateUser(
          UserAttributes(password: newPasswordController.text),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 密码修改成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ 密码修改失败: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // 修改昵称
  Future<void> _changeName() async {
    final nameController = TextEditingController(text: _userName);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '昵称',
            prefixIcon: Icon(Icons.person),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _isLoading = true);

      try {
        await _supabase.auth.updateUser(
          UserAttributes(data: {'name': result}),
        );

        setState(() => _userName = result);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 昵称修改成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ 昵称修改失败: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // 退出登录
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('您确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);

      try {
        await _supabase.auth.signOut();

        if (mounted) {
          // 返回登录页面并清除所有路由栈
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ 退出失败: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账户设置'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // 用户头像
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(
                      _userName?.isNotEmpty == true
                          ? _userName![0].toUpperCase()
                          : (_userEmail?.isNotEmpty == true ? _userEmail![0].toUpperCase() : '?'),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 用户昵称
                  Text(
                    _userName?.isNotEmpty == true ? _userName! : '未设置昵称',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // 用户邮箱
                  Text(
                    _userEmail ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 账户信息部分
                  _buildSection(
                    title: '账户信息',
                    children: [
                      _buildListTile(
                        icon: Icons.person,
                        title: '修改昵称',
                        subtitle: _userName?.isNotEmpty == true ? _userName! : '未设置',
                        onTap: _changeName,
                      ),
                      _buildListTile(
                        icon: Icons.email,
                        title: '邮箱',
                        subtitle: _userEmail ?? '',
                        trailing: const Icon(Icons.check_circle, color: Colors.green),
                        onTap: null, // 邮箱不可修改
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 安全设置部分
                  _buildSection(
                    title: '安全设置',
                    children: [
                      _buildListTile(
                        icon: Icons.lock,
                        title: '修改密码',
                        subtitle: '定期修改密码以保护账户安全',
                        onTap: _changePassword,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 退出登录按钮
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('退出登录'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            )
          : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.arrow_forward_ios, size: 16) : null),
      onTap: onTap,
      enabled: onTap != null,
    );
  }
}
