import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../utils/ui_helpers.dart';
import '../../community_screen.dart';
import 'lost_pet_generator.dart';

class LostPetRescuePage extends StatefulWidget {
  const LostPetRescuePage({super.key});

  @override
  State<LostPetRescuePage> createState() => _LostPetRescuePageState();
}

class _LostPetRescuePageState extends State<LostPetRescuePage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _posterKey = GlobalKey();
  late TabController _tabController;
  
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final boundary = _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('无法获取渲染边界');
      }

      // Use a slightly lower pixel ratio to avoid memory issues, but still high quality
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('图片数据为空');
      }
      
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // 2. Save to temporary file
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/lost_pet_poster_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(pngBytes);

      // 3. Share or Save
      if (isShare) {
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
      // Wait for any potential layout updates
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Capture Image
      final boundary = _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('无法获取渲染边界');

      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('图片数据为空');
      
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // 2. Save to temporary file
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/lost_pet_poster_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(pngBytes);

      // 3. Create Post
      final newPost = Post(
        id: 'lost_${DateTime.now().millisecondsSinceEpoch}',
        imageUrl: '', // Local file used
        imageFile: imageFile,
        content: '#寻宠启事 ${_generatedMaterials!.posterHeadline}\n\n${_generatedMaterials!.xiaohongshuText}',
        userAvatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=Felix', // Mock avatar
        username: '急切的铲屎官',
        likeCount: 0,
        imageHeight: 300, // Fixed height for poster
      );

      // 4. Add to mock data
      mockPosts.insert(0, newPost);

      // 5. Navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 已发布到社区'), backgroundColor: Colors.green),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CommunityScreen()),
        );
      }
    } catch (e) {
      debugPrint('Error publishing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布失败: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
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
        titleTextStyle: const TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.w700),
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
              width: 300, height: 300,
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
                      position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _generatedMaterials == null ? _buildForm() : _buildResults(),
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
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('基本信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 20),
                    
                    _buildSpeciesSelector(),
                    const SizedBox(height: 20),

                    _buildModernTextField(label: '宠物名字', controller: _nameController, icon: Icons.pets_rounded, hint: '例如：咪咪'),
                    _buildModernTextField(label: '走失时间', controller: _timeController, icon: Icons.access_time_rounded, hint: '例如：今天下午2点'),
                    _buildModernTextField(label: '走失地点', controller: _locationController, icon: Icons.location_on_rounded, hint: '例如：xx小区xx号楼'),
                    _buildModernTextField(label: '外貌特征', controller: _descriptionController, icon: Icons.face_rounded, hint: '例如：橘猫，左耳有缺口...', maxLines: 3),
                    _buildModernTextField(label: '联系方式', controller: _contactController, icon: Icons.phone_rounded, hint: '电话号码', keyboardType: TextInputType.phone),
                    _buildModernTextField(label: '悬赏金额 (选填)', controller: _rewardController, icon: Icons.attach_money_rounded, hint: '例如：1000', isRequired: false, keyboardType: TextInputType.number),

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
        gradient: const LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFFFF512F).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('72小时黄金救援', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('根据物种习性生成专业搜救方案与多平台文案', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesSelector() {
    return Row(
      children: [
        Expanded(child: _buildSpeciesOption('猫', Icons.cruelty_free_rounded)), // Using cruelty_free as cat-like icon
        const SizedBox(width: 16),
        Expanded(child: _buildSpeciesOption('狗', Icons.pets_rounded)),
      ],
    );
  }

  Widget _buildSpeciesOption(String label, IconData icon) {
    final bool isSelected = _speciesController.text == label;
    return GestureDetector(
      onTap: () => setState(() => _speciesController.text = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF512F) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.transparent),
          boxShadow: isSelected ? [
            BoxShadow(color: const Color(0xFFFF512F).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
          ] : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[400], size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold)),
          ],
        ),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 15, color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF512F), width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.red.shade200, width: 1)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF512F).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('立即生成救援物料', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认退出', style: TextStyle(color: Colors.red))),
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
                const Icon(Icons.warning_amber_rounded, color: Color(0xFF856404), size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '警惕诈骗：请勿轻信任何要求先转账、支付运费或鉴定费的线索！',
                    style: TextStyle(color: Color(0xFF856404), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('生成结果', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              TextButton.icon(
                onPressed: () => setState(() => _generatedMaterials = null),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新填写'),
                style: TextButton.styleFrom(foregroundColor: AppColors.textGrey),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Checklist Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange.shade50, Colors.white]),
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
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.checklist_rounded, color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('黄金72小时救援行动清单', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16)),
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
                        child: Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.orange),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item, style: const TextStyle(color: AppColors.textDark, fontSize: 14, height: 1.4))),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),

        // Tab Bar
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(25),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            labelColor: AppColors.textDark,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: '文案生成'),
              Tab(text: '海报预览'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          height: 500, // Fixed height for tab view content
          child: TabBarView(
            controller: _tabController,
            children: [
              // Copywriting Tab
              SingleChildScrollView(
                child: Column(
                  children: [
                    _buildPlatformCard('朋友圈文案', m.wechatMomentsText, const Color(0xFF07C160), Icons.chat_bubble_rounded),
                    _buildPlatformCard('小红书文案', '${m.xiaohongshuTitle}\n\n${m.xiaohongshuText}', const Color(0xFFFF2442), Icons.camera_alt_rounded),
                    _buildPlatformCard('短消息/群发', m.shortMessageText, const Color(0xFF007AFF), Icons.message_rounded),
                  ],
                ),
              ),
              // Poster Tab
              SingleChildScrollView(
                child: Column(
                  children: [
                    RepaintBoundary(
                      key: _posterKey,
                      child: _buildPosterPreview(m),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isGenerating ? null : () => _captureAndShare(false),
                            icon: const Icon(Icons.save_alt_rounded),
                            label: const Text('保存到相册'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isGenerating ? null : () => _captureAndShare(true),
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('生成并分享'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF512F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                        label: const Text('一键发布到社区求助', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    ),
    );
  }

  Widget _buildPlatformCard(String title, String content, Color brandColor, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: brandColor, size: 24),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: brandColor)),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(content, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4A4A4A))),
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: const BoxDecoration(
              color: Color(0xFFD32F2F), // Strong Red
            ),
            child: const Text(
              '寻 宠 启 事',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 12,
                height: 1.0,
              ),
            ),
          ),

          // 2. Content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Column(
              children: [
                // Photo
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border.all(color: Colors.black12, width: 1),
                      borderRadius: BorderRadius.circular(8),
                      image: _selectedImage != null 
                        ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                        : null,
                    ),
                    child: _selectedImage == null 
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_rounded, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('点击上传照片', style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : null,
                  ),
                ),
                
                const SizedBox(height: 32),

                // Name & Species
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _nameController.text.isEmpty ? '宠物名字' : _nameController.text,
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.textDark),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _speciesController.text,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Info Grid
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(
                    children: [
                      _buildPosterInfoRow(Icons.access_time_filled_rounded, '走失时间', _timeController.text),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                      _buildPosterInfoRow(Icons.location_on_rounded, '走失地点', _locationController.text),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                      _buildPosterInfoRow(Icons.info_rounded, '外貌特征', _descriptionController.text),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Reward
                if (hasReward)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1), // Light Amber
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFC107), width: 2),
                    ),
                    child: Column(
                      children: [
                        const Text('提供有效线索并寻回必有重谢', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8D6E63))),
                        const SizedBox(height: 4),
                        Text(
                          '¥ ${_rewardController.text}',
                          style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Color(0xFFD32F2F)),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // Contact
                const Text('发现请立即联系', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  _contactController.text.isEmpty ? '暂无电话' : _contactController.text,
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.textDark, letterSpacing: 2),
                ),
                
                const SizedBox(height: 40),
                
                // Watermark
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                      child: const Icon(Icons.pets, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '由 智宠合生Peture AI 生成',
                      style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: const Color(0xFF757575)),
        const SizedBox(width: 16),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$label：', style: const TextStyle(color: Color(0xFF757575), fontSize: 16, fontWeight: FontWeight.bold)),
                TextSpan(text: value.isEmpty ? '未填写' : value, style: const TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.w600, height: 1.4)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

