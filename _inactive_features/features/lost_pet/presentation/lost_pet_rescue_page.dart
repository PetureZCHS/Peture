import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:math' as math; // Added import
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/ui_helpers.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/pet.dart';
import '../../community/presentation/publish_post_page.dart';
import 'lost_pet_generator.dart';

class LostPetRescuePage extends StatefulWidget {
  const LostPetRescuePage({super.key});

  @override
  State<LostPetRescuePage> createState() => _LostPetRescuePageState();
}

class _LostPetRescuePageState extends State<LostPetRescuePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _posterKey = GlobalKey();
  late TabController _tabController;

  // Services
  final _supabaseService = SupabaseService();

  // Pet selection
  List<Pet> _pets = [];
  Pet? _selectedPet;
  bool _isLoadingPets = false;

  // Date time picker
  DateTime? _lostDateTime;
  bool _includeTime = true;

  // Controllers
  final _nameController = TextEditingController();
  final _speciesController = TextEditingController(text: '猫'); // Default to Cat
  final _descriptionController = TextEditingController();
  final _timeController = TextEditingController();
  final _locationController = TextEditingController();
  final _rewardController = TextEditingController();
  final _contactController = TextEditingController();

  LostPetMaterials? _generatedMaterials;
  File? _selectedImage;
  bool _isGenerating = false;
  bool _isA4Ratio = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPets();
  }

  Future<void> _loadPets() async {
    if (!mounted) return;
    setState(() => _isLoadingPets = true);
    try {
      final petsData = await _supabaseService.getAllPets();
      if (mounted) {
        setState(() {
          _pets = petsData.map((data) => Pet.fromMap(data)).toList();
          _isLoadingPets = false;
        });
      }
    } catch (e) {
      debugPrint('加载宠物列表失败: $e');
      if (mounted) {
        setState(() => _isLoadingPets = false);
      }
    }
  }

  void _onPetSelected(Pet? pet) {
    setState(() {
      _selectedPet = pet;
      if (pet != null) {
        _nameController.text = pet.name;
        _speciesController.text = pet.type;
        // 自动填充外貌特征：品种、性别、年龄等
        final descriptionParts = <String>[];
        if (pet.breed.isNotEmpty) descriptionParts.add(pet.breed);
        if (pet.gender.isNotEmpty) descriptionParts.add(pet.gender);
        if (pet.age.isNotEmpty) descriptionParts.add('${pet.age}岁');
        if (pet.neuterStatus != null) descriptionParts.add(pet.neuterStatus!);
        _descriptionController.text = descriptionParts.join('，');

        // 如果有头像，可以自动选择
        if (pet.avatar != null && File(pet.avatar!).existsSync()) {
          _selectedImage = File(pet.avatar!);
        }
      }
    });
  }

  Future<void> _selectLostDateTime() async {
    // 先选择日期
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _lostDateTime ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (pickedDate == null) return;

    // 如果包含时间，再选择时间
    if (_includeTime) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _lostDateTime != null
            ? TimeOfDay.fromDateTime(_lostDateTime!)
            : TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _lostDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _updateTimeController();
        });
      } else {
        // 用户取消了时间选择，只使用日期
        setState(() {
          _lostDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
          );
          _updateTimeController();
        });
      }
    } else {
      setState(() {
        _lostDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
        );
        _updateTimeController();
      });
    }
  }

  void _updateTimeController() {
    if (_lostDateTime == null) {
      _timeController.clear();
      return;
    }

    if (_includeTime) {
      _timeController.text =
          DateFormat('yyyy年MM月dd日 HH:mm', 'zh_CN').format(_lostDateTime!);
    } else {
      _timeController.text =
          DateFormat('yyyy年MM月dd日', 'zh_CN').format(_lostDateTime!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _speciesController.dispose();
    _descriptionController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    _rewardController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _captureAndShare(bool isShare) async {
    setState(() => _isGenerating = true);
    try {
      // Wait for any potential layout updates
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Capture Image
      final boundary = _posterKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('无法获取渲染边界');
      }

      // Use a slightly lower pixel ratio to avoid memory issues, but still high quality
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('图片数据为空');
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();

      // 2. Save to temporary file
      final directory = await getTemporaryDirectory();
      final imagePath =
          '${directory.path}/lost_pet_poster_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(pngBytes);

      // 3. Share or Save
      if (isShare) {
        if (!mounted) return;
        // Calculate share position origin for iPad
        final box = context.findRenderObject() as RenderBox?;
        final shareOrigin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : const Rect.fromLTWH(0, 0, 100, 100); // Fallback

        await Share.shareXFiles(
          [XFile(imagePath)],
          text: '紧急寻宠！请大家帮忙扩散！ #Peture寻宠救援',
          sharePositionOrigin: shareOrigin,
        );
      } else {
        // Save to Gallery using 'gal' package
        await Gal.putImage(imagePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 已保存到相册'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error generating image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _publishToCommunity() async {
    setState(() => _isGenerating = true);
    try {
      await Future.delayed(const Duration(milliseconds: 50));

      final boundary = _posterKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('无法获取渲染边界');

      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('图片数据为空');

      final pngBytes = byteData.buffer.asUint8List();
      final content =
          '#寻宠启事 ${_generatedMaterials!.posterHeadline}\n\n${_generatedMaterials!.xiaohongshuText}';

      if (mounted) {
        setState(() => _isGenerating = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PublishPostPage(
              initialImageBytes: pngBytes,
              initialContent: content,
              sourceType: 'lost_pet',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error publishing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('发布失败: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
        setState(() => _isGenerating = false);
      }
    }
  }

  void _generate() {
    if (_formKey.currentState!.validate()) {
      final info = LostPetInfo(
        name: _nameController.text,
        species: _speciesController.text,
        description: _descriptionController.text,
        lostTime: _timeController.text,
        lostLocation: _locationController.text,
        rewardAmount: _rewardController.text,
        contactInfo: _contactController.text,
      );

      setState(() {
        _generatedMaterials = LostPetGenerator.generate(info);
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已复制到剪贴板'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.textDark,
      ),
    );
  }

  void _shareText(String text) {
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('寻宠救援'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: AppColors.textDark),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withOpacity(0.5)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient Blob
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF512F).withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              physics: const BouncingScrollPhysics(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInBack,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, 0.05), end: Offset.zero)
                          .animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _generatedMaterials == null
                    ? _buildForm()
                    : _buildResults(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return AnimationLimiter(
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: AnimationConfiguration.toStaggeredList(
          duration: const Duration(milliseconds: 375),
          childAnimationBuilder: (widget) => SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(
              child: widget,
            ),
          ),
          children: [
            const SizedBox(height: 10),
            _buildHeaderCard(),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('基本信息',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                    const SizedBox(height: 20),
                    _buildPetSelector(),
                    _buildDateTimePicker(),
                    _buildModernTextField(
                        label: '走失地点',
                        controller: _locationController,
                        icon: Icons.location_on_rounded,
                        hint: '例如：xx小区xx号楼'),
                    _buildModernTextField(
                        label: '外貌特征',
                        controller: _descriptionController,
                        icon: Icons.face_rounded,
                        hint: '例如：橘猫，左耳有缺口...',
                        maxLines: 3),
                    _buildModernTextField(
                        label: '联系方式',
                        controller: _contactController,
                        icon: Icons.phone_rounded,
                        hint: '电话号码',
                        keyboardType: TextInputType.phone),
                    _buildModernTextField(
                        label: '悬赏金额 (选填)',
                        controller: _rewardController,
                        icon: Icons.attach_money_rounded,
                        hint: '例如：1000',
                        isRequired: false,
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 30),
                    _buildGenerateButton(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFF512F), Color(0xFFDD2476)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFF512F).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.campaign_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('72小时黄金救援',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('根据物种习性生成专业搜救方案与多平台文案',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetSelector() {
    if (_isLoadingPets) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_pets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '请先在宠物档案中添加宠物',
                style: TextStyle(color: Colors.orange[700], fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择宠物',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Pet>(
          value: _selectedPet,
          isDense: true,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: '请选择走失的宠物',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon:
                Icon(Icons.pets_rounded, color: Colors.grey[400], size: 20),
            filled: true,
            fillColor: Colors.grey[50],
            // 选中态只需要单行展示，避免过高导致溢出
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFFFF512F), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red.shade200, width: 1),
            ),
          ),
          items: _pets.map((pet) {
            return DropdownMenuItem<Pet>(
              value: pet,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPetAvatar(pet.avatar, size: 32),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pet.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        // 下拉列表里可以显示类型/品种；但“选中后”的输入框里不显示灰字，避免溢出
                        if (_selectedPet?.id != pet.id)
                          Text(
                            '${pet.type} · ${pet.breed}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          // 选中后的显示：仅显示头像 + 名字（单行），避免 “Bottom Overflowed by Pixels”
          selectedItemBuilder: (context) {
            return _pets.map((pet) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPetAvatar(pet.avatar, size: 32),
                  const SizedBox(width: 12),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      pet.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              );
            }).toList();
          },
          onChanged: _onPetSelected,
          validator: (value) => value == null ? '请选择宠物' : null,
        ),
      ],
    );
  }

  Widget _buildPetAvatar(String? avatar, {double size = 32}) {
    final radius = size / 2;
    if (avatar != null && avatar.trim().isNotEmpty) {
      final a = avatar.trim();
      final uri = Uri.tryParse(a);
      final isHttp =
          uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      if (isHttp) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.network(
            a,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _petAvatarFallback(size),
          ),
        );
      }
      if (File(a).existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.file(
            File(a),
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      }
    }
    return _petAvatarFallback(size);
  }

  Widget _petAvatarFallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.pets, size: size * 0.6, color: Colors.grey[600]),
    );
  }

  Widget _buildDateTimePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签和开关分行显示，避免挤在一起
          Row(
            children: [
              Expanded(
                child: Text('走失时间',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 日期时间选择器
          InkWell(
            onTap: _selectLostDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.transparent),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      color: Colors.grey[400], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _lostDateTime == null
                          ? '请选择走失日期${_includeTime ? '和时间' : ''}'
                          : _timeController.text,
                      style: TextStyle(
                        fontSize: 15,
                        color: _lostDateTime == null
                            ? Colors.grey[400]
                            : AppColors.textDark,
                      ),
                    ),
                  ),
                  Icon(Icons.calendar_today, color: Colors.grey[400], size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 包含时间开关（类似Notion）
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('包含时间',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(width: 8),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: _includeTime,
                  onChanged: (value) {
                    setState(() {
                      _includeTime = value;
                      if (!value && _lostDateTime != null) {
                        // 如果关闭时间，移除时间部分
                        _lostDateTime = DateTime(
                          _lostDateTime!.year,
                          _lostDateTime!.month,
                          _lostDateTime!.day,
                        );
                      }
                      _updateTimeController();
                    });
                  },
                  activeColor: const Color(0xFFFF512F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    bool isRequired = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700])),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            readOnly: readOnly,
            style: TextStyle(
                fontSize: 15,
                color: readOnly ? Colors.grey[600] : AppColors.textDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
              filled: true,
              fillColor: readOnly ? Colors.grey[100] : Colors.grey[50],
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFFFF512F), width: 1.5)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.red.shade200, width: 1)),
            ),
            validator: isRequired
                ? (value) => value == null || value.isEmpty ? '请输入$label' : null
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _generate,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFFF512F), Color(0xFFDD2476)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFFF512F).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('立即生成救援物料',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final m = _generatedMaterials!;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认退出？'),
            content: const Text('退出后生成的救援信息将丢失，建议先保存海报或复制文案。'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child:
                      const Text('确认退出', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (shouldPop == true && mounted) {
          Navigator.pop(context);
        }
      },
      child: Column(
        key: const ValueKey('results'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Anti-Fraud Banner
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFEEBA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFF856404), size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '警惕诈骗：请勿轻信任何要求先转账、支付运费或鉴定费的线索！',
                    style: TextStyle(
                        color: Color(0xFF856404),
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('生成结果',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
              TextButton.icon(
                onPressed: () => setState(() => _generatedMaterials = null),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新填写'),
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.textGrey),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Checklist Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient:
                  LinearGradient(colors: [Colors.orange.shade50, Colors.white]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.checklist_rounded,
                          color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('黄金72小时救援行动清单',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                ...m.searchChecklist.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2.0),
                            child: Icon(Icons.check_circle_outline_rounded,
                                size: 16, color: Colors.orange),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(item,
                                  style: const TextStyle(
                                      color: AppColors.textDark,
                                      fontSize: 14,
                                      height: 1.4))),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const SizedBox(height: 24),

          // Sliding Nav Bar (Glassmorphism Style)
          LayoutBuilder(
            builder: (context, constraints) {
              return AnimatedBuilder(
                animation: _tabController.animation!,
                builder: (context, child) {
                  final double position = _tabController.animation!.value;
                  final double width = constraints.maxWidth;
                  final double itemWidth = width / 2;
                  
                  return Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Indicator
                        Positioned(
                          left: position * itemWidth + 4, // Add padding
                          top: 4,
                          bottom: 4,
                          width: itemWidth - 8, // Subtract padding
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF512F).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Tap Targets
                        Row(
                          children: [
                            _buildSlidingTabItem(0, '文案生成', position, itemWidth),
                            _buildSlidingTabItem(1, '海报预览', position, itemWidth),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 24),

          // 动态计算海报预览所需高度
          Builder(
            builder: (context) {
              final width = MediaQuery.of(context).size.width - 40; // Subtract padding
              // A4 (1:√2) 约 1.414 | 手机屏 9:16 约 1.778
              final double aspectRatio = _isA4Ratio ? 1.414 : 1.778;
              final double posterHeight = width * aspectRatio;
              
              // 加上 ToggleButtons (48px) + Spacing (16px) + Buttons (48px) + Spacing(12px) + Publish Button (48px) + Spacing (20px)
              // Total extra space needed roughly 200px
              // Use a minimum height of 600 or the calculated height
              final layoutHeight = math.max(600.0, posterHeight + 220);

              return SizedBox(
                height: layoutHeight,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Copywriting Tab
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildPlatformCard('朋友圈文案', m.wechatMomentsText,
                              const Color(0xFF07C160), Icons.chat_bubble_rounded),
                          _buildPlatformCard(
                              '小红书文案',
                              '${m.xiaohongshuTitle}\n\n${m.xiaohongshuText}',
                              const Color(0xFFFF2442),
                              Icons.camera_alt_rounded),
                          _buildPlatformCard('短消息/群发', m.shortMessageText,
                              const Color(0xFF007AFF), Icons.message_rounded),
                        ],
                      ),
                    ),
                    // Poster Tab
                    Column(
                      children: [
                      // 海报比例切换
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('海报尺寸：',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            ToggleButtons(
                              constraints: const BoxConstraints(minHeight: 32),
                              isSelected: [_isA4Ratio, !_isA4Ratio],
                              onPressed: (index) {
                                setState(() {
                                  _isA4Ratio = index == 0;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              selectedColor: Colors.white,
                              fillColor: const Color(0xFFFF512F),
                              color: Colors.grey,
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('A4 打印版'),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('手机屏幕版'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      RepaintBoundary(
                        key: _posterKey,
                        child: _buildPosterPreview(m),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isGenerating
                                  ? null
                                  : () => _captureAndShare(false),
                              icon: const Icon(Icons.save_alt_rounded),
                              label: const Text('保存到相册'),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isGenerating
                                  ? null
                                  : () => _captureAndShare(true),
                              icon: const Icon(Icons.share_rounded),
                              label: const Text('生成并分享'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF512F),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _isGenerating ? null : _publishToCommunity,
                          icon: const Icon(Icons.send_rounded,
                              color: AppColors.primary),
                          label: const Text('一键发布到社区求助',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.primary)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ); // End SizedBox
          },
        ),
        const SizedBox(height: 40),
      ],
    ),
    );
  }

  Widget _buildSlidingTabItem(
      int index, String label, double position, double itemWidth) {
    // 0.0 -> 1.0 smoothly
    final t = (1.0 - (position - index).abs()).clamp(0.0, 1.0);
    
    final color = Color.lerp(Colors.grey[600], Colors.white, t);
    final scale = 1.0 + 0.15 * t;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _tabController.animateTo(index);
          HapticFeedback.lightImpact();
        },
        child: Container(
          alignment: Alignment.center,
          color: Colors.transparent, // Hit test target
          child: Transform.scale(
            scale: scale,
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformCard(
      String title, String content, Color brandColor, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: brandColor, size: 24),
          title: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: brandColor)),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(content,
                style: const TextStyle(
                    fontSize: 14, height: 1.6, color: Color(0xFF4A4A4A))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _shareText(content),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('分享'),
                  style: TextButton.styleFrom(foregroundColor: brandColor),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _copyToClipboard(content),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('一键复制'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor.withOpacity(0.1),
                    foregroundColor: brandColor,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterPreview(LostPetMaterials m) {
    final bool hasReward = _rewardController.text.isNotEmpty;
    // A4 (1:√2) 约 0.707 | 手机屏 9:16 约 0.56
    final double aspectRatio = _isA4Ratio ? 1 / 1.414 : 9 / 16;
    
    // 设定虚拟画布宽度（基准分辨率），提高至 720 以获得更好的文字/图片比例
    const double designWidth = 720.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算适应当前容器的虚拟高度
        final double designHeight = designWidth / aspectRatio;
        
        return AspectRatio(
          aspectRatio: aspectRatio,
          child: FittedBox(
            fit: BoxFit.contain, // 将设计稿缩放至当前屏幕显示区域
            child: Container(
              width: designWidth,
              height: designHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16), // 稍微加大倒角
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // 1. Header Banner (Also scaled now)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28), // 增加 Banner 高度
                    decoration: const BoxDecoration(
                      color: Color(0xFFD32F2F), 
                    ),
                    child: const Text(
                      '寻 宠 启 事',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48, // 配合 720 宽度略微加大
                        fontWeight: FontWeight.w900,
                        letterSpacing: 16,
                        height: 1.0,
                      ),
                    ),
                  ),

                  // 2. Content Area (Fills remaining height)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: _isA4Ratio ? 24 : 32, // 恢复一点边距
                        vertical: 24
                      ),
                      child: Column(
                        // 移除 spaceBetween，改为自适应布局
                        children: [
                            // Photo Area (Flexible - takes remaining space)
                            Expanded(
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 1.0,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            border: Border.all(
                                                color: Colors.black12, width: 2),
                                            borderRadius: BorderRadius.circular(16),
                                            image: _selectedImage != null
                                                ? DecorationImage(
                                                    image: FileImage(_selectedImage!),
                                                    fit: BoxFit.cover)
                                                : null,
                                          ),
                                          child: _selectedImage == null
                                              ? Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.add_a_photo_rounded,
                                                        size: 90,
                                                        color: Colors.grey[300]),
                                                    const SizedBox(height: 12),
                                                    Text('点击上传照片',
                                                        style: TextStyle(
                                                            color: Colors.grey[400],
                                                            fontSize: 24,
                                                            fontWeight:
                                                                FontWeight.bold)),
                                                  ],
                                                )
                                              : null,
                                        ),
                                        // Change Photo Button
                                        if (_selectedImage != null && !_isGenerating)
                                          Positioned(
                                            right: 16,
                                            bottom: 16,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 8),
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.black.withOpacity(0.6),
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.camera_alt_rounded,
                                                      color: Colors.white,
                                                      size: 18),
                                                  SizedBox(width: 6),
                                                  Text('更换照片',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16)),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),

                            // Name & Species
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    _nameController.text.isEmpty
                                        ? '宠物名字'
                                        : _nameController.text,
                                    // 保持大号字体，但因为画布变大，相对占比变小
                                    style: const TextStyle(
                                        fontSize: 60, 
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textDark),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _speciesController.text,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),

                            // Info Grid
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9F9F9),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: const Color(0xFFEEEEEE), width: 2),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min, 
                                children: [
                                  _buildPosterInfoRow(
                                      Icons.access_time_filled_rounded,
                                      '走失时间',
                                      _timeController.text,
                                      fontSize: 20, iconSize: 24),
                                  const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12),
                                      child: Divider(height: 1)),
                                  _buildPosterInfoRow(Icons.location_on_rounded,
                                      '走失地点', _locationController.text,
                                      fontSize: 20, iconSize: 24),
                                  const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12),
                                      child: Divider(height: 1)),
                                  _buildPosterInfoRow(Icons.info_rounded,
                                      '外貌特征', _descriptionController.text,
                                      fontSize: 20, iconSize: 24),
                                ],
                              ),
                            ),
                            
                            if (hasReward) const SizedBox(height: 16),

                            // Reward Area
                            if (hasReward)
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFFFFC107), width: 4), // 加粗边框
                                ),
                                child: Column(
                                  children: [
                                    const Text('提供有效线索并寻回必有重谢',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF8D6E63))),
                                    const SizedBox(height: 4),
                                    Text(
                                      '¥ ${_rewardController.text}',
                                      style: const TextStyle(
                                          fontSize: 60,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFFD32F2F)),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 24),

                            // Footer Area
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('发现请立即联系',
                                style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(
                                  _contactController.text.isEmpty
                                      ? '暂无电话'
                                      : _contactController.text,
                                  style: const TextStyle(
                                      fontSize: 72, 
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textDark,
                                      letterSpacing: 4),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Watermark
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.pets,
                                    size: 18, color: Color(0xFF9E9E9E)),
                                const SizedBox(width: 8),
                                const Text(
                                  '由 智宠合生Peture AI 生成',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF9E9E9E),
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPosterInfoRow(IconData icon, String label, String value,
      {double fontSize = 14, double iconSize = 16}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: iconSize, color: const Color(0xFF757575)),
        const SizedBox(width: 8), // 进一步缩小图标与文字的间距
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                    text: '$label：',
                    style: TextStyle(
                        color: const Color(0xFF757575),
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold)),
                TextSpan(
                    text: value.isEmpty ? '未填写' : value,
                    style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: fontSize + 2,
                        fontWeight: FontWeight.w600,
                        height: 1.25)), // 稍微调小行高，更紧凑
              ],
            ),
          ),
        ),
      ],
    );
  }
}
