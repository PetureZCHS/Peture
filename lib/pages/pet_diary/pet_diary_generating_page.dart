import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/supabase_edge_service.dart';
import 'pet_diary_result_page.dart';

/// AI生成日记中间页面 - 显示生成进度
class PetDiaryGeneratingPage extends StatefulWidget {
  final String userInput;
  final PetDiaryEdgeService diaryService;
  final String style;

  const PetDiaryGeneratingPage({
    super.key,
    required this.userInput,
    required this.diaryService,
    this.style = '小红书',
  });

  @override
  State<PetDiaryGeneratingPage> createState() => _PetDiaryGeneratingPageState();
}

class _PetDiaryGeneratingPageState extends State<PetDiaryGeneratingPage>
    with TickerProviderStateMixin {
  String _aiGeneratedContent = '';
  late AnimationController _cursorAnimationController; // 光标闪烁动画
  late AnimationController _loadingAnimationController; // 加载旋转动画
  final bool _isGenerating = true; // 是否正在生成

  @override
  void initState() {
    super.initState();

    // 光标闪烁动画控制器
    _cursorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    // 加载旋转动画控制器
    _loadingAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // 开始生成
    _generateDiary();
  }

  @override
  void dispose() {
    _cursorAnimationController.dispose();
    _loadingAnimationController.dispose();
    super.dispose();
  }

  Future<void> _generateDiary() async {
    try {
      // 开始生成流
      final stream = widget.diaryService.generatePetDiary(
        query: widget.userInput,
        style: widget.style,
        // nickname 和 breed 可以根据需要从用户数据中获取
      );

      // 监听流事件
      await for (final event in stream) {
        if (event is DiaryContentEvent) {
          // 收到内容事件，更新界面
          if (mounted) {
            setState(() {
              _aiGeneratedContent = event.fullText;
            });
          }
        } else if (event is DiaryDoneEvent) {
          // 生成完成，跳转到结果页面
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => PetDiaryResultPage(
                  originalText: widget.userInput,
                  style: widget.style,
                  diaryService: widget.diaryService,
                  initialContent: _aiGeneratedContent, // 传递已收到的内容
                ),
              ),
            );
          }
          break;
        } else if (event is DiaryErrorEvent) {
          // 发生错误
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text('生成失败: ${event.error}')),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 3),
              ),
            );
            Navigator.pop(context);
          }
          break;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('生成失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              CupertinoIcons.back,
              color: Colors.black87,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 风格标签 - 居中显示
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7B95FF), Color(0xFF9B7FFF)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7B95FF).withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.style, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        widget.style,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // 主内容卡片
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 60,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7B95FF).withOpacity(0.08),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: _aiGeneratedContent.isEmpty
                      ? _buildWaitingState()
                      : _buildStreamingText(),
                ),

                // 完成状态标签
                if (!_isGenerating) ...[
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          '生成完成',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 等待状态 - 简洁高级版本
  Widget _buildWaitingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 旋转加载动画
        RotationTransition(
          turns: _loadingAnimationController,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B95FF), Color(0xFF9B7FFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B95FF).withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 56,
            ),
          ),
        ),

        const SizedBox(height: 48),

        // 主标题
        const Text(
          '十六正在写日记.....',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D3142),
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 56),

        // 简化的骨架屏 - 只显示3行
        ...List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 流式文本显示（带光标动画）
  Widget _buildStreamingText() {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: _aiGeneratedContent,
            style: const TextStyle(
              fontSize: 15.5,
              height: 2.0,
              color: Color(0xFF2D3142),
              letterSpacing: 0.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          // 打字光标
          if (_isGenerating)
            WidgetSpan(
              child: FadeTransition(
                opacity: _cursorAnimationController,
                child: Container(
                  margin: const EdgeInsets.only(left: 2),
                  width: 2,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7B95FF), Color(0xFF9B7FFF)],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
