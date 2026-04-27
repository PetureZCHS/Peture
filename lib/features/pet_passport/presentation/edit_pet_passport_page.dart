import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../shared/models/pet.dart';
import '../../../shared/models/pet_passport.dart';
import '../../../services/supabase_service.dart';

/// 编辑宠物身份证页面
class EditPetPassportPage extends StatefulWidget {
  final Pet pet;
  final PetPassport? passport;

  /// 与账号昵称同步后的展示用主人名（占位「铲屎官」等会替换为此值），用于表单初始文案。
  final String? suggestedOwnerDisplay;

  const EditPetPassportPage({
    super.key,
    required this.pet,
    this.passport,
    this.suggestedOwnerDisplay,
  });

  @override
  State<EditPetPassportPage> createState() => _EditPetPassportPageState();
}

class _EditPetPassportPageState extends State<EditPetPassportPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ownerNameController;
  late TextEditingController _bioController;
  final ImagePicker _picker = ImagePicker();

  String? _selectedMbti;
  DateTime? _adoptionDate;
  List<String> _selectedTags = [];
  String? _photoPath;
  File? _photoFile;

  @override
  void initState() {
    super.initState();
    _ownerNameController = TextEditingController(
      text: widget.suggestedOwnerDisplay ??
          widget.passport?.ownerName ??
          '宠物家长',
    );
    _bioController = TextEditingController(text: widget.passport?.bio ?? '');
    _selectedMbti = widget.passport?.mbtiType;
    _adoptionDate = widget.passport?.adoptionDate;
    _selectedTags = List.from(widget.passport?.interestTags ?? []);

    // 优先使用电子档案头像，如果没有则使用宠物档案头像（仅在电子档案没设置前保存）
    _photoPath = widget.passport?.photoPath;
    if (_photoPath == null || _photoPath!.isEmpty) {
      // 电子档案没有头像时，使用宠物档案的头像作为初始值
      _photoPath = widget.pet.avatar;
    }

    // 如果有照片路径，加载照片
    if (_photoPath != null && _photoPath!.isNotEmpty) {
      _photoFile = File(_photoPath!);
    }
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E1E1E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '编辑身份证',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              '保存',
              style: TextStyle(
                color: Color(0xFF5A8EFA),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 宠物照片
            _buildSectionTitle('宠物照片'),
            const SizedBox(height: 12),
            _buildPhotoSelector(),

            const SizedBox(height: 32),

            // 基本信息
            _buildSectionTitle('基本信息'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _ownerNameController,
              label: '主人姓名',
              hint: '默认与账号昵称一致，可改成展示用姓名',
              icon: Icons.person,
            ),
            const SizedBox(height: 16),
            _buildDatePicker(),

            const SizedBox(height: 32),

            // MBTI类型选择
            _buildSectionTitle('性格类型 (MBTI)'),
            const SizedBox(height: 12),
            _buildMbtiSelector(),

            const SizedBox(height: 32),

            // 兴趣标签
            _buildSectionTitle('兴趣标签'),
            const SizedBox(height: 12),
            _buildTagSelector(),

            const SizedBox(height: 32),

            // 个人简介
            _buildSectionTitle('个人简介'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _bioController,
              label: '介绍一下你的宠物',
              icon: Icons.notes,
              maxLines: 4,
            ),

            const SizedBox(height: 32),

            // 成就徽章（只读展示）
            _buildSectionTitle('成就徽章'),
            const SizedBox(height: 8),
            Text(
              '成就徽章由系统自动解锁',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            _buildAchievementDisplay(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E1E1E),
      ),
    );
  }

  Widget _buildPhotoSelector() {
    return Container(
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
      child: Column(
        children: [
          // 照片预览区域
          GestureDetector(
            onTap: _showPhotoOptions,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: _photoFile != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: Image.file(_photoFile!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击添加宠物照片',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // 操作按钮区域
          if (_photoFile != null)
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showPhotoOptions,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('更换照片'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5A8EFA),
                        side: const BorderSide(color: Color(0xFF5A8EFA)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _removePhoto,
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('删除照片'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 显示照片选择选项
  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '选择照片来源',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A8EFA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF5A8EFA),
                    ),
                  ),
                  title: const Text('拍照'),
                  subtitle: const Text('使用相机拍摄新照片'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B77FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.photo_library,
                      color: Color(0xFF8B77FF),
                    ),
                  ),
                  title: const Text('从相册选择'),
                  subtitle: const Text('选择已有的照片'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 选择图片
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _photoFile = File(image.path);
          _photoPath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择照片失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 删除照片
  void _removePhoto() {
    setState(() {
      _photoFile = null;
      _photoPath = null;
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? hint,
  }) {
    return Container(
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
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF5A8EFA)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
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
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: Color(0xFF5A8EFA)),
        title: const Text('领养日期'),
        subtitle: Text(
          _adoptionDate != null
              ? '${_adoptionDate!.year}-${_adoptionDate!.month.toString().padLeft(2, '0')}-${_adoptionDate!.day.toString().padLeft(2, '0')}'
              : '请选择日期',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _adoptionDate ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (date != null) {
            setState(() => _adoptionDate = date);
          }
        },
      ),
    );
  }

  Widget _buildMbtiSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedMbti != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _selectedMbti!,
                      style: const TextStyle(
                        color: Color(0xFF667eea),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          MBTITypes.getTypeInfo(_selectedMbti!)!['name']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          MBTITypes.getTypeInfo(
                            _selectedMbti!,
                          )!['description']!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton.icon(
            onPressed: () => _showMbtiPicker(),
            icon: const Icon(Icons.psychology),
            label: Text(_selectedMbti == null ? '选择MBTI类型' : '更改MBTI类型'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A8EFA),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '已选择 ${_selectedTags.length} 个标签',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: InterestTags.allTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? const Color(0xFF5A8EFA) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF5A8EFA)
                          : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementDisplay() {
    final achievements = widget.passport?.achievements ?? [];

    if (achievements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.emoji_events, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 8),
              Text('还没有解锁任何成就', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF5A8EFA), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5A8EFA).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getAchievementIcon(achievement.iconName),
                color: const Color(0xFF5A8EFA),
                size: 32,
              ),
              const SizedBox(height: 6),
              Text(
                achievement.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMbtiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '选择MBTI类型',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: MBTITypes.types.length,
                  itemBuilder: (context, index) {
                    final entry = MBTITypes.types.entries.elementAt(index);
                    final type = entry.key;
                    final info = entry.value;

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          type,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        info['name']!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        info['description']!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: _selectedMbti == type
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF5A8EFA),
                            )
                          : null,
                      onTap: () {
                        setState(() => _selectedMbti = type);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getAchievementIcon(String iconName) {
    switch (iconName) {
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'vaccines':
        return Icons.vaccines;
      case 'groups':
        return Icons.groups;
      case 'book':
        return Icons.book;
      case 'military_tech':
        return Icons.military_tech;
      case 'celebration':
        return Icons.celebration;
      case 'restaurant':
        return Icons.restaurant;
      case 'sports_score':
        return Icons.sports_score;
      default:
        return Icons.emoji_events;
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      try {
        // 创建更新后的护照对象
        final updatedPassport = PetPassport(
          id: widget.passport?.id,
          petId: widget.pet.id!,
          photoPath: _photoPath,
          ownerName: _ownerNameController.text,
          adoptionDate: _adoptionDate,
          mbtiType: _selectedMbti,
          mbtiDescription: _selectedMbti != null
              ? MBTITypes.getTypeInfo(_selectedMbti!)!['description']
              : null,
          interestTags: _selectedTags,
          achievements: widget.passport?.achievements ?? [],
          bio: _bioController.text,
          friendCount: widget.passport?.friendCount ?? 0,
        );

        // 保存到数据库
        final supabaseService = SupabaseService();
        final result =
            await supabaseService.upsertPetPassport(updatedPassport.toMap());

        if (result == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('保存失败，请检查网络连接'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // 同步头像到宠物表：以电子档案中的头像为准
        if (_photoPath != null &&
            _photoPath!.isNotEmpty &&
            widget.pet.id != null) {
          try {
            final petData = widget.pet.toMap();
            petData['avatar'] = _photoPath; // 使用电子档案的头像路径
            await supabaseService.updatePet(petData);
          } catch (e) {
            debugPrint('同步头像到宠物表失败: $e');
            // 不影响护照保存，只记录错误
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('保存成功'),
              backgroundColor: Color(0xFF5A8EFA),
            ),
          );
          // 返回更新后的护照对象
          Navigator.pop(context, updatedPassport);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
