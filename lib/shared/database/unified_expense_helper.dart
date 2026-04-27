import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/unified_expense.dart';

/// 统一的宠物消费数据库帮助类
class UnifiedExpenseHelper {
  static final UnifiedExpenseHelper instance = UnifiedExpenseHelper._init();
  static Database? _database;

  UnifiedExpenseHelper._init();

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('unified_expenses.db');
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
      CREATE TABLE unified_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        expenseType TEXT NOT NULL,
        date TEXT NOT NULL,
        petId INTEGER,
        petName TEXT,
        note TEXT,
        photoPath TEXT,
        itemName TEXT,
        estimatedEndDate TEXT,
        itemType TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // 创建索引以提高查询效率
    await db.execute('CREATE INDEX idx_date ON unified_expenses(date)');
    await db.execute(
      'CREATE INDEX idx_expense_type ON unified_expenses(expenseType)',
    );
    await db.execute('CREATE INDEX idx_pet_id ON unified_expenses(petId)');
  }

  /// 插入消费记录
  Future<int> insertExpense(UnifiedExpense expense) async {
    final db = await database;
    return await db.insert('unified_expenses', expense.toMap());
  }

  /// 更新消费记录
  Future<int> updateExpense(UnifiedExpense expense) async {
    final db = await database;
    return await db.update(
      'unified_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  /// 删除消费记录
  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete(
      'unified_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取所有消费记录（按日期倒序）
  Future<List<UnifiedExpense>> getAllExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'unified_expenses',
      orderBy: 'date DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => UnifiedExpense.fromMap(maps[i]));
  }

  /// 获取所有一次性支出
  Future<List<UnifiedExpense>> getOneOffExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'unified_expenses',
      where: 'expenseType = ?',
      whereArgs: ['one-off'],
      orderBy: 'date DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => UnifiedExpense.fromMap(maps[i]));
  }

  /// 获取所有周期性成本
  Future<List<UnifiedExpense>> getRecurringExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'unified_expenses',
      where: 'expenseType = ?',
      whereArgs: ['recurring'],
      orderBy: 'date DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => UnifiedExpense.fromMap(maps[i]));
  }

  /// 根据宠物ID获取消费记录
  Future<List<UnifiedExpense>> getExpensesByPetId(int petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'unified_expenses',
      where: 'petId = ?',
      whereArgs: [petId],
      orderBy: 'date DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => UnifiedExpense.fromMap(maps[i]));
  }

  /// 根据日期范围获取消费记录
  Future<List<UnifiedExpense>> getExpensesByDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'unified_expenses',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => UnifiedExpense.fromMap(maps[i]));
  }

  /// 获取指定月份的总支出
  Future<double> getMonthlyTotal(int year, int month) async {
    final db = await database;
    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final endDate = '$year-${month.toString().padLeft(2, '0')}-31';

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM unified_expenses WHERE date >= ? AND date <= ?',
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
      'SELECT SUM(amount) as total FROM unified_expenses WHERE date >= ? AND date <= ?',
      [startDate, endDate],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// 获取总日均成本（所有周期性成本的日均成本总和）
  Future<double> getTotalDailyCost() async {
    final recurringExpenses = await getRecurringExpenses();
    double totalDailyCost = 0.0;

    for (var expense in recurringExpenses) {
      totalDailyCost += expense.dailyCost;
    }

    return totalDailyCost;
  }

  /// 根据宠物ID获取该宠物的总日均成本
  Future<double> getDailyCostByPetId(int petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'unified_expenses',
      where: 'petId = ? AND expenseType = ?',
      whereArgs: [petId, 'recurring'],
    );

    final expenses = List.generate(
      maps.length,
      (i) => UnifiedExpense.fromMap(maps[i]),
    );
    double totalDailyCost = 0.0;

    for (var expense in expenses) {
      totalDailyCost += expense.dailyCost;
    }

    return totalDailyCost;
  }

  /// 获取分类统计（指定日期范围）
  Future<Map<String, double>> getCategoryStatistics(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT category, SUM(amount) as total FROM unified_expenses WHERE date >= ? AND date <= ? GROUP BY category ORDER BY total DESC',
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
      'SELECT SUM(amount) as total FROM unified_expenses',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
