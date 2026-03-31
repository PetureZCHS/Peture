// 账户设置页面 - 支持修改密码、编辑个人资料等

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/presentation/login_page.dart';
import '../../../shared/utils/user_avatar_helper.dart';
import '../../../services/supabase_service.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _supabase = Supabase.instance.client;
  final _supabaseService = SupabaseService();
  bool _isLoading = false;

  // 用户信息
  String? _userEmail;
  String? _userName;
  String? _avatarPath;
  String? _avatarUrl;
  String _ownerNickname = '主人'; // 宠物对主人的称呼
  String _gender = '未设置';
  String? _birthDate; // yyyy-MM-dd
  String _province = '';
  String _city = '';

  // 图片选择器
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // 加载用户信息
  Future<void> _loadUserInfo() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // 从本地存储加载头像路径
        final avatarPath = await UserAvatarHelper.getCurrentUserAvatarPath();

        // 从 Supabase users_profiles 表加载昵称
        final profile = await _supabaseService.getUserProfile();
        final nickname = profile?['nickname'] as String?;
        final avatarUrl = profile?['avatar_url'] as String?;
        final ownerNickname = profile?['owner_nickname'] as String? ?? '主人';
        final gender = profile?['gender'] as String?;
        final birthDateRaw = profile?['birth_date']?.toString();
        final province = profile?['province'] as String? ?? '';
        final city = profile?['city'] as String? ?? '';

        if (mounted) {
          setState(() {
            _userEmail = user.email;
            // 优先使用数据库中的昵称，如果没有则使用 Auth 的元数据
            _userName = nickname ?? user.userMetadata?['name'] ?? '';
            _avatarPath = avatarPath;
            _avatarUrl = avatarUrl;
            _ownerNickname = ownerNickname;
            _gender = (gender == null || gender.isEmpty) ? '未设置' : gender;
            _birthDate = birthDateRaw?.split('T')[0];
            _province = province;
            _city = city;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ 加载用户信息失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatBirthDate(String? date) {
    if (date == null || date.isEmpty) return '未设置';
    return date.split('T')[0];
  }

  String _regionText() {
    if (_province.isEmpty && _city.isEmpty) return '未设置';
    if (_province.isNotEmpty && _city.isNotEmpty) return '$_province $_city';
    return _province.isNotEmpty ? _province : _city;
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('新密码至少需要6个字符')));
                return;
              }

              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('两次输入的新密码不一致')));
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ 密码修改失败: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // 更换头像
  Future<void> _changeAvatar() async {
    try {
      // 显示选择对话框
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择头像'),
          content: const Text('请选择头像来源'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt, size: 18),
                  SizedBox(width: 8),
                  Text('拍照'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, size: 18),
                  SizedBox(width: 8),
                  Text('相册'),
                ],
              ),
            ),
          ],
        ),
      );

      if (source == null) return;

      setState(() => _isLoading = true);

      // 选择图片
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final avatarUrl =
          await _supabaseService.uploadUserAvatar(File(pickedFile.path));
      final success = avatarUrl != null
          ? await _supabaseService.upsertUserProfile(avatarUrl: avatarUrl)
          : false;

      if (mounted) {
        if (success) {
          setState(() {
            _avatarPath = null;
            _avatarUrl = avatarUrl;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '✅ 头像更换成功' : '❌ 头像上传失败，请重试'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ 更换头像失败: $e')));
      }
    } finally {
      if (mounted) {
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
            hintText: '请输入昵称',
            prefixIcon: Icon(Icons.person),
            helperText: '昵称长度为1-20个字符',
          ),
          autofocus: true,
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final nickname = nameController.text.trim();
              if (nickname.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('昵称不能为空'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, nickname);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _isLoading = true);

      try {
        // 使用 SupabaseService 保存昵称到 users_profiles 表
        final success = await _supabaseService.upsertUserProfile(
          nickname: result.trim(),
        );

        if (success) {
          if (mounted) {
            setState(() => _userName = result.trim());

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ 昵称修改成功'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ 昵称修改失败，请检查网络连接'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(
            content: Text('❌ 昵称修改失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _changeGender() async {
    const options = ['男', '女', '其他', '不透露'];
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择性别'),
        children: options
            .map(
              (item) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, item),
                child: Text(item),
              ),
            )
            .toList(),
      ),
    );

    if (result == null || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final success = await _supabaseService.upsertUserProfile(gender: result);
      if (success && mounted) {
        setState(() => _gender = result);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate != null
        ? DateTime.tryParse(_birthDate!) ?? DateTime(now.year - 18, 1, 1)
        : DateTime(now.year - 18, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
    );
    if (picked == null || !mounted) return;

    final birthDate = picked.toIso8601String().split('T')[0];
    setState(() => _isLoading = true);
    try {
      final success =
          await _supabaseService.upsertUserProfile(birthDate: birthDate);
      if (success && mounted) {
        setState(() => _birthDate = birthDate);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeRegion() async {
    final provinceController = TextEditingController(text: _province);
    final cityController = TextEditingController(text: _city);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置地区'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: provinceController,
              decoration: const InputDecoration(labelText: '省份'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cityController,
              decoration: const InputDecoration(labelText: '城市'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'province': provinceController.text.trim(),
              'city': cityController.text.trim(),
            }),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final success = await _supabaseService.upsertUserProfile(
        province: result['province'] ?? '',
        city: result['city'] ?? '',
      );
      if (success && mounted) {
        setState(() {
          _province = result['province'] ?? '';
          _city = result['city'] ?? '';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 修改主人昵称（宠物对主人的称呼）
  Future<void> _changeOwnerNickname() async {
    final nicknameController = TextEditingController(text: _ownerNickname);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('宠物对你的称呼'),
        content: TextField(
          controller: nicknameController,
          decoration: const InputDecoration(
            labelText: '称呼',
            hintText: '例如：主人、妈妈、姐姐',
            prefixIcon: Icon(Icons.pets),
            helperText: '这将作为宠物日记中对你的默认称呼',
          ),
          autofocus: true,
          maxLength: 10,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final nickname = nicknameController.text.trim();
              if (nickname.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('称呼不能为空'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, nickname);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _isLoading = true);

      try {
        final success = await _supabaseService.updateOwnerNickname(result.trim());

        if (success) {
          if (mounted) {
            setState(() => _ownerNickname = result.trim());

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ 称呼修改成功'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ 称呼修改失败，请检查网络连接'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(
            content: Text('❌ 称呼修改失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ 退出失败: $e')));
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账户设置'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // 用户头像（可点击更换）
                  GestureDetector(
                    onTap: _changeAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          backgroundImage: _avatarPath != null &&
                                  File(_avatarPath!).existsSync()
                              ? FileImage(File(_avatarPath!))
                              : (_avatarUrl != null
                                  ? NetworkImage(_avatarUrl!)
                                  : null) as ImageProvider?,
                          child: _avatarPath == null ||
                                  !File(_avatarPath!).existsSync() &&
                                      _avatarUrl == null
                              ? Text(
                                  _userName?.isNotEmpty == true
                                      ? _userName![0].toUpperCase()
                                      : (_userEmail?.isNotEmpty == true
                                          ? _userEmail![0].toUpperCase()
                                          : '?'),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
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
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),

                  const SizedBox(height: 32),

                  // 账户信息部分
                  _buildSection(
                    title: '账户信息',
                    children: [
                      _buildListTile(
                        icon: Icons.photo_camera,
                        title: '更换头像',
                        subtitle: '点击更换个人头像',
                        onTap: _changeAvatar,
                      ),
                      _buildListTile(
                        icon: Icons.person,
                        title: '修改昵称',
                        subtitle:
                            _userName?.isNotEmpty == true ? _userName! : '未设置',
                        onTap: _changeName,
                      ),
                      _buildListTile(
                        icon: Icons.wc,
                        title: '性别',
                        subtitle: _gender,
                        onTap: _changeGender,
                      ),
                      _buildListTile(
                        icon: Icons.cake_outlined,
                        title: '出生日期',
                        subtitle: _formatBirthDate(_birthDate),
                        onTap: _changeBirthDate,
                      ),
                      _buildListTile(
                        icon: Icons.location_on_outlined,
                        title: '地区',
                        subtitle: _regionText(),
                        onTap: _changeRegion,
                      ),
                      _buildListTile(
                        icon: Icons.pets,
                        title: '宠物对我的称呼',
                        subtitle: _ownerNickname,
                        onTap: _changeOwnerNickname,
                      ),
                      _buildListTile(
                        icon: Icons.email,
                        title: '邮箱',
                        subtitle: _userEmail ?? '',
                        trailing: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
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

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.arrow_forward_ios, size: 16)
              : null),
      onTap: onTap,
      enabled: onTap != null,
    );
  }
}
