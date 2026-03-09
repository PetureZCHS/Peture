import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/pet_passport.dart';

/// 宠物身份证数据库助手
class PetPassportHelper {
  static final PetPassportHelper instance = PetPassportHelper._init();
  static Database? _database;

  PetPassportHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pet_passport.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // 创建宠物身份证表
    await db.execute('''
      CREATE TABLE pet_passports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pet_id TEXT NOT NULL UNIQUE,
        photo_path TEXT,
        owner_name TEXT,
        adoption_date TEXT,
        mbti_type TEXT,
        mbti_description TEXT,
        interest_tags TEXT,
        bio TEXT,
        friend_count INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 创建成就表
    await db.execute('''
      CREATE TABLE achievements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        passport_id INTEGER NOT NULL,
        achievement_id TEXT NOT NULL,
        achievement_name TEXT NOT NULL,
        achievement_description TEXT NOT NULL,
        icon_name TEXT NOT NULL,
        category TEXT NOT NULL,
        unlocked_at TEXT NOT NULL,
        FOREIGN KEY (passport_id) REFERENCES pet_passports (id) ON DELETE CASCADE
      )
    ''');

    // 创建索引
    await db.execute('''
      CREATE INDEX idx_pet_id ON pet_passports(pet_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_passport_id ON achievements(passport_id)
    ''');
  }

  /// 保存或更新宠物身份证
  Future<int> savePassport(PetPassport passport) async {
    final db = await database;

    // 准备数据
    final Map<String, dynamic> data = {
      'pet_id': passport.petId,
      'photo_path': passport.photoPath,
      'owner_name': passport.ownerName,
      'adoption_date': passport.adoptionDate?.toIso8601String(),
      'mbti_type': passport.mbtiType,
      'mbti_description': passport.mbtiDescription,
      'interest_tags': passport.interestTags.join(','),
      'bio': passport.bio,
      'friend_count': passport.friendCount,
      'created_at': passport.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    int passportId;

    // 检查是否已存在
    final existing = await db.query(
      'pet_passports',
      where: 'pet_id = ?',
      whereArgs: [passport.petId],
    );

    if (existing.isNotEmpty) {
      // 更新现有记录
      passportId = existing.first['id'] as int;
      await db.update(
        'pet_passports',
        data,
        where: 'id = ?',
        whereArgs: [passportId],
      );
    } else {
      // 插入新记录
      passportId = await db.insert('pet_passports', data);
    }

    // 保存成就徽章
    await _saveAchievements(passportId, passport.achievements);

    return passportId;
  }

  /// 保存成就徽章
  Future<void> _saveAchievements(
    int passportId,
    List<Achievement> achievements,
  ) async {
    final db = await database;

    // 删除旧的成就记录
    await db.delete(
      'achievements',
      where: 'passport_id = ?',
      whereArgs: [passportId],
    );

    // 插入新的成就记录
    for (var achievement in achievements) {
      await db.insert('achievements', {
        'passport_id': passportId,
        'achievement_id': achievement.id,
        'achievement_name': achievement.name,
        'achievement_description': achievement.description,
        'icon_name': achievement.iconName,
        'category': achievement.category,
        'unlocked_at': achievement.unlockedAt.toIso8601String(),
      });
    }
  }

  /// 根据宠物ID获取身份证
  Future<PetPassport?> getPassportByPetId(String petId) async {
    final db = await database;

    final results = await db.query(
      'pet_passports',
      where: 'pet_id = ?',
      whereArgs: [petId],
    );

    if (results.isEmpty) return null;

    final passportData = results.first;
    final passportId = passportData['id'] as int;

    // 获取成就徽章
    final achievementResults = await db.query(
      'achievements',
      where: 'passport_id = ?',
      whereArgs: [passportId],
    );

    final achievements = achievementResults.map((data) {
      return Achievement(
        id: data['achievement_id'] as String,
        name: data['achievement_name'] as String,
        description: data['achievement_description'] as String,
        iconName: data['icon_name'] as String,
        category: data['category'] as String,
        unlockedAt: DateTime.parse(data['unlocked_at'] as String),
      );
    }).toList();

    return PetPassport(
      id: passportId.toString(), // 转换为 String
      petId: passportData['pet_id'] as String,
      photoPath: passportData['photo_path'] as String?,
      ownerName: passportData['owner_name'] as String?,
      adoptionDate: passportData['adoption_date'] != null
          ? DateTime.parse(passportData['adoption_date'] as String)
          : null,
      mbtiType: passportData['mbti_type'] as String?,
      mbtiDescription: passportData['mbti_description'] as String?,
      interestTags: passportData['interest_tags'] != null &&
              (passportData['interest_tags'] as String).isNotEmpty
          ? (passportData['interest_tags'] as String).split(',')
          : [],
      achievements: achievements,
      bio: passportData['bio'] as String?,
      friendCount: passportData['friend_count'] as int? ?? 0,
      createdAt: DateTime.parse(passportData['created_at'] as String),
      updatedAt: DateTime.parse(passportData['updated_at'] as String),
    );
  }

  /// 获取所有身份证
  Future<List<PetPassport>> getAllPassports() async {
    final db = await database;

    final results = await db.query('pet_passports');

    List<PetPassport> passports = [];
    for (var passportData in results) {
      final passportId = passportData['id'] as int;

      // 获取成就徽章
      final achievementResults = await db.query(
        'achievements',
        where: 'passport_id = ?',
        whereArgs: [passportId],
      );

      final achievements = achievementResults.map((data) {
        return Achievement(
          id: data['achievement_id'] as String,
          name: data['achievement_name'] as String,
          description: data['achievement_description'] as String,
          iconName: data['icon_name'] as String,
          category: data['category'] as String,
          unlockedAt: DateTime.parse(data['unlocked_at'] as String),
        );
      }).toList();

      passports.add(
        PetPassport(
          id: passportId.toString(), // 转换为 String
          petId: passportData['pet_id'] as String,
          photoPath: passportData['photo_path'] as String?,
          ownerName: passportData['owner_name'] as String?,
          adoptionDate: passportData['adoption_date'] != null
              ? DateTime.parse(passportData['adoption_date'] as String)
              : null,
          mbtiType: passportData['mbti_type'] as String?,
          mbtiDescription: passportData['mbti_description'] as String?,
          interestTags: passportData['interest_tags'] != null &&
                  (passportData['interest_tags'] as String).isNotEmpty
              ? (passportData['interest_tags'] as String).split(',')
              : [],
          achievements: achievements,
          bio: passportData['bio'] as String?,
          friendCount: passportData['friend_count'] as int? ?? 0,
          createdAt: DateTime.parse(passportData['created_at'] as String),
          updatedAt: DateTime.parse(passportData['updated_at'] as String),
        ),
      );
    }

    return passports;
  }

  /// 删除宠物身份证
  Future<int> deletePassport(String petId) async {
    final db = await database;

    return await db.delete(
      'pet_passports',
      where: 'pet_id = ?',
      whereArgs: [petId],
    );
  }

  /// 解锁成就
  Future<void> unlockAchievement(String petId, Achievement achievement) async {
    final passport = await getPassportByPetId(petId);
    if (passport == null) return;

    final db = await database;
    final passportId = passport.id!;

    // 检查成就是否已存在
    final existing = await db.query(
      'achievements',
      where: 'passport_id = ? AND achievement_id = ?',
      whereArgs: [passportId, achievement.id],
    );

    if (existing.isEmpty) {
      await db.insert('achievements', {
        'passport_id': passportId,
        'achievement_id': achievement.id,
        'achievement_name': achievement.name,
        'achievement_description': achievement.description,
        'icon_name': achievement.iconName,
        'category': achievement.category,
        'unlocked_at': achievement.unlockedAt.toIso8601String(),
      });
    }
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
