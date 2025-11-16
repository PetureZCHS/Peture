import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/fitness_course.dart';

class FitnessHelper {
  static final FitnessHelper instance = FitnessHelper._init();
  static Database? _database;

  FitnessHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fitness.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE fitness_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        courseId TEXT NOT NULL,
        courseName TEXT NOT NULL,
        completedAt TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        caloriesBurned INTEGER NOT NULL,
        petCaloriesBurned INTEGER NOT NULL,
        notes TEXT
      )
    ''');
  }

  /// 添加健身记录
  Future<int> addRecord(FitnessRecord record) async {
    final db = await database;
    return await db.insert('fitness_records', record.toMap());
  }

  /// 获取所有健身记录
  Future<List<FitnessRecord>> getAllRecords() async {
    final db = await database;
    final result = await db.query(
      'fitness_records',
      orderBy: 'completedAt DESC',
    );
    return result.map((map) => FitnessRecord.fromMap(map)).toList();
  }

  /// 获取最近N天的健身记录
  Future<List<FitnessRecord>> getRecentRecords(int days) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final result = await db.query(
      'fitness_records',
      where: 'completedAt >= ?',
      whereArgs: [cutoffDate.toIso8601String()],
      orderBy: 'completedAt DESC',
    );
    return result.map((map) => FitnessRecord.fromMap(map)).toList();
  }

  /// 获取总统计数据
  Future<Map<String, int>> getTotalStats() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as totalWorkouts,
        SUM(caloriesBurned) as totalCalories,
        SUM(durationMinutes) as totalMinutes
      FROM fitness_records
    ''');

    if (result.isEmpty) {
      return {'totalWorkouts': 0, 'totalCalories': 0, 'totalMinutes': 0};
    }

    return {
      'totalWorkouts': result[0]['totalWorkouts'] as int? ?? 0,
      'totalCalories': result[0]['totalCalories'] as int? ?? 0,
      'totalMinutes': result[0]['totalMinutes'] as int? ?? 0,
    };
  }

  /// 删除记录
  Future<int> deleteRecord(int id) async {
    final db = await database;
    return await db.delete('fitness_records', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
