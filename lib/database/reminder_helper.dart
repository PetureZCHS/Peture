import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// 提醒系统数据库助手
class ReminderHelper {
  static final ReminderHelper instance = ReminderHelper._init();
  static Database? _database;

  ReminderHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('reminder.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT';
    const integerType = 'INTEGER NOT NULL';

    // 驱虫提醒表
    await db.execute('''
      CREATE TABLE deworming_reminders (
        id $idType,
        pet_id $integerType,
        pet_name $textType,
        type $textType,
        brand $textNullableType,
        last_date $textType,
        next_reminder_date $textType,
        frequency $textType,
        custom_days $integerType DEFAULT 0,
        status $textType DEFAULT 'upcoming',
        created_at $textType,
        updated_at $textType
      )
    ''');

    // 疫苗提醒表
    await db.execute('''
      CREATE TABLE vaccine_reminders (
        id $idType,
        pet_id $integerType,
        pet_name $textType,
        vaccine_name $textType,
        injection_date $textType,
        dose_type $textType,
        next_due_date $textNullableType,
        notes $textNullableType,
        status $textType DEFAULT 'upcoming',
        created_at $textType,
        updated_at $textType
      )
    ''');

    // 用药记录表
    await db.execute('''
      CREATE TABLE medication_reminders (
        id $idType,
        pet_id $integerType,
        pet_name $textType,
        med_name $textType,
        dosage $textType,
        frequency_type $textType,
        frequency_details $textType,
        start_date $textType,
        end_date $textType,
        notes $textNullableType,
        status $textType DEFAULT 'active',
        created_at $textType,
        updated_at $textType
      )
    ''');

    // 用药打卡记录表
    await db.execute('''
      CREATE TABLE medication_checkmarks (
        id $idType,
        medication_id $integerType,
        check_date $textType,
        check_time $textType,
        is_completed INTEGER DEFAULT 0,
        created_at $textType
      )
    ''');
  }

  // ==================== 驱虫提醒 CRUD ====================

  /// 创建驱虫提醒
  Future<int> createDewormingReminder(Map<String, dynamic> data) async {
    final db = await instance.database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('deworming_reminders', data);
  }

  /// 读取所有驱虫提醒
  Future<List<Map<String, dynamic>>> getAllDewormingReminders() async {
    final db = await instance.database;
    return await db.query(
      'deworming_reminders',
      orderBy: 'next_reminder_date ASC',
    );
  }

  /// 更新驱虫提醒
  Future<int> updateDewormingReminder(Map<String, dynamic> data) async {
    final db = await instance.database;
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'deworming_reminders',
      data,
      where: 'id = ?',
      whereArgs: [data['id']],
    );
  }

  /// 删除驱虫提醒
  Future<int> deleteDewormingReminder(int id) async {
    final db = await instance.database;
    return await db.delete(
      'deworming_reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 完成驱虫（自动更新到下一个周期）
  Future<int> completeDewormingReminder(int id) async {
    final db = await instance.database;
    final reminder = await db.query(
      'deworming_reminders',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (reminder.isEmpty) return 0;

    final data = reminder.first;
    final frequency = data['frequency'] as String;
    final customDays = data['custom_days'] as int;
    final today = DateTime.now();

    // 计算下一次提醒日期
    DateTime nextDate;
    switch (frequency) {
      case 'monthly':
        nextDate = DateTime(today.year, today.month + 1, today.day);
        break;
      case 'quarterly':
        nextDate = DateTime(today.year, today.month + 3, today.day);
        break;
      case 'half_yearly':
        nextDate = DateTime(today.year, today.month + 6, today.day);
        break;
      case 'custom':
        nextDate = today.add(Duration(days: customDays));
        break;
      default:
        nextDate = DateTime(today.year, today.month + 1, today.day);
    }

    return await db.update(
      'deworming_reminders',
      {
        'last_date': today.toIso8601String(),
        'next_reminder_date': nextDate.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== 疫苗提醒 CRUD ====================

  /// 创建疫苗提醒
  Future<int> createVaccineReminder(Map<String, dynamic> data) async {
    final db = await instance.database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('vaccine_reminders', data);
  }

  /// 读取所有疫苗提醒
  Future<List<Map<String, dynamic>>> getAllVaccineReminders() async {
    final db = await instance.database;
    return await db.query('vaccine_reminders', orderBy: 'next_due_date ASC');
  }

  /// 更新疫苗提醒
  Future<int> updateVaccineReminder(Map<String, dynamic> data) async {
    final db = await instance.database;
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'vaccine_reminders',
      data,
      where: 'id = ?',
      whereArgs: [data['id']],
    );
  }

  /// 删除疫苗提醒
  Future<int> deleteVaccineReminder(int id) async {
    final db = await instance.database;
    return await db.delete(
      'vaccine_reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 批量创建疫苗计划（用于智能模板）
  Future<List<int>> createVaccineTemplate({
    required int petId,
    required String petName,
    required String vaccineName,
    required DateTime firstDoseDate,
    required String templateType, // 'puppy', 'kitten', 'adult'
  }) async {
    final List<int> ids = [];
    final List<Map<String, dynamic>> doses = [];

    // 根据模板类型生成疫苗计划
    if (templateType == 'puppy' || templateType == 'kitten') {
      doses.addAll([
        {
          'dose_type': 'first',
          'injection_date': firstDoseDate.toIso8601String(),
          'next_due_date': firstDoseDate
              .add(const Duration(days: 21))
              .toIso8601String(),
          'notes': '第一针',
        },
        {
          'dose_type': 'second',
          'injection_date': firstDoseDate
              .add(const Duration(days: 21))
              .toIso8601String(),
          'next_due_date': firstDoseDate
              .add(const Duration(days: 42))
              .toIso8601String(),
          'notes': '第二针',
        },
        {
          'dose_type': 'third',
          'injection_date': firstDoseDate
              .add(const Duration(days: 42))
              .toIso8601String(),
          'next_due_date': firstDoseDate
              .add(const Duration(days: 365))
              .toIso8601String(),
          'notes': '第三针',
        },
      ]);
    }

    for (final dose in doses) {
      final id = await createVaccineReminder({
        'pet_id': petId,
        'pet_name': petName,
        'vaccine_name': vaccineName,
        'injection_date': dose['injection_date'],
        'dose_type': dose['dose_type'],
        'next_due_date': dose['next_due_date'],
        'notes': dose['notes'],
        'status': 'upcoming',
      });
      ids.add(id);
    }

    return ids;
  }

  // ==================== 用药记录 CRUD ====================

  /// 创建用药记录
  Future<int> createMedicationReminder(Map<String, dynamic> data) async {
    final db = await instance.database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('medication_reminders', data);
  }

  /// 读取所有用药记录
  Future<List<Map<String, dynamic>>> getAllMedicationReminders() async {
    final db = await instance.database;
    return await db.query('medication_reminders', orderBy: 'start_date DESC');
  }

  /// 读取进行中的用药记录
  Future<List<Map<String, dynamic>>> getActiveMedicationReminders() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    return await db.query(
      'medication_reminders',
      where: 'status = ? AND start_date <= ? AND end_date >= ?',
      whereArgs: ['active', today, today],
    );
  }

  /// 更新用药记录
  Future<int> updateMedicationReminder(Map<String, dynamic> data) async {
    final db = await instance.database;
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'medication_reminders',
      data,
      where: 'id = ?',
      whereArgs: [data['id']],
    );
  }

  /// 删除用药记录
  Future<int> deleteMedicationReminder(int id) async {
    final db = await instance.database;
    // 同时删除相关的打卡记录
    await db.delete(
      'medication_checkmarks',
      where: 'medication_id = ?',
      whereArgs: [id],
    );
    return await db.delete(
      'medication_reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== 用药打卡 CRUD ====================

  /// 创建用药打卡记录
  Future<int> createMedicationCheckmark(Map<String, dynamic> data) async {
    final db = await instance.database;
    data['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('medication_checkmarks', data);
  }

  /// 获取今日用药清单
  Future<List<Map<String, dynamic>>> getTodayMedicationCheckmarks() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().split('T')[0];

    return await db.rawQuery(
      '''
      SELECT 
        mc.*,
        mr.pet_name,
        mr.med_name,
        mr.dosage,
        mr.notes
      FROM medication_checkmarks mc
      INNER JOIN medication_reminders mr ON mc.medication_id = mr.id
      WHERE mc.check_date = ?
      ORDER BY mc.check_time ASC
    ''',
      [today],
    );
  }

  /// 更新打卡状态
  Future<int> updateCheckmarkStatus(int id, bool isCompleted) async {
    final db = await instance.database;
    return await db.update(
      'medication_checkmarks',
      {'is_completed': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取指定日期的打卡记录
  Future<List<Map<String, dynamic>>> getCheckmarksByDate(
    int medicationId,
    String date,
  ) async {
    final db = await instance.database;
    return await db.query(
      'medication_checkmarks',
      where: 'medication_id = ? AND check_date = ?',
      whereArgs: [medicationId, date],
      orderBy: 'check_time ASC',
    );
  }

  /// 为用药记录生成今日打卡清单
  Future<void> generateTodayCheckmarks(int medicationId) async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().split('T')[0];

    // 查询用药记录
    final medication = await db.query(
      'medication_reminders',
      where: 'id = ?',
      whereArgs: [medicationId],
    );

    if (medication.isEmpty) return;

    final data = medication.first;
    final frequencyType = data['frequency_type'] as String;
    final frequencyDetails = data['frequency_details'] as String;

    List<String> times = [];

    if (frequencyType == 'daily') {
      // 格式: "09:00,20:00"
      times = frequencyDetails.split(',');
    } else if (frequencyType == 'every_x_hours') {
      // 格式: "8" (每8小时)
      final hours = int.parse(frequencyDetails);
      final startTime = DateTime.parse(data['start_date'] as String);
      var currentTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        startTime.hour,
      );

      while (currentTime.day == DateTime.now().day) {
        times.add('${currentTime.hour.toString().padLeft(2, '0')}:00');
        currentTime = currentTime.add(Duration(hours: hours));
      }
    }

    // 为每个时间点创建打卡记录
    for (final time in times) {
      // 检查是否已存在
      final existing = await db.query(
        'medication_checkmarks',
        where: 'medication_id = ? AND check_date = ? AND check_time = ?',
        whereArgs: [medicationId, today, time],
      );

      if (existing.isEmpty) {
        await createMedicationCheckmark({
          'medication_id': medicationId,
          'check_date': today,
          'check_time': time,
          'is_completed': 0,
        });
      }
    }
  }

  /// 关闭数据库
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
