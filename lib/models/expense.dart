/// 宠物账单数据模型
class Expense {
  final String? id; // 改为 String? 以支持 Supabase UUID
  final double amount; // 金额
  final String category; // 分类（食品、医疗、玩具、洗护、用品等）
  final String date; // 日期（格式：yyyy-MM-dd）
  final int? petId; // 宠物ID（可选，如果用户有多只宠物）
  final String? petName; // 宠物名称（用于显示）
  final String? note; // 备注
  final String? photoPath; // 照片路径（可选）
  final String createdAt; // 创建时间

  Expense({
    this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.petId,
    this.petName,
    this.note,
    this.photoPath,
    required this.createdAt,
  });

  /// 转换为 Map（用于数据库存储）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'date': date,
      'petId': petId,
      'petName': petName,
      'note': note,
      'photoPath': photoPath,
      'createdAt': createdAt,
    };
  }

  /// 从 Map 创建对象（从数据库读取）
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id']?.toString(), // 支持 int 和 String
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      date: map['date'] as String,
      petId: map['petId'] as int?,
      petName: map['petName'] as String?,
      note: map['note'] as String?,
      photoPath: map['photoPath'] as String?,
      createdAt: map['createdAt'] as String,
    );
  }

  /// 复制对象（用于编辑）
  Expense copyWith({
    String? id,
    double? amount,
    String? category,
    String? date,
    int? petId,
    String? petName,
    String? note,
    String? photoPath,
    String? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      petId: petId ?? this.petId,
      petName: petName ?? this.petName,
      note: note ?? this.note,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 消费分类定义
class ExpenseCategory {
  final String name; // 分类名称
  final int icon; // 图标代码点 (IconData 的 codePoint)
  final int color; // 颜色值 (ARGB 格式的整数)

  const ExpenseCategory({
    required this.name,
    required this.icon,
    required this.color,
  });

  /// 默认分类列表
  static const List<ExpenseCategory> defaultCategories = [
    ExpenseCategory(
      name: '食品',
      icon: 0xe3a3,
      color: 0xFFFF8A65,
    ), // Icons.restaurant
    ExpenseCategory(
      name: '医疗',
      icon: 0xe3c9,
      color: 0xFF4FC3F7,
    ), // Icons.local_hospital
    ExpenseCategory(name: '玩具', icon: 0xe540, color: 0xFFFFD54F), // Icons.toys
    ExpenseCategory(
      name: '洗护',
      icon: 0xe325,
      color: 0xFF81C784,
    ), // Icons.bathtub
    ExpenseCategory(
      name: '用品',
      icon: 0xe8f6,
      color: 0xFFBA68C8,
    ), // Icons.shopping_bag
    ExpenseCategory(
      name: '培训',
      icon: 0xe80c,
      color: 0xFF4DB6AC,
    ), // Icons.school
    ExpenseCategory(name: '寄养', icon: 0xe318, color: 0xFFFF8A80), // Icons.home
    ExpenseCategory(
      name: '其他',
      icon: 0xe5d3,
      color: 0xFF90A4AE,
    ), // Icons.more_horiz
  ];

  /// 根据分类名称获取分类信息
  static ExpenseCategory? getCategoryByName(String name) {
    try {
      return defaultCategories.firstWhere((cat) => cat.name == name);
    } catch (e) {
      return null;
    }
  }
}
