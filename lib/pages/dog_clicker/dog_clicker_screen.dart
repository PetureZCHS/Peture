import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/skeuomorphic_clicker_device.dart';

/// 训宠响片游戏页面
/// 点击屏幕中央的按钮播放点击音效
class DogClickerScreen extends StatefulWidget {
  const DogClickerScreen({super.key});

  @override
  State<DogClickerScreen> createState() => _DogClickerScreenState();
}

class _DogClickerScreenState extends State<DogClickerScreen>
    with TickerProviderStateMixin {
  // 预设音效列表
  static const List<Map<String, String>> presetSounds = [
    {'name': '音效 1', 'path': 'mp3/1.mp3', 'emoji': '🔊'},
    {'name': '音效 2', 'path': 'mp3/2.mp3', 'emoji': '🎵'},
    {'name': '音效 3', 'path': 'mp3/3.mp3', 'emoji': '🎶'},
    {'name': '音效 4', 'path': 'mp3/4.mp3', 'emoji': '🔔'},
    {'name': '音效 5', 'path': 'mp3/5.mp3', 'emoji': '✨'},
    {'name': '音效 6', 'path': 'mp3/6.mp3', 'emoji': '🎺'},
  ];

  late AnimationController _orbController;
  late AudioPlayer _audioPlayer;
  AudioPlayer? _previewPlayer; // 音效预览播放器
  int _clickCount = 0;
  int _failCount = 0; // 失败记录次数
  int _unconfirmedCount = 0; // 未确认的点击次数
  bool _isCoolingDown = false; // 点击防抖标志
  bool _pendingConfirmation = false; // 是否处于待确认状态
  int _selectedFilterIndex = 0; // 选中的筛选标签索引
  List<String> _filterOptions = []; // 用户自定义的训练项目列表

  // 本地存储的键名
  static const String _keyPrefix = 'dog_clicker_';
  static const String _customProjectsKey = 'dog_clicker_custom_projects';

  // 各训练项目的音效映射（项目名 -> 音效文件名）
  Map<String, String> _projectSounds = {};
  static const String _projectSoundsKey = 'dog_clicker_project_sounds';

  // 各训练项目的统计数据
  final Map<String, int> _successCounts = {};
  final Map<String, int> _failureCounts = {};
  final Map<String, int> _unconfirmedCounts = {}; // 未确认计数
  int _totalSuccessCount = 0;
  int _totalFailureCount = 0;
  int _totalUnconfirmedCount = 0;
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

    // 初始化预览播放器
    _previewPlayer = AudioPlayer();
    _previewPlayer?.setReleaseMode(ReleaseMode.stop);

    // 加载本地数据
    _loadTrainingData();
  }

  @override
  void dispose() {
    _orbController.dispose();
    // 释放音频播放器资源
    _audioPlayer.dispose();
    _previewPlayer?.dispose();
    super.dispose();
  }

  /// 加载训练数据
  Future<void> _loadTrainingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载用户自定义项目
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
        // 只使用用户自定义的项目
        _filterOptions = [...customProjects];

        // 为项目添加默认音效（如果还没有）
        for (var project in _filterOptions) {
          if (!_projectSounds.containsKey(project)) {
            _projectSounds[project] = 'mp3/1.mp3';
          }
        }

        // 加载总计数
        _totalSuccessCount = prefs.getInt('${_keyPrefix}total_success') ?? 0;
        _totalFailureCount = prefs.getInt('${_keyPrefix}total_failure') ?? 0;
        _totalUnconfirmedCount =
            prefs.getInt('${_keyPrefix}total_unconfirmed') ?? 0;

        // 加载各项目的成功、失败和未确认次数
        for (var option in _filterOptions) {
          _successCounts[option] =
              prefs.getInt('$_keyPrefix${option}_success') ?? 0;
          _failureCounts[option] =
              prefs.getInt('$_keyPrefix${option}_failure') ?? 0;
          _unconfirmedCounts[option] =
              prefs.getInt('$_keyPrefix${option}_unconfirmed') ?? 0;
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
    _unconfirmedCount = _unconfirmedCounts[currentOption] ?? 0;
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
  Future<void> _addCustomProject(String projectName,
      {String? soundPath}) async {
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

      // 为新项目设置音效（使用传入的或默认第一个预设音效）
      _projectSounds[projectName] = soundPath ?? 'mp3/1.mp3';
      await _saveProjectSounds();

      // 更新状态
      setState(() {
        _filterOptions.add(projectName);
        _successCounts[projectName] = 0;
        _failureCounts[projectName] = 0;
        _unconfirmedCounts[projectName] = 0;
        // 如果是第一个项目，自动选中
        if (_filterOptions.length == 1) {
          _selectedFilterIndex = 0;
          _updateCurrentCounts();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加训练项目「$projectName」'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: '选择音效',
              textColor: Colors.white,
              onPressed: () {
                _showSoundPickerDialog(projectName);
              },
            ),
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
    String? selectedSound = 'mp3/1.mp3'; // 默认选择第一个音效
    String? errorText;
    bool isAdding = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 700),
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
                  onChanged: (value) {
                    setDialogState(() {
                      if (errorText != null) errorText = null;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: '例如：趴下、转圈、握爪...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    errorText: errorText,
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
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 1.5,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.red,
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

                // 音效选择标题
                const Text(
                  '选择音效',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 12),

                // 音效选择网格
                SizedBox(
                  height: 200,
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: presetSounds.length,
                    itemBuilder: (context, index) {
                      final sound = presetSounds[index];
                      final isSelected = selectedSound == sound['path'];

                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedSound = sound['path'];
                          });
                          _previewSound(sound['path']!);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isSelected
                                  ? [
                                      const Color(0xFF5A8EFA),
                                      const Color(0xFF8B77FF)
                                    ]
                                  : [
                                      const Color(0xFFF0F0F0),
                                      const Color(0xFFE8E8E8)
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF5A8EFA)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                sound['emoji']!,
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sound['name']!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // 按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isAdding
                          ? null
                          : () {
                              _previewPlayer?.stop();
                              Navigator.pop(context);
                            },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          color: isAdding ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: isAdding
                          ? null
                          : () async {
                              final projectName = controller.text.trim();

                              // 输入验证
                              if (projectName.isEmpty) {
                                setDialogState(() {
                                  errorText = '请输入训练项目名称';
                                });
                                HapticFeedback.lightImpact();
                                return;
                              }

                              if (_filterOptions.contains(projectName)) {
                                setDialogState(() {
                                  errorText = '该项目已存在，请使用其他名称';
                                });
                                HapticFeedback.lightImpact();
                                return;
                              }

                              // 显示加载状态
                              setDialogState(() => isAdding = true);

                              HapticFeedback.mediumImpact();
                              _previewPlayer?.stop();
                              await _addCustomProject(projectName,
                                  soundPath: selectedSound);

                              if (context.mounted) {
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
                        disabledBackgroundColor: Colors.grey[400],
                      ),
                      child: isAdding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
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
      ),
    );
  }

  /// 预览音效
  Future<void> _previewSound(String soundPath) async {
    try {
      await _previewPlayer?.stop();
      await _previewPlayer?.play(AssetSource(soundPath));
      await HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('预览音效失败: $e');
    }
  }

  /// 显示音效选择器
  void _showSoundPickerDialog(String projectName) {
    final currentSound = _projectSounds[projectName] ?? 'mp3/1.mp3';
    String? selectedSound = currentSound;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5A8EFA), Color(0xFF8B77FF)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '选择音效 - $projectName',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '点击试听，选择喜欢的音效',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 音效列表
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: presetSounds.length,
                    itemBuilder: (context, index) {
                      final sound = presetSounds[index];
                      final isSelected = selectedSound == sound['path'];

                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedSound = sound['path'];
                          });
                          _previewSound(sound['path']!);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isSelected
                                  ? [
                                      const Color(0xFF5A8EFA),
                                      const Color(0xFF8B77FF)
                                    ]
                                  : [
                                      const Color(0xFF3A3A3A),
                                      const Color(0xFF2D2D2D)
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                sound['emoji']!,
                                style: const TextStyle(fontSize: 40),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                sound['name']!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '已选择',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // 按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        _previewPlayer?.stop();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (selectedSound != null) {
                          setState(() {
                            _projectSounds[projectName] = selectedSound!;
                          });
                          await _saveProjectSounds();
                          _previewPlayer?.stop();
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已为「$projectName」设置新音效'),
                                backgroundColor: Colors.green[700],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }
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
                        '确定',
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
      ),
    );
  }

  /// 显示滑动删除确认
  Future<bool?> _showDeleteConfirmation(String projectName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange[700], size: 28),
            const SizedBox(width: 12),
            const Text('确认删除'),
          ],
        ),
        content: Text(
          '确定要删除「$projectName」吗？\n所有训练记录将被永久删除。',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _deleteCustomProject(projectName);
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 显示删除训练项目确认对话框
  void _showDeleteProjectDialog(String projectName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3A3A3A)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 警告图标
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              // 标题
              const Text(
                '删除训练项目',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              // 提示文字
              Text(
                '确定要删除「$projectName」吗？\n所有训练记录将被永久删除。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // 按钮
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deleteCustomProject(projectName);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        '删除',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
  }

  /// 显示重置确认对话框
  void _showResetConfirmDialog() {
    final currentProject = _filterOptions[_selectedFilterIndex];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3A3A3A)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withOpacity(0.3),
                      Colors.red.withOpacity(0.3),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.orange,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              // 标题
              const Text(
                '重置训练数据',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // 描述
              Text(
                '确定要重置「$currentProject」的训练数据吗？\n此操作不可恢复。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // 按钮
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side:
                              BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _resetCurrentProjectData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '确定重置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
  }

  /// 重置当前项目数据
  Future<void> _resetCurrentProjectData() async {
    final currentProject = _filterOptions[_selectedFilterIndex];
    await _deleteProjectRecord(currentProject);

    setState(() {
      _clickCount = 0;
      _failCount = 0;
    });
  }

  /// 显示详细统计数据
  void _showDetailedStatistics() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 拖拽条
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 标题
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.analytics_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '训练统计',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '查看所有训练项目的详细数据',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 总体统计卡片
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildOverallStatsCard(),
              ),

              const SizedBox(height: 16),

              // 各项目统计列表
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filterOptions.length,
                  itemBuilder: (context, index) {
                    final project = _filterOptions[index];
                    final success = _successCounts[project] ?? 0;
                    final failure = _failureCounts[project] ?? 0;
                    final total = success + failure;
                    final rate = total > 0 ? (success / total * 100) : 0.0;
                    final isSelected = index == _selectedFilterIndex;

                    return Dismissible(
                      key: Key(project),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        HapticFeedback.mediumImpact();
                        return await _showDeleteConfirmation(project);
                      },
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        child: const Icon(
                          Icons.delete_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedFilterIndex = index;
                          });
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isSelected
                                  ? [
                                      const Color(0xFF3A3A3A),
                                      const Color(0xFF2D2D2D)
                                    ]
                                  : [
                                      const Color(0xFF2D2D2D),
                                      const Color(0xFF252525)
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF4CAF50).withOpacity(0.5)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // 项目名称
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          project,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? const Color(0xFF4CAF50)
                                                : Colors.white,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4CAF50)
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              '当前',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF4CAF50),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // 音效选择按钮
                                  IconButton(
                                    icon: const Icon(Icons.music_note_rounded),
                                    color: Colors.white70,
                                    iconSize: 20,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.pop(context);
                                      _showSoundPickerDialog(project);
                                    },
                                    tooltip: '选择音效',
                                  ),
                                  // 删除按钮
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded),
                                    color: Colors.red.withOpacity(0.7),
                                    iconSize: 20,
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      Navigator.pop(context);
                                      _showDeleteProjectDialog(project);
                                    },
                                    tooltip: '删除训练项目',
                                  ),
                                  // 成功率
                                  Text(
                                    '${rate.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: rate >= 70
                                          ? const Color(0xFF4CAF50)
                                          : rate >= 40
                                              ? const Color(0xFFFFC107)
                                              : const Color(0xFFFF5722),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // 进度条
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: rate / 100,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.1),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    rate >= 70
                                        ? const Color(0xFF4CAF50)
                                        : rate >= 40
                                            ? const Color(0xFFFFC107)
                                            : const Color(0xFFFF5722),
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // 详细数据
                              Row(
                                children: [
                                  _buildStatItem(
                                    icon: Icons.check_circle_outline,
                                    label: '成功',
                                    value: success.toString(),
                                    color: const Color(0xFF4CAF50),
                                  ),
                                  const SizedBox(width: 20),
                                  _buildStatItem(
                                    icon: Icons.replay,
                                    label: '重试',
                                    value: failure.toString(),
                                    color: const Color(0xFFFF9800),
                                  ),
                                  const SizedBox(width: 20),
                                  _buildStatItem(
                                    icon: Icons.touch_app,
                                    label: '总次数',
                                    value: total.toString(),
                                    color: const Color(0xFF2196F3),
                                  ),
                                ],
                              ),
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
        ),
      ),
    );
  }

  /// 构建总体统计卡片
  Widget _buildOverallStatsCard() {
    final totalClicks = _totalSuccessCount + _totalFailureCount;
    final overallRate =
        totalClicks > 0 ? (_totalSuccessCount / totalClicks * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverallStatColumn(
                icon: Icons.emoji_events_rounded,
                label: '总成功',
                value: _totalSuccessCount.toString(),
                color: const Color(0xFF4CAF50),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.1),
              ),
              _buildOverallStatColumn(
                icon: Icons.replay_rounded,
                label: '总重试',
                value: _totalFailureCount.toString(),
                color: const Color(0xFFFF9800),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white.withOpacity(0.1),
              ),
              _buildOverallStatColumn(
                icon: Icons.insights_rounded,
                label: '综合成功率',
                value: '${overallRate.toStringAsFixed(0)}%',
                color: overallRate >= 70
                    ? const Color(0xFF4CAF50)
                    : overallRate >= 40
                        ? const Color(0xFFFFC107)
                        : const Color(0xFFFF5722),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建总体统计列
  Widget _buildOverallStatColumn({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  /// 构建统计项
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 响片点击 - 只播放声音和触觉反馈，进入待确认状态
  Future<void> _handleClickerClick() async {
    // 冷却检查，防止连点
    if (_isCoolingDown || _pendingConfirmation) return;

    try {
      // 开启冷却
      setState(() {
        _isCoolingDown = true;
        _pendingConfirmation = true; // 进入待确认状态
      });

      // 250ms 后解除冷却
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

      // 添加强力触感反馈 - 模拟真实机械响片的手感
      await HapticFeedback.heavyImpact();

      // 不立即计数，等待用户确认
    } catch (e) {
      debugPrint('播放音效失败: $e');
      // 即使播放失败，也给予触觉反馈
      await HapticFeedback.mediumImpact();
    }
  }

  /// 确认成功
  Future<void> _handleConfirmSuccess() async {
    if (!_pendingConfirmation) return;

    setState(() {
      _clickCount++;
      _pendingConfirmation = false;
    });
    await _saveSuccessCount();

    // 轻微的成功触觉反馈
    await HapticFeedback.lightImpact();
  }

  /// 确认失败
  Future<void> _handleConfirmFail() async {
    if (!_pendingConfirmation) return;

    setState(() {
      _failCount++;
      _pendingConfirmation = false;
    });
    await _saveFailureCount();

    // 触觉反馈
    await HapticFeedback.mediumImpact();

    if (mounted) {
      _showFailureTip(context);
    }
  }

  /// 跳过确认（记为未确认）
  Future<void> _handleSkipConfirm() async {
    if (!_pendingConfirmation) return;

    setState(() {
      _unconfirmedCount++;
      _pendingConfirmation = false;
    });
    await _saveUnconfirmedCount();

    await HapticFeedback.lightImpact();
  }

  /// 保存未确认计数
  Future<void> _saveUnconfirmedCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentOption = _filterOptions[_selectedFilterIndex];

      // 更新总计数
      _totalUnconfirmedCount++;
      await prefs.setInt(
          '${_keyPrefix}total_unconfirmed', _totalUnconfirmedCount);

      // 更新具体项目的计数
      _unconfirmedCounts[currentOption] =
          (_unconfirmedCounts[currentOption] ?? 0) + 1;
      await prefs.setInt(
        '$_keyPrefix${currentOption}_unconfirmed',
        _unconfirmedCounts[currentOption]!,
      );
    } catch (e) {
      debugPrint('保存未确认记录失败: $e');
    }
  }

  /// 播放点击音效（保留旧方法用于兼容）
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

          // 内容层 - 简化为直接显示设备
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 如果没有项目，显示空状态引导
                    if (_filterOptions.isEmpty) ...[
                      _buildEmptyState(),
                    ] else ...[
                      // 新手提示（呼吸感文字）
                      if (!_pendingConfirmation) _buildTrainingTip(),
                      // 待确认状态提示
                      if (_pendingConfirmation) _buildConfirmationTip(),
                      const SizedBox(height: 12),
                      // 拟物化响片设备（包含项目选择和统计）
                      SkeuomorphicClickerDevice(
                        successCount: _clickCount,
                        failCount: _failCount,
                        unconfirmedCount: _unconfirmedCount,
                        totalSuccessCount: _totalSuccessCount,
                        totalFailCount: _totalFailureCount,
                        currentProject: _filterOptions[_selectedFilterIndex],
                        projects: _filterOptions,
                        selectedIndex: _selectedFilterIndex,
                        // 新流程的回调
                        onClick: _handleClickerClick,
                        onConfirmSuccess: _handleConfirmSuccess,
                        onConfirmFail: _handleConfirmFail,
                        onSkipConfirm: _handleSkipConfirm,
                        pendingConfirmation: _pendingConfirmation,
                        // 保留旧的回调用于兼容
                        onSuccess: _playClickSound,
                        onFail: () async {
                          setState(() => _failCount++);
                          await HapticFeedback.lightImpact();
                          await _saveFailureCount();
                          if (mounted) {
                            _showFailureTip(context);
                          }
                        },
                        onProjectChanged: (index) {
                          // 如果正在待确认状态，先取消
                          if (_pendingConfirmation) {
                            _handleSkipConfirm();
                          }
                          setState(() {
                            _selectedFilterIndex = index;
                            _updateCurrentCounts();
                          });
                        },
                        onAddProject: _showAddProjectDialog,
                        onDeleteProject: _deleteCustomProject,
                        onReset: _showResetConfirmDialog,
                        onShowStats: _showDetailedStatistics,
                        isCoolingDown: _isCoolingDown,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 新手提示 - 呼吸感文字
  Widget _buildTrainingTip() {
    return AnimatedBuilder(
      animation: _orbController,
      builder: (context, child) {
        // 使用 sin 函数创建平滑的呼吸效果
        final breathValue =
            0.5 + 0.5 * math.sin(_orbController.value * math.pi * 2);
        return Opacity(
          opacity: 0.5 + breathValue * 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  color: Colors.white.withOpacity(0.5),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '在它做对的那一秒，按下快门（响片）',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 待确认状态提示
  Widget _buildConfirmationTip() {
    return AnimatedBuilder(
      animation: _orbController,
      builder: (context, child) {
        // 脉冲效果
        final pulseValue =
            0.5 + 0.5 * math.sin(_orbController.value * math.pi * 6);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4CAF50).withOpacity(0.15),
                const Color(0xFFFF9800).withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 脉冲指示器
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4CAF50)
                      .withOpacity(0.5 + pulseValue * 0.5),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF4CAF50).withOpacity(pulseValue * 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '它做到了吗？请确认结果',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A1A1A),
                Color(0xFF0F0F0F),
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // 顶部拖拽条
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题栏
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    // 图标
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 标题
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '响片训练指南',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Professional Clicker Training',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 关闭按钮
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 内容区域
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // 核心理念卡片
                    _buildDarkConceptCard(
                      icon: Icons.psychology_rounded,
                      iconGradient: const [
                        Color(0xFF7C4DFF),
                        Color(0xFFB388FF)
                      ],
                      title: '正向强化训练',
                      subtitle: 'Positive Reinforcement',
                      content: '科学证明最有效的训练方法，通过奖励正确行为引导宠物学习，建立深厚的信任关系。',
                    ),
                    const SizedBox(height: 12),
                    _buildDarkConceptCard(
                      icon: Icons.touch_app_rounded,
                      iconGradient: const [
                        Color(0xFF4CAF50),
                        Color(0xFF8BC34A)
                      ],
                      title: '响片的作用',
                      subtitle: 'Clicker Function',
                      content: '精准的行为标记器。清脆的声音告诉宠物："做对了！"每次点击都是奖励的承诺。',
                    ),

                    const SizedBox(height: 28),

                    // 使用步骤
                    _buildSectionHeader(
                      title: '使用步骤',
                      subtitle: 'STEPS',
                      color: const Color(0xFF2196F3),
                    ),
                    const SizedBox(height: 16),
                    _buildDarkStepCard(
                      step: 1,
                      title: '响片充能',
                      subtitle: '建立条件反射',
                      duration: '2-3天',
                      steps: [
                        '按响片 → 立刻给零食',
                        '重复10-15次',
                        '观察：听到声音是否期待',
                      ],
                      color: const Color(0xFF2196F3),
                    ),
                    const SizedBox(height: 12),
                    _buildDarkStepCard(
                      step: 2,
                      title: '开始训练',
                      subtitle: '标记正确行为',
                      duration: '每次5-10分钟',
                      steps: [
                        '等待或引导目标行为',
                        '行为发生瞬间 → 点击',
                        '3秒内给予奖励',
                      ],
                      color: const Color(0xFF00BCD4),
                    ),

                    const SizedBox(height: 28),

                    // 黄金法则
                    _buildSectionHeader(
                      title: '训练黄金法则',
                      subtitle: 'GOLDEN RULES',
                      color: const Color(0xFFFFB74D),
                    ),
                    const SizedBox(height: 16),
                    _buildGoldenRulesGrid(),

                    const SizedBox(height: 28),

                    // Pro Tips
                    _buildSectionHeader(
                      title: '专业小贴士',
                      subtitle: 'PRO TIPS',
                      color: const Color(0xFFE91E63),
                    ),
                    const SizedBox(height: 16),
                    _buildProTipsCard(),

                    const SizedBox(height: 24),

                    // 底部鼓励
                    _buildMotivationCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 深色概念卡片
  Widget _buildDarkConceptCard({
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required String subtitle,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图标
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: iconGradient),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: iconGradient[0].withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          // 内容
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
                    fontSize: 10,
                    color: iconGradient[0].withOpacity(0.8),
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 区块标题
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.4)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.8),
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 深色步骤卡片
  Widget _buildDarkStepCard({
    required int step,
    required String title,
    required String subtitle,
    required String duration,
    required List<String> steps,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              // 步骤编号
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$step',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // 标题
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
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // 时长标签
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, color: color, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      duration,
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 步骤列表
          ...steps.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: entry.key < steps.length - 1 ? 10 : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 黄金法则网格
  Widget _buildGoldenRulesGrid() {
    final rules = [
      {
        'icon': Icons.looks_one_rounded,
        'text': '一次只教一个',
        'color': const Color(0xFFFF9800)
      },
      {
        'icon': Icons.volume_off_rounded,
        'text': '安静的环境',
        'color': const Color(0xFF9C27B0)
      },
      {
        'icon': Icons.emoji_events_rounded,
        'text': '结束在成功',
        'color': const Color(0xFF4CAF50)
      },
      {
        'icon': Icons.timer_rounded,
        'text': '短时多次',
        'color': const Color(0xFF2196F3)
      },
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: rules.map((rule) {
        final color = rule['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                rule['icon'] as IconData,
                color: color,
                size: 26,
              ),
              const SizedBox(height: 8),
              Text(
                rule['text'] as String,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Pro Tips 卡片
  Widget _buildProTipsCard() {
    final tips = [
      '🎯 时机比奖励更重要，行为发生的瞬间点击',
      '🍖 使用高价值零食，如鸡肉干、奶酪',
      '😊 保持愉快心情，狗狗能感受到你的情绪',
      '🔄 失败了？回到上一个成功的步骤重来',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE91E63).withOpacity(0.1),
            const Color(0xFF9C27B0).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.2),
        ),
      ),
      child: Column(
        children: tips.asMap().entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: entry.key < tips.length - 1 ? 14 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.value.substring(0, 2),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value.substring(2).trim(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 底部鼓励卡片
  Widget _buildMotivationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // 狗爪图标
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('🐾', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '训练是一场充满爱的旅程',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '享受与毛孩子相处的每一刻 ❤️',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 空状态引导页面
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图标
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF5A8EFA).withOpacity(0.3),
                  const Color(0xFF8B77FF).withOpacity(0.3),
                ],
              ),
            ),
            child: const Icon(
              Icons.pets_rounded,
              size: 60,
              color: Color(0xFF5A8EFA),
            ),
          ),
          const SizedBox(height: 24),

          // 标题
          const Text(
            '开始训练之旅',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // 描述
          Text(
            '创建你的第一个训练项目\n为每个动作选择独特的音效',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.7),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),

          // 添加按钮
          ElevatedButton.icon(
            onPressed: _showAddProjectDialog,
            icon: const Icon(Icons.add_circle_outline, size: 24),
            label: const Text(
              '添加训练项目',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A8EFA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
          const SizedBox(height: 24),

          // 示例提示
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFFFFC107),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '例如：坐下、趴下、握手、转圈...',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
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
}
