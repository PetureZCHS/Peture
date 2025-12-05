/// 统一的宠物消费数据模型
class UnifiedExpense {
  final String? id; // 改为 String? 以支持 Supabase UUID
  final double amount; // 金额
  final String category; // 分类（医疗、美容、零食、消耗品、耐用品等）
  final String expenseType; // 支出类型：'one-off'(一次性) 或 'recurring'(周期性)
  final String date; // 日期（格式：yyyy-MM-dd）
  final String? petId; // 宠物ID（可选，改为 String? 以支持 UUID）
  final String? petName; // 宠物名称（用于显示）
  final String? note; // 备注
  final String? photoPath; // 照片路径（可选）

  // 周期性成本专用字段
  final String? itemName; // 物品名称（仅周期性成本）
  final String? estimatedEndDate; // 预计用完日期/使用寿命结束日期（仅周期性成本）
  final String? itemType; // 物品类型：'consumable'(消耗品) 或 'durable'(耐用品)

  final String createdAt; // 创建时间

  UnifiedExpense({
    this.id,
    required this.amount,
    required this.category,
    required this.expenseType,
    required this.date,
    this.petId,
    this.petName,
    this.note,
    this.photoPath,
    this.itemName,
    this.estimatedEndDate,
    this.itemType,
    required this.createdAt,
  });

  /// 计算使用天数（仅周期性成本）
  int get usageDays {
    if (expenseType != 'recurring') {
      return 0;
    }

    final purchase = DateTime.parse(date);
    final DateTime end;

    if (estimatedEndDate != null) {
      // 如果已填写用完日期，使用该日期
      end = DateTime.parse(estimatedEndDate!);
    } else {
      // 如果未填写用完日期，使用今天（动态计算）
      end = DateTime.now();
    }

    final difference = end.difference(purchase).inDays;
    return difference > 0 ? difference : 1;
  }

  /// 计算日均成本（仅周期性成本）
  double get dailyCost {
    if (expenseType != 'recurring' || usageDays == 0) {
      return 0.0;
    }
    return amount / usageDays;
  }

  /// 是否使用中（未填写用完日期）
  bool get isInUse => expenseType == 'recurring' && estimatedEndDate == null;

  /// 是否已用完（已填写用完日期）
  bool get isFinished => expenseType == 'recurring' && estimatedEndDate != null;

  /// 是否为一次性支出
  bool get isOneOff => expenseType == 'one-off';

  /// 是否为周期性成本
  bool get isRecurring => expenseType == 'recurring';

  /// 转换为 Map（用于数据库存储）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'expenseType': expenseType,
      'date': date,
      'petId': petId,
      'petName': petName,
      'note': note,
      'photoPath': photoPath,
      'itemName': itemName,
      'estimatedEndDate': estimatedEndDate,
      'itemType': itemType,
      'createdAt': createdAt,
    };
  }

  /// 从 Map 创建对象（从数据库读取）
  factory UnifiedExpense.fromMap(Map<String, dynamic> map) {
    // 处理 petId：支持 int、String 和 null
    String? petId;
    if (map['petId'] != null) {
      petId = map['petId'].toString();
    } else if (map['pet_id'] != null) {
      petId = map['pet_id'].toString();
    }
    
    return UnifiedExpense(
      id: map['id']?.toString(), // 支持 int 和 String
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      expenseType: map['expenseType'] as String,
      date: map['date'] as String,
      petId: petId,
      petName: map['petName'] as String? ?? map['pet_name'] as String?,
      note: map['note'] as String?,
      photoPath: map['photoPath'] as String? ?? map['photo_path'] as String?,
      itemName: map['itemName'] as String? ?? map['item_name'] as String?,
      estimatedEndDate: map['estimatedEndDate'] as String? ?? map['estimated_end_date'] as String?,
      itemType: map['itemType'] as String? ?? map['item_type'] as String?,
      createdAt: map['createdAt'] as String? ?? map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  /// 复制对象（用于编辑）
  UnifiedExpense copyWith({
    String? id,
    double? amount,
    String? category,
    String? expenseType,
    String? date,
    String? petId,
    String? petName,
    String? note,
    String? photoPath,
    String? itemName,
    String? estimatedEndDate,
    bool clearEstimatedEndDate = false, // 是否清除预计用完日期
    String? itemType,
    String? createdAt,
  }) {
    return UnifiedExpense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      expenseType: expenseType ?? this.expenseType,
      date: date ?? this.date,
      petId: petId ?? this.petId,
      petName: petName ?? this.petName,
      note: note ?? this.note,
      photoPath: photoPath ?? this.photoPath,
      itemName: itemName ?? this.itemName,
      estimatedEndDate: clearEstimatedEndDate
          ? null
          : (estimatedEndDate ?? this.estimatedEndDate),
      itemType: itemType ?? this.itemType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 支出类型枚举
enum ExpenseTypeEnum {
  oneOff('one-off', '一次性支出'),
  recurring('recurring', '周期性支出');

  final String value;
  final String label;

  const ExpenseTypeEnum(this.value, this.label);
}

/// 物品类型枚举（仅周期性成本）
enum ItemTypeEnum {
  consumable('consumable', '消耗品'),
  durable('durable', '耐用品');

  final String value;
  final String label;

  const ItemTypeEnum(this.value, this.label);
}

/// 统一的消费分类定义
class UnifiedExpenseCategory {
  final String name; // 分类名称
  final int icon; // 图标代码点
  final int color; // 颜色值
  final ExpenseTypeEnum expenseType; // 所属的支出类型

  const UnifiedExpenseCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.expenseType,
  });

  /// 一次性支出分类（单次花费）
  static const List<UnifiedExpenseCategory> oneOffCategories = [
    UnifiedExpenseCategory(
      name: '医疗问诊',
      icon: 0xe3c9,
      color: 0xFF4FC3F7,
      expenseType: ExpenseTypeEnum.oneOff,
    ), // Icons.local_hospital
    UnifiedExpenseCategory(
      name: '清洁美容',
      icon: 0xe325,
      color: 0xFFBA68C8,
      expenseType: ExpenseTypeEnum.oneOff,
    ), // Icons.bathtub
    UnifiedExpenseCategory(
      name: '零食罐头',
      icon: 0xe3a3,
      color: 0xFFFF8A65,
      expenseType: ExpenseTypeEnum.oneOff,
    ), // Icons.restaurant
    UnifiedExpenseCategory(
      name: '玩具服饰',
      icon: 0xe540,
      color: 0xFFFFD54F,
      expenseType: ExpenseTypeEnum.oneOff,
    ), // Icons.toys
    UnifiedExpenseCategory(
      name: '外出交通',
      icon: 0xe530,
      color: 0xFF81C784,
      expenseType: ExpenseTypeEnum.oneOff,
    ), // Icons.directions_car
    UnifiedExpenseCategory(
      name: '课程训练',
      icon: 0xe80c,
      color: 0xFF4DB6AC,
      expenseType: ExpenseTypeEnum.oneOff,
    ), // Icons.school
    UnifiedExpenseCategory(
      name: '宠物寄养',
      icon: 0xe318,
      color: 0xFFFF8A80,
      expenseType: ExpenseTypeEnum.oneOff,
    ), // Icons.home
    UnifiedExpenseCategory(
      name: '应急备用',
      icon: 0xe002,
      color: 0xFFE57373,
      expenseType: ExpenseTypeEnum.oneOff,
    ), // Icons.warning
    UnifiedExpenseCategory(
      name: '其他',
      icon: 0xe5d3,
      color: 0xFF90A4AE,
      expenseType: ExpenseTypeEnum.oneOff,
    ), // Icons.more_horiz
  ];

  /// 周期性成本分类（囤货消费）
  static const List<UnifiedExpenseCategory> recurringCategories = [
    UnifiedExpenseCategory(
      name: '主粮日用',
      icon: 0xe3a3,
      color: 0xFFFF8A65,
      expenseType: ExpenseTypeEnum.recurring,
    ), // Icons.restaurant
    UnifiedExpenseCategory(
      name: '健康保健',
      icon: 0xe3c9,
      color: 0xFF4FC3F7,
      expenseType: ExpenseTypeEnum.recurring,
    ), // Icons.local_hospital
    UnifiedExpenseCategory(
      name: '清洁护理',
      icon: 0xe325,
      color: 0xFFBA68C8,
      expenseType: ExpenseTypeEnum.recurring,
    ), // Icons.bathtub
    UnifiedExpenseCategory(
      name: '居住睡眠',
      icon: 0xe318,
      color: 0xFFFFD54F,
      expenseType: ExpenseTypeEnum.recurring,
    ), // Icons.home
    UnifiedExpenseCategory(
      name: '饮食器具',
      icon: 0xe1f9,
      color: 0xFF4DD0E1,
      expenseType: ExpenseTypeEnum.recurring,
    ), // Icons.local_drink
    UnifiedExpenseCategory(
      name: '出行装备',
      icon: 0xe530,
      color: 0xFF81C784,
      expenseType: ExpenseTypeEnum.recurring,
    ), // Icons.directions_car
    UnifiedExpenseCategory(
      name: '玩具娱乐',
      icon: 0xe540,
      color: 0xFF9575CD,
      expenseType: ExpenseTypeEnum.recurring,
    ), // Icons.toys
    UnifiedExpenseCategory(
      name: '保险证件',
      icon: 0xe32a,
      color: 0xFFA5D6A7,
      expenseType: ExpenseTypeEnum.recurring,
    ), // Icons.card_membership
    UnifiedExpenseCategory(
      name: '其他用品',
      icon: 0xe5d3,
      color: 0xFF90A4AE,
      expenseType: ExpenseTypeEnum.recurring,
    ), // Icons.more_horiz
  ];

  /// 获取所有分类
  static List<UnifiedExpenseCategory> get allCategories => [
    ...oneOffCategories,
    ...recurringCategories,
  ];

  /// 根据分类名称获取分类信息
  static UnifiedExpenseCategory? getCategoryByName(String name) {
    try {
      return allCategories.firstWhere((cat) => cat.name == name);
    } catch (e) {
      return null;
    }
  }
}
