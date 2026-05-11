import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 训宠响片「训练之旅」面板组件
///
/// 展示训练里程碑、连续天数、技能进度等，作为辅助信息面板
/// 可折叠/展开，默认显示概览，点击展开详情
class TrainingJourneyPanel extends StatefulWidget {
  final List<String> projects;
  final Map<String, int> successCounts;
  final Map<String, int> failureCounts;
  final int totalSuccessCount;
  final int totalFailureCount;
  final int currentStreak;
  final int bestStreak;
  final VoidCallback? onViewDetails;

  const TrainingJourneyPanel({
    super.key,
    required this.projects,
    required this.successCounts,
    required this.failureCounts,
    required this.totalSuccessCount,
    required this.totalFailureCount,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.onViewDetails,
  });

  @override
  State<TrainingJourneyPanel> createState() => _TrainingJourneyPanelState();
}

class _TrainingJourneyPanelState extends State<TrainingJourneyPanel>
    with TickerProviderStateMixin {
  bool _isExpanded = false;

  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  late AnimationController _progressController;

  // 数字动画
  late AnimationController _numberController;
  late Animation<double> _numberAnimation;

  // 成就徽章入场动画
  late AnimationController _badgeController;
  late Animation<double> _badgeAnimation;

  // 激励语
  final List<String> _motivationalQuotes = [
    '每一次点击，都是爱的信号 📯',
    '耐心是最好的训练工具 🧘',
    '小家伙正在努力理解你，给它一点时间 🐾',
    '正向强化，让训练充满快乐 🎉',
    '今天的坚持，是明天的默契 🤝',
    '训练不是命令，是双向的沟通 💬',
    '它的进步，肉眼可见 🌱',
    '最好的训练师，是充满爱的你 ❤️',
    '保持节奏，循序渐进 🥁',
    '响片一响，快乐登场 ✨',
    '毛孩子的每一次尝试都值得鼓励 🌟',
    '训练是一场充满爱的旅程 🐕',
    '你的耐心，是它最好的礼物 🎁',
    '慢就是快，稳扎稳打 💪',
    '每一个小进步，都是大突破 🚀',
  ];

  String get _randomQuote {
    final total = widget.totalSuccessCount + widget.totalFailureCount;
    final index = total % _motivationalQuotes.length;
    return _motivationalQuotes[index];
  }

  @override
  void initState() {
    super.initState();

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _numberController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _numberAnimation = CurvedAnimation(
      parent: _numberController,
      curve: Curves.easeOutCubic,
    );

    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _badgeAnimation = CurvedAnimation(
      parent: _badgeController,
      curve: Curves.easeOutBack,
    );

    // 延迟触发动画，确保页面已渲染
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _progressController.forward();
        _numberController.forward();
      }
    });
  }

  @override
  void didUpdateWidget(covariant TrainingJourneyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 数据变化时重新触发动画
    if (widget.totalSuccessCount != oldWidget.totalSuccessCount ||
        widget.totalFailureCount != oldWidget.totalFailureCount) {
      _progressController.forward(from: 0);
      _numberController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    _progressController.dispose();
    _numberController.dispose();
    _badgeController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _expandController.forward();
      _badgeController.forward();
    } else {
      _expandController.reverse();
      _badgeController.reverse();
    }
  }

  // ────────────────────────── 掌握等级 ──────────────────────────

  static const List<Map<String, dynamic>> _skillLevels = [
    {'name': '新手', 'min': 0, 'color': Color(0xFF9E9E9E)},
    {'name': '入门', 'min': 10, 'color': Color(0xFF8BC34A)},
    {'name': '熟练', 'min': 30, 'color': Color(0xFF4CAF50)},
    {'name': '精通', 'min': 60, 'color': Color(0xFF00BCD4)},
    {'name': '大师', 'min': 100, 'color': Color(0xFFFFB300)},
  ];

  Map<String, dynamic> _getSkillLevel(int successCount) {
    for (int i = _skillLevels.length - 1; i >= 0; i--) {
      if (successCount >= (_skillLevels[i]['min'] as int)) {
        return _skillLevels[i];
      }
    }
    return _skillLevels.first;
  }

  double _getLevelProgress(int successCount) {
    final currentLevel = _getSkillLevel(successCount);
    final currentMin = currentLevel['min'] as int;
    final currentIndex = _skillLevels.indexOf(currentLevel);

    if (currentIndex >= _skillLevels.length - 1) return 1.0;

    final nextMin = _skillLevels[currentIndex + 1]['min'] as int;
    final progress = (successCount - currentMin) / (nextMin - currentMin);
    return progress.clamp(0.0, 1.0);
  }

  // ────────────────────────── 成就系统 ──────────────────────────

  List<_Achievement> _getAchievements() {
    final List<_Achievement> list = [];
    final total = widget.totalSuccessCount + widget.totalFailureCount;
    final overallRate = total > 0
        ? (widget.totalSuccessCount / total * 100).toInt()
        : 0;

    // 1. 初次训练
    list.add(_Achievement(
      id: 'first_train',
      name: '初次训练',
      desc: '完成第一次响片训练',
      icon: Icons.pets,
      isUnlocked: total >= 1,
      unlockedColor: const Color(0xFF4CAF50),
      lockedColor: const Color(0xFF3A3A3A),
    ));

    // 2. 百次点击
    list.add(_Achievement(
      id: 'hundred_clicks',
      name: '百次点击',
      desc: '累计完成100次点击',
      icon: Icons.touch_app,
      isUnlocked: total >= 100,
      unlockedColor: const Color(0xFF8BC34A),
      lockedColor: const Color(0xFF3A3A3A),
    ));

    // 3. 连续7天
    list.add(_Achievement(
      id: 'streak_7',
      name: '坚持不懈',
      desc: '连续训练7天',
      icon: Icons.local_fire_department,
      isUnlocked: widget.bestStreak >= 7,
      unlockedColor: const Color(0xFFFF9800),
      lockedColor: const Color(0xFF3A3A3A),
    ));

    // 4. 单项目50次
    final hasProject50 = widget.successCounts.values.any((c) => c >= 50);
    list.add(_Achievement(
      id: 'project_50',
      name: '单项专精',
      desc: '单个项目成功50次',
      icon: Icons.emoji_events,
      isUnlocked: hasProject50,
      unlockedColor: const Color(0xFFFFB300),
      lockedColor: const Color(0xFF3A3A3A),
    ));

    // 5. 成功率80%+
    list.add(_Achievement(
      id: 'rate_80',
      name: '精准训练',
      desc: '综合成功率达到80%',
      icon: Icons.verified,
      isUnlocked: overallRate >= 80 && total >= 20,
      unlockedColor: const Color(0xFF00BCD4),
      lockedColor: const Color(0xFF3A3A3A),
    ));

    // 6. 总成功500次
    list.add(_Achievement(
      id: 'success_500',
      name: '训练达人',
      desc: '累计成功500次',
      icon: Icons.military_tech,
      isUnlocked: widget.totalSuccessCount >= 500,
      unlockedColor: const Color(0xFFE91E63),
      lockedColor: const Color(0xFF3A3A3A),
    ));

    // 7. 连续14天
    list.add(_Achievement(
      id: 'streak_14',
      name: '习惯养成',
      desc: '连续训练14天',
      icon: Icons.calendar_today,
      isUnlocked: widget.bestStreak >= 14,
      unlockedColor: const Color(0xFF9C27B0),
      lockedColor: const Color(0xFF3A3A3A),
    ));

    // 8. 单项目大师
    final hasMasterProject = widget.successCounts.values.any((c) => c >= 100);
    list.add(_Achievement(
      id: 'master_project',
      name: '大师级',
      desc: '单个项目达到大师级',
      icon: Icons.workspace_premium,
      isUnlocked: hasMasterProject,
      unlockedColor: const Color(0xFFFFD700),
      lockedColor: const Color(0xFF3A3A3A),
    ));

    return list;
  }

  // ────────────────────────── 构建 ──────────────────────────

  @override
  Widget build(BuildContext context) {
    final total = widget.totalSuccessCount + widget.totalFailureCount;
    final overallRate = total > 0
        ? (widget.totalSuccessCount / total * 100).toInt()
        : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF3A3A3A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部（可点击折叠/展开）
            _buildHeader(total, overallRate),

            // 展开内容
            AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                return ClipRect(
                  child: Align(
                    heightFactor: _expandAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部概览卡片
                  _buildOverviewCard(total, overallRate),

                  // 技能进度区
                  if (widget.projects.isNotEmpty) _buildSkillProgressSection(),

                  // 里程碑/成就区
                  _buildAchievementsSection(),

                  // 底部激励语
                  _buildMotivationFooter(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 头部区域
  Widget _buildHeader(int total, int overallRate) {
    return InkWell(
      onTap: _toggleExpand,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        child: Row(
          children: [
            // 图标
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.route,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // 标题
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '训练之旅',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isExpanded
                        ? '点击收起详情'
                        : '总训练 $total 次 · 成功率 $overallRate% · 点击展开',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            // 展开/收起箭头
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶部概览卡片
  Widget _buildOverviewCard(int total, int overallRate) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A3A3A), Color(0xFF2D2D2D)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4A4A4A)),
        ),
        child: Column(
          children: [
            // 第一行统计
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOverviewItem(
                  icon: Icons.fitness_center,
                  label: '今日训练',
                  value: '$total',
                  color: const Color(0xFF4CAF50),
                ),
                _buildDivider(),
                _buildOverviewItem(
                  icon: Icons.emoji_events,
                  label: '总成功',
                  value: '${widget.totalSuccessCount}',
                  color: const Color(0xFF4CAF50),
                ),
                _buildDivider(),
                _buildOverviewItem(
                  icon: Icons.local_fire_department,
                  label: '连续天数',
                  value: '${widget.currentStreak}',
                  color: const Color(0xFFFF9800),
                ),
                _buildDivider(),
                _buildOverviewItem(
                  icon: Icons.star,
                  label: '最佳记录',
                  value: '${widget.bestStreak}',
                  color: const Color(0xFFFFB300),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 综合成功率条
            _buildOverallRateBar(overallRate),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return AnimatedBuilder(
      animation: _numberAnimation,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 50,
      color: Colors.white.withOpacity(0.1),
    );
  }

  /// 综合成功率条
  Widget _buildOverallRateBar(int overallRate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '综合成功率',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$overallRate%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: overallRate >= 70
                    ? const Color(0xFF4CAF50)
                    : overallRate >= 40
                        ? const Color(0xFFFFC107)
                        : const Color(0xFFFF5722),
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: (overallRate / 100) * _progressController.value,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  overallRate >= 70
                      ? const Color(0xFF4CAF50)
                      : overallRate >= 40
                          ? const Color(0xFFFFC107)
                          : const Color(0xFFFF5722),
                ),
                minHeight: 8,
              );
            },
          ),
        ),
      ],
    );
  }

  /// 技能进度区
  Widget _buildSkillProgressSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 区块标题
          _buildSectionTitle(
            icon: Icons.trending_up,
            title: '技能进度',
            subtitle: '${widget.projects.length} 个训练项目',
          ),
          const SizedBox(height: 12),
          // 项目列表
          ...widget.projects.map((project) {
            final success = widget.successCounts[project] ?? 0;
            final failure = widget.failureCounts[project] ?? 0;
            final level = _getSkillLevel(success);
            final levelProgress = _getLevelProgress(success);
            final totalProject = success + failure;
            final rate = totalProject > 0 ? (success / totalProject * 100).toInt() : 0;

            return _buildSkillProgressItem(
              project: project,
              success: success,
              failure: failure,
              levelName: level['name'] as String,
              levelColor: level['color'] as Color,
              levelProgress: levelProgress,
              rate: rate,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSkillProgressItem({
    required String project,
    required int success,
    required int failure,
    required String levelName,
    required Color levelColor,
    required double levelProgress,
    required int rate,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2D2D2D),
            const Color(0xFF252525),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: levelColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 项目名称和等级
          Row(
            children: [
              Expanded(
                child: Text(
                  project,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      levelColor.withOpacity(0.3),
                      levelColor.withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: levelColor.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  levelName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: levelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: levelProgress * _progressController.value,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                  minHeight: 6,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // 详细数据
          Row(
            children: [
              _buildMiniStat(
                label: '成功',
                value: '$success',
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 16),
              _buildMiniStat(
                label: '重试',
                value: '$failure',
                color: const Color(0xFFFF9800),
              ),
              const SizedBox(width: 16),
              _buildMiniStat(
                label: '成功率',
                value: '$rate%',
                color: rate >= 70
                    ? const Color(0xFF4CAF50)
                    : rate >= 40
                        ? const Color(0xFFFFC107)
                        : const Color(0xFFFF5722),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  /// 里程碑/成就区
  Widget _buildAchievementsSection() {
    final achievements = _getAchievements();
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 区块标题
          _buildSectionTitle(
            icon: Icons.workspace_premium,
            title: '成就徽章',
            subtitle: '$unlockedCount / ${achievements.length} 已解锁',
          ),
          const SizedBox(height: 12),
          // 成就网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.78,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final ach = achievements[index];
              return _buildAchievementBadge(ach, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge(_Achievement ach, int index) {
    return AnimatedBuilder(
      animation: _badgeAnimation,
      builder: (context, child) {
        // 错峰入场
        final delay = index * 0.08;
        final value = (_badgeAnimation.value - delay).clamp(0.0, 1.0) / (1.0 - delay);
        if (value <= 0) {
          return Opacity(
            opacity: 0,
            child: Transform.scale(scale: 0.5, child: child),
          );
        }
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.5 + value * 0.5,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _showAchievementDetail(ach),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 徽章图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: ach.isUnlocked
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ach.unlockedColor.withOpacity(0.3),
                          ach.unlockedColor.withOpacity(0.1),
                        ],
                      )
                    : null,
                color: ach.isUnlocked ? null : const Color(0xFF252525),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ach.isUnlocked
                      ? ach.unlockedColor.withOpacity(0.5)
                      : Colors.white.withOpacity(0.06),
                  width: 1.5,
                ),
                boxShadow: ach.isUnlocked
                    ? [
                        BoxShadow(
                          color: ach.unlockedColor.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  ach.icon,
                  color: ach.isUnlocked
                      ? ach.unlockedColor
                      : Colors.white.withOpacity(0.15),
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 徽章名称
            Text(
              ach.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: ach.isUnlocked ? FontWeight.bold : FontWeight.w500,
                color: ach.isUnlocked
                    ? Colors.white.withOpacity(0.9)
                    : Colors.white.withOpacity(0.3),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showAchievementDetail(_Achievement ach) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: ach.isUnlocked
                  ? ach.unlockedColor.withOpacity(0.4)
                  : Colors.white.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 徽章大图标
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: ach.isUnlocked
                      ? LinearGradient(
                          colors: [
                            ach.unlockedColor.withOpacity(0.3),
                            ach.unlockedColor.withOpacity(0.1),
                          ],
                        )
                      : null,
                  color: ach.isUnlocked ? null : const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: ach.isUnlocked
                        ? ach.unlockedColor.withOpacity(0.5)
                        : Colors.white.withOpacity(0.08),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    ach.icon,
                    color: ach.isUnlocked
                        ? ach.unlockedColor
                        : Colors.white.withOpacity(0.2),
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 名称
              Text(
                ach.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ach.isUnlocked ? Colors.white : Colors.white54,
                ),
              ),
              const SizedBox(height: 8),
              // 描述
              Text(
                ach.desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // 状态标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: ach.isUnlocked
                      ? ach.unlockedColor.withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ach.isUnlocked
                        ? ach.unlockedColor.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  ach.isUnlocked ? '✨ 已解锁' : '🔒 未解锁',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ach.isUnlocked ? ach.unlockedColor : Colors.white54,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 关闭按钮
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                child: const Text('关闭', style: TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 底部激励语
  Widget _buildMotivationFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withOpacity(0.25),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '🐾',
                style: TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '今日寄语',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _randomQuote,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 区块标题组件
  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.trending_up,
            color: Color(0xFF4CAF50),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        if (widget.onViewDetails != null)
          TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.onViewDetails!();
            },
            icon: const Icon(Icons.arrow_forward, size: 14),
            label: const Text('详情'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4CAF50),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}

// ────────────────────────── 数据模型 ──────────────────────────

class _Achievement {
  final String id;
  final String name;
  final String desc;
  final IconData icon;
  final bool isUnlocked;
  final Color unlockedColor;
  final Color lockedColor;

  const _Achievement({
    required this.id,
    required this.name,
    required this.desc,
    required this.icon,
    required this.isUnlocked,
    required this.unlockedColor,
    required this.lockedColor,
  });
}
