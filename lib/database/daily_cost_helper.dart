import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/daily_cost_item.dart';

/// 宠物消费品日均成本数据库帮助类
class DailyCostHelper {
  static final DailyCostHelper instance = DailyCostHelper._init();
  static Database? _database;

  DailyCostHelper._init();

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('daily_cost.db');
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
      CREATE TABLE daily_cost_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemName TEXT NOT NULL,
        totalPrice REAL NOT NULL,
        purchaseDate TEXT NOT NULL,
        finishDate TEXT,
        petId INTEGER,
        petName TEXT,
        imagePath TEXT,
        note TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // 创建索引以提高查询效率
    await db.execute(
      'CREATE INDEX idx_purchase_date ON daily_cost_items(purchaseDate)',
    );
    await db.execute('CREATE INDEX idx_pet_id ON daily_cost_items(petId)');
  }

  /// 插入消费品记录
  Future<int> insertItem(DailyCostItem item) async {
    final db = await database;
    return await db.insert('daily_cost_items', item.toMap());
  }

  /// 更新消费品记录
  Future<int> updateItem(DailyCostItem item) async {
    final db = await database;
    return await db.update(
      'daily_cost_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// 删除消费品记录
  Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.delete(
      'daily_cost_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取所有消费品记录（按购买日期倒序）
  Future<List<DailyCostItem>> getAllItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_cost_items',
      orderBy: 'purchaseDate DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => DailyCostItem.fromMap(maps[i]));
  }

  /// 根据宠物ID获取消费品记录
  Future<List<DailyCostItem>> getItemsByPetId(int petId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_cost_items',
      where: 'petId = ?',
      whereArgs: [petId],
      orderBy: 'purchaseDate DESC, createdAt DESC',
    );
    return List.generate(maps.length, (i) => DailyCostItem.fromMap(maps[i]));
  }

  /// 获取总日均成本
  /// 计算所有消费品的日均成本总和
  Future<double> getTotalDailyCost() async {
    final items = await getAllItems();
    double totalDailyCost = 0.0;

    for (var item in items) {
      totalDailyCost += item.dailyCost;
    }

    return totalDailyCost;
  }

  /// 根据宠物ID获取该宠物的总日均成本
  Future<double> getDailyCostByPetId(int petId) async {
    final items = await getItemsByPetId(petId);
    double totalDailyCost = 0.0;

    for (var item in items) {
      totalDailyCost += item.dailyCost;
    }

    return totalDailyCost;
  }

  /// 获取所有消费品的总价值
  Future<double> getTotalValue() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(totalPrice) as total FROM daily_cost_items',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
