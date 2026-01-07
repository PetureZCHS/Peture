import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/supabase_edge_service.dart';
import 'pet_diary_result_page.dart';
import 'pet_diary_list_page.dart';

/// 撰写日记页面 - AI将用户输入改写成宠物第一人称
class PetDiaryComposePage extends StatefulWidget {
  const PetDiaryComposePage({super.key});

  @override
  State<PetDiaryComposePage> createState() => _PetDiaryComposePageState();
}

class _PetDiaryComposePageState extends State<PetDiaryComposePage> {
  final TextEditingController _inputController = TextEditingController();
  final PetDiaryEdgeService _diaryService = PetDiaryEdgeService();

  // 当前选中的风格
  String _selectedStyle = '小红书';

  // 可用的风格列表
  final List<String> _availableStyles = ['哲学', '搞笑', '治愈', '中二', '小红书'];

  // 示例文本
  final String _exampleText =
      '今天，我带我的宠物狗狗十六去逍遥津的大草坪玩飞盘。小妮带着她的宠物狗狗朱朱一起。十六跑得比朱朱快。十六和朱朱都玩得很开心，我奖励它们吃苹果狗粮。';

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  /// 生成宠物日记（跳转到生成页面）
  Future<void> _generatePetDiary() async {
    final userInput = _inputController.text.trim();

    if (userInput.isEmpty) {
      _showToast('请先输入内容');
      return;
    }

    // 字数限制检查 (10-500字)
    if (userInput.length < 10) {
      _showToast('输入内容太短，至少需要10个字');
      return;
    }

    if (userInput.length > 500) {
      _showToast('输入内容超出限制，最多500个字');
      return;
    }

    // 直接跳转到结果页面,在那里显示加载动画和流式生成
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetDiaryResultPage(
          originalText: userInput,
          style: _selectedStyle,
          diaryService: _diaryService,
        ),
      ),
    );
  }

  /// 选择风格
  void _onStyleSelected(String style) {
    setState(() {
      _selectedStyle = style;
    });
  }

  /// 点击示例文本
  void _onExampleTap() {
    setState(() {
      _inputController.text = _exampleText;
    });
  }

  /// 显示提示信息
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PetDiaryListPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 提示信息卡片
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7B95FF), Color(0xFF9B7FFF)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '输入今天发生的事情，AI 会帮你改写成十六的第一人称日记～',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 输入框
                Container(
                  constraints: const BoxConstraints(minHeight: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _inputController,
                    maxLines: null,
                    minLines: 8,
                    maxLength: 500,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      hintText: '今天带十六去公园玩了',
                      hintStyle: TextStyle(color: Colors.black26, fontSize: 16),
                      border: InputBorder.none,
                      counterStyle: TextStyle(
                        color: Colors.black38,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 风格选择区域
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          size: 16,
                          color: Colors.black54,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '选择风格',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _StyleSelector(
                      styles: _availableStyles,
                      selectedStyle: _selectedStyle,
                      onStyleSelected: _onStyleSelected,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 示例区域
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: Colors.black54,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '示例',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MultiLineExampleChip(
                      text: _exampleText,
                      onTap: _onExampleTap,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 不再在当前页面显示生成结果，改为跳转到结果页面
                // 底部间距，为按钮留出空间
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      // 悬浮生成按钮
      floatingActionButton: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          onPressed: _generatePetDiary,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7B95FF),
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            minimumSize: const Size(double.infinity, 56),
          ),
          child: const Text(
            '生成日记',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

/// 多行示例文本组件（支持长文本换行）
class _MultiLineExampleChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _MultiLineExampleChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.pets, size: 16, color: Colors.black54),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 风格选择器组件
class _StyleSelector extends StatelessWidget {
  final List<String> styles;
  final String selectedStyle;
  final ValueChanged<String> onStyleSelected;

  const _StyleSelector({
    required this.styles,
    required this.selectedStyle,
    required this.onStyleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: styles.map((style) {
          final isSelected = style == selectedStyle;
          return InkWell(
            onTap: () => onStyleSelected(style),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF7B95FF), Color(0xFF9B7FFF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: isSelected ? null : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                style,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
