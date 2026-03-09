import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/conversation.dart';
import '../models/pet_diary.dart';

class DatabaseHelper {
  // 单例模式
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('conversations.db');
    return _database!;
  }

  // 初始化数据库
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // 创建数据表 (这是我们修改的地方)
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question TEXT NOT NULL,
        answer TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        is_pinned INTEGER DEFAULT 0 
      )
    ''');

    // v2: 新增宠物日记表
    // v3: 扩展宠物日记表结构
    await db.execute('''
      CREATE TABLE pet_diaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_text TEXT NOT NULL,
        content TEXT NOT NULL,
        style TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  // 数据库升级：从 v1 -> v2 -> v3
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pet_diaries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          content TEXT NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      // 升级到v3：添加 original_text 和 style 字段
      await db.execute('''
        ALTER TABLE pet_diaries ADD COLUMN original_text TEXT DEFAULT ''
      ''');
      await db.execute('''
        ALTER TABLE pet_diaries ADD COLUMN style TEXT DEFAULT '小红书'
      ''');
    }
  }

  // 插入新对话
  Future<int> insertConversation(Conversation conversation) async {
    final db = await database;
    return await db.insert('conversations', conversation.toMap());
  }

  // 获取所有对话（按时间倒序）
  Future<List<Conversation>> getAllConversations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'conversations',
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return Conversation.fromMap(maps[i]);
    });
  }

  // 根据ID获取单个对话
  Future<Conversation?> getConversation(int id) async {
    final db = await database;
    final maps = await db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Conversation.fromMap(maps.first);
    }
    return null;
  }

  // 删除对话
  Future<int> deleteConversation(int id) async {
    final db = await database;
    return await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  // 更新对话
  Future<int> updateConversation(Conversation conversation) async {
    final db = await database;
    return await db.update(
      'conversations',
      conversation.toMap(),
      where: 'id = ?',
      whereArgs: [int.parse(conversation.id!)],
    );
  }

  // 删除所有对话
  Future<int> deleteAllConversations() async {
    final db = await database;
    return await db.delete('conversations');
  }

  // ==================== Pet Diary CRUD ====================
  Future<int> insertDiary(PetDiary diary) async {
    final db = await database;
    return await db.insert('pet_diaries', diary.toMap());
  }

  Future<List<PetDiary>> getAllDiaries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pet_diaries',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => PetDiary.fromMap(maps[i]));
  }

  Future<int> deleteDiary(int id) async {
    final db = await database;
    return await db.delete('pet_diaries', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllDiaries() async {
    final db = await database;
    return await db.delete('pet_diaries');
  }

  // 关闭数据库
  Future close() async {
    final db = await database;
    db.close();
  }
}
