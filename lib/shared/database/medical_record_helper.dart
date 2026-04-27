import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicalRecordHelper {
  // 单例模式
  static final MedicalRecordHelper instance = MedicalRecordHelper._init();
  static Database? _database;

  MedicalRecordHelper._init();

  // 获取数据库实例
  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite is not supported on Web. Use getAllPets() instead.',
      );
    }
    if (_database != null) return _database!;
    _database = await _initDB('medical_records.db');
    return _database!;
  }

  // 初始化数据库 - 升级版本号到 4
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4, // 升级到版本4
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // 从 v1 升级到 v2：添加 pets 表
          await db.execute('''
            CREATE TABLE IF NOT EXISTS pets (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type TEXT NOT NULL,
              name TEXT NOT NULL,
              age TEXT NOT NULL,
              gender TEXT NOT NULL,
              breed TEXT NOT NULL
            )
          ''');
        }

        if (oldVersion < 3) {
          // 从 v2 升级到 v3：为 medical_records 和 daily_reminders 表添加 pet_id 列
          // 由于 SQLite 不支持直接添加列，我们需要重新创建表
          await _migrateToVersion3(db);
        }

        if (oldVersion < 4) {
          // 从 v3 升级到 v4：继续为其他表添加 pet_id 列
          await _migrateToVersion4(db);
        }
      },
    );
  }

  // 迁移到版本3
  Future<void> _migrateToVersion3(Database db) async {
    // 为 medical_records 表添加 pet_id 列
    await db.execute('''
      CREATE TABLE medical_records_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        description TEXT NOT NULL,
        pet_id INTEGER
      )
    ''');

    await db.execute('''
      INSERT INTO medical_records_new (id, date, description)
      SELECT id, date, description FROM medical_records
    ''');

    await db.execute('DROP TABLE medical_records');
    await db.execute(
      'ALTER TABLE medical_records_new RENAME TO medical_records',
    );

    // 为 daily_reminders 表添加 pet_id 列
    await db.execute('''
      CREATE TABLE daily_reminders_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        time TEXT NOT NULL,
        task TEXT NOT NULL,
        pet_id INTEGER
      )
    ''');

    await db.execute('''
      INSERT INTO daily_reminders_new (id, time, task)
      SELECT id, time, task FROM daily_reminders
    ''');

    await db.execute('DROP TABLE daily_reminders');
    await db.execute(
      'ALTER TABLE daily_reminders_new RENAME TO daily_reminders',
    );
  }

  // 迁移到版本4
  Future<void> _migrateToVersion4(Database db) async {
    // 为 weight_records 表添加 pet_id 列
    await db.execute('''
      CREATE TABLE weight_records_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        weight REAL NOT NULL,
        notes TEXT,
        pet_id INTEGER
      )
    ''');

    await db.execute('''
      INSERT INTO weight_records_new (id, date, weight, notes)
      SELECT id, date, weight, notes FROM weight_records
    ''');

    await db.execute('DROP TABLE weight_records');
    await db.execute('ALTER TABLE weight_records_new RENAME TO weight_records');

    // 为 vaccine_records 表添加 pet_id 列
    await db.execute('''
      CREATE TABLE vaccine_records_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        nextDueDate TEXT NOT NULL,
        pet_id INTEGER
      )
    ''');

    await db.execute('''
      INSERT INTO vaccine_records_new (id, date, type, name, nextDueDate)
      SELECT id, date, type, name, nextDueDate FROM vaccine_records
    ''');

    await db.execute('DROP TABLE vaccine_records');
    await db.execute(
      'ALTER TABLE vaccine_records_new RENAME TO vaccine_records',
    );
  }

  // 创建所有数据表（首次安装时调用）
  Future _createDB(Database db, int version) async {
    // 原有表（可保留或删除）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pet_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        age TEXT NOT NULL,
        breed TEXT NOT NULL,
        weight TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS medical_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        description TEXT NOT NULL,
        pet_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        time TEXT NOT NULL,
        task TEXT NOT NULL,
        pet_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS weight_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        weight REAL NOT NULL,
        notes TEXT,
        pet_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS vaccine_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        nextDueDate TEXT NOT NULL,
        pet_id INTEGER
      )
    ''');

    // 确保 pets 表在首次创建时也存在
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        age TEXT NOT NULL,
        gender TEXT NOT NULL,
        breed TEXT NOT NULL
      )
    ''');
  }

  // ==================== Pets ====================
  Future<int> insertPet(Map<String, dynamic> pet) async {
    if (kIsWeb) {
      // Web 平台：使用 SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final petsJson = prefs.getString('pets') ?? '[]';
        final List<dynamic> pets = jsonDecode(petsJson);

        int newId = 1;
        if (pets.isNotEmpty) {
          newId = (pets.last['id'] as int) + 1;
        }

        pet['id'] = newId;
        pets.add(pet);

        await prefs.setString('pets', jsonEncode(pets));
        return newId;
      } catch (e) {
        debugPrint('Error inserting pet in Web: $e');
        return -1;
      }
    } else {
      // 移动/桌面平台：使用 SQLite
      final db = await database;
      return await db.insert('pets', pet);
    }
  }

  Future<List<Map<String, dynamic>>> getAllPets() async {
    if (kIsWeb) {
      // Web 平台：从 SharedPreferences 读取
      try {
        final prefs = await SharedPreferences.getInstance();
        final petsJson = prefs.getString('pets') ?? '[]';
        final List<dynamic> pets = jsonDecode(petsJson);
        return pets.cast<Map<String, dynamic>>();
      } catch (e) {
        debugPrint('Error getting all pets in Web: $e');
        return [];
      }
    } else {
      // 移动/桌面平台：使用 SQLite
      final db = await database;
      return await db.query('pets');
    }
  }

  Future<int> deletePet(int id) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final petsJson = prefs.getString('pets') ?? '[]';
        final List<dynamic> pets = jsonDecode(petsJson);

        final initialLength = pets.length;
        pets.removeWhere((pet) => pet['id'] == id);

        await prefs.setString('pets', jsonEncode(pets));
        return initialLength - pets.length;
      } catch (e) {
        debugPrint('Error deleting pet in Web: $e');
        return 0;
      }
    } else {
      final db = await database;
      return await db.delete('pets', where: 'id = ?', whereArgs: [id]);
    }
  }

  // 补全 updatePet 方法
  Future<int> updatePet(Map<String, dynamic> pet) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final petsJson = prefs.getString('pets') ?? '[]';
        final List<dynamic> pets = jsonDecode(petsJson);

        final index = pets.indexWhere((p) => p['id'] == pet['id']);
        if (index >= 0) {
          pets[index] = pet;
          await prefs.setString('pets', jsonEncode(pets));
          return 1;
        }
        return 0;
      } catch (e) {
        debugPrint('Error updating pet in Web: $e');
        return 0;
      }
    } else {
      final db = await database;
      final id = pet['id'];
      if (id == null) {
        throw ArgumentError('Pet ID cannot be null when updating.');
      }

      // 创建一个不包含 id 的更新映射，避免更新主键
      final updateMap = Map<String, dynamic>.from(pet);
      updateMap.remove('id');

      return await db.update(
        'pets',
        updateMap,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // ==================== Medical Records ====================
  Future<int> insertMedicalRecord(Map<String, dynamic> record) async {
    final db = await database;
    return await db.insert('medical_records', record);
  }

  Future<List<Map<String, dynamic>>> getAllMedicalRecords() async {
    final db = await database;
    return await db.query('medical_records', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getMedicalRecordsForPet(int petId) async {
    final db = await database;
    return await db.query(
      'medical_records',
      where: 'pet_id = ?',
      whereArgs: [petId],
      orderBy: 'date DESC',
    );
  }

  Future<int> deleteMedicalRecord(int id) async {
    final db = await database;
    return await db.delete('medical_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateMedicalRecord(Map<String, dynamic> record) async {
    final db = await database;
    final id = record['id'];
    if (id == null) {
      throw ArgumentError('Medical record ID cannot be null when updating.');
    }

    final updateMap = Map<String, dynamic>.from(record);
    updateMap.remove('id');

    return await db.update(
      'medical_records',
      updateMap,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Daily Reminders ====================
  Future<int> insertDailyReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    return await db.insert('daily_reminders', reminder);
  }

  Future<List<Map<String, dynamic>>> getAllDailyReminders() async {
    final db = await database;
    return await db.query('daily_reminders');
  }

  Future<List<Map<String, dynamic>>> getDailyRemindersForPet(int petId) async {
    final db = await database;
    return await db.query(
      'daily_reminders',
      where: 'pet_id = ?',
      whereArgs: [petId],
    );
  }

  Future<int> deleteDailyReminder(int id) async {
    final db = await database;
    return await db.delete('daily_reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateDailyReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    final id = reminder['id'];
    if (id == null) {
      throw ArgumentError('Daily reminder ID cannot be null when updating.');
    }

    final updateMap = Map<String, dynamic>.from(reminder);
    updateMap.remove('id');

    return await db.update(
      'daily_reminders',
      updateMap,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Weight Records ====================
  Future<int> insertWeightRecord(Map<String, dynamic> record) async {
    final db = await database;
    return await db.insert('weight_records', record);
  }

  Future<List<Map<String, dynamic>>> getAllWeightRecords() async {
    final db = await database;
    return await db.query('weight_records', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getWeightRecordsForPet(int petId) async {
    final db = await database;
    return await db.query(
      'weight_records',
      where: 'pet_id = ?',
      whereArgs: [petId],
      orderBy: 'date DESC',
    );
  }

  Future<int> deleteWeightRecord(int id) async {
    final db = await database;
    return await db.delete('weight_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateWeightRecord(Map<String, dynamic> record) async {
    final db = await database;
    final id = record['id'];
    if (id == null) {
      throw ArgumentError('Weight record ID cannot be null when updating.');
    }

    final updateMap = Map<String, dynamic>.from(record);
    updateMap.remove('id');

    return await db.update(
      'weight_records',
      updateMap,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Vaccine Records ====================
  Future<int> insertVaccineRecord(Map<String, dynamic> record) async {
    final db = await database;
    return await db.insert('vaccine_records', record);
  }

  Future<List<Map<String, dynamic>>> getAllVaccineRecords() async {
    final db = await database;
    return await db.query('vaccine_records', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getVaccineRecordsForPet(int petId) async {
    final db = await database;
    return await db.query(
      'vaccine_records',
      where: 'pet_id = ?',
      whereArgs: [petId],
      orderBy: 'date DESC',
    );
  }

  Future<int> deleteVaccineRecord(int id) async {
    final db = await database;
    return await db.delete('vaccine_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateVaccineRecord(Map<String, dynamic> record) async {
    final db = await database;
    final id = record['id'];
    if (id == null) {
      throw ArgumentError('Vaccine record ID cannot be null when updating.');
    }

    final updateMap = Map<String, dynamic>.from(record);
    updateMap.remove('id');

    return await db.update(
      'vaccine_records',
      updateMap,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Pet Profiles ====================
  Future<int> insertPetProfile(Map<String, dynamic> profile) async {
    final db = await database;
    return await db.insert('pet_profiles', profile);
  }

  Future<List<Map<String, dynamic>>> getAllPetProfiles() async {
    final db = await database;
    return await db.query('pet_profiles');
  }

  Future<int> updatePetProfile(int id, Map<String, dynamic> profile) async {
    final db = await database;
    return await db.update(
      'pet_profiles',
      profile,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 关闭数据库
  Future close() async {
    final db = await database;
    db.close();
  }
}
