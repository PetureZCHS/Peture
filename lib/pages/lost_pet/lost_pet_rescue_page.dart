import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../utils/ui_helpers.dart';
import 'lost_pet_generator.dart';

class LostPetRescuePage extends StatefulWidget {
  const LostPetRescuePage({super.key});

  @override
  State<LostPetRescuePage> createState() => _LostPetRescuePageState();
}

class _LostPetRescuePageState extends State<LostPetRescuePage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _speciesController = TextEditingController(text: '猫'); // Default to Cat
  final _descriptionController = TextEditingController();
  final _timeController = TextEditingController();
  final _locationController = TextEditingController();
  final _rewardController = TextEditingController();
  final _contactController = TextEditingController();

  LostPetMaterials? _generatedMaterials;

  @override
  void dispose() {
    _nameController.dispose();
    _speciesController.dispose();
    _descriptionController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    _rewardController.dispose();
    _contactController.dispose();
    super.dispose();
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
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
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
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.start,
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
    return Column(
      key: const ValueKey('results'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

        // Urgency Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.red.shade50, Colors.white]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.priority_high_rounded, color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('紧急程度: ${m.urgencyLevel}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              Text(m.searchStrategyTip, style: const TextStyle(color: AppColors.textDark, height: 1.5, fontSize: 15)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildPlatformCard('朋友圈文案', m.wechatMomentsText, const Color(0xFF07C160), Icons.chat_bubble_rounded),
        _buildPlatformCard('小红书文案', '${m.xiaohongshuTitle}\n\n${m.xiaohongshuText}', const Color(0xFFFF2442), Icons.camera_alt_rounded),
        _buildPlatformCard('短消息/群发', m.shortMessageText, const Color(0xFF007AFF), Icons.message_rounded),
        
        _buildPosterSection(m),

        const SizedBox(height: 40),
      ],
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
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _copyToClipboard(content),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('一键复制'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor.withOpacity(0.1),
                  foregroundColor: brandColor,
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterSection(LostPetMaterials m) {
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
          leading: const Icon(Icons.image_rounded, color: Colors.orange, size: 24),
          title: const Text('寻宠海报预览', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
          childrenPadding: const EdgeInsets.all(20),
          children: [
             _buildPosterPreview(m),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterPreview(LostPetMaterials m) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5), // Paper color
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          // Pin
          Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
          const SizedBox(height: 16),
          
          Text(m.posterHeadline, 
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.red, letterSpacing: 1)
          ),
          const SizedBox(height: 20),
          
          // Image Placeholder
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border.all(color: Colors.grey[300]!, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_rounded, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text('请贴上宠物照片', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.1)),
            ),
            child: Text(m.posterKeyInfo, 
              style: const TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w600, color: AppColors.textDark), 
              textAlign: TextAlign.center
            ),
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: m.posterFeatures.map((f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.yellow[300], borderRadius: BorderRadius.circular(20)),
              child: Text(f, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            )).toList(),
          ),
          const SizedBox(height: 24),
          
          Text(m.posterCtaText, 
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Colors.red, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(30)),
            child: Text(_contactController.text.isEmpty ? '联系电话: XXXXXXXXXXX' : _contactController.text, 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.yellow)
            ),
          ),
        ],
      ),
    );
  }
}

