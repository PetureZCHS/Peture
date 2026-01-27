import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/ui_helpers.dart';

/// 训宠响片游戏页面
/// 点击屏幕中央的按钮播放点击音效
class DogClickerScreen extends StatefulWidget {
  const DogClickerScreen({super.key});

  @override
  State<DogClickerScreen> createState() => _DogClickerScreenState();
}

class _DogClickerScreenState extends State<DogClickerScreen>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AudioPlayer _audioPlayer;
  int _clickCount = 0;
  int _failCount = 0; // 失败记录次数
  bool _isPressed = false;
  bool _isCoolingDown = false; // 点击防抖标志
  int _selectedFilterIndex = 0; // 选中的筛选标签索引
  List<String> _filterOptions = ['喂食', '握手', '坐下']; // 筛选选项（改为可变列表，默认不包含"全部"）

  // 本地存储的键名
  static const String _keyPrefix = 'dog_clicker_';
  static const String _customProjectsKey = 'dog_clicker_custom_projects';

  // 各训练项目的音效映射（项目名 -> 音效文件名）
  Map<String, String> _projectSounds = {
    '喂食': 'mp3/喂食.mp3',
    '握手': 'mp3/握手.mp3',
    '坐下': 'mp3/坐下.mp3',
  };
  static const String _projectSoundsKey = 'dog_clicker_project_sounds';

  // 各训练项目的统计数据
  final Map<String, int> _successCounts = {};
  final Map<String, int> _failureCounts = {};
  int _totalSuccessCount = 0;
  int _totalFailureCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    // 初始化音频播放器
    _audioPlayer = AudioPlayer();
    // 设置为低延迟模式，确保快速响应
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    // 加载本地数据
    _loadTrainingData();
  }

  @override
  void dispose() {
    _orbController.dispose();
    // 释放音频播放器资源
    _audioPlayer.dispose();
    super.dispose();
  }

  /// 加载训练数据
  Future<void> _loadTrainingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载自定义项目
      final customProjects = prefs.getStringList(_customProjectsKey) ?? [];

      // 加载项目音效映射
      final soundsJson = prefs.getString(_projectSoundsKey);
      if (soundsJson != null) {
        final Map<String, dynamic> soundsMap = Map<String, dynamic>.from(
          Uri.splitQueryString(soundsJson),
        );
        _projectSounds = soundsMap.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      }

      setState(() {
        // 重建筛选选项：默认项目 + 自定义项目（去掉"全部"）
        _filterOptions = ['喂食', '握手', '坐下', ...customProjects];

        // 为自定义项目添加默认音效路径（如果还没有）
        for (var project in customProjects) {
          if (!_projectSounds.containsKey(project)) {
            _projectSounds[project] = 'mp3/$project.mp3';
          }
        }

        // 加载总计数
        _totalSuccessCount = prefs.getInt('${_keyPrefix}total_success') ?? 0;
        _totalFailureCount = prefs.getInt('${_keyPrefix}total_failure') ?? 0;

        // 加载各项目的成功和失败次数
        for (var option in _filterOptions) {
          _successCounts[option] =
              prefs.getInt('$_keyPrefix${option}_success') ?? 0;
          _failureCounts[option] =
              prefs.getInt('$_keyPrefix${option}_failure') ?? 0;
        }

        // 更新当前项目的计数
        _updateCurrentCounts();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('加载训练数据失败: $e');
      setState(() => _isLoading = false);
    }
  }

  /// 更新当前选中项目的计数
  void _updateCurrentCounts() {
    final currentOption = _filterOptions[_selectedFilterIndex];
    _clickCount = _successCounts[currentOption] ?? 0;
    _failCount = _failureCounts[currentOption] ?? 0;
  }

  /// 保存成功记录
  Future<void> _saveSuccessCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentOption = _filterOptions[_selectedFilterIndex];

      // 更新总计数
      _totalSuccessCount++;
      await prefs.setInt('${_keyPrefix}total_success', _totalSuccessCount);

      // 更新具体项目的计数
      _successCounts[currentOption] = (_successCounts[currentOption] ?? 0) + 1;
      await prefs.setInt(
        '$_keyPrefix${currentOption}_success',
        _successCounts[currentOption]!,
      );
    } catch (e) {
      debugPrint('保存成功记录失败: $e');
    }
  }

  /// 保存失败记录
  Future<void> _saveFailureCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentOption = _filterOptions[_selectedFilterIndex];

      // 更新总计数
      _totalFailureCount++;
      await prefs.setInt('${_keyPrefix}total_failure', _totalFailureCount);

      // 更新具体项目的计数
      _failureCounts[currentOption] = (_failureCounts[currentOption] ?? 0) + 1;
      await prefs.setInt(
        '$_keyPrefix${currentOption}_failure',
        _failureCounts[currentOption]!,
      );
    } catch (e) {
      debugPrint('保存失败记录失败: $e');
    }
  }

  /// 保存项目音效映射
  Future<void> _saveProjectSounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 将 Map 转换为简单的字符串格式保存
      final soundsString = _projectSounds.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
      await prefs.setString(_projectSoundsKey, soundsString);
    } catch (e) {
      debugPrint('保存音效映射失败: $e');
    }
  }

  /// 删除单个项目的训练记录
  Future<void> _deleteProjectRecord(String projectName) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 获取该项目的成功和失败次数
      final successCount = _successCounts[projectName] ?? 0;
      final failureCount = _failureCounts[projectName] ?? 0;

      // 从总计数中减去该项目的数据
      _totalSuccessCount -= successCount;
      _totalFailureCount -= failureCount;

      // 保存更新后的总计数
      await prefs.setInt('${_keyPrefix}total_success', _totalSuccessCount);
      await prefs.setInt('${_keyPrefix}total_failure', _totalFailureCount);

      // 删除该项目的记录
      await prefs.remove('$_keyPrefix${projectName}_success');
      await prefs.remove('$_keyPrefix${projectName}_failure');

      // 更新状态
      setState(() {
        _successCounts[projectName] = 0;
        _failureCounts[projectName] = 0;
        _updateCurrentCounts();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除「$projectName」的训练记录'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('删除项目记录失败: $e');
    }
  }

  /// 添加自定义训练项目
  Future<void> _addCustomProject(String projectName) async {
    try {
      if (projectName.trim().isEmpty) {
        return;
      }

      // 检查项目是否已存在
      if (_filterOptions.contains(projectName)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('该训练项目已存在'),
              backgroundColor: Colors.orange[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // 获取现有自定义项目
      final customProjects = prefs.getStringList(_customProjectsKey) ?? [];
      customProjects.add(projectName);

      // 保存自定义项目
      await prefs.setStringList(_customProjectsKey, customProjects);

      // 为新项目添加默认音效路径
      _projectSounds[projectName] = 'mp3/$projectName.mp3';
      await _saveProjectSounds();

      // 更新状态
      setState(() {
        _filterOptions.add(projectName);
        _successCounts[projectName] = 0;
        _failureCounts[projectName] = 0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已添加训练项目「$projectName」\n请在 assets/mp3/ 目录下添加 $projectName.mp3 音效文件',
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('添加自定义项目失败: $e');
    }
  }

  /// 删除自定义训练项目
  Future<void> _deleteCustomProject(String projectName) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 先删除该项目的训练记录
      await _deleteProjectRecord(projectName);

      // 获取现有自定义项目
      final customProjects = prefs.getStringList(_customProjectsKey) ?? [];
      customProjects.remove(projectName);

      // 保存更新后的自定义项目列表
      await prefs.setStringList(_customProjectsKey, customProjects);

      // 删除音效映射
      _projectSounds.remove(projectName);
      await _saveProjectSounds();

      // 更新状态
      setState(() {
        _filterOptions.remove(projectName);
        _successCounts.remove(projectName);
        _failureCounts.remove(projectName);

        // 如果删除的是当前选中的项目，切换到第一个项目
        if (_selectedFilterIndex >= _filterOptions.length) {
          _selectedFilterIndex = 0;
          _updateCurrentCounts();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除训练项目「$projectName」'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('删除自定义项目失败: $e');
    }
  }

  /// 显示添加自定义项目对话框
  void _showAddProjectDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      '添加训练项目',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 输入框
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 10,
                decoration: InputDecoration(
                  hintText: '例如：趴下、转圈、握爪...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFFF8F8F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF5A8EFA),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      '取消',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final projectName = controller.text.trim();
                      if (projectName.isNotEmpty) {
                        _addCustomProject(projectName);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A8EFA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      '添加',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
  }

  /// 播放点击音效
  Future<void> _playClickSound() async {
    // 冷却检查，防止连点
    if (_isCoolingDown) return;

    try {
      // 开启冷却
      setState(() => _isCoolingDown = true);
      // 250ms 后解除冷却 - 这是防误触的黄金时间窗口
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() => _isCoolingDown = false);
        }
      });

      final currentOption = _filterOptions[_selectedFilterIndex];
      final soundPath = _projectSounds[currentOption];

      if (soundPath == null) {
        debugPrint('项目 $currentOption 没有配置音效');
        return;
      }

      // 停止当前播放（如果有），确保快速重播
      await _audioPlayer.stop();
      // 播放对应项目的音频资源
      await _audioPlayer.play(AssetSource(soundPath));

      // 添加触感反馈 - 模拟真实机械响片的手感
      await HapticFeedback.heavyImpact();

      // 增加点击计数并保存
      setState(() {
        _clickCount++;
      });
      await _saveSuccessCount();
    } catch (e) {
      debugPrint('播放音效失败: $e');
      // 如果播放失败，仍然增加计数并反馈
      await HapticFeedback.mediumImpact();
      setState(() {
        _clickCount++;
      });
      await _saveSuccessCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: const Text('训宠响片',
            style: TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, size: 28),
            onPressed: () => _showStatistics(context),
            tooltip: '训练统计',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 28),
            onPressed: () => _showHelpGuide(context),
            tooltip: '训练指南',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 背景层
          Stack(
            children: [
              Container(color: AppColors.background),
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  return Positioned(
                    top: -100 + (_orbController.value * 40),
                    left: -50 + (_orbController.value * 20),
                    child: Container(
                      width: 500,
                      height: 500,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.orb1.withOpacity(0.5),
                      ),
                    ).blurred(sigmaX: 90, sigmaY: 90),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  return Positioned(
                    top: 300 + (math.sin(_orbController.value * math.pi) * 60),
                    right: -100,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.orb3.withOpacity(0.4),
                      ),
                    ).blurred(sigmaX: 80, sigmaY: 80),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  return Positioned(
                    bottom: -150,
                    left: -80 + (_orbController.value * 150),
                    child: Container(
                      width: 600,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.orb2.withOpacity(0.5),
                      ),
                    ).blurred(sigmaX: 100, sigmaY: 100),
                  );
                },
              ),
            ],
          ),

          // 内容层
          SafeArea(
            child: Column(
              children: [
                // 优化后的固定标签栏 - 更紧凑
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 5),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _filterOptions.length + 1, // +1 为添加按钮
                          itemBuilder: (context, index) {
                            // 添加按钮
                            if (index == _filterOptions.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: InkWell(
                                  onTap: _showAddProjectDialog,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F5F5)
                                          .withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE0E0E0),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.add_circle_outline,
                                      color: const Color(0xFF5A8EFA),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final isSelected = _selectedFilterIndex == index;
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedFilterIndex = index;
                                    _updateCurrentCounts();
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFF5A8EFA),
                                              Color(0xFF8B77FF),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: isSelected
                                        ? null
                                        : const Color(0xFFF5F5F5)
                                            .withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF5A8EFA,
                                              ).withOpacity(0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _filterOptions[index],
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF666666),
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // 原有的内容区域
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        // 可点击的圆形按钮 - 放大尺寸
                        Column(
                          children: [
                            // 成功标记按钮引导文案 - 简化
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.stars,
                                    color: Colors.green[700],
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '宠物成功时点击 → 立即给予奖励',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 成功按钮 - 更大尺寸
                            AnimatedScale(
                              scale: _isPressed ? 0.88 : 1.0, // 增加按压深度
                              duration:
                                  const Duration(milliseconds: 100), // 加快按压响应
                              curve: Curves.easeInOutQuad, // 更柔和的弹性曲线
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  // 冷却期间禁用点击，防止误触，且不显示水波纹
                                  onTap: _isCoolingDown
                                      ? null
                                      : () {
                                          _playClickSound(); // 发出响片声音
                                        },
                                  onTapDown: _isCoolingDown
                                      ? null
                                      : (_) {
                                          setState(() => _isPressed = true);
                                        },
                                  onTapUp: _isCoolingDown
                                      ? null
                                      : (_) {
                                          setState(() => _isPressed = false);
                                        },
                                  onTapCancel: _isCoolingDown
                                      ? null
                                      : () {
                                          setState(() => _isPressed = false);
                                        },
                                  borderRadius: BorderRadius.circular(190),
                                  splashColor: Colors.white.withOpacity(0.3),
                                  highlightColor: Colors.white.withOpacity(0.1),
                                  child: Ink(
                                    width: 380,
                                    height: 380,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF5A8EFA),
                                          Color(0xFF8B77FF),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF5A8EFA)
                                              .withOpacity(0.4),
                                          blurRadius: 30,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Click!',
                                        style: TextStyle(
                                          fontSize: 64,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 失败按钮区域 - 简化
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              // 只记录失败，不发出声音
                              setState(() => _failCount++);
                              // 失败时给予轻微震动反馈
                              await HapticFeedback.lightImpact();
                              await _saveFailureCount();
                              if (mounted) {
                                _showFailureTip(context);
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange[400]!,
                                    Colors.deepOrange[400]!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '标记失败',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // 底部统计卡片
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    Icons.check_circle_outline,
                                    '成功',
                                    _clickCount,
                                    Colors.green,
                                  ),
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: Colors.grey.withOpacity(0.2),
                                  ),
                                  _buildStatItem(
                                    Icons.refresh,
                                    '重试',
                                    _failCount,
                                    Colors.orange,
                                  ),
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: Colors.grey.withOpacity(0.2),
                                  ),
                                  _buildStatItem(
                                    Icons.trending_up,
                                    '成功率',
                                    (_clickCount + _failCount) > 0
                                        ? ((_clickCount /
                                                    (_clickCount +
                                                        _failCount)) *
                                                100)
                                            .toInt()
                                        : 0,
                                    Colors.blue,
                                    suffix: '%',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
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

  /// 显示训练统计
  void _showStatistics(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // 顶部把手
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // 标题栏 - 简化
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '训练统计',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                    ],
                  ),
                ),

                // 总体统计卡片 - 重新设计
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5A8EFA).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildOverallStat(
                            Icons.check_circle_rounded,
                            '总成功',
                            _totalSuccessCount.toString(),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        Expanded(
                          child: _buildOverallStat(
                            Icons.refresh_rounded,
                            '总重试',
                            _totalFailureCount.toString(),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        Expanded(
                          child: _buildOverallStat(
                            Icons.trending_up_rounded,
                            '成功率',
                            _totalSuccessCount + _totalFailureCount > 0
                                ? '${((_totalSuccessCount / (_totalSuccessCount + _totalFailureCount)) * 100).toStringAsFixed(0)}%'
                                : '0%',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 项目列表标题
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        '各项目详情',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_filterOptions.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 各项目统计 - 优化列表
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filterOptions.length,
                    itemBuilder: (context, index) {
                      // 重新排序：当前选中的项目排在第一位
                      String option;
                      final currentOption =
                          _filterOptions[_selectedFilterIndex];

                      // 将选中具体项目排在第一位
                      if (index == 0) {
                        option = currentOption;
                      } else {
                        // 其他项目按原顺序，跳过当前选中的
                        final otherOptions = _filterOptions
                            .where((o) => o != currentOption)
                            .toList();
                        option = otherOptions[index - 1];
                      }

                      final successCount = _successCounts[option] ?? 0;
                      final failureCount = _failureCounts[option] ?? 0;
                      final total = successCount + failureCount;
                      final successRate =
                          total > 0 ? (successCount / total * 100) : 0;

                      // 判断是否为当前选中的项目
                      final isCurrentProject = option == currentOption;

                      // 判断是否为自定义项目（不是默认的3个项目）
                      final isCustomProject = ![
                        '喂食',
                        '握手',
                        '坐下',
                      ].contains(option);

                      return Dismissible(
                        key: Key(option),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          // 显示操作选择对话框
                          return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.cleaning_services_rounded,
                                          color: Colors.orange[700],
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        '选择操作',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '「$option」',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildActionOption(
                                        context,
                                        icon: Icons.delete_outline_rounded,
                                        title: '清除训练记录',
                                        subtitle: '仅删除成功和重试次数，保留项目',
                                        color: Colors.orange,
                                        onTap: () async {
                                          Navigator.pop(context);
                                          await _deleteProjectRecord(option);
                                          setModalState(
                                            () {},
                                          ); // 刷新 BottomSheet
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      _buildActionOption(
                                        context,
                                        icon: Icons.delete_forever_rounded,
                                        title: '删除整个项目',
                                        subtitle: isCustomProject
                                            ? '删除项目及所有训练数据'
                                            : '删除默认项目及所有训练数据',
                                        color: Colors.red,
                                        onTap: () {
                                          Navigator.pop(context);
                                          _showDeleteProjectConfirm(
                                            context,
                                            option,
                                            isCustomProject,
                                            setModalState,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('取消'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (direction) {
                          // 这里不会被调用，因为 confirmDismiss 总是返回 false
                        },
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF9800), Color(0xFFFF6B6B)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cleaning_services_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              SizedBox(height: 4),
                              Text(
                                '管理',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: isCurrentProject
                                ? const BorderSide(
                                    color: Color(0xFF5A8EFA),
                                    width: 2,
                                  )
                                : BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // 项目名称标签
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: isCurrentProject
                                            ? const LinearGradient(
                                                colors: [
                                                  Color(0xFF5A8EFA),
                                                  Color(0xFF8B77FF),
                                                ],
                                              )
                                            : null,
                                        color: isCurrentProject
                                            ? null
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isCurrentProject)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                right: 6,
                                              ),
                                              child: Icon(
                                                Icons.star_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          Text(
                                            option,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: isCurrentProject
                                                  ? Colors.white
                                                  : const Color(0xFF666666),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    // 成功率百分比
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (successRate >= 70
                                                ? Colors.green
                                                : Colors.orange)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${successRate.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: successRate >= 70
                                              ? Colors.green[700]
                                              : Colors.orange[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // 数据统计
                                Row(
                                  children: [
                                    _buildCompactStat(
                                      Icons.check_circle_rounded,
                                      successCount,
                                      Colors.green,
                                      '成功',
                                    ),
                                    const SizedBox(width: 20),
                                    _buildCompactStat(
                                      Icons.refresh_rounded,
                                      failureCount,
                                      Colors.orange,
                                      '重试',
                                    ),
                                    const SizedBox(width: 20),
                                    _buildCompactStat(
                                      Icons.format_list_numbered_rounded,
                                      total,
                                      Colors.blue,
                                      '总计',
                                    ),
                                  ],
                                ),
                                if (total > 0) ...[
                                  const SizedBox(height: 12),
                                  // 进度条
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: successCount / total,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        successRate >= 70
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建紧凑型统计项
  Widget _buildCompactStat(
    IconData icon,
    int value,
    Color color,
    String label,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  /// 构建总体统计项（白色文字用于渐变背景）
  Widget _buildOverallStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 构建操作选项按钮
  Widget _buildActionOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示删除项目确认对话框
  void _showDeleteProjectConfirm(
    BuildContext context,
    String projectName,
    bool isCustomProject,
    StateSetter setModalState,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.warning_rounded,
                color: Colors.red[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('确认删除项目'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要删除「$projectName」项目吗？'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.red[700],
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isCustomProject
                          ? '此操作将永久删除项目及其所有训练数据，且无法恢复'
                          : '此操作将删除该默认项目及其所有训练数据。注意：项目本身会保留在列表中，但所有记录将被清空',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (isCustomProject) {
                await _deleteCustomProject(projectName);
              } else {
                await _deleteProjectRecord(projectName);
              }
              setModalState(() {}); // 刷新 BottomSheet
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
  }

  /// 显示失败提示
  void _showFailureTip(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '训练小贴士：永远不要惩罚，试试分解步骤或增加引导',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// 显示帮助指南对话框
  void _showHelpGuide(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部渐变标题栏
              Container(
                padding: const EdgeInsets.fromLTRB(28, 24, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6B7FBD).withOpacity(0.95),
                      const Color(0xFF8B9DC3).withOpacity(0.90),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '响片训练指南',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Clicker Training Guide',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 内容区域
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 核心概念区块
                      _buildConceptCard(
                        icon: Icons.lightbulb_rounded,
                        title: '什么是正向强化训练？',
                        content:
                            '是一种科学的训练方法，通过奖励正确行为引导宠物学习，比惩罚更有效、更人道，更好的与主人建立信任关系。',
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFFF8E1).withOpacity(0.6),
                            const Color(0xFFFFECB3).withOpacity(0.5),
                          ],
                        ),
                        iconColor: const Color(0xFF8D6E63),
                      ),

                      const SizedBox(height: 14),

                      _buildConceptCard(
                        icon: Icons.notifications_active_rounded,
                        title: '响片的作用',
                        content: '行为标记器，声音精准告诉宠物："这个动作对了！"\n点击响片 = 承诺必定给予奖励',
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFE3F2FD).withOpacity(0.6),
                            const Color(0xFFBBDEFB).withOpacity(0.5),
                          ],
                        ),
                        iconColor: const Color(0xFF5F7C8A),
                      ),

                      const SizedBox(height: 32),

                      // 分步指南
                      _buildStepGuideSection(),

                      const SizedBox(height: 28),

                      // 黄金法则
                      _buildGoldenRulesCard(),

                      const SizedBox(height: 20),

                      // 底部提示
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFF3E5F5).withOpacity(0.6),
                              const Color(0xFFE1BEE7).withOpacity(0.5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFE1BEE7).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.favorite_rounded,
                                color: const Color(0xFF8E7A9E),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                '训练是一场充满爱的旅程\n享受与宠物相处的每一刻',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: const Color(0xFF6A5D7B),
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                  letterSpacing: 0.2,
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
            ],
          ),
        ),
      ),
    );
  }

  /// 构建概念卡片
  Widget _buildConceptCard({
    required IconData icon,
    required String title,
    required String content,
    required Gradient gradient,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：图标 + 标题
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A4A4A),
                    letterSpacing: 0.2,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 第二行：描述文字（左对齐）
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B6B6B),
              height: 1.6,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建步骤式指南章节（优化排版）
  Widget _buildStepGuideSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 区块标题
        Row(
          children: [
            Container(
              width: 5,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6B7FBD).withOpacity(0.9),
                    const Color(0xFF8B9DC3).withOpacity(0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '使用步骤',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C2C2C),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF6B7FBD).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '2步',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B7FBD),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 步骤1
        _buildCompactStepCard(
          stepNumber: '01',
          title: '响片"充能"',
          description: '建立响片声 = 奖励的连接',
          steps: ['按按钮发出音效，立刻给零食', '重复直到宠物听到声音就期待', '此阶段无需宠物做任何动作'],
          color: const Color(0xFF6B7FBD),
        ),

        const SizedBox(height: 14),

        // 步骤2
        _buildCompactStepCard(
          stepNumber: '02',
          title: '开始训练',
          description: '标记正确行为并奖励',
          steps: ['每次训练5-10分钟', '宠物做对 → 立即点击按钮', '3秒内给予奖励', '标记失败后不给奖励'],
          color: const Color(0xFF8B9DC3),
        ),
      ],
    );
  }

  /// 构建紧凑型步骤卡片
  Widget _buildCompactStepCard({
    required String stepNumber,
    required String title,
    required String description,
    required List<String> steps,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.75)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  stepNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A4A4A),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9E9E9E),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 步骤列表
          ...steps.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key < steps.length - 1 ? 10 : 0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.6),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B6B6B),
                            height: 1.6,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  /// 构建黄金法则卡片
  Widget _buildGoldenRulesCard() {
    final rules = [
      {'icon': Icons.filter_1_rounded, 'text': '一次只教一个技能'},
      {'icon': Icons.volume_off_rounded, 'text': '安静无干扰的环境'},
      {'icon': Icons.celebration_rounded, 'text': '结束在成功的时刻'},
      {'icon': Icons.calendar_today_rounded, 'text': '每天坚持，勿过度'},
    ];

    Widget buildRuleItem(Map<String, Object> rule) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFFF3E0).withOpacity(0.5),
              const Color(0xFFFFE0B2).withOpacity(0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFFFCC80).withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB74D).withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                rule['icon'] as IconData,
                color: const Color(0xFF8D6E63),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                rule['text'] as String,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6D5D5D),
                  height: 1.4,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 区块标题
        Row(
          children: [
            Container(
              width: 5,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFB74D).withOpacity(0.9),
                    const Color(0xFFFF9800).withOpacity(0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '训练黄金法则',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C2C2C),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB74D).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '必读',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 法则网格 - 使用 Column + Row + Expanded 布局，确保卡片等高对齐
        Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: buildRuleItem(rules[0])),
                  const SizedBox(width: 10),
                  Expanded(child: buildRuleItem(rules[1])),
                ],
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: buildRuleItem(rules[2])),
                  const SizedBox(width: 10),
                  Expanded(child: buildRuleItem(rules[3])),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建统计项
  Widget _buildStatItem(
    IconData icon,
    String label,
    int value,
    Color color, {
    String suffix = '',
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) =>
              FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: Text(
            '$value$suffix',
            key: ValueKey<String>('$value$suffix'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
