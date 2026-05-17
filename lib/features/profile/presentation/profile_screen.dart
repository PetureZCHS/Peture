import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/page_tracker_mixin.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/design_system/peture_design_system.dart';
import '../../../shared/models/pet.dart';
import '../../../shared/utils/data_change_notifier.dart';
import 'account_settings_page.dart';
import 'pet_profile_form_page.dart';
import '../../../shared/utils/ui_helpers.dart';
import '../../../shared/utils/user_avatar_helper.dart';
import '../../../shared/utils/avatar_image_helper.dart';
import '../../moderation/data/moderation_client.dart';
import '../../moderation/domain/moderation_scene.dart';
import '../../moderation/utils/moderation_guard.dart';

// =========================================================
// 全局设计系统 - 美学升级版
// =========================================================

class AppStyles {
  static const TextStyle sectionTitle = PetureTextStyles.sectionTitle;
  static const TextStyle petName = PetureTextStyles.bodyStrong;
  static const TextStyle petDetails = PetureTextStyles.body;
  static const TextStyle ownerId = PetureTextStyles.body;
  static const TextStyle listItemTitle = PetureTextStyles.label;
}

class AppSpaces {
  static const double horizontalPadding = 20.0;
  static const double sectionSpacing = 24.0;
}

// =========================================================
// 主个人主页屏幕
// =========================================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with PageTrackerMixin<ProfileScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _picker = ImagePicker();
  late final ModerationGuard _moderationGuard;

  String _userNickname = '';
  String? _avatarPath;
  String? _avatarUrl; // Supabase Storage 的 URL

  @override
  String get analyticsPageName => 'pet_profile_home';

  @override
  void initState() {
    super.initState();
    _moderationGuard = ModerationGuard(ModerationClient());
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final localAvatar = await UserAvatarHelper.getCurrentUserAvatarPath();
      if (mounted && localAvatar != null) {
        setState(() => _avatarPath = localAvatar);
      }

      // 从 Supabase 加载昵称和头像 URL
      final profile = await _supabaseService.getUserProfile();
      final avatarUrl = profile?['avatar_url'] as String?;
      if (mounted) {
        setState(() {
          _userNickname = profile?['nickname'] as String? ?? '';
          _avatarUrl = avatarUrl;
        });
      }
      final cachedAvatar = await UserAvatarHelper.ensureCachedAvatarFile(
        avatarUrl,
        _supabaseService.cacheUserAvatarFromPublicUrl,
      );
      if (mounted && cachedAvatar != null) {
        setState(() => _avatarPath = cachedAvatar);
      }
    } catch (e) {
      debugPrint('加载用户资料失败: $e');
    }
  }

  void _updateNickname(String newName) {
    setState(() {
      _userNickname = newName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PetureColors.background,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpaces.horizontalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              _buildHeader(context),
              const SizedBox(height: AppSpaces.sectionSpacing),
              PetProfileSection(onProfileUpdate: _updateNickname),
              const SizedBox(height: 120), // Bottom padding for nav bar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final String displayName = _userNickname.isEmpty ? '点击设置昵称' : _userNickname;
    final String avatarText =
        _userNickname.isEmpty ? '?' : _userNickname[0].toUpperCase();
    final bool hasAvatar =
        (_avatarPath != null && File(_avatarPath!).existsSync()) ||
            _avatarUrl != null;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _showEditNicknameDialog,
            child: Row(
              children: [
                // 头像（可点击更换）
                GestureDetector(
                  onTap: _showChangeAvatarDialog,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primaryGradientStart,
                          AppColors.primaryGradientEnd,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        key: ValueKey<String>(
                          '${_avatarUrl ?? ''}|${_avatarPath ?? ''}',
                        ),
                        radius: 32,
                        backgroundColor: AppColors.primary,
                        backgroundImage: hasAvatar &&
                                _avatarPath != null &&
                                File(_avatarPath!).existsSync()
                            ? FileImage(File(_avatarPath!))
                            : (_avatarUrl != null
                                ? NetworkImage(_avatarUrl!)
                                : null) as ImageProvider?,
                        child: !hasAvatar
                            ? Text(
                                avatarText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyles.ownerId.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '主人',
                          style: AppStyles.ownerId.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon:
              const Icon(Icons.settings_outlined, color: AppColors.primaryText),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AccountSettingsPage()),
            ).then((_) => _loadUserProfile()); // 返回时刷新资料
          },
        ),
      ],
    );
  }

  // 显示编辑昵称对话框
  Future<void> _showEditNicknameDialog() async {
    final nameController = TextEditingController(text: _userNickname);
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
                      content: Text('昵称不能为空'), backgroundColor: PetureColors.danger),
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
      try {
        final passed = await _moderationGuard.runTextGuard(
          context: context,
          scene: ModerationScene.nickname,
          content: result.trim(),
          onPassed: () async {},
        );
        if (!passed || !mounted) return;

        final success =
            await _supabaseService.upsertUserProfile(nickname: result.trim());
        if (!mounted) return;
        if (success) {
          setState(() => _userNickname = result.trim());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ 昵称修改成功'), backgroundColor: PetureColors.success),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('❌ 昵称修改失败'), backgroundColor: PetureColors.danger),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 昵称修改失败: $e'), backgroundColor: PetureColors.danger),
        );
      }
    }
  }

  // 显示更换头像对话框
  Future<void> _showChangeAvatarDialog() async {
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('取消'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _changeAvatar(result);
    }
  }

  // 更换头像
  Future<void> _changeAvatar(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (pickedFile == null) {
        return;
      }

      if (!mounted) return;
      final cropped = await AvatarImageHelper.cropAndCompressAvatar(
        context,
        pickedFile.path,
      );
      if (cropped == null) {
        return;
      }
      final avatarBytes = await cropped.readAsBytes();
      if (!mounted) return;
      final avatarPassed = await _moderationGuard.runImageGuardByBytes(
        context: context,
        scene: ModerationScene.avatar,
        bytes: avatarBytes,
        onPassed: () async {},
      );
      if (!avatarPassed || !mounted) return;

      // 先本地生效，避免网络波动导致“改了但看起来没改”
      final localFile = cropped;
      var persistedPath =
          await UserAvatarHelper.persistAvatarFile(localFile.path);
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
      if (upload.url == null && _retryableSyncError(upload.error)) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        upload = await _supabaseService.uploadUserAvatarWithError(
          fileForUpload,
        );
      }

      String? avatarUrl = upload.url;
      String? syncError = upload.error;
      var success = false;

      if (avatarUrl != null) {
        final prof = await _supabaseService.upsertUserProfileWithError(
          avatarUrl: avatarUrl,
        );
        success = prof.success;
        if (!prof.success) {
          syncError = prof.error ?? '更新头像链接到资料失败';
        }
      }

      String? localPath = persistedPath;
      if (avatarUrl != null) {
        await UserAvatarHelper.setAvatarSourceUrlBasename(
          avatarUrl.split('?').first,
        );
        // 上传文件即 persistedPath，避免 ensureCachedAvatarFile 先删本地再下载导致拍照等场景不刷新
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
          if (avatarUrl != null) _avatarUrl = avatarUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '✅ 头像更换成功'
                  : '⚠️ 头像已保存，但同步失败${syncError != null ? '：$syncError' : ''}',
            ),
            backgroundColor: success ? Colors.green : Colors.orange,
            duration: Duration(seconds: success ? 2 : 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 更换头像失败: $e'), backgroundColor: PetureColors.danger),
        );
      }
    }
  }

  bool _retryableSyncError(String? message) {
    if (message == null) return false;
    final s = message.toLowerCase();
    return s.contains('socket') ||
        s.contains('timeout') ||
        s.contains('connection') ||
        s.contains('network') ||
        s.contains('failed host') ||
        s.contains('temporar');
  }
}

// =========================================================
// 宠物档案部分
// =========================================================
class PetProfileSection extends StatefulWidget {
  final Function(String)? onProfileUpdate;

  const PetProfileSection({super.key, this.onProfileUpdate});

  @override
  State<PetProfileSection> createState() => _PetProfileSectionState();
}

class _PetProfileSectionState extends State<PetProfileSection> {
  final List<Pet> pets = [];
  final _supabaseService = SupabaseService();
  late final VoidCallback _petDataRefreshListener;

  @override
  void initState() {
    super.initState();
    _petDataRefreshListener = () {
      if (!mounted) return;
      _loadPets();
    };
    DataChangeNotifier.petDataRefreshNotifier.addListener(
      _petDataRefreshListener,
    );
    _loadPets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 检查宠物数据是否在其他页面被修改，如果是则刷新
    if (DataChangeNotifier.checkAndReset()) {
      _loadPets();
    }
  }

  @override
  void dispose() {
    DataChangeNotifier.petDataRefreshNotifier.removeListener(
      _petDataRefreshListener,
    );
    super.dispose();
  }

  Future<void> _loadPets() async {
    final List<Map<String, dynamic>> petsData =
        await _supabaseService.getAllPets();
    if (mounted) {
      setState(() {
        pets.clear();
        pets.addAll(petsData.map((petMap) => Pet.fromMap(petMap)).toList());
      });
    }
  }

  void _addPet(Pet newPet) {
    // 表单页已完成 pets 写库并返回 id 时，这里只刷新本地列表，避免重复 insert 导致主键冲突
    if (newPet.id != null && newPet.id!.trim().isNotEmpty) {
      _loadPets();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('宠物档案添加成功')));
      }
      return;
    }

    _supabaseService.insertPet(newPet.toMap()).then((generatedId) {
      if (generatedId != null) {
        final petWithId = Pet(
          id: generatedId, // generatedId 已经是 String 类型
          type: newPet.type,
          name: newPet.name,
          age: newPet.age,
          gender: newPet.gender,
          breed: newPet.breed,
          avatar: newPet.avatar,
          birthDate: newPet.birthDate,
          neuterStatus: newPet.neuterStatus,
          weight: newPet.weight,
        );

        if (mounted) {
          setState(() {
            pets.add(petWithId);
          });
          // 通知其他页面（如医疗记录页）数据已变更
          DataChangeNotifier.markPetDataChanged();
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('宠物档案添加成功')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('宠物档案添加失败，请检查网络连接')));
        }
      }
    }).catchError((error, stackTrace) {
      // 使用 debugPrint 替代 print
      debugPrint('--- 宠物档案添加失败 ---');
      debugPrint('错误详情 (Error): $error');
      debugPrint('错误类型: ${error.runtimeType}');
      debugPrint('堆栈跟踪 (Stack Trace): $stackTrace');

      // 检查是否是数据库约束错误（可能是 user_id 类型不匹配）
      final errorStr = error.toString().toLowerCase();
      String errorMessage = '添加失败，请检查终端日志';

      if (errorStr.contains('foreign key') || errorStr.contains('user_id')) {
        errorMessage = '添加失败：用户ID格式错误，请重新登录';
      } else if (errorStr.contains('duplicate key') ||
          errorStr.contains('pets_pkey') ||
          errorStr.contains('23505')) {
        errorMessage = '该宠物档案已存在，已为你刷新最新数据';
        _loadPets();
      } else if (errorStr.contains('null') || errorStr.contains('not null')) {
        errorMessage = '添加失败：缺少必要字段';
      } else if (errorStr.contains('network') ||
          errorStr.contains('connection')) {
        errorMessage = '添加失败，请检查网络连接';
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    });
  }

  void _deletePet(Pet petToDelete) {
    final targetName = petToDelete.name.trim();
    String confirmInput = '';

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canDelete = confirmInput.trim() == targetName;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: PetureColors.surfacePure,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFE05757),
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '高风险操作：删除宠物档案',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '删除后不可恢复，${petToDelete.name} 的宠物档案照数据将被永久删除。',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.secondaryText.withOpacity(0.92),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFC999)),
                      ),
                      child: Text(
                        '请输入宠物名“$targetName”以确认删除',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9A5A1F),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      onChanged: (value) {
                        confirmInput = value;
                        setDialogState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: '输入宠物名',
                        filled: true,
                        fillColor: PetureColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('我再想想'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: canDelete
                                  ? const LinearGradient(
                                      colors: [
                                        AppColors.primaryGradientStart,
                                        AppColors.primaryGradientEnd,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: canDelete ? null : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: canDelete
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.28),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ElevatedButton(
                              onPressed: canDelete
                                  ? () => Navigator.of(dialogContext).pop(true)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.white70,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                '确认删除',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((confirmed) async {
      if (confirmed != true) return;

      try {
        if (petToDelete.id != null) {
          final success = await _supabaseService.deletePet(
            petToDelete.id.toString(),
          );
          if (!success) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('删除失败，请检查网络连接')),
              );
            }
            return;
          }
          if (mounted) {
            setState(() {
              pets.removeWhere((pet) => pet.id == petToDelete.id);
            });
            DataChangeNotifier.markPetDataChanged();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${petToDelete.name} 的档案已删除')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('宠物档案', style: AppStyles.sectionTitle),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primaryGradientStart,
                    AppColors.primaryGradientEnd,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PetProfileFormPage(),
                      ),
                    );

                    if (result != null && mounted) {
                      // 从表单页面返回的数据
                      final petData = result as Map<String, dynamic>;

                      // 更新主人昵称
                      if (petData['owner_name'] != null &&
                          widget.onProfileUpdate != null) {
                        widget.onProfileUpdate!(petData['owner_name']);
                      }

                      // 计算年龄（根据出生日期）
                      String age = '未知';
                      if (petData['birth_date'] != null) {
                        final birthDate =
                            DateTime.tryParse(petData['birth_date']);
                        if (birthDate != null) {
                          final now = DateTime.now();
                          int years = now.year - birthDate.year;
                          int months = now.month - birthDate.month;
                          // Adjust for month and day
                          if (months < 0 ||
                              (months == 0 && now.day < birthDate.day)) {
                            years--;
                            months += 12;
                          }
                          if (now.day < birthDate.day && months > 0) {
                            months--;
                          }
                          age = '$years岁$months个月';
                        }
                      }

                      // 创建Pet对象，包含所有表单字段
                      final newPet = Pet(
                        id: petData['id']?.toString(),
                        type: petData['type'] ?? '狗', // 宠物类型
                        name: petData['name'] ?? '',
                        age: age, // 根据出生日期计算
                        gender: petData['gender'] ?? '哥哥',
                        breed: petData['breed'] ?? '', // 品种
                        avatar: petData['avatar'], // 头像路径
                        birthDate: petData['birth_date']
                            ?.toString()
                            .split('T')[0], // 出生日期（只保留年月日）
                        neuterStatus: petData['neuter_status'], // 绝育状态
                        weight: petData['weight'] != null
                            ? (petData['weight'] as num).toDouble()
                            : null, // 体重
                        ownerNickname: petData['ownerNickname'],
                        useCustomNickname:
                            petData['useCustomNickname'] ?? false,
                      );

                      _addPet(newPet);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: const [
                        Icon(Icons.add, size: 18, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          '添加宠物',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        pets.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: Text('暂无宠物档案', style: AppStyles.petDetails),
                ),
              )
            // 🎨 美学升级：交错入场动画
            : AnimationLimiter(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: pets.length,
                  itemBuilder: (context, index) {
                    final pet = pets[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: Dismissible(
                            key: ValueKey(pet.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              _deletePet(pet);
                              return false;
                            },
                            child: PetProfileCard(
                              pet: pet,
                              onView: () async {
                                await Navigator.push<Pet>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PetProfileDetailsPage(pet: pet),
                                  ),
                                );
                                _loadPets();
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                ),
              ),
      ],
    );
  }
}

// =========================================================
// 单个宠物档案卡片 - 美学升级版
// =========================================================
class PetProfileCard extends StatefulWidget {
  final Pet pet;
  final VoidCallback onView;

  const PetProfileCard({super.key, required this.pet, required this.onView});

  @override
  State<PetProfileCard> createState() => _PetProfileCardState();
}

class _PetProfileCardState extends State<PetProfileCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // 🎨 美学升级：点击动效控制器
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98, // 轻微缩小2%
    ).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
    widget.onView();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  String _formatAgeWithSpaces(String age) {
    return age
        .replaceAllMapped(RegExp(r'(\d+)岁'), (m) => '${m.group(1)} 岁 ')
        .replaceAllMapped(RegExp(r'(\d+)个月'), (m) => '${m.group(1)} 个月')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.6), width: 1),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.8),
                        Colors.white.withOpacity(0.4),
                      ],
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTapDown: _onTapDown,
                      onTapUp: _onTapUp,
                      onTapCancel: _onTapCancel,
                      borderRadius: BorderRadius.circular(24),
                      splashColor: AppColors.primary.withOpacity(0.1),
                      highlightColor: AppColors.primary.withOpacity(0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // 宠物头像
                            Hero(
                              // Home 使用 IndexedStack，会导致不同页面的 Hero 同时存在于同一路由树
                              // 这里加页面前缀，保证 tag 在同一路由树内唯一，避免 Hero tag 冲突崩溃
                              tag: 'profile_pet_avatar_${widget.pet.id}',
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: widget.pet.avatar != null &&
                                          widget.pet.avatar!.isNotEmpty
                                      ? (widget.pet.avatar!
                                                  .startsWith('http://') ||
                                              widget.pet.avatar!
                                                  .startsWith('https://')
                                          ? CachedNetworkImage(
                                              imageUrl: widget.pet.avatar!,
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                              errorWidget:
                                                  (context, url, error) {
                                                return Container(
                                                  color: AppColors
                                                              .petTypeColors[
                                                          widget.pet.type] ??
                                                      AppColors
                                                          .petTypeColors['其他'],
                                                  child: Icon(
                                                    Icons.pets,
                                                    color: Colors.white
                                                        .withOpacity(0.8),
                                                    size: 30,
                                                  ),
                                                );
                                              },
                                            )
                                          : Image.file(
                                              File(widget.pet.avatar!),
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  color: AppColors
                                                              .petTypeColors[
                                                          widget.pet.type] ??
                                                      AppColors
                                                          .petTypeColors['其他'],
                                                  child: Icon(
                                                    Icons.pets,
                                                    color: Colors.white
                                                        .withOpacity(0.8),
                                                    size: 30,
                                                  ),
                                                );
                                              },
                                            ))
                                      : Container(
                                          color: AppColors.petTypeColors[
                                                  widget.pet.type] ??
                                              AppColors.petTypeColors['其他'],
                                          child: Icon(
                                            Icons.pets,
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            size: 30,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 宠物信息
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.pet.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        _formatAgeWithSpaces(widget.pet.age),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.secondaryText
                                              .withOpacity(0.8),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Container(
                                          width: 1,
                                          height: 12,
                                          color: AppColors.secondaryText
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      Text(
                                        widget.pet.gender,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.secondaryText
                                              .withOpacity(0.8),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Container(
                                          width: 1,
                                          height: 12,
                                          color: AppColors.secondaryText
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          widget.pet.breed,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.secondaryText
                                                .withOpacity(0.8),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // 箭头图标
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.secondaryText,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// =========================================================
// 宠物档案详情页 - 全新美学设计
// =========================================================
class PetProfileDetailsPage extends StatefulWidget {
  final Pet pet;

  const PetProfileDetailsPage({super.key, required this.pet});

  @override
  State<PetProfileDetailsPage> createState() => _PetProfileDetailsPageState();
}

class _PetProfileDetailsPageState extends State<PetProfileDetailsPage>
    with
        SingleTickerProviderStateMixin,
        PageTrackerMixin<PetProfileDetailsPage> {
  late Pet _currentPet;
  final _supabaseService = SupabaseService();
  bool _isSyncingProfile = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  String get analyticsPageName => 'pet_profile_detail';

  @override
  void initState() {
    super.initState();
    _currentPet = widget.pet;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 获取宠物主题色
  Color get _petThemeColor {
    return AppColors.petTypeColors[_currentPet.type] ??
        AppColors.petTypeColors['其他']!;
  }

  // 格式化年龄：在数字和中文之间添加空格
  String _formatAgeWithSpaces(String age) {
    // 将 "3岁1个月" 转换为 "3 岁 1 个月"
    return age
        .replaceAllMapped(RegExp(r'(\d+)岁'), (match) => '${match.group(1)} 岁 ')
        .replaceAllMapped(RegExp(r'(\d+)个月'), (match) => '${match.group(1)} 个月')
        .trim();
  }

  // 构建带有图标的信息项
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
    bool isPlaceholder = false,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 图标容器
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withOpacity(0.22),
                  accentColor.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: accentColor.withOpacity(0.72),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // 标签和值
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryText.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isPlaceholder ? Colors.grey : AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.secondaryText.withOpacity(0.4),
            ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: content,
      ),
    );
  }

  // 构建信息分组卡片
  Widget _buildInfoGroup({
    required String title,
    required List<Widget> children,
    required Animation<double> animation,
    int delay = 0,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final delayedValue =
            ((animation.value * 100) - delay).clamp(0.0, 100.0) / 100;
        return Opacity(
          opacity: delayedValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - delayedValue)),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPetAvatar() {
    final avatar = _currentPet.avatar;
    Widget avatarWidget;

    if (avatar != null && avatar.isNotEmpty) {
      if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
        avatarWidget = Hero(
          tag: 'pet_avatar_${_currentPet.id}',
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: avatar,
              width: 124,
              height: 124,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) =>
                  _buildPetAvatarPlaceholder(),
            ),
          ),
        );
      } else {
        final file = File(avatar);
        if (file.existsSync()) {
          avatarWidget = Hero(
            tag: 'pet_avatar_${_currentPet.id}',
            child: ClipOval(
              child: Image.file(
                file,
                width: 124,
                height: 124,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPetAvatarPlaceholder(),
              ),
            ),
          );
        } else {
          avatarWidget = _buildPetAvatarPlaceholder();
        }
      }
    } else {
      avatarWidget = _buildPetAvatarPlaceholder();
    }

    // 装饰性头像容器
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _petThemeColor.withOpacity(0.8),
            AppColors.primaryGradientEnd.withOpacity(0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _petThemeColor.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: avatarWidget,
      ),
    );
  }

  Widget _buildPetAvatarPlaceholder() {
    return Container(
      width: 124,
      height: 124,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _petThemeColor.withOpacity(0.6),
            _petThemeColor.withOpacity(0.3),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.pets,
        color: Colors.white.withOpacity(0.9),
        size: 50,
      ),
    );
  }

  // 全新的生活照展示组件
  Widget _buildLifePhotoCard() {
    final life = _currentPet.lifePhoto;
    final hasLifePhoto = life != null && life.isNotEmpty;
    final heroTag = 'life_photo_hero_${_currentPet.id ?? 'unknown'}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _petThemeColor.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: hasLifePhoto
                ? () => _openLifePhotoPreview(life, heroTag)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.pink[200]!.withOpacity(0.4),
                              Colors.pink[100]!.withOpacity(0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.favorite,
                          color: Colors.pink[400],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '生活照',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasLifePhoto ? '点击查看大图' : '记录美好瞬间',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryText.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasLifePhoto)
                        Icon(
                          Icons.fullscreen_rounded,
                          color: AppColors.secondaryText.withOpacity(0.4),
                          size: 24,
                        ),
                    ],
                  ),
                ),
                // 图片展示区域
                if (hasLifePhoto)
                  Hero(
                    tag: heroTag,
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: life.startsWith('http://') ||
                                life.startsWith('https://')
                            ? CachedNetworkImage(
                                imageUrl: life,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    _buildLifePhotoPlaceholder(),
                              )
                            : Image.file(
                                File(life),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildLifePhotoPlaceholder(),
                              ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 120,
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey[200]!,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Colors.grey[400],
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '请到编辑页面添加生活照',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLifePhotoPlaceholder() {
    return Container(
      color: const Color(0xFFF2F3F7),
      child: const Icon(Icons.broken_image, color: Color(0xFFB8BEC9), size: 40),
    );
  }

  void _openLifePhotoPreview(String source, String heroTag) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => FullscreenLifePhotoPage(
          imageSource: source,
          heroTag: heroTag,
        ),
      ),
    );
  }

  Future<void> _openEditPage() async {
    final initialData = {
      'id': _currentPet.id,
      'name': _currentPet.name,
      'species': _currentPet.breed,
      'birthDate': _currentPet.birthDate,
      'gender': _currentPet.gender,
      'neuterStatus': _currentPet.neuterStatus,
      'weight': _currentPet.weight,
      'avatar': _currentPet.avatar,
      'lifePhoto': _currentPet.lifePhoto,
      'type': _currentPet.type,
      'ownerNickname': _currentPet.ownerNickname,
      'useCustomNickname': _currentPet.useCustomNickname,
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PetProfileFormPage(initialData: initialData),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    // 计算年龄
    String age = '未知';
    if (result['birth_date'] != null) {
      try {
        final birthDate = DateTime.parse(result['birth_date']);
        final now = DateTime.now();
        int years = now.year - birthDate.year;
        int months = now.month - birthDate.month;
        if (months < 0) {
          years--;
          months += 12;
        }
        age = '$years岁$months个月';
      } catch (e) {
        debugPrint('Error calculating age: $e');
        age = '未知';
      }
    }

    final updatedPet = Pet(
      id: _currentPet.id,
      name: result['name'],
      type: result['type'],
      breed: result['breed'],
      birthDate: result['birth_date'],
      gender: result['gender'],
      neuterStatus: result['neuter_status'],
      weight: result['weight'],
      avatar: result['avatar'],
      lifePhoto: result['life_photo'] ?? result['lifePhoto'],
      age: age,
      ownerNickname: result['ownerNickname'],
      useCustomNickname: result['useCustomNickname'] ?? false,
    );

    setState(() => _isSyncingProfile = true);
    try {
      final success = await _supabaseService.updatePet(updatedPet.toMap());
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新失败，请检查网络连接')),
          );
        }
        return;
      }
      setState(() {
        _currentPet = updatedPet;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('档案已更新')),
        );
      }
      DataChangeNotifier.markPetDataChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新失败，请重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        // 🎨 全新设计：现代柔和渐变背景
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF0F4F8), // 浅蓝灰，干净清爽
              Colors.white,
              Color(0xFFFAFBFC),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Text(
                  '${_currentPet.name} 的档案',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.primaryText,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFD79466),
                          Color(0xFFE5A65E),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _openEditPage,
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 5),
                              Text(
                                '编辑',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      // 宠物头像区域
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildPetAvatar(),
                      ),
                      const SizedBox(height: 14),
                      // 宠物名字
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          _currentPet.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 品种标签
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _petThemeColor.withOpacity(0.4),
                                _petThemeColor.withOpacity(0.18),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _currentPet.breed,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // 基本信息分组
                      _buildInfoGroup(
                        title: '基本信息',
                        animation: _fadeAnimation,
                        delay: 10,
                        children: [
                          _buildInfoItem(
                            icon: Icons.pets_rounded,
                            label: '宠物类型',
                            value: _currentPet.type,
                            accentColor: Colors.orange[300]!,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoItem(
                            icon: Icons.category_rounded,
                            label: '品种',
                            value: _currentPet.breed,
                            accentColor: Colors.blue[300]!,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoItem(
                            icon: _currentPet.gender == '妹妹'
                                ? Icons.female_rounded
                                : Icons.male_rounded,
                            label: '性别',
                            value: _currentPet.gender,
                            accentColor: _currentPet.gender == '妹妹'
                                ? Colors.pink[300]!
                                : Colors.blue[300]!,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 身体特征分组
                      _buildInfoGroup(
                        title: '身体特征',
                        animation: _fadeAnimation,
                        delay: 25,
                        children: [
                          if (_currentPet.birthDate != null)
                            _buildInfoItem(
                              icon: Icons.calendar_today_rounded,
                              label: '出生日期',
                              value: _currentPet.birthDate!.split('T')[0],
                              accentColor: Colors.teal[300]!,
                            ),
                          if (_currentPet.birthDate != null)
                            const SizedBox(height: 8),
                          _buildInfoItem(
                            icon: Icons.cake_rounded,
                            label: '年龄',
                            value: _formatAgeWithSpaces(_currentPet.age),
                            accentColor: Colors.purple[300]!,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoItem(
                            icon: Icons.scale_rounded,
                            label: '体重',
                            value: _currentPet.weight != null
                                ? '${_currentPet.weight!.toStringAsFixed(1)} kg'
                                : '未填写',
                            accentColor: Colors.green[300]!,
                            isPlaceholder: _currentPet.weight == null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 其他信息分组
                      _buildInfoGroup(
                        title: '其他信息',
                        animation: _fadeAnimation,
                        delay: 40,
                        children: [
                          if (_currentPet.neuterStatus != null)
                            _buildInfoItem(
                              icon: Icons.health_and_safety_rounded,
                              label: '绝育状态',
                              value: _currentPet.neuterStatus!,
                              accentColor: Colors.red[300]!,
                            ),
                          if (_currentPet.neuterStatus != null)
                            const SizedBox(height: 8),
                          _buildInfoItem(
                            icon: Icons.person_outline_rounded,
                            label: '我的称呼',
                            value: _currentPet.ownerNickname != null &&
                                    _currentPet.ownerNickname!.isNotEmpty
                                ? _currentPet.ownerNickname!
                                : '主人',
                            accentColor: Colors.indigo[300]!,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 生活照卡片
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildLifePhotoCard(),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
            // 保存中遮罩
            if (_isSyncingProfile)
              Positioned.fill(
                child: AbsorbPointer(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      color: Colors.black.withOpacity(0.35),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '保存中…',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
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

class FullscreenLifePhotoPage extends StatefulWidget {
  final String imageSource;
  final String heroTag;

  const FullscreenLifePhotoPage({
    super.key,
    required this.imageSource,
    required this.heroTag,
  });

  @override
  State<FullscreenLifePhotoPage> createState() =>
      _FullscreenLifePhotoPageState();
}

class _FullscreenLifePhotoPageState extends State<FullscreenLifePhotoPage>
    with SingleTickerProviderStateMixin {
  double dragOffsetY = 0;
  late AnimationController _controller;
  late Animation<double> _reboundAnimation;

  static const double dismissThreshold = 150;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runReboundAnimation() {
    _reboundAnimation =
        Tween<double>(begin: dragOffsetY, end: 0).animate(_controller)
          ..addListener(() {
            setState(() {
              dragOffsetY = _reboundAnimation.value;
            });
          });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dragPercent = (dragOffsetY / screenHeight).clamp(0.0, 1.0);
    final scale = 1.0 - dragPercent * 0.4;
    final bgOpacity = (1.0 - dragPercent).clamp(0.0, 1.0);
    final isNetwork = widget.imageSource.startsWith('http://') ||
        widget.imageSource.startsWith('https://');

    final imageWidget = isNetwork
        ? CachedNetworkImage(
            imageUrl: widget.imageSource,
            fit: BoxFit.contain,
            errorWidget: (context, url, error) => const Icon(
              Icons.broken_image,
              color: Colors.white54,
              size: 56,
            ),
          )
        : Image.file(
            File(widget.imageSource),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.broken_image,
              color: Colors.white54,
              size: 56,
            ),
          );

    return Stack(
      children: [
        Opacity(
          opacity: bgOpacity,
          child: Container(color: Colors.black),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            onVerticalDragUpdate: (details) {
              setState(() {
                dragOffsetY += details.delta.dy;
                if (dragOffsetY < 0) dragOffsetY = 0;
              });
            },
            onVerticalDragEnd: (_) {
              if (dragOffsetY > dismissThreshold) {
                Navigator.pop(context);
              } else {
                _runReboundAnimation();
              }
            },
            child: Transform.translate(
              offset: Offset(0, dragOffsetY),
              child: Transform.scale(
                scale: scale,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: Hero(
                      tag: widget.heroTag,
                      child: imageWidget,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =========================================================
// 编辑宠物档案对话框
// =========================================================
class EditPetDialog extends StatefulWidget {
  final Pet pet;

  const EditPetDialog({super.key, required this.pet});

  @override
  State<EditPetDialog> createState() => _EditPetDialogState();
}

class _EditPetDialogState extends State<EditPetDialog> {
  late final TextEditingController _nameController;
  late String _selectedGender;
  late String _selectedPetType;
  late String _selectedBreed;
  late int _selectedYears;
  late int _selectedMonths;

  final Map<String, List<String>> _petBreeds = {
    '狗': ['拉布拉多', '金毛寻回犬', '法国斗牛犬', '贵宾犬', '比熊', '柯基', '柴犬', '哈士奇'],
    '猫': ['英国短毛猫', '美国短毛猫', '布偶猫', '暹罗猫', '波斯猫', '缅因猫', '苏格兰折耳猫'],
    '兔': ['垂耳兔', '荷兰兔', '安哥拉兔', '侏儒兔', '新西兰兔'],
    '仓鼠': ['金丝熊', '三线仓鼠', '银狐', '布丁', '奶茶'],
    '其他': ['未知品种'],
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pet.name);
    _selectedGender = widget.pet.gender;
    _selectedPetType = widget.pet.type;
    _selectedBreed = widget.pet.breed;
    _parseAge(widget.pet.age);
  }

  void _parseAge(String age) {
    _selectedYears = 0;
    _selectedMonths = 0;
    final yearsMatch = RegExp(r'(\d+)岁').firstMatch(age);
    if (yearsMatch != null) {
      _selectedYears = int.tryParse(yearsMatch.group(1) ?? '0') ?? 0;
    }
    final monthsMatch = RegExp(r'(\d+)个月').firstMatch(age);
    if (monthsMatch != null) {
      _selectedMonths = int.tryParse(monthsMatch.group(1) ?? '0') ?? 0;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改宠物档案'),
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '昵称'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: '性别'),
              value: _selectedGender,
              items: const ['哥哥', '妹妹'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedGender = newValue!;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: '年龄(岁)'),
                    value: _selectedYears,
                    items: List.generate(20, (index) => index).map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      setState(() {
                        _selectedYears = newValue!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: '年龄(月)'),
                    value: _selectedMonths,
                    items: List.generate(12, (index) => index).map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      setState(() {
                        _selectedMonths = newValue!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: '宠物类型'),
              value: _selectedPetType,
              items: _petBreeds.keys.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedPetType = newValue!;
                  if (!_petBreeds[newValue]!.contains(_selectedBreed)) {
                    _selectedBreed = _petBreeds[newValue]!.first;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: '品种'),
              value: _selectedBreed,
              items: _petBreeds[_selectedPetType]!.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedBreed = newValue!;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              final String ageString = '$_selectedYears岁$_selectedMonths个月';

              Navigator.of(context).pop(
                Pet(
                  id: widget.pet.id,
                  type: _selectedPetType,
                  name: _nameController.text,
                  age: ageString,
                  gender: _selectedGender,
                  breed: _selectedBreed,
                ),
              );
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
