import 'package:flutter/material.dart';
import '../../models/fitness_course.dart';
import '../community/publish_post_page.dart';

/// 训练完成页面
class PartnerFitCompletionPage extends StatefulWidget {
  final FitnessCourse course;
  final FitnessRecord record;

  const PartnerFitCompletionPage({
    super.key,
    required this.course,
    required this.record,
  });

  @override
  State<PartnerFitCompletionPage> createState() =>
      _PartnerFitCompletionPageState();
}

class _PartnerFitCompletionPageState extends State<PartnerFitCompletionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // 庆祝图标 - 带动画
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5A8EFA).withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 70,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 完成文字（Keep 风格）
                const Text(
                  '太棒了！',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  '你完成了「${widget.course.name}」',
                  style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 4),
                
                const SizedBox(height: 40),

                // 成就卡片
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5A8EFA).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '你的成就',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          icon: Icons.timer,
                          value: _formatDuration(widget.record.durationMinutes),
                          unit: 'mm:ss',
                          label: '训练时长',
                        ),
                          _buildStatItem(
                            icon: Icons.local_fire_department,
                            value: '${widget.record.caloriesBurned}',
                            unit: '大卡',
                            label: '你消耗',
                          ),
                          _buildStatItem(
                            icon: Icons.pets,
                            value: '${widget.record.petCaloriesBurned}',
                            unit: '罐头',
                            label: '宠物消耗',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 鼓励文字
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text('🎉', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      Text(
                        '你和你的宠物都获得了锻炼！\n这是一石二鸟的完美方案！',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 分享按钮
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _shareAchievement,
                    icon: const Icon(Icons.share),
                    label: const Text('分享到社区', style: TextStyle(fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5A8EFA),
                      side: const BorderSide(
                        color: Color(0xFF5A8EFA),
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 返回按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // 返回到健身房主页（pop掉详情页和完成页，留在列表页）
                      Navigator.of(context).pop(); // pop 完成页
                      Navigator.of(context).pop(); // pop 详情页
                      // 现在回到了 PartnerFitGymPage
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A8EFA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      '完成',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String unit,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextSpan(
                text: '\n$unit',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
      ],
    );
  }

  /// 将分钟数转换为 mm:ss 形式的字符串
  String _formatDuration(int minutes) {
    final totalSeconds = minutes * 60;
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _shareAchievement() {
    final text =
        '''
🎉 我刚刚完成了「${widget.course.name}」！

⏱️ 训练时长：${widget.record.durationMinutes}分钟
🔥 消耗卡路里：${widget.record.caloriesBurned}大卡
🐾 宠物消耗：${widget.record.petCaloriesBurned}个罐头的能量

和毛孩一起健身，一石二鸟的完美方案！💪🐾

#活力伙伴 #人宠健身 #萌星球
    ''';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PublishPostPage(
          initialContent: text.trim(),
          sourceType: 'partner_fit',
        ),
      ),
    );
  }
}
