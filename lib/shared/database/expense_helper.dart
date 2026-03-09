import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';

/// 宠物账单数据库帮助类
class ExpenseHelper {
  static final ExpenseHelper instance = ExpenseHelper._init();
  static Database? _database;

  ExpenseHelper._init();

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pet_expenses.db');
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  /// 创建数据库表
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        petId INTEGER,
        petName TEXT,
        note TEXT,
        photoPath TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // 创建索引以提高查询效率
    await db.execute('CREATE INDEX idx_date ON expenses(date)');
    await db.execute('CREATE INDEX idx_category ON expenses(category)');
    await db.execute('CREATE INDEX idx_petId ON expenses(petId)');
  }

  /// 插入账单
  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return await db.insert('expenses', expense.toMap());
  }

  /// 更新账单
  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  /// 删除账单
  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  /// 获取所有账单（按日期倒序）
  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      orderBy: 'date DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  /// 根据日期范围获取账单
  Future<List<Expense>> getExpensesByDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  /// 根据宠物ID获取账单
  Future<List<Expense>> getExpensesByPetId(int petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'petId = ?',
      whereArgs: [petId],
      orderBy: 'date DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  /// 获取指定月份的总支出
  Future<double> getMonthlyTotal(int year, int month) async {
    final db = await database;
    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final endDate = '$year-${month.toString().padLeft(2, '0')}-31';

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE date >= ? AND date <= ?',
      [startDate, endDate],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// 获取指定年份的总支出
  Future<double> getYearlyTotal(int year) async {
    final db = await database;
    final startDate = '$year-01-01';
    final endDate = '$year-12-31';

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE date >= ? AND date <= ?',
      [startDate, endDate],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// 获取分类统计（指定日期范围）
  Future<Map<String, double>> getCategoryStatistics(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT category, SUM(amount) as total FROM expenses WHERE date >= ? AND date <= ? GROUP BY category ORDER BY total DESC',
      [startDate, endDate],
    );

    Map<String, double> statistics = {};
    for (var row in result) {
      statistics[row['category'] as String] = (row['total'] as num).toDouble();
    }
    return statistics;
  }

  /// 获取所有支出总额
  Future<double> getTotalExpenses() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
