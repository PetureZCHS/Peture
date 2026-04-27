// 账户设置页面 - 支持修改密码、编辑个人资料等

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/presentation/login_page.dart';
import '../../../shared/utils/china_regions_loader.dart';
import '../../../shared/utils/user_avatar_helper.dart';
import '../../../shared/utils/user_gender_mapper.dart';
import '../../../shared/utils/avatar_image_helper.dart';
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
  String _birthDate = '未设置';
  String _province = '未设置';
  String _city = '未设置';

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
        // 从 Supabase users_profiles 表加载昵称
        final profile = await _supabaseService.getUserProfile();
        final nickname = profile?['nickname'] as String?;
        final avatarUrl = profile?['avatar_url'] as String?;
        final ownerNickname = profile?['owner_nickname'] as String? ?? '主人';
        final gender = profile?['gender'] as String?;
        // 线上库可能是 birth_date（迁移）或仅 birthday（旧/手工库）
        final birthDateRaw = profile?['birth_date'] as String? ??
            profile?['birthday']?.toString();
        String? province = profile?['province'] as String?;
        String? city = profile?['city'] as String?;
        final region = profile?['region'] as String?;
        if ((province == null || province.isEmpty) &&
            (city == null || city.isEmpty) &&
            region != null &&
            region.isNotEmpty) {
          final tokens = region
              .split(RegExp(r'[/\-\s]+'))
              .where((e) => e.trim().isNotEmpty)
              .toList();
          if (tokens.isNotEmpty) {
            province = tokens.first.trim();
            if (tokens.length > 1) city = tokens[1].trim();
          }
        }
        final localAvatar = await UserAvatarHelper.ensureCachedAvatarFile(
          avatarUrl,
          _supabaseService.cacheUserAvatarFromPublicUrl,
        );

        if (mounted) {
          setState(() {
            _userEmail = user.email;
            // 优先使用数据库中的昵称，如果没有则使用 Auth 的元数据
            _userName = nickname ?? user.userMetadata?['name'] ?? '';
            _avatarPath = localAvatar;
            _avatarUrl = avatarUrl;
            _ownerNickname = ownerNickname;
            _gender = UserGenderMapper.toDisplayLabel(gender);
            _birthDate = (birthDateRaw != null && birthDateRaw.isNotEmpty)
                ? birthDateRaw
                : '未设置';
            _province =
                (province != null && province.isNotEmpty) ? province : '未设置';
            _city = (city != null && city.isNotEmpty) ? city : '未设置';
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

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (pickedFile == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      if (!mounted) return;
      final cropped = await AvatarImageHelper.cropAndCompressAvatar(
        context,
        pickedFile.path,
      );
      if (cropped == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // 网络不稳定时先本地显示新头像，云端再异步同步
      final localFile = cropped;
      var persistedPath = await UserAvatarHelper.persistAvatarFile(localFile.path);
      if (persistedPath == null && localFile.existsSync()) {
        persistedPath = await UserAvatarHelper.persistAvatarBytes(
          await localFile.readAsBytes(),
        );
      }
      persistedPath ??= localFile.path;
      await UserAvatarHelper.saveUserAvatarPath(persistedPath);
      if (mounted) {
        setState(() {
          _avatarPath = persistedPath;
        });
      }

      final fileForUpload = File(persistedPath);
      var upload = await _supabaseService.uploadUserAvatarWithError(
        fileForUpload,
      );
      if (upload.url == null) {
        final err = upload.error ?? '上传失败';
        final retry = err.toLowerCase().contains('socket') ||
            err.toLowerCase().contains('timeout') ||
            err.toLowerCase().contains('connection') ||
            err.toLowerCase().contains('network');
        if (retry) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          upload = await _supabaseService.uploadUserAvatarWithError(
            fileForUpload,
          );
        }
      }

      String? avatarUrl = upload.url;
      String? failMsg = upload.error;
      var success = false;

      if (avatarUrl != null) {
        final prof = await _supabaseService.upsertUserProfileWithError(
          avatarUrl: avatarUrl,
        );
        success = prof.success;
        if (!prof.success) {
          failMsg = prof.error ?? '保存头像链接失败';
        }
      }

      String? localPath = persistedPath;
      if (avatarUrl != null) {
        await UserAvatarHelper.setAvatarSourceUrlBasename(
          avatarUrl.split('?').first,
        );
        localPath = persistedPath;
        if (File(persistedPath).existsSync()) {
          try {
            await FileImage(File(persistedPath)).evict();
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _avatarPath = localPath;
          _avatarUrl = avatarUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '✅ 头像更换成功'
                  : '❌ 同步失败${failMsg != null ? '：$failMsg' : ''}',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: Duration(seconds: success ? 2 : 6),
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

  Future<void> _changeGender() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择性别'),
        children: UserGenderMapper.dialogOptions
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
    final dbValue = UserGenderMapper.toDatabaseValue(result);
    if (dbValue == null) return;
    setState(() => _isLoading = true);
    try {
      final r = await _supabaseService.upsertUserProfileWithError(gender: dbValue);
      if (r.success && mounted) {
        setState(() => _gender = result);
      } else if (mounted) {
        final msg = r.error ?? '保存失败';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('性别保存失败：$msg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeBirthDate() async {
    DateTime initial = DateTime.now();
    if (_birthDate != '未设置') {
      final parsed = DateTime.tryParse(_birthDate);
      if (parsed != null) initial = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    final value =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() => _isLoading = true);
    try {
      final r = await _supabaseService.upsertUserProfileWithError(birthDate: value);
      if (r.success && mounted) {
        setState(() => _birthDate = value);
      } else if (mounted) {
        final msg = r.error ?? '保存失败';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('出生日期保存失败：$msg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeRegion() async {
    final regions = await ChinaRegionsLoader.load();
    if (!mounted) return;

    String selectedProvince = _province == '未设置' ? '' : _province;
    String selectedCity = _city == '未设置' ? '' : _city;

    final provinceNames = regions
        .map((e) => (e['province'] as String?) ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    if (selectedProvince.isNotEmpty && !provinceNames.contains(selectedProvince)) {
      selectedProvince = '';
      selectedCity = '';
    }

    List<String> citiesForProvince(String province) {
      final entry = regions.cast<Map<String, dynamic>?>().firstWhere(
            (e) => e?['province'] == province,
            orElse: () => null,
          );
      if (entry == null) return <String>[];
      return (entry['cities'] as List<dynamic>)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    var cityNames =
        selectedProvince.isEmpty ? <String>[] : citiesForProvince(selectedProvince);
    if (selectedCity.isNotEmpty && !cityNames.contains(selectedCity)) {
      selectedCity = '';
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('设置地区'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: selectedProvince.isEmpty ? null : selectedProvince,
                decoration: const InputDecoration(labelText: '省份'),
                hint: const Text('请选择省份'),
                items: provinceNames
                    .map(
                      (p) => DropdownMenuItem<String>(
                        value: p,
                        child: Text(
                          p,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedProvince = value ?? '';
                    cityNames = selectedProvince.isEmpty
                        ? <String>[]
                        : citiesForProvince(selectedProvince);
                    selectedCity = '';
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: selectedCity.isEmpty ? null : selectedCity,
                decoration: const InputDecoration(labelText: '城市'),
                hint: const Text('请选择城市'),
                items: cityNames
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(
                          c,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: selectedProvince.isEmpty
                    ? null
                    : (value) {
                        setDialogState(() {
                          selectedCity = value ?? '';
                        });
                      },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: selectedProvince.isEmpty || selectedCity.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;
    final newProvince = selectedProvince.trim();
    final newCity = selectedCity.trim();
    setState(() => _isLoading = true);
    try {
      final r = await _supabaseService.upsertUserProfileWithError(
        province: newProvince,
        city: newCity,
      );
      if (r.success && mounted) {
        setState(() {
          _province = newProvince.isEmpty ? '未设置' : newProvince;
          _city = newCity.isEmpty ? '未设置' : newCity;
        });
      } else if (mounted) {
        final msg = r.error ?? '保存失败';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('地区保存失败：$msg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        final r = await _supabaseService.upsertUserProfileWithError(
          nickname: result.trim(),
        );

        if (r.success) {
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
            final msg = r.error ?? '保存失败';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ 昵称修改失败：$msg'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
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
        final r = await _supabaseService.upsertUserProfileWithError(
          ownerNickname: result.trim(),
        );

        if (r.success) {
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
            final msg = r.error ?? '保存失败';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ 称呼修改失败：$msg'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
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
                          key: ValueKey<String>(
                            '${_avatarUrl ?? ''}|${_avatarPath ?? ''}',
                          ),
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
                          child: (_avatarPath == null ||
                                      !File(_avatarPath!).existsSync()) &&
                                  (_avatarUrl == null || _avatarUrl!.isEmpty)
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _userName?.isNotEmpty == true ? _userName! : '未设置昵称',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
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
                        subtitle: _birthDate,
                        onTap: _changeBirthDate,
                      ),
                      _buildListTile(
                        icon: Icons.location_on_outlined,
                        title: '地区',
                        subtitle: _province == '未设置' && _city == '未设置'
                            ? '未设置'
                            : '${_province == '未设置' ? '' : _province}${_city == '未设置' ? '' : ' / $_city'}',
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
