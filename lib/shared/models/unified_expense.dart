import 'package:flutter/material.dart';

final Map<int, IconData> _materialIconByCodePoint = {
  // Core expense and ledger icons
  Icons.home.codePoint: Icons.home,
  Icons.star.codePoint: Icons.star,
  Icons.favorite.codePoint: Icons.favorite,
  Icons.category.codePoint: Icons.category,
  Icons.book.codePoint: Icons.book,
  Icons.shopping_cart.codePoint: Icons.shopping_cart,
  Icons.local_cafe.codePoint: Icons.local_cafe,
  Icons.pets.codePoint: Icons.pets,
  Icons.sports_esports.codePoint: Icons.sports_esports,
  Icons.add.codePoint: Icons.add,
  Icons.store.codePoint: Icons.store,
  Icons.local_hospital.codePoint: Icons.local_hospital,
  Icons.restaurant.codePoint: Icons.restaurant,
  Icons.toys.codePoint: Icons.toys,
  Icons.shopping_bag.codePoint: Icons.shopping_bag,
  Icons.more_horiz.codePoint: Icons.more_horiz,
  Icons.medication.codePoint: Icons.medication,
  Icons.cleaning_services.codePoint: Icons.cleaning_services,
  Icons.inventory_2.codePoint: Icons.inventory_2,
  Icons.chair.codePoint: Icons.chair,
};

IconData materialIconFromCodePoint(int codePoint) {
  return _materialIconByCodePoint[codePoint] ?? Icons.more_horiz;
}

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
      estimatedEndDate: map['estimatedEndDate'] as String? ??
          map['estimated_end_date'] as String?,
      itemType: map['itemType'] as String? ?? map['item_type'] as String?,
      createdAt: map['createdAt'] as String? ??
          map['created_at']?.toString() ??
          DateTime.now().toIso8601String(),
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
  static final List<UnifiedExpenseCategory> oneOffCategories = [
    UnifiedExpenseCategory(
      name: '医疗/兽医',
      icon: Icons.local_hospital.codePoint,
      color: 0xFFE57373, // 深红 - 医疗刚需
      expenseType: ExpenseTypeEnum.oneOff,
    ),
    UnifiedExpenseCategory(
      name: '美容/洗护',
      icon: Icons.bathtub.codePoint,
      color: 0xFF4FC3F7, // 深蓝 - 生活品质
      expenseType: ExpenseTypeEnum.oneOff,
    ),
    UnifiedExpenseCategory(
      name: '寄养/服务',
      icon: Icons.store.codePoint,
      color: 0xFF9575CD, // 深紫 - 专业服务
      expenseType: ExpenseTypeEnum.oneOff,
    ),
    UnifiedExpenseCategory(
      name: '宠物食品',
      icon: Icons.restaurant.codePoint,
      color: 0xFFFFB74D, // 橙色 - 生存刚需
      expenseType: ExpenseTypeEnum.oneOff,
    ),
    UnifiedExpenseCategory(
      name: '玩具/娱乐',
      icon: Icons.toys.codePoint,
      color: 0xFFFFD54F, // 明黄 - 情感连接
      expenseType: ExpenseTypeEnum.oneOff,
    ),
    UnifiedExpenseCategory(
      name: '用品/配件',
      icon: Icons.shopping_bag.codePoint,
      color: 0xFF81C784, // 草绿 - 户外/生活
      expenseType: ExpenseTypeEnum.oneOff,
    ),
    UnifiedExpenseCategory(
      name: '其他',
      icon: Icons.more_horiz.codePoint,
      color: 0xFF90A4AE, // 灰色 - 其他
      expenseType: ExpenseTypeEnum.oneOff,
    ),
  ];

  /// 周期性成本分类（囤货消费）
  static final List<UnifiedExpenseCategory> recurringCategories = [
    UnifiedExpenseCategory(
      name: '宠物食品',
      icon: Icons.restaurant.codePoint,
      color: 0xFFFFCC80, // 浅橙 - 食品大类（与一次性食品区分明度）
      expenseType: ExpenseTypeEnum.recurring,
    ),
    UnifiedExpenseCategory(
      name: '健康保健',
      icon: Icons.medication.codePoint,
      color: 0xFFEF9A9A, // 浅红 - 医疗大类（与一次性医疗区分明度）
      expenseType: ExpenseTypeEnum.recurring,
    ),
    UnifiedExpenseCategory(
      name: '清洁用品',
      icon: Icons.cleaning_services.codePoint,
      color: 0xFF81D4FA, // 天蓝 - 洗护大类（与一次性洗护区分明度）
      expenseType: ExpenseTypeEnum.recurring,
    ),
    UnifiedExpenseCategory(
      name: '其他消耗品',
      icon: Icons.inventory_2.codePoint,
      color: 0xFFB0BEC5, // 浅灰 - 其他大类
      expenseType: ExpenseTypeEnum.recurring,
    ),
    UnifiedExpenseCategory(
      name: '耐用品/设备',
      icon: Icons.chair.codePoint,
      color: 0xFFAED581, // 浅绿 - 用品大类
      expenseType: ExpenseTypeEnum.recurring,
    ),
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
      // 模糊匹配旧分类
      if (name.contains('医疗') || name.contains('诊治')) {
        return oneOffCategories[0];
      }
      if (name.contains('美容') || name.contains('洗护') || name.contains('清洁')) {
        return oneOffCategories[1];
      }
      if (name.contains('寄养') || name.contains('服务')) {
        return oneOffCategories[2];
      }
      if (name.contains('食') || name.contains('粮') || name.contains('零食')) {
        return oneOffCategories[3];
      }
      if (name.contains('玩具') || name.contains('娱乐') || name.contains('服饰')) {
        return oneOffCategories[4];
      }
      if (name.contains('用品') || name.contains('装备') || name.contains('交通')) {
        return oneOffCategories[5];
      }

      return oneOffCategories.last;
    }
  }
}
