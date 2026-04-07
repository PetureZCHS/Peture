import 'dart:io';
import 'dart:ui';
import 'package:flutter/physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
// 添加数据库助手导入
import '../../../services/supabase_service.dart';
import '../../../shared/models/pet.dart';
import '../../home/presentation/home_screen.dart'; 
import '../../../shared/widgets/weight_trend_card.dart';
import '../../../shared/utils/ui_helpers.dart';

// =========================================================
// 1. 设计系统 (升级版)
// =========================================================
class AppTheme {
  // --- Colors (Mapped to AppColors from ui_helpers) ---
  static const Color primary = AppColors.primary;
  static const Color primaryVariant = Color(0xFF8B77FF);
  static const Color background = AppColors.background;
  static const Color surface = Colors.white;
  static const Color textPrimary = AppColors.primaryText;
  static const Color textSecondary = AppColors.secondaryText;
  static const Color textTertiary = Color(0xFF8E8E93);
  static const Color lightBlue = Color(0xFFEAF2FF);
  static const Color shadow = Color(0xFFB0C4DE);
  static const Color accentGreen = Color(0xFF34D399);
  static const Color accentYellow = Color(0xFFFBBF24);
  static const Color accentYellowDark = Color(0xFFB45309);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryVariant],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Text Styles & Spacing ---
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );
  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.4,
  );
  static const TextStyle bodyText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: 0.0,
    height: 1.5,
  );
  static const TextStyle bodyTextMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0.0,
    height: 1.5,
  );
  static const TextStyle subtitleText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textTertiary,
    letterSpacing: 0.1,
    height: 1.4,
  );
  static const TextStyle captionText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textTertiary,
    letterSpacing: 0.2,
    height: 1.3,
  );
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static const double borderRadius = 20.0;
  static const double horizontalPadding = 20.0;
  static const double cardPadding = 24.0;
  static const double sectionSpacing = 32.0;
}

// =========================================================
// 2. 数据模型 (修改以添加 toMap 和 fromMap 方法)
// =========================================================
abstract class HealthEvent {
  final String date;
  HealthEvent(this.date);
}

class PetProfile {
  final int? id;
  final String name;
  final String age;
  final String breed;
  final String weight;
  final String status;
  PetProfile({
    this.id,
    required this.name,
    required this.age,
    required this.breed,
    required this.weight,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'breed': breed,
      'weight': weight,
      'status': status,
    };
  }

  factory PetProfile.fromMap(Map<String, dynamic> map) {
    return PetProfile(
      id: map['id'] as int?,
      name: map['name'] as String,
      age: map['age'] as String,
      breed: map['breed'] as String,
      weight: map['weight'] as String,
      status: map['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'breed': breed,
        'weight': weight,
        'status': status,
      };
  factory PetProfile.fromJson(Map<String, dynamic> json) {
    return PetProfile(
      name: json['name'] as String,
      age: json['age'] as String,
      breed: json['breed'] as String,
      weight: json['weight'] as String,
      status: json['status'] as String,
    );
  }
}

class MedicalRecord extends HealthEvent {
  final String? id; // 改为 String? 以支持 UUID
  final String description;
  MedicalRecord({this.id, required String date, required this.description})
      : super(date);

  Map<String, dynamic> toMap() {
    return {'id': id, 'date': date, 'description': description};
  }

  factory MedicalRecord.fromMap(Map<String, dynamic> map) {
    // 处理 id：支持 int、String 和 null，统一转换为 String
    String? id;
    if (map['id'] != null) {
      id = map['id'].toString();
    }

    return MedicalRecord(
      id: id,
      date: map['date']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'date': date, 'description': description};
  factory MedicalRecord.fromJson(Map<String, dynamic> json) {
    return MedicalRecord(date: json['date'], description: json['description']);
  }
}

class DailyReminder {
  final String? id; // 改为 String? 以支持 UUID
  final String time;
  final String task;
  DailyReminder({this.id, required this.time, required this.task});

  Map<String, dynamic> toMap() {
    return {'id': id, 'time': time, 'task': task};
  }

  factory DailyReminder.fromMap(Map<String, dynamic> map) {
    // 处理 id：支持 int、String 和 null，统一转换为 String
    String? id;
    if (map['id'] != null) {
      id = map['id'].toString();
    }

    return DailyReminder(
      id: id,
      time: map['time']?.toString() ?? '',
      task: map['task']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'time': time, 'task': task};
  factory DailyReminder.fromJson(Map<String, dynamic> json) {
    return DailyReminder(time: json['time'], task: json['task']);
  }
}

class WeightRecord extends HealthEvent {
  final String? id; // 改为 String? 以支持 UUID
  final double weight;
  final String? notes;
  WeightRecord({
    this.id,
    required String date,
    required this.weight,
    this.notes,
  }) : super(date);

  Map<String, dynamic> toMap() {
    return {'id': id, 'date': date, 'weight': weight, 'notes': notes};
  }

  factory WeightRecord.fromMap(Map<String, dynamic> map) {
    // 处理 id：支持 int、String 和 null，统一转换为 String
    String? id;
    if (map['id'] != null) {
      id = map['id'].toString();
    }

    // 处理 weight：支持 int 和 double
    double weightValue;
    if (map['weight'] is double) {
      weightValue = map['weight'] as double;
    } else if (map['weight'] is int) {
      weightValue = (map['weight'] as int).toDouble();
    } else {
      weightValue = double.tryParse(map['weight']?.toString() ?? '0') ?? 0.0;
    }

    return WeightRecord(
      id: id,
      date: map['date']?.toString() ?? '',
      weight: weightValue,
      notes: map['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'weight': weight,
        'notes': notes,
      };
  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      date: json['date'],
      weight: json['weight'],
      notes: json['notes'],
    );
  }
}

class VaccineRecord extends HealthEvent {
  final String? id; // 改为 String? 以支持 UUID
  final String type;
  final String name;
  final String nextDueDate;
  VaccineRecord({
    this.id,
    required String date,
    required this.type,
    required this.name,
    required this.nextDueDate,
  }) : super(date);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'type': type,
      'name': name,
      'nextDueDate': nextDueDate,
    };
  }

  factory VaccineRecord.fromMap(Map<String, dynamic> map) {
    // 处理 id：支持 int、String 和 null，统一转换为 String
    String? id;
    if (map['id'] != null) {
      id = map['id'].toString();
    }

    // 处理字段名：支持 camelCase 和 snake_case
    final date = map['date']?.toString() ?? '';
    final type = map['type']?.toString() ?? '';
    final name = map['name']?.toString() ?? '';
    final nextDueDate = map['nextDueDate']?.toString() ??
        map['next_due_date']?.toString() ??
        '';

    return VaccineRecord(
      id: id,
      date: date,
      type: type,
      name: name,
      nextDueDate: nextDueDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'type': type,
        'name': name,
        'nextDueDate': nextDueDate,
      };
  factory VaccineRecord.fromJson(Map<String, dynamic> json) {
    return VaccineRecord(
      date: json['date'],
      type: json['type'],
      name: json['name'],
      nextDueDate: json['nextDueDate'],
    );
  }
}

// =========================================================
// 3. App 入口 (无改动)
// =========================================================
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智宠合生 - 宠物健康档案',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: AppTheme.primary,
        scaffoldBackgroundColor: AppTheme.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppTheme.background,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: AppTheme.heading2,
          iconTheme: IconThemeData(color: AppTheme.textSecondary),
        ),
        useMaterial3: true,
      ),
      home: const MedicalRecordScreen(),
    );
  }
}

// =========================================================
// 4. 主屏幕
// =========================================================

class MedicalRecordScreen extends StatefulWidget {
  /// 刷新通知器，当值改变时触发数据刷新
  final ValueNotifier<int>? refreshNotifier;

  const MedicalRecordScreen({super.key, this.refreshNotifier});

  @override
  State<MedicalRecordScreen> createState() => _MedicalRecordScreenState();
}

class _MedicalRecordScreenState extends State<MedicalRecordScreen>
    with SingleTickerProviderStateMixin {
  // --- State variables ---
  List<Pet> _allPets = [];
  Pet? _selectedPet;
  List<MedicalRecord> _records = [];
  List<DailyReminder> _reminders = [];
  List<WeightRecord> _weightRecords = [];
  List<VaccineRecord> _vaccineRecords = [];
  List<HealthEvent> _healthLog = [];
  int _selectedTabIndex = 0;
  bool _isSelectorExpanded = false; // 新增：控制宠物选择器展开状态

  // --- Tab Animation State ---
  late AnimationController _tabController;
  double _currentPosition = 0.0;
  int _lastHapticIndex = 0;

  // 标记是否已经加载过数据（避免重复加载）
  bool _hasLoadedData = false;

  @override
  void initState() {
    super.initState();
    _tabController = AnimationController(
      vsync: this,
      lowerBound: double.negativeInfinity,
      upperBound: double.infinity,
      value: 0.0,
    );
    _tabController.addListener(() {
      setState(() {
        _currentPosition = _tabController.value;
      });
    });

    // ❌ 移除启动时的同步数据加载，改为延迟加载（避免启动卡顿）
    // 数据将在首次切换到该 tab 时加载（通过 refreshNotifier 触发）

    // 监听刷新通知
    widget.refreshNotifier?.addListener(_onRefreshRequested);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ❌ 移除重复加载，避免启动时多次请求导致卡顿
    // 改为：只在首次显示且未加载过数据时才加载
    if (!_hasLoadedData && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasLoadedData) {
          _hasLoadedData = true;
          _loadAllData();
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    widget.refreshNotifier?.removeListener(_onRefreshRequested);
    super.dispose();
  }

  void _animateToPage(int page, {double velocity = 0.0}) {
    final SpringDescription spring = SpringDescription(
      mass: 0.6,
      stiffness: 140.0,
      damping: 12.0,
    );
    final simulation = SpringSimulation(
      spring,
      _currentPosition,
      page.toDouble(),
      velocity,
    );
    _tabController.animateWith(simulation);
  }

  void _onTabTapped(int index) {
    if (_selectedTabIndex == index) return;
    _animateToPage(index);
    setState(() {
      _selectedTabIndex = index;
      _lastHapticIndex = index;
    });
    HapticFeedback.mediumImpact();
  }

  /// 当收到刷新通知时调用
  void _onRefreshRequested() {
    if (mounted) {
      _hasLoadedData = true; // 标记为已加载
      _loadAllData();
    }
  }

  // --- Data Management (使用 Supabase) ---
  final _supabaseService = SupabaseService();

  Future<void> _loadAllData() async {
    // 加载所有宠物（异步执行，不会阻塞 UI）
    final pets = await _supabaseService.getAllPets();
    if (!mounted) return; // 异步操作后检查是否仍然挂载

    // ❌ 移除 print 语句，减少日志输出导致的性能开销
    setState(() {
      _allPets = pets.map((p) => Pet.fromMap(p)).toList();

      // 设置默认选中的宠物
      if (_allPets.isNotEmpty) {
        // 如果当前没有选中的宠物，或者当前选中的宠物不在列表中，则选择第一个
        if (_selectedPet == null ||
            !_allPets.any(
                (pet) => pet.id?.toString() == _selectedPet?.id?.toString())) {
          _selectedPet = _allPets.first;
        }
      } else {
        _selectedPet = null;
      }
    });

    // 加载选中宠物的数据
    if (_selectedPet != null) {
      await _loadDataForSelectedPet();
    } else {
      // 如果没有宠物，则加载默认数据
      await _loadDefaultData();
    }
  }

  Future<void> _loadDataForSelectedPet() async {
    if (_selectedPet == null || _selectedPet!.id == null) return;

    final petId = _selectedPet!.id!;

    try {
      // 加载病历记录
      final records =
          await _supabaseService.getMedicalRecordsForPet(petId.toString());
      _records = records.map((r) {
        try {
          return MedicalRecord.fromMap(r);
        } catch (e) {
          debugPrint('解析病历记录失败: $e, 数据: $r');
          rethrow;
        }
      }).toList();

      // 加载提醒事项
      final reminders =
          await _supabaseService.getDailyRemindersForPet(petId.toString());
      _reminders = reminders.map((r) => DailyReminder.fromMap(r)).toList();

      // 加载体重记录
      final weightRecords =
          await _supabaseService.getWeightRecordsForPet(petId.toString());
      _weightRecords =
          weightRecords.map((r) => WeightRecord.fromMap(r)).toList();

      // 加载疫苗记录
      final vaccineRecords = await _supabaseService.getVaccineRecordsForPet(
        petId.toString(),
      );
      _vaccineRecords =
          vaccineRecords.map((r) => VaccineRecord.fromMap(r)).toList();

      _compileAndSortHealthLog();

      // 更新UI
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('加载宠物数据失败: $e');
      if (mounted) {
        _showErrorSnackBar('加载数据失败，请检查网络连接');
      }
    }
  }

  Future<void> _loadDefaultData() async {
    // 当数据库中没有宠物时，不加载任何测试数据
    setState(() {
      _allPets = [];
      _selectedPet = null;
      _records = [];
      _reminders = [];
      _weightRecords = [];
      _vaccineRecords = [];
      _healthLog = [];
    });
  }

  void _compileAndSortHealthLog() {
    _healthLog = [..._records, ..._weightRecords, ..._vaccineRecords];
    _healthLog.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() {});
    }
  }

  String _getLatestWeight() {
    if (_weightRecords.isEmpty) return '未记录';

    // 按日期排序，获取最新的体重记录
    final sortedWeights = [..._weightRecords];
    sortedWeights.sort((a, b) => b.date.compareTo(a.date));

    final latestWeight = sortedWeights.first;
    return '${latestWeight.weight.toStringAsFixed(1)}kg';
  }

  String _getHealthStatus() {
    if (_weightRecords.isEmpty) return '未评估';

    // 简单的体重评估逻辑
    final latestWeight = [..._weightRecords]
      ..sort((a, b) => b.date.compareTo(a.date));
    if (latestWeight.isEmpty) return '未评估';

    final weight = latestWeight.first.weight;
    if (weight < 2.0) return '偏瘦';
    if (weight > 5.0) return '偏胖';
    return '正常';
  }

  Future<void> _addRecord(MedicalRecord newRecord) async {
    HapticFeedback.mediumImpact();
    // 添加petId到新记录
    final recordMap = newRecord.toMap();
    recordMap['pet_id'] = _selectedPet?.id;

    final newId = await _supabaseService.insertMedicalRecord(recordMap);
    if (newId != null) {
      recordMap['id'] = newId;
      final recordWithPetId = MedicalRecord.fromMap(recordMap);
      _records.add(recordWithPetId);
      _compileAndSortHealthLog();
      if (mounted) _showSuccessSnackBar('病历添加成功!');
    } else {
      if (mounted) _showSuccessSnackBar('病历添加失败，请检查网络连接');
    }
  }

  Future<void> _addReminder(DailyReminder newReminder) async {
    HapticFeedback.mediumImpact();
    // 添加petId到新提醒
    final reminderMap = newReminder.toMap();
    reminderMap['pet_id'] = _selectedPet?.id;

    final newId = await _supabaseService.insertDailyReminder(reminderMap);
    if (newId != null) {
      reminderMap['id'] = newId;
      final reminderWithPetId = DailyReminder.fromMap(reminderMap);
      _reminders.add(reminderWithPetId);
      setState(() {});
      if (mounted) _showSuccessSnackBar('提醒事项添加成功!');
    } else {
      if (mounted) _showSuccessSnackBar('提醒事项添加失败，请检查网络连接');
    }
  }

  Future<void> _addWeightRecord(WeightRecord newRecord) async {
    HapticFeedback.mediumImpact();
    // 添加petId到新记录
    final recordMap = newRecord.toMap();
    recordMap['pet_id'] = _selectedPet?.id;

    final newId = await _supabaseService.insertWeightRecord(recordMap);
    if (newId != null) {
      recordMap['id'] = newId;
      final recordWithPetId = WeightRecord.fromMap(recordMap);
      setState(() {
        _weightRecords.add(recordWithPetId);
      });
      _compileAndSortHealthLog();

      // 同步更新宠物档案中的体重
      await _syncPetWeight();

      if (mounted) _showSuccessSnackBar('体重记录成功!');
    } else {
      if (mounted) _showSuccessSnackBar('体重记录失败，请检查网络连接');
    }
  }

  /// 同步更新宠物档案中的体重（使用最新的体重记录）
  Future<void> _syncPetWeight() async {
    if (_selectedPet == null || _selectedPet!.id == null) return;

    try {
      double? latestWeight;

      // 获取最新的体重记录
      if (_weightRecords.isNotEmpty) {
        final sortedWeights = [..._weightRecords];
        sortedWeights.sort((a, b) => b.date.compareTo(a.date));
        latestWeight = sortedWeights.first.weight;
      } else {
        // 如果没有体重记录，设置为 null
        latestWeight = null;
      }

      // 更新宠物档案中的体重
      final petMap = _selectedPet!.toMap();
      petMap['weight'] = latestWeight;

      debugPrint('同步宠物体重: ${_selectedPet!.name} -> $latestWeight kg');

      final success = await _supabaseService.updatePet(petMap);
      if (success) {
        debugPrint('宠物体重同步成功');
        // 更新本地宠物对象
        if (mounted) {
          setState(() {
            _selectedPet = Pet.fromMap({...petMap, 'id': _selectedPet!.id});
            // 同时更新 _allPets 列表中的对应宠物
            final petIndex =
                _allPets.indexWhere((p) => p.id == _selectedPet!.id);
            if (petIndex != -1) {
              _allPets[petIndex] = _selectedPet!;
            }
          });
        }

        // 通知全局数据变更
        DataChangeNotifier.markPetDataChanged();
      } else {
        debugPrint('宠物体重同步失败');
      }
    } catch (e) {
      debugPrint('同步宠物体重时出错: $e');
    }
  }

  Future<void> _addVaccineRecord(VaccineRecord newRecord) async {
    HapticFeedback.mediumImpact();
    // 添加petId到新记录
    final recordMap = newRecord.toMap();
    recordMap['pet_id'] = _selectedPet?.id;

    final newId = await _supabaseService.insertVaccineRecord(recordMap);
    if (newId != null) {
      recordMap['id'] = newId;
      final recordWithPetId = VaccineRecord.fromMap(recordMap);
      _vaccineRecords.add(recordWithPetId);
      _compileAndSortHealthLog();
      if (mounted) _showSuccessSnackBar('疫苗/驱虫记录成功!');
    } else {
      if (mounted) _showSuccessSnackBar('疫苗/驱虫记录失败，请检查网络连接');
    }
  }

  Future<void> _deleteRecord(MedicalRecord record) async {
    HapticFeedback.heavyImpact();
    // 注意：这里需要根据ID删除数据库中的记录
    if (record.id != null) {
      final success = await _supabaseService.deleteMedicalRecord(
        record.id.toString(),
      );
      if (success) {
        _records.remove(record);
        _compileAndSortHealthLog();
        if (mounted) _showSuccessSnackBar('病历删除成功!');
      } else {
        if (mounted) _showSuccessSnackBar('病历删除失败，请检查网络连接');
      }
    }
  }

  Future<void> _deleteWeightRecord(WeightRecord record) async {
    HapticFeedback.heavyImpact();
    if (record.id != null) {
      final success = await _supabaseService.deleteWeightRecord(
        record.id.toString(),
      );
      if (success) {
        setState(() {
          _weightRecords.remove(record);
        });
        _compileAndSortHealthLog();

        // 同步更新宠物档案中的体重（删除后使用最新的体重记录）
        await _syncPetWeight();

        if (mounted) _showSuccessSnackBar('体重记录已删除!');
      } else {
        if (mounted) _showSuccessSnackBar('体重记录删除失败，请检查网络连接');
      }
    }
  }

  Future<void> _deleteVaccineRecord(VaccineRecord record) async {
    HapticFeedback.heavyImpact();
    if (record.id != null) {
      final success = await _supabaseService.deleteVaccineRecord(
        record.id.toString(),
      );
      if (success) {
        _vaccineRecords.remove(record);
        _compileAndSortHealthLog();
        if (mounted) _showSuccessSnackBar('疫苗/驱虫记录已删除!');
      } else {
        if (mounted) _showSuccessSnackBar('疫苗/驱虫记录删除失败，请检查网络连接');
      }
    }
  }

  Future<void> _deleteReminder(int index) async {
    HapticFeedback.heavyImpact();
    final reminder = _reminders[index];
    if (reminder.id != null) {
      final success = await _supabaseService.deleteDailyReminder(
        reminder.id.toString(),
      );
      if (success) {
        _reminders.removeAt(index);
        setState(() {});
        if (mounted) _showSuccessSnackBar('提醒事项删除成功!');
      } else {
        if (mounted) _showSuccessSnackBar('提醒事项删除失败，请检查网络连接');
      }
    }
  }

  // --- 新的宠物选择器方法 ---
  void _toggleSelectorExpansion() {
    // ❌ 移除所有 print 语句，避免频繁调用时产生大量日志导致卡顿
    if (_allPets.length <= 1) {
      return;
    }
    setState(() {
      _isSelectorExpanded = !_isSelectorExpanded;
    });
  }

  void _selectNewPet(Pet newPet) {
    setState(() {
      _selectedPet = newPet;
      _isSelectorExpanded = false; // 自动折叠选择器
    });
    // 加载新宠物的数据
    _loadDataForSelectedPet();
  }

  Widget _buildExpandedPetSelector() {
    // 过滤出除当前选中宠物外的其他宠物
    // 使用 toString() 确保正确比较，并处理 null 值
    final selectedPetId = _selectedPet?.id?.toString();

    // ❌ 移除所有 print 语句，避免频繁重建时产生大量日志导致卡顿
    final availablePets = _allPets.where((pet) {
      final petId = pet.id?.toString();
      return petId != null && petId != selectedPetId;
    }).toList();

    if (availablePets.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        child: Text(
          '没有其他宠物可切换',
          style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadow.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children:
            availablePets.map((pet) => _buildPetSelectorItem(pet)).toList(),
      ),
    );
  }

  Widget _buildPetSelectorItem(Pet pet) {
    return Material(
      key: ValueKey(pet.id), // 添加唯一的 Key
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectNewPet(pet),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: _buildPetAvatarImage(
                      pet.avatar,
                      width: 48,
                      height: 48,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      style: AppTheme.bodyTextMedium.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pet.age} • ${pet.breed}',
                      style: AppTheme.captionText.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textTertiary.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetAvatarImage(
    String? avatar, {
    required double width,
    required double height,
  }) {
    if (avatar != null && avatar.isNotEmpty) {
      if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
        return Image.network(
          avatar,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPetAvatarFallback(width, height),
        );
      }
      final file = File(avatar);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPetAvatarFallback(width, height),
        );
      }
    }
    return _buildPetAvatarFallback(width, height);
  }

  Widget _buildPetAvatarFallback(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: AppColors.petTypeColors[_selectedPet?.type] ??
          AppColors.petTypeColors['其他'],
      child: Icon(
        Icons.pets,
        color: Colors.white.withOpacity(0.8),
        size: 30,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(''),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        toolbarHeight:
            0, // Hide AppBar but keep status bar handling if needed, or just remove it.
      ),
      body: _allPets.isEmpty
          ? _buildEmptyState()
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.horizontalPadding,
                    60, // Increased top padding to account for status bar/header space since AppBar is gone
                    AppTheme.horizontalPadding,
                    AppTheme.horizontalPadding +
                        80, // Add bottom padding for nav bar
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildPetProfileCard(),
                      const SizedBox(height: 20),
                      _buildRecordsAndRemindersSection(),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  // 空状态显示
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.lightBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.pets, size: 80, color: AppTheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无宠物档案',
            style: AppTheme.heading2.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            '请先在"我的"页面添加宠物档案',
            style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // --- UI 构建方法 ---
  Widget _buildPetProfileCard() {
    return Column(
      children: [
        // 主信息卡片
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 1,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.8),
                      Colors.white.withOpacity(0.4),
                    ],
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap:
                        _allPets.length > 1 ? _toggleSelectorExpansion : null,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.cardPadding),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // 宠物头像
                              Hero(
                                // Home 使用 IndexedStack，会导致不同页面的 Hero 同时存在于同一路由树
                                // 这里加页面前缀，保证 tag 在同一路由树内唯一，避免 Hero tag 冲突崩溃
                                tag: 'medical_pet_avatar_${_selectedPet?.id}',
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: _buildPetAvatarImage(
                                      _selectedPet?.avatar,
                                      width: 80,
                                      height: 80,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _selectedPet?.name ?? '未命名',
                                            style: AppTheme.heading2.copyWith(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (_allPets.length > 1) ...[
                                          const SizedBox(width: 8),
                                          AnimatedRotation(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            turns:
                                                _isSelectorExpanded ? 0.5 : 0,
                                            child: Icon(
                                              Icons.keyboard_arrow_down,
                                              color: AppTheme.textSecondary,
                                              size: 24,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          _selectedPet?.age ?? '',
                                          style: AppTheme.bodyText.copyWith(
                                            fontSize: 14,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Container(
                                            width: 1,
                                            height: 12,
                                            color: AppTheme.textSecondary
                                                .withOpacity(0.3),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            _selectedPet?.breed ?? '',
                                            style: AppTheme.bodyText.copyWith(
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            height: 1,
                            color: AppTheme.textSecondary.withOpacity(0.1),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildGradientInfoColumn(
                                  '体重',
                                  _getLatestWeight(),
                                  Icons.monitor_weight_outlined,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: AppTheme.textSecondary.withOpacity(0.1),
                              ),
                              Expanded(
                                child: _buildGradientInfoColumn(
                                  '体态',
                                  _getHealthStatus(),
                                  Icons.favorite_outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // 展开的宠物选择器
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _isSelectorExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: _buildExpandedPetSelector(),
        ),

        // 体重趋势卡片
        if (_selectedPet != null && _selectedPet!.id != null)
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: WeightTrendCard(petId: _selectedPet!.id!),
          ),
      ],
    );
  }

  Widget _buildGradientInfoColumn(String title, String value, IconData icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: AppTheme.captionText.copyWith(
            color: Colors.white.withOpacity(0.75),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.bodyTextMedium.copyWith(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordsAndRemindersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Liquid Glass Tab Bar
        LayoutBuilder(
          builder: (context, constraints) {
            final double totalWidth = constraints.maxWidth;
            final double itemWidth = totalWidth / 2;
            const double indicatorHeight = 40.0;
            const double navHeight = 56.0;

            // Use primary gradient for the indicator
            const LinearGradient currentGradient = AppTheme.primaryGradient;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final int index =
                    (details.localPosition.dx / itemWidth).floor().clamp(0, 1);
                _onTabTapped(index);
              },
              onHorizontalDragStart: (details) {
                _tabController.stop();
              },
              onHorizontalDragUpdate: (details) {
                double newPosition =
                    (details.localPosition.dx / itemWidth) - 0.5;
                setState(() {
                  _currentPosition = newPosition.clamp(0.0, 1.0);
                  _tabController.value = _currentPosition;
                });

                int potentialIndex = _currentPosition.round();
                if (potentialIndex != _lastHapticIndex) {
                  HapticFeedback.selectionClick();
                  _lastHapticIndex = potentialIndex;
                }
              },
              onHorizontalDragEnd: (details) {
                final double velocity =
                    details.velocity.pixelsPerSecond.dx / itemWidth;
                int targetIndex = _currentPosition.round();

                if (velocity.abs() > 0.3) {
                  if (velocity > 0) {
                    targetIndex = 1;
                  } else {
                    targetIndex = 0;
                  }
                }
                targetIndex = targetIndex.clamp(0, 1);
                _animateToPage(targetIndex, velocity: velocity * 1.2);

                setState(() {
                  _selectedTabIndex = targetIndex;
                  _lastHapticIndex = targetIndex;
                });
                HapticFeedback.lightImpact();
              },
              child: Container(
                height: navHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Background
                        Container(
                          width: totalWidth,
                          height: navHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            color: Colors.white.withOpacity(0.4),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                              width: 1.0,
                            ),
                          ),
                        ),

                        // Sliding Indicator
                        AnimatedBuilder(
                          animation: _tabController,
                          builder: (context, child) {
                            double velocity = 0.0;
                            if (_tabController.isAnimating) {
                              velocity = _tabController.velocity;
                            }
                            double absVelocity = velocity.abs();
                            double stretchFactor =
                                (absVelocity * 0.08).clamp(0.0, 0.4);

                            // Indicator width is slightly less than item width for padding
                            double baseIndicatorWidth = itemWidth - 8;
                            double currentWidth =
                                baseIndicatorWidth * (1 + stretchFactor);
                            double currentHeight =
                                indicatorHeight * (1 - stretchFactor * 0.2);

                            // Center position calculation
                            double centerPos = (_currentPosition * itemWidth) +
                                (itemWidth / 2);
                            double leftPos = centerPos - (currentWidth / 2);

                            return Positioned(
                              left: leftPos,
                              child: Container(
                                width: currentWidth,
                                height: currentHeight,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(currentHeight / 2),
                                  gradient: currentGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withOpacity(
                                          0.3 + (stretchFactor * 0.2)),
                                      blurRadius: 12 + (stretchFactor * 10),
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Text Labels (Overlay)
                        Row(
                          children: [
                            _buildLiquidTabItem(0, '健康日志', itemWidth),
                            _buildLiquidTabItem(1, '每日提醒', itemWidth),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // Content List
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (Widget child, Animation<double> animation) {
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slideAnimation, child: child),
            );
          },
          child: _selectedTabIndex == 0
              ? _buildHealthLogList()
              : Column(
                  children: [
                    // Add Reminder Button (Only visible in Reminders tab)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showAddReminderDialog,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppTheme.primary.withOpacity(0.3),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              color: AppTheme.primary.withOpacity(0.05),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  color: AppTheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '添加提醒',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildRemindersList(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildLiquidTabItem(int index, String title, double width) {
    return SizedBox(
      width: width,
      child: Center(
        child: AnimatedBuilder(
          animation: _tabController,
          builder: (context, child) {
            // Calculate opacity/color based on distance from current position
            double distance = (_currentPosition - index).abs();
            // 0 means selected, 1 means unselected
            double selectedness = (1.0 - distance).clamp(0.0, 1.0);

            return Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color.lerp(
                    AppTheme.textSecondary, Colors.white, selectedness),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHealthLogList() {
    return Container(
      key: const ValueKey<int>(1),
      child: Column(
        children: [
          // Add Health Record Button (Moved here)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showAddEventChoiceDialog();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: AppTheme.primary.withOpacity(0.05),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '记录健康',
                        style: AppTheme.buttonText.copyWith(
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_healthLog.isEmpty)
            const Center(
              child: _EmptyState(
                icon: Icons.history_edu_outlined,
                message: '暂无健康日志',
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < _healthLog.length; i++) ...[
                  _buildHealthEventItem(_healthLog[i], i),
                  if (i < _healthLog.length - 1)
                    const SizedBox(height: 12), // 使用间距代替分割线
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHealthEventItem(HealthEvent event, int index) {
    // 使用组合 key 确保唯一性：类型 + id + 索引
    String getUniqueKey() {
      if (event is MedicalRecord) {
        return 'medical_${event.id ?? index}';
      } else if (event is WeightRecord) {
        return 'weight_${event.id ?? index}';
      } else if (event is VaccineRecord) {
        return 'vaccine_${event.id ?? index}';
      }
      return 'event_$index';
    }

    if (event is MedicalRecord) {
      return Dismissible(
        key: ValueKey(getUniqueKey()),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete, color: Colors.white, size: 24),
        ),
        confirmDismiss: (direction) async {
          return await _showDeleteConfirmDialog('确定删除这条病历记录吗？');
        },
        onDismissed: (direction) {
          _deleteRecord(event);
        },
        child: HealthLogCard(
          icon: Icons.medical_services_outlined,
          themeColor: AppTheme.primary,
          categoryLabel: '病历记录',
          primaryData: event.description,
          date: '记录于 ${event.date}',
          onTap: () => _showEditRecordDialog(event),
        ),
      );
    }
    if (event is WeightRecord) {
      return Dismissible(
        key: ValueKey(getUniqueKey()),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete, color: Colors.white, size: 24),
        ),
        confirmDismiss: (direction) async {
          return await _showDeleteConfirmDialog('确定删除这条体重记录吗？');
        },
        onDismissed: (direction) {
          _deleteWeightRecord(event);
        },
        child: HealthLogCard(
          icon: Icons.monitor_weight_outlined,
          themeColor: AppTheme.accentGreen,
          categoryLabel: '体重记录',
          primaryData: '${event.weight.toStringAsFixed(1)} kg',
          date: '记录于 ${event.date}',
          highlightText: event.notes != null && event.notes!.isNotEmpty
              ? '备注：${event.notes}'
              : null,
          highlightIcon: Icons.notes,
          onTap: () => _showEditWeightDialog(event),
        ),
      );
    }
    if (event is VaccineRecord) {
      return Dismissible(
        key: ValueKey(getUniqueKey()),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete, color: Colors.white, size: 24),
        ),
        confirmDismiss: (direction) async {
          return await _showDeleteConfirmDialog('确定删除这条疫苗/驱虫记录吗？');
        },
        onDismissed: (direction) {
          _deleteVaccineRecord(event);
        },
        child: HealthLogCard(
          icon: Icons.vaccines_outlined,
          themeColor: AppTheme.primaryVariant,
          categoryLabel: event.type,
          primaryData: event.name,
          date: '接种于 ${event.date}',
          highlightText: '下次接种：${event.nextDueDate}',
          highlightIcon: Icons.schedule,
          onTap: () => _showEditVaccineDialog(event),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRemindersList() {
    return Container(
      key: const ValueKey<int>(2),
      child: _reminders.isEmpty
          ? const Center(
              child: _EmptyState(
                icon: Icons.alarm_on_outlined,
                message: '暂无提醒事项',
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < _reminders.length; i++) ...[
                  Dismissible(
                    key: ValueKey(
                      'reminder_dismissible_${_reminders[i].id ?? i}',
                    ),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await _showDeleteConfirmDialog('确定删除这条提醒事项吗？');
                    },
                    onDismissed: (direction) {
                      _deleteReminder(i);
                    },
                    child: _ReminderListItem(
                      key: ValueKey(_reminders[i].id ?? 'reminder_$i'),
                      reminder: _reminders[i],
                      onTap: () => _showEditReminderDialog(_reminders[i]),
                    ),
                  ),
                  if (i < _reminders.length - 1)
                    Divider(
                      key: ValueKey('reminder_divider_$i'),
                      height: 16,
                      color: AppTheme.shadow.withOpacity(0.3),
                      thickness: 0.5,
                    ),
                ],
              ],
            ),
    );
  }

  // --- Dialogs (无改动) ---
  void _showAddEventChoiceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                title: const Text('记录病历', style: AppTheme.bodyText),
                subtitle: Text('记录就诊、用药等医疗信息', style: AppTheme.subtitleText),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  _showAddRecordDialog();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.monitor_weight_outlined,
                    color: AppTheme.accentGreen,
                    size: 24,
                  ),
                ),
                title: const Text('记录体重', style: AppTheme.bodyText),
                subtitle: Text('跟踪宠物体重变化趋势', style: AppTheme.subtitleText),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  _showAddWeightDialog();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryVariant.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.vaccines_outlined,
                    color: AppTheme.primaryVariant,
                    size: 24,
                  ),
                ),
                title: const Text('记录疫苗/驱虫', style: AppTheme.bodyText),
                subtitle: Text('疫苗接种与驱虫记录管理', style: AppTheme.subtitleText),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  _showAddVaccineDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddRecordDialog() {
    final formKey = GlobalKey<FormState>();
    final dateController = TextEditingController();
    final descriptionController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新增病历'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: '日期',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      dateController.text = DateFormat(
                        'yyyy-MM-dd',
                      ).format(picked);
                    }
                  },
                  validator: (v) => v!.isEmpty ? '请选择日期' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: '病历描述'),
                  maxLines: 3,
                  validator: (v) => v!.isEmpty ? '请输入描述' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _addRecord(
                    MedicalRecord(
                      date: dateController.text,
                      description: descriptionController.text,
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showAddReminderDialog() {
    final timeController = TextEditingController();
    final taskController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新增提醒'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: timeController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: '时间',
                  prefixIcon: Icon(Icons.access_time),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) {
                    if (context.mounted) {
                      timeController.text = picked.format(context);
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: taskController,
                decoration: const InputDecoration(labelText: '任务 (例如: 喂食)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (timeController.text.isNotEmpty &&
                    taskController.text.isNotEmpty) {
                  _addReminder(
                    DailyReminder(
                      time: timeController.text,
                      task: taskController.text,
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showEditReminderDialog(DailyReminder reminder) {
    final timeController = TextEditingController(text: reminder.time);
    final taskController = TextEditingController(text: reminder.task);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑提醒'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: timeController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: '时间',
                  prefixIcon: Icon(Icons.access_time),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(
                      DateTime.now(),
                    ), // 可以解析 reminder.time 来设置初始时间
                  );
                  if (picked != null) {
                    if (context.mounted) {
                      timeController.text = picked.format(context);
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: taskController,
                decoration: const InputDecoration(labelText: '任务 (例如: 喂食)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (timeController.text.isNotEmpty &&
                    taskController.text.isNotEmpty) {
                  try {
                    final updatedReminder = DailyReminder(
                      id: reminder.id,
                      time: timeController.text,
                      task: taskController.text,
                    );

                    // 先关闭对话框
                    Navigator.of(context).pop();

                    // 更新数据库
                    if (reminder.id != null) {
                      final success = await _supabaseService
                          .updateDailyReminder(updatedReminder.toMap());
                      if (!success) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('更新失败，请检查网络连接')),
                          );
                        }
                      }
                    }

                    // 更新本地列表
                    final index = _reminders.indexWhere(
                      (r) => r.id == reminder.id,
                    );
                    if (index != -1) {
                      setState(() {
                        _reminders[index] = updatedReminder;
                      });
                      if (mounted) _showSuccessSnackBar('提醒事项更新成功!');
                    }
                  } catch (e) {
                    // 如果出错，显示错误提示
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('更新失败，请重试'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showAddWeightDialog() {
    final formKey = GlobalKey<FormState>();
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final weightController = TextEditingController();
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('记录体重'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: '日期',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      dateController.text = DateFormat(
                        'yyyy-MM-dd',
                      ).format(picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: weightController,
                  decoration: const InputDecoration(
                    labelText: '体重 (kg)',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  // 🎯 用户体验优化：点击时自动全选文本，方便快速替换数值
                  onTap: () {
                    weightController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: weightController.text.length,
                    );
                  },
                  validator: (v) {
                    if (v == null || v.isEmpty) return '请输入体重';
                    final weight = double.tryParse(v);
                    if (weight == null) return '请输入有效的数字';
                    if (weight <= 0 || weight > 100) return '请输入 0.1-100 之间的体重';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: '备注 (可选)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _addWeightRecord(
                    WeightRecord(
                      date: dateController.text,
                      weight: double.parse(weightController.text),
                      notes: notesController.text,
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showEditRecordDialog(MedicalRecord record) {
    final formKey = GlobalKey<FormState>();
    final dateController = TextEditingController(text: record.date);
    final descriptionController = TextEditingController(
      text: record.description,
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑病历'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: '日期',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.tryParse(record.date) ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      dateController.text = DateFormat(
                        'yyyy-MM-dd',
                      ).format(picked);
                    }
                  },
                  validator: (v) => v!.isEmpty ? '请选择日期' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: '病历描述'),
                  maxLines: 3,
                  validator: (v) => v!.isEmpty ? '请输入描述' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final updatedRecord = MedicalRecord(
                      id: record.id,
                      date: dateController.text,
                      description: descriptionController.text,
                    );

                    // 先关闭对话框
                    Navigator.of(context).pop();

                    // 更新数据库
                    if (record.id != null) {
                      final success = await _supabaseService
                          .updateMedicalRecord(updatedRecord.toMap());
                      if (!success) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('更新失败，请检查网络连接')),
                          );
                        }
                      }
                    }

                    // 更新本地列表
                    final index = _records.indexWhere((r) => r.id == record.id);
                    if (index != -1) {
                      setState(() {
                        _records[index] = updatedRecord;
                      });
                      _compileAndSortHealthLog();
                      if (mounted) _showSuccessSnackBar('病历更新成功!');
                    }
                  } catch (e) {
                    // 如果出错，显示错误提示
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('更新失败，请重试'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showEditWeightDialog(WeightRecord record) {
    final formKey = GlobalKey<FormState>();
    final dateController = TextEditingController(text: record.date);
    final weightController = TextEditingController(
      text: record.weight.toString(),
    );
    final notesController = TextEditingController(text: record.notes ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑体重记录'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: '日期',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.tryParse(record.date) ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      dateController.text = DateFormat(
                        'yyyy-MM-dd',
                      ).format(picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: weightController,
                  decoration: const InputDecoration(
                    labelText: '体重 (kg)',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  // 🎯 用户体验优化：点击时自动全选文本，方便快速替换数值
                  onTap: () {
                    weightController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: weightController.text.length,
                    );
                  },
                  validator: (v) {
                    if (v == null || v.isEmpty) return '请输入体重';
                    final weight = double.tryParse(v);
                    if (weight == null) return '请输入有效的数字';
                    if (weight <= 0 || weight > 100) return '请输入 0.1-100 之间的体重';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: '备注 (可选)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final updatedRecord = WeightRecord(
                      id: record.id,
                      date: dateController.text,
                      weight: double.parse(weightController.text),
                      notes: notesController.text.isEmpty
                          ? null
                          : notesController.text,
                    );

                    // 先关闭对话框
                    Navigator.of(context).pop();

                    // 更新数据库
                    if (record.id != null) {
                      final success = await _supabaseService.updateWeightRecord(
                        updatedRecord.toMap(),
                      );
                      if (!success) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('更新失败，请检查网络连接')),
                          );
                        }
                      }
                    }

                    // 更新本地列表
                    final index = _weightRecords.indexWhere(
                      (r) => r.id == record.id,
                    );
                    if (index != -1) {
                      setState(() {
                        _weightRecords[index] = updatedRecord;
                      });
                      _compileAndSortHealthLog();

                      // 同步更新宠物档案中的体重
                      await _syncPetWeight();

                      // 强制刷新UI，确保顶部体重显示更新
                      if (mounted) {
                        setState(() {});
                      }

                      if (mounted) _showSuccessSnackBar('体重记录更新成功!');
                    }
                  } catch (e) {
                    // 如果出错，显示错误提示
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('更新失败，请重试'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showEditVaccineDialog(VaccineRecord record) {
    final formKey = GlobalKey<FormState>();
    final dateController = TextEditingController(text: record.date);
    final nameController = TextEditingController(text: record.name);
    final typeController = TextEditingController(text: record.type);
    final nextDateController = TextEditingController(text: record.nextDueDate);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑疫苗/驱虫记录'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: typeController,
                    decoration: const InputDecoration(
                      labelText: '类型 (例如: 疫苗, 内驱, 外驱)',
                    ),
                    validator: (v) => v!.isEmpty ? '请输入类型' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '名称 (例如: 狂犬疫苗, 拜宠清)',
                    ),
                    validator: (v) => v!.isEmpty ? '请输入名称' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: dateController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: '接种/使用日期'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(record.date) ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        dateController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(picked);
                      }
                    },
                    validator: (v) => v!.isEmpty ? '请选择日期' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nextDateController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: '下次计划日期'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.tryParse(record.nextDueDate) ??
                            DateTime.now().add(const Duration(days: 90)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        nextDateController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(picked);
                      }
                    },
                    validator: (v) => v!.isEmpty ? '请选择下次日期' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final updatedRecord = VaccineRecord(
                      id: record.id,
                      date: dateController.text,
                      type: typeController.text,
                      name: nameController.text,
                      nextDueDate: nextDateController.text,
                    );

                    // 先关闭对话框
                    Navigator.of(context).pop();

                    // 更新数据库
                    if (record.id != null) {
                      final success = await _supabaseService
                          .updateVaccineRecord(updatedRecord.toMap());
                      if (!success) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('更新失败，请检查网络连接')),
                          );
                        }
                      }
                    }

                    // 更新本地列表
                    final index = _vaccineRecords.indexWhere(
                      (r) => r.id == record.id,
                    );
                    if (index != -1) {
                      setState(() {
                        _vaccineRecords[index] = updatedRecord;
                      });
                      _compileAndSortHealthLog();
                      if (mounted) _showSuccessSnackBar('疫苗/驱虫记录更新成功!');
                    }
                  } catch (e) {
                    // 如果出错，显示错误提示
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('更新失败，请重试'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showAddVaccineDialog() {
    final formKey = GlobalKey<FormState>();
    final dateController = TextEditingController();
    final nameController = TextEditingController();
    final typeController = TextEditingController();
    final nextDateController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('记录疫苗/驱虫'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: typeController,
                    decoration: const InputDecoration(
                      labelText: '类型 (例如: 疫苗, 内驱, 外驱)',
                    ),
                    validator: (v) => v!.isEmpty ? '请输入类型' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '名称 (例如: 狂犬疫苗, 拜宠清)',
                    ),
                    validator: (v) => v!.isEmpty ? '请输入名称' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: dateController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: '接种/使用日期'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        dateController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(picked);
                      }
                    },
                    validator: (v) => v!.isEmpty ? '请选择日期' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nextDateController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: '下次计划日期'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 90),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        nextDateController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(picked);
                      }
                    },
                    validator: (v) => v!.isEmpty ? '请选择下次日期' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _addVaccineRecord(
                    VaccineRecord(
                      date: dateController.text,
                      type: typeController.text,
                      name: nameController.text,
                      nextDueDate: nextDateController.text,
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showDeleteConfirmDialog(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认删除'),
            content: Text(message),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  '取消',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
    );
  }
}

// =========================================================
// 5. 自定义小组件
// =========================================================

// 统一的健康日志卡片组件
class HealthLogCard extends StatelessWidget {
  final IconData icon;
  final Color themeColor;
  final String categoryLabel;
  final String primaryData;
  final String date;
  final String? highlightText;
  final IconData? highlightIcon;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const HealthLogCard({
    super.key,
    required this.icon,
    required this.themeColor,
    required this.categoryLabel,
    required this.primaryData,
    required this.date,
    this.highlightText,
    this.highlightIcon,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeColor.withOpacity(0.15), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 主内容行
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 统一的圆形图标区域
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: themeColor.withOpacity(0.1),
                    child: Icon(icon, color: themeColor, size: 20),
                  ),
                  const SizedBox(width: 16),
                  // 内容区域
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题行：类别标签 + 主数据
                        Row(
                          children: [
                            Text(
                              categoryLabel,
                              style: AppTheme.captionText.copyWith(
                                color: AppTheme.textTertiary,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                primaryData,
                                style: AppTheme.bodyTextMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // 日期行
                        Text(
                          date,
                          style: AppTheme.captionText.copyWith(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 删除按钮
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: AppTheme.textTertiary.withOpacity(0.6),
                        size: 20,
                      ),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                ],
              ),
              // 高亮区域（按需显示）
              if (highlightText != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentYellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.accentYellow.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        highlightIcon ?? Icons.schedule,
                        size: 14,
                        color: AppTheme.accentYellowDark,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          highlightText!,
                          style: AppTheme.captionText.copyWith(
                            color: AppTheme.accentYellowDark,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 56.0, horizontal: 24.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.shadow.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: AppTheme.shadow.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: AppTheme.bodyTextMedium.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击上方按钮添加记录',
            style: AppTheme.captionText.copyWith(
              fontSize: 13,
              color: AppTheme.textTertiary.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderListItem extends StatelessWidget {
  final DailyReminder reminder;
  final VoidCallback onTap;
  const _ReminderListItem({
    super.key,
    required this.reminder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.alarm,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.task,
                      style: AppTheme.bodyTextMedium.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: AppTheme.primary.withOpacity(0.7),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            reminder.time,
                            style: AppTheme.captionText.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textTertiary.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
